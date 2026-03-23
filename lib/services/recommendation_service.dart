import '../models/anime.dart';
import '../models/user_anime_entry.dart';
import 'api_service.dart';
import 'user_anime_list_service.dart';

class RecommendationService {
  RecommendationService({
    ApiService? apiService,
    UserAnimeListService? listService,
  })  : _apiService = apiService ?? ApiService(),
        _listService = listService ?? UserAnimeListService();

  final ApiService _apiService;
  final UserAnimeListService _listService;

  Future<List<Anime>> getRecommendations({int limit = 24}) async {
    final entries = await _listService.fetchUserList();
    if (entries.isEmpty) {
      return _apiService.getTopAnime(page: 1);
    }

    final libraryIds = entries.map((e) => e.animeId).toSet();
    final scored = entries.where((e) => (e.score ?? 0) >= 7).toList();
    final seedEntries = (scored.isNotEmpty ? scored : entries)
        .where((e) => e.status != AnimeListStatus.dropped)
        .take(4)
        .toList();

    final collected = <Anime>[];
    final seen = <int>{};

    for (final seed in seedEntries) {
      final recs = await _apiService.getAnimeRecommendations(seed.animeId);
      for (final rec in recs.take(8)) {
        if (libraryIds.contains(rec.id) || seen.contains(rec.id)) {
          continue;
        }

        try {
          final details = await _apiService.getAnimeDetails(rec.id);
          collected.add(details);
          seen.add(details.id);
          if (collected.length >= limit) {
            return collected;
          }
        } catch (_) {
          // Ignore failing detail fetches to keep recommendation flow resilient.
        }
      }
    }

    if (collected.length < limit) {
      final fallback = await _apiService.getTopAnime(page: 1);
      for (final anime in fallback) {
        if (libraryIds.contains(anime.id) || seen.contains(anime.id)) {
          continue;
        }
        collected.add(anime);
        seen.add(anime.id);
        if (collected.length >= limit) {
          break;
        }
      }
    }

    return collected;
  }
}
