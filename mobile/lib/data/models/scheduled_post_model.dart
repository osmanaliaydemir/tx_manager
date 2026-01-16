class ScheduledPostModel {
  final String id;
  final String content;
  final DateTime scheduledFor;
  final DateTime createdAt;
  final String status; // "Scheduled"

  ScheduledPostModel({
    required this.id,
    required this.content,
    required this.scheduledFor,
    required this.createdAt,
    required this.status,
  });

  factory ScheduledPostModel.fromJson(Map<String, dynamic> json) {
    return ScheduledPostModel(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      scheduledFor: DateTime.parse(json['scheduledFor'] ?? json['createdAt']),
      createdAt: DateTime.parse(json['createdAt']),
      status: json['status']?.toString() ?? '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'scheduledFor': scheduledFor.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }

  ScheduledPostModel copyWith({
    String? id,
    String? content,
    DateTime? scheduledFor,
    DateTime? createdAt,
    String? status,
  }) {
    return ScheduledPostModel(
      id: id ?? this.id,
      content: content ?? this.content,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
