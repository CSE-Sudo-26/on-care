import 'package:oncare/features/diet/domain/entities/diet_day.dart';

/// One row of the "오늘의 건강 요약" progress list.
class HealthIndicator {
  const HealthIndicator({
    required this.label,
    required this.current,
    required this.max,
    required this.unit,
    this.overBudget = false,
  });

  final String label;
  final num current;
  final num max;
  final String unit;

  /// True when [current] should be treated as exceeding the target,
  /// even if the number is below `max` for a different reason. The
  /// React mock marks 나트륨 2100/2000 as `warning: true`.
  final bool overBudget;

  double get progress =>
      max == 0 ? 0 : (current / max).clamp(0.0, 1.0).toDouble();

  factory HealthIndicator.fromJson(Map<String, Object?> json) =>
      HealthIndicator(
        label: json['label']! as String,
        current: json['current']! as num,
        max: json['max']! as num,
        unit: json['unit']! as String,
        overBudget: (json['over_budget'] as bool?) ?? false,
      );
}

class ScheduleItem {
  const ScheduleItem({
    required this.time,
    required this.title,
    required this.emoji,
  });

  final String time;
  final String title;
  final String emoji;

  factory ScheduleItem.fromJson(Map<String, Object?> json) => ScheduleItem(
    time: json['time']! as String,
    title: json['title']! as String,
    emoji: (json['emoji'] as String?) ?? '',
  );
}

/// One day of the 식단 카드 weekly-trend chart (칼로리/나트륨/당류).
class NutritionDay {
  const NutritionDay({
    required this.label,
    required this.calories,
    required this.sodiumMg,
    required this.sugarG,
  });

  final String label; // 요일(월/화/…)
  final int calories;
  final int sodiumMg;
  final int sugarG;

  factory NutritionDay.fromJson(Map<String, Object?> json) => NutritionDay(
    label: (json['label'] as String?) ?? '',
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    sodiumMg: (json['sodium_mg'] as num?)?.toInt() ?? 0,
    sugarG: (json['sugar_g'] as num?)?.toInt() ?? 0,
  );
}

/// Snapshot displayed on the home dashboard. Mirrors the data the
/// React `Dashboard.tsx` mounts in `healthData` / `todaySchedule` /
/// `quickStats` / weekly score.
class DashboardSummary {
  const DashboardSummary({
    required this.indicators,
    required this.macros,
    required this.dietEntries,
    required this.exerciseMinutes,
    this.exerciseCalories = 0,
    this.exerciseCount = 0,
    this.exerciseBurnGoal = 500,
    this.nutritionWeek = const <NutritionDay>[],
    this.nutritionWeekPrev = const <NutritionDay>[],
    required this.todaySchedule,
    required this.weekScore,
    required this.weekScoreDelta,
    required this.sodiumWarning,
    this.exerciseFeedback,
  });

  /// 3-row health summary (칼로리 / 나트륨 / 당류).
  final List<HealthIndicator> indicators;

  /// Today's carbohydrate, protein, and fat totals and calorie ratios.
  final DietMacros macros;

  /// `quickStats` left tile — number of diet records logged today.
  final int dietEntries;

  /// `quickStats` right tile — total exercise minutes for the current week.
  final int exerciseMinutes;

  /// Total calories burned by the exercise sessions included in this summary.
  final int exerciseCalories;

  /// Number of exercise sessions included in this summary.
  final int exerciseCount;

  /// 운동 카드 소모 목표(kcal). 개인화 전까지 서버 기본값(500).
  final int exerciseBurnGoal;

  /// 식단 카드 주간 추이(최근 7일 일별 영양) + 지난 주 같은 요일(비교선).
  /// 비어 있으면(데모/목·데이터 없음) 화면은 기존 데모 상수로 폴백한다.
  final List<NutritionDay> nutritionWeek;
  final List<NutritionDay> nutritionWeekPrev;

  /// Today's schedule list (병원 정기검진 / 헬스장 운동 …).
  final List<ScheduleItem> todaySchedule;

  /// "이번 주 건강 점수" card.
  final int weekScore;
  final int weekScoreDelta;

  /// Diet-side daily feedback line — currently driven by the sodium
  /// budget, but treated generically as "the diet feedback the AI
  /// coach wants surfaced today". Null = nothing to say.
  final String? sodiumWarning;

  /// Exercise-side weekly feedback line. Optional for back-compat.
  final String? exerciseFeedback;

  HealthIndicator get calorieIndicator => indicators.firstWhere(
    (HealthIndicator indicator) => indicator.unit == 'kcal',
    orElse: () => const HealthIndicator(
      label: '칼로리',
      current: 0,
      max: 2000,
      unit: 'kcal',
    ),
  );

  HealthIndicator get sodiumIndicator => indicators.firstWhere(
    (HealthIndicator indicator) => indicator.unit == 'mg',
    orElse: () =>
        const HealthIndicator(label: '나트륨', current: 0, max: 2000, unit: 'mg'),
  );

  HealthIndicator get sugarIndicator => indicators.firstWhere(
    (HealthIndicator indicator) => indicator.unit == 'g',
    orElse: () =>
        const HealthIndicator(label: '당류', current: 0, max: 50, unit: 'g'),
  );

  bool get isEmpty =>
      dietEntries == 0 &&
      exerciseMinutes == 0 &&
      todaySchedule.isEmpty &&
      calorieIndicator.current == 0 &&
      // 오늘 기록이 없어도 이번 주(과거 요일)에 실제 식단 기록이 있으면 홈은
      // 비어 있지 않다 — 주간 추이 차트가 표시돼야 한다.
      !nutritionWeek.any((NutritionDay day) => day.calories > 0);

  factory DashboardSummary.fromJson(
    Map<String, Object?> json,
  ) => DashboardSummary(
    indicators: (json['indicators']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(HealthIndicator.fromJson)
        .toList(),
    macros: json['macros'] is Map<Object?, Object?>
        ? DietMacros.fromJson(
            (json['macros']! as Map<Object?, Object?>).cast<String, Object?>(),
          )
        : const DietMacros.zero(),
    dietEntries: (json['diet_entries']! as num).toInt(),
    exerciseMinutes: (json['exercise_minutes']! as num).toInt(),
    exerciseCalories: (json['exercise_calories'] as num?)?.toInt() ?? 0,
    exerciseCount: (json['exercise_count'] as num?)?.toInt() ?? 0,
    exerciseBurnGoal: (json['exercise_burn_goal'] as num?)?.toInt() ?? 500,
    nutritionWeek:
        ((json['nutrition_week'] as List<Object?>?) ?? const <Object?>[])
            .cast<Map<String, Object?>>()
            .map(NutritionDay.fromJson)
            .toList(),
    nutritionWeekPrev:
        ((json['nutrition_week_prev'] as List<Object?>?) ?? const <Object?>[])
            .cast<Map<String, Object?>>()
            .map(NutritionDay.fromJson)
            .toList(),
    todaySchedule: (json['today_schedule']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(ScheduleItem.fromJson)
        .toList(),
    weekScore: (json['week_score']! as num).toInt(),
    weekScoreDelta: (json['week_score_delta']! as num).toInt(),
    sodiumWarning: json['sodium_warning'] as String?,
    exerciseFeedback: json['exercise_feedback'] as String?,
  );
}
