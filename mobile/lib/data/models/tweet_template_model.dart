class TweetTemplateModel {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  const TweetTemplateModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory TweetTemplateModel.fromJson(Map<String, dynamic> json) {
    return TweetTemplateModel(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
