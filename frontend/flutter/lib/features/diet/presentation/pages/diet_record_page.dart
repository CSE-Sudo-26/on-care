import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/widgets/diet_flows.dart';
import 'package:oncare/features/member_coach/presentation/widgets/trainer_chat_header_button.dart';
import 'package:oncare/features/notification/presentation/widgets/notification_panel.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/modals/right_slide_panel.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// 식단 tab, rebuilt to match the On-Care Figma redesign. The weekly date
/// strip is centred on today (per the product request); the nutrition summary /
/// AI feedback / meal log are driven by [dietTodayProvider], and the "식단 추가"
/// and meal-edit flows open as bottom sheets wired to the diet repository.
///
/// The backend currently exposes only "today", so a non-today selection shows
/// an empty state until the per-date query lands (tracked as a follow-up).
class DietRecordPage extends ConsumerStatefulWidget {
  const DietRecordPage({super.key});

  @override
  ConsumerState<DietRecordPage> createState() => _DietRecordPageState();
}

/// Localized short weekday label (1 = Mon … 7 = Sun).
String _weekdayLabel(AppLocalizations l, int weekday) => switch (weekday) {
  1 => l.dietWeekdayMon,
  2 => l.dietWeekdayTue,
  3 => l.dietWeekdayWed,
  4 => l.dietWeekdayThu,
  5 => l.dietWeekdayFri,
  6 => l.dietWeekdaySat,
  _ => l.dietWeekdaySun,
};

/// Meal-type presentation metadata (thumbnail emoji + tint). The badge label is
/// localized separately at display time via [mealBadge] so the API `meal_type`
/// stays decoupled from the UI language.
const Map<MealType, ({String emoji, Color bg})> _mealMeta =
    <MealType, ({String emoji, Color bg})>{
      MealType.breakfast: (emoji: '🥣', bg: Color(0xFFFFF3E0)),
      MealType.lunch: (emoji: '🥗', bg: Color(0xFFE8F5E9)),
      MealType.dinner: (emoji: '🐟', bg: Color(0xFFE3F2FD)),
      MealType.snack: (emoji: '🍎', bg: Color(0xFFFCE4EC)),
    };

String _grams(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

/// Maps a backend [DietEntry] onto the Figma meal-card view model. [l] localizes
/// the nutrient tag labels; the meal type is carried as a [MealType] so the badge
/// text is resolved at render time.
DietMeal _mealFromEntry(DietEntry e) {
  final ({String emoji, Color bg}) meta =
      _mealMeta[e.mealType] ?? _mealMeta[MealType.snack]!;
  // Totals are summed from the per-food nutrition so the pills on the card and
  // the "오늘의 영양 요약" numbers stay consistent. Real-server payloads carry
  // nutrition only at the entry level (foods = [{name, calories}]), so fall back
  // to the entry totals when the per-food sum is 0.
  final int foodSodium = e.foods.fold<int>(
    0,
    (int a, FoodItem f) => a + f.sodiumMg,
  );
  final double foodSugar = e.foods.fold<double>(
    0,
    (double a, FoodItem f) => a + f.sugarG,
  );
  final int sodium = foodSodium > 0 ? foodSodium : e.sodiumMg;
  final double sugar = foodSugar > 0 ? foodSugar : e.sugarG;
  return DietMeal(
    id: e.id,
    mealType: e.mealType,
    time: e.timeLabel,
    total: e.totalCalories,
    emoji: meta.emoji,
    thumbBg: meta.bg,
    photoAsset: e.photoAsset,
    aiComment: e.aiComment,
    items: <DietFood>[
      for (final FoodItem f in e.foods)
        DietFood(f.name, f.calories, sodiumMg: f.sodiumMg, sugarG: f.sugarG),
    ],
    tags: const <DietTag>[],
    sodium: sodium,
    sugar: sugar,
  );
}

/// Formats grams dropping a trailing `.0` (6.0 → "6", 8.5 → "8.5").
String _formatG(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Groups an integer with thousands separators (3200 → "3,200").
String _formatInt(int v) => v.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (Match _) => ',',
);

class _DietRecordPageState extends ConsumerState<DietRecordPage> {
  int _weekShift = 0; // whole-week steps away from today
  late DateTime _selected;

  DateTime get _today {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _selected = _today;
  }

  int _weekOfMonth(DateTime d) {
    final DateTime first = DateTime(d.year, d.month);
    final int offset = first.weekday - 1; // days from Monday
    return ((d.day + offset - 1) / 7).floor() + 1;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final DateTime today = _today;
    // Window is always centred on today (+ whole-week shifts): 3 days before,
    // today in the middle, 3 days after.
    final DateTime center = today.add(Duration(days: _weekShift * 7));
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (int i) => center.add(Duration(days: i - 3)),
    );
    final bool atToday = _weekShift == 0 && _selected == today;
    final AsyncValue<DietDay> diet = ref.watch(dietTodayProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 108),
              children: <Widget>[
                FigmaTabHeader(
                  title: l.dietTitle,
                  trailingAction: const TrainerChatHeaderButton(),
                  onBell: () => showRightSlidePanel<void>(
                    context,
                    content: const NotificationPanelBody(),
                  ),
                  onCalendar: () => showScheduleCalendarSheet(context),
                ),
                _DateStrip(
                  days: days,
                  today: today,
                  selected: _selected,
                  weekLabel: l.dietWeekLabel(
                    center.month,
                    _weekOfMonth(center),
                  ),
                  showTodayButton: !atToday,
                  onSelect: (DateTime d) => setState(() => _selected = d),
                  onPrev: () => setState(() => _weekShift -= 1),
                  onNext: _weekShift >= 0
                      ? null
                      : () => setState(() => _weekShift += 1),
                  onToday: () => setState(() {
                    _weekShift = 0;
                    _selected = today;
                  }),
                ),
                const SizedBox(height: 8),
                if (!atToday)
                  const _EmptyDay()
                else
                  diet.when(
                    loading: () => const _DietLoading(),
                    error: (Object e, StackTrace _) => _DietError(
                      onRetry: () => ref.invalidate(dietTodayProvider),
                    ),
                    data: (DietDay day) => Column(
                      children: <Widget>[
                        NutritionSummary(day: day),
                        const SizedBox(height: 20),
                        _AiFeedback(message: day.aiCoachMessage),
                        const SizedBox(height: 20),
                        _MealLog(
                          entries: day.entries,
                          onAdd: () => showDietAddSheet(context),
                          onEditMeal: (DietMeal m) =>
                              showMealEditSheet(context, m),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────── date strip ──

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.days,
    required this.today,
    required this.selected,
    required this.weekLabel,
    required this.showTodayButton,
    required this.onSelect,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime selected;
  final String weekLabel;
  final bool showTodayButton;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  weekLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (showTodayButton)
                  GestureDetector(
                    onTap: onToday,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: FigmaColors.primaryA(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: FigmaColors.primaryA(0.25)),
                      ),
                      child: Text(
                        l.dietToday,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _Arrow(icon: Icons.chevron_left, onTap: onPrev),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (final DateTime d in days)
                      _DayCell(
                        day: d,
                        isToday: d == today,
                        isSelected: d == selected,
                        onTap: () => onSelect(d),
                      ),
                  ],
                ),
              ),
              _Arrow(icon: Icons.chevron_right, onTap: onNext),
            ],
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: FigmaColors.softBlue,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 16, color: FigmaColors.primary),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color labelColor = isSelected || isToday
        ? FigmaColors.primary
        : AppColors.mutedForeground;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _weekdayLabel(l, day.weekday),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? FigmaColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              // 선택된 날짜 칩도 카드와 같은 회색 그림자를 쓴다(예전 파란 글로우).
              boxShadow: isSelected ? kCardShadow : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : isToday
                    ? FigmaColors.primary
                    : AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────── nutrition summary ──

class NutritionSummary extends StatelessWidget {
  const NutritionSummary({required this.day, super.key});

  final DietDay day;

  static const double _calorieGoal = 2000;
  static const double _sodiumGoal = 2000;
  static const double _sugarGoal = 50;
  static const double _carbsGoal = 275;
  static const double _proteinGoal = 100;
  static const double _fatGoal = 55;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // Sum straight from the foods so the summary always equals the meal cards;
    // fall back to the server day totals when the per-food sum is 0 (real-server
    // payloads carry nutrition only at the day/entry level).
    final List<FoodItem> foods = <FoodItem>[
      for (final DietEntry e in day.entries) ...e.foods,
    ];
    final int foodKcal = foods.fold<int>(
      0,
      (int a, FoodItem f) => a + f.calories,
    );
    final int foodSodium = foods.fold<int>(
      0,
      (int a, FoodItem f) => a + f.sodiumMg,
    );
    final double foodSugar = foods.fold<double>(
      0,
      (double a, FoodItem f) => a + f.sugarG,
    );
    final int kcal = foodKcal > 0 ? foodKcal : day.totalCalories;
    final int sodium = foodSodium > 0 ? foodSodium : day.totalSodiumMg;
    final double sugar = foodSugar > 0 ? foodSugar : day.totalSugarG;
    final List<_NutritionSummaryItem> items = <_NutritionSummaryItem>[
      _NutritionSummaryItem(
        label: l.dietCalories,
        value: _formatInt(kcal),
        goal: _formatInt(_calorieGoal.toInt()),
        unit: l.unitKcal,
        ratio: _nutritionRatio(kcal, _calorieGoal),
        isOverGoal: kcal > _calorieGoal,
      ),
      _NutritionSummaryItem(
        label: l.dietSodium,
        value: _formatInt(sodium),
        goal: _formatInt(_sodiumGoal.toInt()),
        unit: l.dietUnitMg,
        ratio: _nutritionRatio(sodium, _sodiumGoal),
        isOverGoal: sodium > _sodiumGoal,
      ),
      _NutritionSummaryItem(
        label: l.dietSugar,
        value: _formatG(sugar),
        goal: _formatG(_sugarGoal),
        unit: l.dietUnitG,
        ratio: _nutritionRatio(sugar, _sugarGoal),
        isOverGoal: sugar > _sugarGoal,
      ),
      _NutritionSummaryItem(
        label: l.homeMacroProtein,
        value: _grams(day.macros.proteinG),
        goal: _formatG(_proteinGoal),
        unit: l.dietUnitG,
        ratio: _nutritionRatio(day.macros.proteinG, _proteinGoal),
        isOverGoal: day.macros.proteinG > _proteinGoal,
      ),
      _NutritionSummaryItem(
        label: l.homeMacroFat,
        value: _grams(day.macros.fatG),
        goal: _formatG(_fatGoal),
        unit: l.dietUnitG,
        ratio: _nutritionRatio(day.macros.fatG, _fatGoal),
        isOverGoal: day.macros.fatG > _fatGoal,
      ),
      _NutritionSummaryItem(
        label: l.homeMacroCarbs,
        value: _grams(day.macros.carbsG),
        goal: _formatG(_carbsGoal),
        unit: l.dietUnitG,
        ratio: _nutritionRatio(day.macros.carbsG, _carbsGoal),
        isOverGoal: day.macros.carbsG > _carbsGoal,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.dietNutritionSummary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          _NutritionSummaryCard(
            calories: items[0],
            calorieDifference: _formatInt((kcal - _calorieGoal).abs().round()),
            carbs: items[5],
            protein: items[3],
            fat: items[4],
          ),
          const SizedBox(height: 12),
          _NutritionStatusCards(
            sodium: items[1],
            sodiumDifference: _formatInt((sodium - _sodiumGoal).abs().round()),
            sugar: items[2],
            sugarDifference: _formatG((sugar - _sugarGoal).abs()),
          ),
        ],
      ),
    );
  }
}

double _nutritionRatio(num current, num goal) {
  if (goal <= 0) return 0;
  return (current / goal).clamp(0.0, 1.0).toDouble();
}

class _NutritionSummaryItem {
  const _NutritionSummaryItem({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.ratio,
    required this.isOverGoal,
  });

  final String label;
  final String value;
  final String goal;
  final String unit;
  final double ratio;
  final bool isOverGoal;
}

class _NutritionSummaryCard extends StatelessWidget {
  const _NutritionSummaryCard({
    required this.calories,
    required this.calorieDifference,
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final _NutritionSummaryItem calories;
  final String calorieDifference;
  final _NutritionSummaryItem carbs;
  final _NutritionSummaryItem protein;
  final _NutritionSummaryItem fat;

  @override
  Widget build(BuildContext context) {
    final Color macroProgressColor = FigmaColors.primaryA(0.65);
    final List<_MacroProgressData> macros = <_MacroProgressData>[
      _MacroProgressData(item: carbs, color: macroProgressColor),
      _MacroProgressData(item: protein, color: macroProgressColor),
      _MacroProgressData(item: fat, color: macroProgressColor),
    ];
    final AppLocalizations l = AppLocalizations.of(context);
    final Color calorieColor = calories.isOverGoal
        ? FigmaColors.dangerRed
        : FigmaColors.primary;
    final String calorieStatus = calories.isOverGoal
        ? l.dietAmountOver('$calorieDifference ${calories.unit}')
        : l.dietAmountRemaining('$calorieDifference ${calories.unit}');
    return Container(
      key: const Key('nutrition-summary-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.homeCalorieIntake,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: calories.value,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: calorieColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${calories.goal} ${calories.unit}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      calorieStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: calories.isOverGoal
                            ? FigmaColors.dangerRed
                            : AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _CalorieCircularProgress(calories: calories, color: calorieColor),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: FigmaColors.hairline),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < 280) {
                return Column(
                  children: <Widget>[
                    for (final _MacroProgressData macro in macros) ...<Widget>[
                      _MacroProgressItem(macro: macro),
                      if (macro != macros.last) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (
                    int index = 0;
                    index < macros.length;
                    index++
                  ) ...<Widget>[
                    Expanded(child: _MacroProgressItem(macro: macros[index])),
                    if (index < macros.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalorieCircularProgress extends StatelessWidget {
  const _CalorieCircularProgress({required this.calories, required this.color});

  final _NutritionSummaryItem calories;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SizedBox.square(
      dimension: 92,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox.square(
            dimension: 92,
            child: CircularProgressIndicator(
              key: const Key('nutrition-calorie-progress'),
              value: calories.ratio,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: FigmaColors.track,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${(calories.ratio * 100).round()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.homeAchieveRate,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroProgressData {
  const _MacroProgressData({required this.item, required this.color});

  final _NutritionSummaryItem item;
  final Color color;
}

class _MacroProgressItem extends StatelessWidget {
  const _MacroProgressItem({required this.macro});

  final _MacroProgressData macro;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('nutrition-macro-${macro.item.label}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          macro.item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: macro.item.value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
                TextSpan(
                  text: ' / ${macro.item.goal}${macro.item.unit}',
                  style: kGoalSuffixStyle,
                ),
              ],
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 7),
        _NutritionProgressBar(
          key: Key('nutrition-macro-progress-${macro.item.label}'),
          progress: macro.item.ratio,
          color: macro.color,
        ),
      ],
    );
  }
}

class _NutritionProgressBar extends StatelessWidget {
  const _NutritionProgressBar({
    required this.progress,
    required this.color,
    super.key,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const double barHeight = 6;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: barHeight,
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: ColoredBox(color: FigmaColors.track),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                    height: barHeight,
                    child: ColoredBox(color: color),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NutritionStatusCards extends StatelessWidget {
  const _NutritionStatusCards({
    required this.sodium,
    required this.sodiumDifference,
    required this.sugar,
    required this.sugarDifference,
  });

  final _NutritionSummaryItem sodium;
  final String sodiumDifference;
  final _NutritionSummaryItem sugar;
  final String sugarDifference;

  @override
  Widget build(BuildContext context) {
    final Widget sodiumCard = _NutritionStatusCard(
      key: const Key('nutrition-sodium-status'),
      item: sodium,
      difference: sodiumDifference,
      progressColor: sodium.isOverGoal
          ? FigmaColors.dangerRed
          : FigmaColors.primaryDeep,
    );
    final Widget sugarCard = _NutritionStatusCard(
      key: const Key('nutrition-sugar-status'),
      item: sugar,
      difference: sugarDifference,
      progressColor: sugar.isOverGoal
          ? FigmaColors.dangerRed
          : FigmaColors.greenText,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 310) {
          return Column(
            children: <Widget>[
              sodiumCard,
              const SizedBox(height: 10),
              sugarCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: sodiumCard),
            const SizedBox(width: 10),
            Expanded(child: sugarCard),
          ],
        );
      },
    );
  }
}

class _NutritionStatusCard extends StatelessWidget {
  const _NutritionStatusCard({
    required this.item,
    required this.difference,
    required this.progressColor,
    super.key,
  });

  final _NutritionSummaryItem item;
  final String difference;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color statusColor = item.isOverGoal
        ? FigmaColors.dangerRed
        : FigmaColors.greenText;
    final String differenceText = item.isOverGoal
        ? l.dietAmountOver('$difference${item.unit}')
        : l.dietAmountRemaining('$difference${item.unit}');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isOverGoal
              ? FigmaColors.dangerRed.withValues(alpha: 0.32)
              : FigmaColors.primaryA(0.18),
        ),
        boxShadow: kCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _VerticalNutritionProgressBar(
            key: Key('nutrition-status-vertical-progress-${item.label}'),
            progress: item.ratio,
            color: progressColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      item.isOverGoal
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: item.value,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: item.isOverGoal
                                ? FigmaColors.dangerRed
                                : FigmaColors.ink,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${item.goal}${item.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.isOverGoal
                        ? '${l.homeGoal} ${l.homeMetricOver}'
                        : l.homeMetricNormal,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  differenceText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.isOverGoal
                        ? FigmaColors.dangerRed
                        : AppColors.foreground,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalNutritionProgressBar extends StatelessWidget {
  const _VerticalNutritionProgressBar({
    required this.progress,
    required this.color,
    super.key,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const double barWidth = 8;
    const double barHeight = 104;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: barWidth,
        height: barHeight,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: ColoredBox(color: FigmaColors.track)),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: barWidth,
                height: barHeight * progress.clamp(0.0, 1.0),
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────── AI feedback ──

class _AiFeedback extends StatelessWidget {
  const _AiFeedback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return const SizedBox.shrink();
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FigmaColors.softBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FigmaColors.primaryA(0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const OniAvatar(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l.dietAiFeedback,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: FigmaColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── meal log ──

class _MealLog extends StatelessWidget {
  const _MealLog({
    required this.entries,
    required this.onAdd,
    required this.onEditMeal,
  });

  final List<DietEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<DietMeal> onEditMeal;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                l.dietTodayMeals,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.ink,
                ),
              ),
              const Spacer(),
              _AddButton(onTap: onAdd),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  l.dietEmptyLog,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            )
          else
            for (final DietEntry e in entries) ...<Widget>[
              Builder(
                builder: (BuildContext context) {
                  final DietMeal m = _mealFromEntry(e);
                  return _MealCard(meal: m, onTap: () => onEditMeal(m));
                },
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Material(
      color: FigmaColors.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.add, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                l.dietAddMeal,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.onTap});
  final DietMeal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: FigmaColors.primaryA(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        mealBadge(l, meal.mealType),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      meal.time,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_formatInt(meal.total)} ${l.unitKcal}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: FigmaColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: FigmaColors.textFaint,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    _MealThumb(meal: meal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (final DietFood f in meal.items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      f.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.foreground,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${f.kcal}${l.unitKcal} · '
                                    '${_formatInt(f.sodiumMg)}${l.dietUnitMg} · '
                                    '${_formatG(f.sugarG)}${l.dietUnitG}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _TotalPill(
                      label: l.dietCalories,
                      value: '${_formatInt(meal.total)} ${l.unitKcal}',
                      color: FigmaColors.primary,
                    ),
                    _TotalPill(
                      label: l.dietSodium,
                      value: '${_formatInt(meal.sodium)} ${l.dietUnitMg}',
                      // 좋으면 파란계열, 나트륨이 과다하면 빨간계열.
                      color: meal.sodium > 1000
                          ? FigmaColors.dangerRed
                          : FigmaColors.primary,
                    ),
                    _TotalPill(
                      label: l.dietSugar,
                      value: '${_formatG(meal.sugar)} ${l.dietUnitG}',
                      color: FigmaColors.primary,
                    ),
                  ],
                ),
                if (meal.aiComment.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _MealAiNote(text: meal.aiComment),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Meal thumbnail: the AI-analysed food photo, falling back to the meal-type
/// emoji chip when no photo is bundled.
class _MealThumb extends StatelessWidget {
  const _MealThumb({required this.meal});
  final DietMeal meal;

  @override
  Widget build(BuildContext context) {
    final String? asset = meal.photoAsset;
    if (asset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          asset,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          // Fall back to the emoji chip if the bundled asset is missing.
          errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
              _emojiThumb(),
        ),
      );
    }
    return _emojiThumb();
  }

  Widget _emojiThumb() => Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: meal.thumbBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(meal.emoji, style: const TextStyle(fontSize: 24)),
  );
}

/// Rounded "button-style" total chip: nutrient label + value in a tinted pill.
class _TotalPill extends StatelessWidget {
  const _TotalPill({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.75),
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact per-meal AI feedback line shown under the food breakdown.
class _MealAiNote extends StatelessWidget {
  const _MealAiNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FigmaColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.auto_awesome, size: 13, color: FigmaColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────── loading / error / empty ──

class _DietLoading extends StatelessWidget {
  const _DietLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class _DietError extends StatelessWidget {
  const _DietError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: <Widget>[
          Text(
            l.dietLoadError,
            style: const TextStyle(fontSize: 14, color: AppColors.foreground),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.primary,
              side: BorderSide(color: FigmaColors.primaryA(0.4)),
            ),
            child: Text(l.actionRetry),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Text(
          l.otherDateEmpty(l.pageDietTitle),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
