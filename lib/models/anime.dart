class Anime {
  final int id;
  final String title;
  final String imageUrl;
  final String synopsis;
  final String type;
  final String source;
  final String score;
  final double? numericScore;
  final int? year;
  final List<String> studios;
  final List<String> genres;
  final List<String> themes;
  final List<String> demographics;
  final String? trailerUrl;

  String get primaryStudio => studios.isEmpty ? 'Unknown' : studios.first;

  List<String> get tags => [...themes, ...demographics];

  Anime({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.synopsis,
    required this.type,
    required this.source,
    required this.score,
    required this.numericScore,
    required this.year,
    required this.studios,
    required this.genres,
    required this.themes,
    required this.demographics,
    this.trailerUrl,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['mal_id'],
      title: json['title'],
      imageUrl: json['images']['jpg']['large_image_url'],
      synopsis: json['synopsis'] ?? 'No synopsis available.',
      type: json['type'] ?? 'N/A',
      source: (json['source'] ?? 'Unknown').toString(),
      score: json['score']?.toString() ?? 'N/A',
      numericScore: (json['score'] as num?)?.toDouble(),
      year: (json['year'] as num?)?.toInt() ??
          (json['aired']?['prop']?['from']?['year'] as num?)?.toInt(),
      studios: (json['studios'] as List<dynamic>? ?? const [])
          .map((studio) => (studio['name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toList(),
      genres: (json['genres'] as List<dynamic>)
          .map((genre) => genre['name'] as String)
          .toList(),
      themes: (json['themes'] as List<dynamic>? ?? const [])
          .map((theme) => (theme['name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toList(),
      demographics: (json['demographics'] as List<dynamic>? ?? const [])
          .map((demographic) => (demographic['name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toList(),
      trailerUrl: json['trailer']?['url'],
    );
  }
}
