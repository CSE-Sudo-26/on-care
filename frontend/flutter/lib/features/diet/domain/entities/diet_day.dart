enum MealType { breakfast, lunch, dinner, snack }

MealType _mealFromString(String s) =>
    MealType.values.firstWhere((m) => m.name == s);

class FoodItem {
  const FoodItem({
    required this.name,
    required this.calories,
    this.sodiumMg = 0,
    this.sugarG = 0,
  });
  final String name;
  final int calories;

  /// Per-food nutrition, used by the diet-tab meal card to break a meal down
  /// food-by-food. Optional so backend payloads that omit them still parse.
  final int sodiumMg;
  final double sugarG;

  factory FoodItem.fromJson(Map<String, Object?> json) => FoodItem(
    name: json['name']! as String,
    calories: (json['calories']! as num).toInt(),
    sodiumMg: (json['sodium_mg'] as num?)?.toInt() ?? 0,
    sugarG: (json['sugar_g'] as num?)?.toDouble() ?? 0,
  );
}

class DietEntry {
  const DietEntry({
    this.id,
    required this.mealType,
    required this.timeLabel,
    required this.foods,
    required this.totalCalories,
    this.sodiumMg = 0,
    this.sugarG = 0,
    this.aiComment = '',
    this.photoAsset,
  });

  final String? id;
  final MealType mealType;
  final String timeLabel;
  final List<FoodItem> foods;
  final int totalCalories;
  final int sodiumMg;
  final double sugarG;

  /// Short per-meal AI feedback shown on the diet-tab meal card. Empty when the
  /// backend hasn't produced a per-entry comment.
  final String aiComment;

  /// Bundled asset path for the meal thumbnail photo (demo data). Null falls
  /// back to the meal-type emoji.
  final String? photoAsset;

  factory DietEntry.fromJson(Map<String, Object?> json) => DietEntry(
    id: json['id'] as String?,
    mealType: _mealFromString(json['meal_type']! as String),
    timeLabel: json['time_label']! as String,
    foods: (json['foods']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(FoodItem.fromJson)
        .toList(),
    totalCalories: (json['total_calories']! as num).toInt(),
    sodiumMg: (json['sodium_mg'] as num?)?.toInt() ?? 0,
    sugarG: (json['sugar_g'] as num?)?.toDouble() ?? 0,
    aiComment: (json['ai_comment'] as String?) ?? '',
  );
}

class DietMacros {
  const DietMacros({
    required this.carbsPct,
    required this.proteinPct,
    required this.fatPct,
  });

  final int carbsPct;
  final int proteinPct;
  final int fatPct;

  factory DietMacros.fromJson(Map<String, Object?> json) => DietMacros(
    carbsPct: (json['carbs_pct']! as num).toInt(),
    proteinPct: (json['protein_pct']! as num).toInt(),
    fatPct: (json['fat_pct']! as num).toInt(),
  );
}

class DietDay {
  const DietDay({
    required this.entries,
    required this.totalCalories,
    required this.macros,
    required this.totalSodiumMg,
    required this.totalSugarG,
    required this.aiCoachMessage,
  });

  final List<DietEntry> entries;
  final int totalCalories;
  final DietMacros macros;
  final int totalSodiumMg;
  final double totalSugarG;
  final String aiCoachMessage;

  factory DietDay.fromJson(Map<String, Object?> json) => DietDay(
    entries: (json['entries']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(DietEntry.fromJson)
        .toList(),
    totalCalories: (json['total_calories']! as num).toInt(),
    totalSodiumMg: (json['total_sodium_mg']! as num).toInt(),
    totalSugarG: (json['total_sugar_g']! as num).toDouble(),
    macros: DietMacros.fromJson(json['macros']! as Map<String, Object?>),
    aiCoachMessage: json['ai_coach_message']! as String,
  );
}
