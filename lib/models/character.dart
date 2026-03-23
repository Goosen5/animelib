class Character {
  final int id;
  final String name;
  final String imageUrl;
  final String role;

  Character({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.role,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['character']['mal_id'],
      name: json['character']['name'],
      imageUrl: json['character']['images']['jpg']['image_url'],
      role: json['role'],
    );
  }
}
