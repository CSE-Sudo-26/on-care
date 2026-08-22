/// Result of POST /diet/analyze — the recognized foods + nutrition the
/// server materialised (and already persisted as a diet entry).
class RecognizedFood {
  const RecognizedFood({
    required this.name,
    required this.calories,
    required this.sodiumMg,
    required this.sugarG,
    required this.source,
  });

  final String name;
  final int calories;
  final int sodiumMg;
  final double sugarG;
  final String source; // "db"(공공 영양 DB 매핑) | "estimate"(LLM 추정)

  bool get isFromDb => source == 'db';

  factory RecognizedFood.fromJson(Map<String, Object?> json) => RecognizedFood(
    name: json['name']! as String,
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    sodiumMg: (json['sodium_mg'] as num?)?.toInt() ?? 0,
    sugarG: (json['sugar_g'] as num?)?.toDouble() ?? 0,
    source: (json['source'] as String?) ?? 'estimate',
  );
}

class DietAnalysisResult {
  const DietAnalysisResult({
    required this.entryId,
    required this.foods,
    required this.totalCalories,
    required this.totalSodiumMg,
    required this.totalSugarG,
    required this.coachComment,
  });

  final String entryId;
  final List<RecognizedFood> foods;
  final int totalCalories;
  final int totalSodiumMg;
  final double totalSugarG;
  final String coachComment;

  factory DietAnalysisResult.fromResponse(Map<String, Object?> json) {
    final analysis =
        (json['analysis'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    return DietAnalysisResult(
      entryId: (json['entry_id'] as String?) ?? '',
      foods: ((analysis['foods'] as List<Object?>?) ?? const <Object?>[])
          .cast<Map<String, Object?>>()
          .map(RecognizedFood.fromJson)
          .toList(),
      totalCalories: (analysis['total_calories'] as num?)?.toInt() ?? 0,
      totalSodiumMg: (analysis['total_sodium_mg'] as num?)?.toInt() ?? 0,
      totalSugarG: (analysis['total_sugar_g'] as num?)?.toDouble() ?? 0,
      coachComment: (analysis['coach_comment'] as String?) ?? '',
    );
  }
}
