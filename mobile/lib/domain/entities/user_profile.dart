class UserProfile {
  final String id;
  final String username;
  final String name;
  final String profileImageUrl;

  UserProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.profileImageUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'],
      name: json['name'],
      profileImageUrl: json['profileImageUrl'] ?? '',
    );
  }
}
