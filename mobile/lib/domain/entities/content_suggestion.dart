enum SuggestionStatus { pending, accepted, rejected, edited }

class ContentSuggestion {
  final String id;
  final String suggestedText;
  final String rationale;
  final String riskAssessment;
  final String generatedAt;
  SuggestionStatus status;

  ContentSuggestion({
    required this.id,
    required this.suggestedText,
    required this.rationale,
    required this.riskAssessment,
    required this.generatedAt,
    this.status = SuggestionStatus.pending,
  });

  factory ContentSuggestion.fromJson(Map<String, dynamic> json) {
    return ContentSuggestion(
      id: json['id'],
      suggestedText: json['suggestedText'] ?? '',
      rationale: json['rationale'] ?? '',
      riskAssessment: json['riskAssessment'] ?? 'Low',
      generatedAt: json['generatedAt'],
    );
  }
}
