class AnimeRecommendation {
  final int id;
  final String title;
  final String imageUrl;

  AnimeRecommendation({
    required this.id,
    required this.title,
    required this.imageUrl,
  });

  factory AnimeRecommendation.fromJson(Map<String, dynamic> json) {
    return AnimeRecommendation(
      id: json['entry']['mal_id'],
      title: json['entry']['title'],
      imageUrl: json['entry']['images']['jpg']['large_image_url'],
    );
  }
}
