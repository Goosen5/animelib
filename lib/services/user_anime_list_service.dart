import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/anime.dart';
import '../models/user_anime_entry.dart';

class UserAnimeListService {
  UserAnimeListService();

  List<UserAnimeEntry>? _cachedEntries;
  DateTime? _cacheExpiry;

  supabase.User? get _currentUser {
    try {
      return supabase.Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String _requireUserId() {
    final uid = _currentUser?.id;
    if (uid == null) {
      throw Exception('Not authenticated');
    }
    return uid;
  }

  Future<String> get _userId async => _requireUserId();

  Future<UserAnimeEntry> addAnimeToList({
    required Anime anime,
    AnimeListStatus status = AnimeListStatus.planToWatch,
    int episodesWatched = 0,
    int? score,
  }) async {
    _validateInput(episodesWatched: episodesWatched, score: score);

    final userId = await _userId;
    final entries = await _loadEntries(userId);

    final now = DateTime.now();
    final index = entries.indexWhere((e) => e.animeId == anime.id);

    UserAnimeEntry entry;
    if (index >= 0) {
      final old = entries[index];
      entry = UserAnimeEntry(
        id: old.id,
        userId: userId,
        animeId: anime.id,
        animeTitle: anime.title,
        animeImageUrl: anime.imageUrl,
        status: status,
        episodesWatched: episodesWatched,
        score: score,
        createdAt: old.createdAt,
        updatedAt: now,
      );
      entries[index] = entry;
    } else {
      final nextId = entries.isEmpty
          ? 1
          : entries.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;

      entry = UserAnimeEntry(
        id: nextId,
        userId: userId,
        animeId: anime.id,
        animeTitle: anime.title,
        animeImageUrl: anime.imageUrl,
        status: status,
        episodesWatched: episodesWatched,
        score: score,
        createdAt: now,
        updatedAt: now,
      );
      entries.add(entry);
    }

    await _saveEntries(userId, entries);
    _invalidateCache();
    return entry;
  }

  Future<UserAnimeEntry> updateProgress({
    required int animeId,
    AnimeListStatus? status,
    int? episodesWatched,
    int? score,
    bool clearScore = false,
  }) async {
    _validateInput(episodesWatched: episodesWatched, score: score);

    if (status == null && episodesWatched == null && score == null && !clearScore) {
      throw ArgumentError('No update values provided.');
    }

    final userId = await _userId;
    final entries = await _loadEntries(userId);
    final index = entries.indexWhere((e) => e.animeId == animeId);
    if (index < 0) {
      throw Exception('Anime entry not found.');
    }

    final old = entries[index];
    final updated = UserAnimeEntry(
      id: old.id,
      userId: old.userId,
      animeId: old.animeId,
      animeTitle: old.animeTitle,
      animeImageUrl: old.animeImageUrl,
      status: status ?? old.status,
      episodesWatched: episodesWatched ?? old.episodesWatched,
      score: clearScore ? null : (score ?? old.score),
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );

    entries[index] = updated;
    await _saveEntries(userId, entries);
    _invalidateCache();
    return updated;
  }

  Future<List<UserAnimeEntry>> fetchUserList({AnimeListStatus? status}) async {
    final now = DateTime.now();
    if (status == null &&
        _cachedEntries != null &&
        _cacheExpiry != null &&
        now.isBefore(_cacheExpiry!)) {
      return List<UserAnimeEntry>.from(_cachedEntries!);
    }

    final userId = await _userId;
    final entries = await _loadEntries(userId);
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (status == null) {
      _cachedEntries = List<UserAnimeEntry>.from(entries);
      _cacheExpiry = now.add(const Duration(seconds: 30));
      return entries;
    }

    return entries.where((entry) => entry.status == status).toList();
  }

  Future<UserAnimeEntry?> fetchUserEntryForAnime(int animeId) async {
    final entries = await fetchUserList();
    for (final entry in entries) {
      if (entry.animeId == animeId) {
        return entry;
      }
    }
    return null;
  }

  Future<List<UserAnimeEntry>> _loadEntries(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUser(userId));
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => UserAnimeEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveEntries(String userId, List<UserAnimeEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      entries.map((entry) {
        return {
          'id': entry.id,
          'user_id': entry.userId,
          'anime_id': entry.animeId,
          'anime_title': entry.animeTitle,
          'anime_image_url': entry.animeImageUrl,
          'status': entry.status.value,
          'episodes_watched': entry.episodesWatched,
          'score': entry.score,
          'created_at': entry.createdAt.toIso8601String(),
          'updated_at': entry.updatedAt.toIso8601String(),
        };
      }).toList(),
    );
    await prefs.setString(_keyForUser(userId), encoded);
  }

  String _keyForUser(String userId) => 'local_library_$userId';

  void _validateInput({int? episodesWatched, int? score}) {
    if (episodesWatched != null && episodesWatched < 0) {
      throw ArgumentError('episodesWatched cannot be negative.');
    }

    if (score != null && (score < 0 || score > 10)) {
      throw ArgumentError('score must be between 0 and 10.');
    }
  }

  void _invalidateCache() {
    _cachedEntries = null;
    _cacheExpiry = null;
  }
}
