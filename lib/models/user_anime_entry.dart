enum AnimeListStatus {
  watching,
  completed,
  dropped,
  planToWatch,
}

extension AnimeListStatusX on AnimeListStatus {
  String get value {
    switch (this) {
      case AnimeListStatus.watching:
        return 'watching';
      case AnimeListStatus.completed:
        return 'completed';
      case AnimeListStatus.dropped:
        return 'dropped';
      case AnimeListStatus.planToWatch:
        return 'plan_to_watch';
    }
  }

  static AnimeListStatus fromValue(String value) {
    switch (value) {
      case 'watching':
        return AnimeListStatus.watching;
      case 'completed':
        return AnimeListStatus.completed;
      case 'dropped':
        return AnimeListStatus.dropped;
      case 'plan_to_watch':
      default:
        return AnimeListStatus.planToWatch;
    }
  }
}

class UserAnimeEntry {
  final int id;
  final String userId;
  final int animeId;
  final String animeTitle;
  final String? animeImageUrl;
  final AnimeListStatus status;
  final int episodesWatched;
  final int? score;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAnimeEntry({
    required this.id,
    required this.userId,
    required this.animeId,
    required this.animeTitle,
    required this.animeImageUrl,
    required this.status,
    required this.episodesWatched,
    required this.score,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAnimeEntry.fromJson(Map<String, dynamic> json) {
    return UserAnimeEntry(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      animeId: (json['anime_id'] as num).toInt(),
      animeTitle: json['anime_title'] as String,
      animeImageUrl: json['anime_image_url'] as String?,
      status: AnimeListStatusX.fromValue(json['status'] as String),
      episodesWatched: (json['episodes_watched'] as num).toInt(),
      score: (json['score'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
