import '../models/user_anime_entry.dart';
import '../models/user_stats.dart';
import 'user_anime_list_service.dart';

class StatisticsService {
  StatisticsService({UserAnimeListService? listService})
      : _listService = listService ?? UserAnimeListService();

  final UserAnimeListService _listService;

  Future<UserStats> getUserStats() async {
    final entries = await _listService.fetchUserList();
    final total = entries.length;
    final watching =
        entries.where((e) => e.status == AnimeListStatus.watching).length;
    final completed =
        entries.where((e) => e.status == AnimeListStatus.completed).length;
    final dropped =
        entries.where((e) => e.status == AnimeListStatus.dropped).length;
    final planToWatch =
        entries.where((e) => e.status == AnimeListStatus.planToWatch).length;

    final scored = entries.where((e) => e.score != null).toList();
    final averageScore = scored.isEmpty
        ? 0.0
        : scored
                .map((e) => e.score!.toDouble())
                .reduce((a, b) => a + b) /
            scored.length;

    final completionRate =
        total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0).toDouble();

    return UserStats(
      total: total,
      watching: watching,
      completed: completed,
      dropped: dropped,
      planToWatch: planToWatch,
      averageScore: averageScore,
      completionRate: completionRate,
    );
  }
}
