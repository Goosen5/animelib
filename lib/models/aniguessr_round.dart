class AniGuessrRound {
  final int animeId;
  final String imageUrl;
  final String displayTitle;
  final List<String> acceptedTitles;

  AniGuessrRound({
    required this.animeId,
    required this.imageUrl,
    required this.displayTitle,
    required this.acceptedTitles,
  });

  factory AniGuessrRound.fromJson(Map<String, dynamic> json) {
    final List<String> titles = [];

    void addTitle(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        titles.add(value.trim());
      }
    }

    addTitle(json['title']);
    addTitle(json['title_english']);
    addTitle(json['title_japanese']);

    final titleSynonyms = json['title_synonyms'];
    if (titleSynonyms is List) {
      for (final synonym in titleSynonyms) {
        addTitle(synonym);
      }
    }

    return AniGuessrRound(
      animeId: (json['mal_id'] as num).toInt(),
      imageUrl: (json['images']?['jpg']?['large_image_url'] ??
              json['images']?['jpg']?['image_url'] ??
              '')
          .toString(),
      displayTitle: (json['title'] ?? 'Unknown title').toString(),
      acceptedTitles: titles.toSet().toList(),
    );
  }
}
