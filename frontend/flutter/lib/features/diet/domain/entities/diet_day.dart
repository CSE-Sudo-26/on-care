enum MealType { breakfast, lunch, dinner, snack }

MealType _mealFromString(String s) =>
    MealType.values.firstWhere((m) => m.name == s);

class FoodItem {
  const FoodItem({
    required this.name,
    required this.calories,
    this.sodiumMg = 0,
    this.sugarG = 0,
    this.carbsG = 0,
    this.proteinG = 0,
    this.fatG = 0,
  });
  final String name;
  final int calories;

  /// Per-food nutrition, used by the diet-tab meal card to break a meal down
  /// food-by-food. Optional so backend payloads that omit them still parse.
  final int sodiumMg;
  final double sugarG;
  final double carbsG;
  final double proteinG;
  final double fatG;

  factory FoodItem.fromJson(Map<String, Object?> json) => FoodItem(
    name: json['name']! as String,
    calories: (json['calories']! as num).toInt(),
    sodiumMg: (json['sodium_mg'] as num?)?.toInt() ?? 0,
    sugarG: (json['sugar_g'] as num?)?.toDouble() ?? 0,
    carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
    proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
    fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
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
    this.carbsG = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.aiComment = '',
    this.photoAsset,
    this.photoUrl,
  });

  final String? id;
  final MealType mealType;
  final String timeLabel;
  final List<FoodItem> foods;
  final int totalCalories;
  final int sodiumMg;
  final double sugarG;
  final double carbsG;
  final double proteinG;
  final double fatG;

  /// Short per-meal AI feedback shown on the diet-tab meal card. Empty when the
  /// backend hasn't produced a per-entry comment.
  final String aiComment;

  /// Bundled asset path for the meal thumbnail photo (demo data). Null falls
  /// back to the meal-type emoji.
  final String? photoAsset;

  /// API path of the photo the member actually uploaded (#699), relative to
  /// the API base. Null for entries recorded before photos were stored, and
  /// for entries whose photo could not be read. Takes precedence over
  /// [photoAsset]: the demo asset is a stand-in for exactly this.
  final String? photoUrl;

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
    carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
    proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
    fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
    aiComment: (json['ai_comment'] as String?) ?? '',
    photoAsset: json['photo_asset'] as String?,
    photoUrl: json['photo_url'] as String?,
  );
}

class DietMacros {
  const DietMacros({
    required this.carbsPct,
    required this.proteinPct,
    required this.fatPct,
    this.carbsG = 0,
    this.proteinG = 0,
    this.fatG = 0,
  });

  const DietMacros.zero()
    : carbsPct = 0,
      proteinPct = 0,
      fatPct = 0,
      carbsG = 0,
      proteinG = 0,
      fatG = 0;

  final int carbsPct;
  final int proteinPct;
  final int fatPct;
  final double carbsG;
  final double proteinG;
  final double fatG;

  factory DietMacros.fromJson(Map<String, Object?> json) => DietMacros(
    carbsPct: (json['carbs_pct'] as num?)?.toInt() ?? 0,
    proteinPct: (json['protein_pct'] as num?)?.toInt() ?? 0,
    fatPct: (json['fat_pct'] as num?)?.toInt() ?? 0,
    carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
    proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
    fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
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
    macros: switch (json['macros']) {
      final Map<String, Object?> macros => DietMacros.fromJson(macros),
      _ => const DietMacros.zero(),
    },
    aiCoachMessage: json['ai_coach_message']! as String,
  );
}

/// 화면이 쓰는 하루 합계.
///
/// 끼니별 음식의 합을 먼저 보고, 그 합이 0 이면 서버가 준 하루 합계로 떨어진다.
/// 실서버 응답은 영양을 하루/끼니 단위로만 내려주기 때문이다(음식 배열에는
/// 이름과 칼로리만 들어 있다). 식단 탭의 하루 요약과 기간 뷰가 **같은 규칙**을
/// 써야 두 화면의 숫자가 어긋나지 않는다.
extension DietDayTotals on DietDay {
  List<FoodItem> get _allFoods => <FoodItem>[
    for (final DietEntry e in entries) ...e.foods,
  ];

  int get effectiveCalories {
    final int sum = _allFoods.fold<int>(
      0,
      (int a, FoodItem f) => a + f.calories,
    );
    return sum > 0 ? sum : totalCalories;
  }

  int get effectiveSodiumMg {
    final int sum = _allFoods.fold<int>(
      0,
      (int a, FoodItem f) => a + f.sodiumMg,
    );
    return sum > 0 ? sum : totalSodiumMg;
  }

  double get effectiveSugarG {
    final double sum = _allFoods.fold<double>(
      0,
      (double a, FoodItem f) => a + f.sugarG,
    );
    return sum > 0 ? sum : totalSugarG;
  }
}
