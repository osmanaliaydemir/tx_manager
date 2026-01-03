enum StrategyGoal { authority, engagement, community, sales }

enum ToneVoice { professional, friendly, witty, minimalist, provocative }

class UserStrategy {
  final StrategyGoal primaryGoal;
  final ToneVoice tone;
  final String forbiddenTopics;
  final String language;
  final int postsPerDay;

  UserStrategy({
    required this.primaryGoal,
    required this.tone,
    required this.forbiddenTopics,
    required this.language,
    required this.postsPerDay,
  });

  Map<String, dynamic> toJson() => {
    'primaryGoal': primaryGoal.index,
    'tone': tone.index,
    'forbiddenTopics': forbiddenTopics,
    'language': language,
    'postsPerDay': postsPerDay,
  };
}
