import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/anime.dart';
import '../models/aniguessr_round.dart';
import '../models/anime_recommendation.dart';
import '../models/character.dart';
import '../models/genre.dart';

class ApiService {
  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.jikan.moe/v4',
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 8),
          ),
        );

  final Dio _dio;

  final Map<String, _CacheEntry<dynamic>> _cache = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  static const Set<String> _blockedContentTags = {
    'ecchi',
    'erotica',
    'hentai',
  };

  bool _isBlockedAnime(Anime anime) {
    final type = anime.type.toLowerCase().trim();
    if (_blockedContentTags.contains(type)) {
      return true;
    }

    for (final genre in anime.genres) {
      final normalizedGenre = genre.toLowerCase().trim();
      if (_blockedContentTags.contains(normalizedGenre)) {
        return true;
      }
    }

    return false;
  }

  List<Anime> _filterBlockedContent(List<Anime> animeList) {
    return animeList.where((anime) => !_isBlockedAnime(anime)).toList();
  }

  int _dayOfYear(DateTime date) {
    final first = DateTime(date.year, 1, 1);
    return date.difference(first).inDays + 1;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _makeKey(String endpoint, [Map<String, dynamic>? query]) {
    if (query == null || query.isEmpty) {
      return endpoint;
    }

    final sortedEntries = query.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '$endpoint?${jsonEncode(Map.fromEntries(sortedEntries))}';
  }

  Future<T> _cachedRequest<T>({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    required Duration ttl,
    required T Function(dynamic data) parser,
  }) async {
    final key = _makeKey(endpoint, queryParameters);
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data as T;
    }

    if (_inFlight.containsKey(key)) {
      return await _inFlight[key] as T;
    }

    final future = () async {
      final response = await _dio.get(endpoint, queryParameters: queryParameters);
      final parsed = parser(response.data['data']);
      _cache[key] = _CacheEntry(parsed, DateTime.now().add(ttl));
      return parsed;
    }();

    _inFlight[key] = future;

    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<List<Anime>> getTopAnime({int page = 1, int? genreId}) async {
    final endpoint = genreId == null ? '/top/anime' : '/anime';
    final query = <String, dynamic>{'page': page};
    if (genreId != null) {
      query['genres'] = genreId;
    }

    return _cachedRequest<List<Anime>>(
      endpoint: endpoint,
      queryParameters: query,
      ttl: const Duration(minutes: 15),
      parser: (data) {
        final animeList = (data as List<dynamic>)
            .map((json) => Anime.fromJson(json as Map<String, dynamic>))
            .toList();
        return _filterBlockedContent(animeList);
      },
    );
  }

  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    return _cachedRequest<List<Anime>>(
      endpoint: '/anime',
      queryParameters: {'q': query, 'page': page},
      ttl: const Duration(minutes: 5),
      parser: (data) {
        final animeList = (data as List<dynamic>)
            .map((json) => Anime.fromJson(json as Map<String, dynamic>))
            .toList();
        return _filterBlockedContent(animeList);
      },
    );
  }

  Future<Anime> getAnimeDetails(int id) async {
    return _cachedRequest<Anime>(
      endpoint: '/anime/$id/full',
      ttl: const Duration(minutes: 30),
      parser: (data) => Anime.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<Character>> getAnimeCharacters(int id) async {
    return _cachedRequest<List<Character>>(
      endpoint: '/anime/$id/characters',
      ttl: const Duration(minutes: 30),
      parser: (data) => (data as List<dynamic>)
          .map((json) => Character.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<AnimeRecommendation>> getAnimeRecommendations(int id) async {
    return _cachedRequest<List<AnimeRecommendation>>(
      endpoint: '/anime/$id/recommendations',
      ttl: const Duration(minutes: 20),
      parser: (data) => (data as List<dynamic>)
          .map((json) => AnimeRecommendation.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<Genre>> getGenres() async {
    return _cachedRequest<List<Genre>>(
      endpoint: '/genres/anime',
      ttl: const Duration(hours: 6),
      parser: (data) => (data as List<dynamic>)
          .map((json) => Genre.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<AniGuessrRound> getRandomAnimeRound() async {
    final response = await _dio.get('/random/anime');
    return AniGuessrRound.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Anime> getDailyAnime({DateTime? date}) async {
    final current = date ?? DateTime.now();
    final day = _dayOfYear(current);
    final seed = (current.year * 1000) + day;

    final page = (seed % 10) + 1;
    final topAnime = await getTopAnime(page: page);

    if (topAnime.isEmpty) {
      throw Exception('No anime available for today');
    }

    final index = seed % topAnime.length;
    return topAnime[index];
  }

  Future<Anime?> resolveAnimeGuess(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final results = await searchAnime(trimmed, page: 1);
    if (results.isEmpty) {
      return null;
    }

    final normalizedQuery = _normalize(trimmed);

    for (final anime in results) {
      final normalizedTitle = _normalize(anime.title);
      if (normalizedQuery == normalizedTitle) {
        return anime;
      }
    }

    for (final anime in results) {
      final normalizedTitle = _normalize(anime.title);
      if (normalizedTitle.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedTitle)) {
        return anime;
      }
    }

    return results.first;
  }

  Future<List<Anime>> getGuessSuggestions(String query, {int limit = 8}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final results = await searchAnime(trimmed, page: 1);
    if (results.isEmpty) {
      return const [];
    }

    final seen = <int>{};
    final suggestions = <Anime>[];
    final normalizedQuery = _normalize(trimmed);

    for (final anime in results) {
      if (seen.contains(anime.id)) {
        continue;
      }

      final normalizedTitle = _normalize(anime.title);
      if (normalizedTitle.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedTitle)) {
        suggestions.add(anime);
        seen.add(anime.id);
      }

      if (suggestions.length >= limit) {
        return suggestions;
      }
    }

    for (final anime in results) {
      if (suggestions.length >= limit) {
        break;
      }
      if (seen.add(anime.id)) {
        suggestions.add(anime);
      }
    }

    return suggestions;
  }

  void clearCache() {
    _cache.clear();
  }
}

class _CacheEntry<T> {
  _CacheEntry(this.data, this.expiresAt);

  final T data;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
