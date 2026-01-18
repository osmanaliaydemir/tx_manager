enum SuggestionStatus { pending, accepted, rejected, edited }

class ContentSuggestion {
  final String id;
  final String suggestedText;
  final String rationale;
  final String riskAssessment;
  final String estimatedImpact;
  final DateTime generatedAtUtc;
  SuggestionStatus status;

  ContentSuggestion({
    required this.id,
    required this.suggestedText,
    required this.rationale,
    required this.riskAssessment,
    required this.estimatedImpact,
    required this.generatedAtUtc,
    this.status = SuggestionStatus.pending,
  });

  static SuggestionStatus _parseStatus(dynamic v) {
    if (v is String) {
      switch (v.toLowerCase()) {
        case 'accepted':
          return SuggestionStatus.accepted;
        case 'rejected':
          return SuggestionStatus.rejected;
        case 'edited':
          return SuggestionStatus.edited;
        default:
          return SuggestionStatus.pending;
      }
    }
    if (v is int) {
      if (v == 1) return SuggestionStatus.accepted;
      if (v == 2) return SuggestionStatus.rejected;
      if (v == 3) return SuggestionStatus.edited;
      return SuggestionStatus.pending;
    }
    return SuggestionStatus.pending;
  }

  factory ContentSuggestion.fromJson(Map<String, dynamic> json) {
    return ContentSuggestion(
      id: json['id'],
      suggestedText: json['suggestedText'] ?? '',
      rationale: json['rationale'] ?? '',
      riskAssessment: json['riskAssessment'] ?? 'Low',
      estimatedImpact: json['estimatedImpact'] ?? 'Unknown',
      generatedAtUtc:
          DateTime.tryParse((json['generatedAtUtc'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      status: _parseStatus(json['status']),
    );
  }
}
