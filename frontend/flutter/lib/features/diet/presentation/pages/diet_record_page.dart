import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/widgets/diet_flows.dart';
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

/// Maps a backend [DietEntry] onto the Figma meal-card view model. [l] localizes
/// the nutrient tag labels; the meal type is carried as a [MealType] so the badge
/// text is resolved at render time.
DietMeal _mealFromEntry(AppLocalizations l, DietEntry e) {
  final ({String emoji, Color bg}) meta =
      _mealMeta[e.mealType] ?? _mealMeta[MealType.snack]!;
  return DietMeal(
    id: e.id,
    mealType: e.mealType,
    time: e.timeLabel,
    total: e.totalCalories,
    emoji: meta.emoji,
    thumbBg: meta.bg,
    items: <DietFood>[
      for (final FoodItem f in e.foods) DietFood(f.name, f.calories),
    ],
    tags: <DietTag>[
      DietTag(l.dietTagSodium(e.sodiumMg), over: e.sodiumMg > 700),
      DietTag(l.dietTagSugar(e.sugarG)),
    ],
    sodium: e.sodiumMg,
    sugar: e.sugarG,
  );
}

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
                  weekLabel: l.dietWeekLabel(center.month, _weekOfMonth(center)),
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
                        _NutritionSummary(day: day),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textSub,
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
                          fontSize: 10,
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
        : FigmaColors.textFaint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _weekdayLabel(l, day.weekday),
            style: TextStyle(
              fontSize: 9.5,
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
              boxShadow: isSelected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: FigmaColors.primaryA(0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : isToday
                    ? FigmaColors.primary
                    : FigmaColors.textSub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────── nutrition summary ──

class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({required this.day});

  final DietDay day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.dietNutritionSummary,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryTile(
                  label: l.dietCalories,
                  value: '${day.totalCalories}',
                  unit: l.unitKcal,
                  color: FigmaColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryTile(
                  label: l.dietSodium,
                  value: '${day.totalSodiumMg}',
                  unit: l.dietUnitMg,
                  color: FigmaColors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryTile(
                  label: l.dietSugar,
                  value: '${day.totalSugarG}',
                  unit: l.dietUnitG,
                  color: FigmaColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: FigmaColors.textSub,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            unit,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
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
                  fontSize: 14,
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
                    fontSize: 12.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.textMuted,
                  ),
                ),
              ),
            )
          else
            for (final DietEntry e in entries) ...<Widget>[
              Builder(
                builder: (BuildContext context) {
                  final DietMeal m = _mealFromEntry(l, e);
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
                  fontSize: 11,
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
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      meal.time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: FigmaColors.textFaint,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l.unitKcalValue(meal.total),
                      style: const TextStyle(
                        fontSize: 13,
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
                const Divider(height: 1, color: FigmaColors.hairline),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: meal.thumbBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            meal.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          Text(
                            l.dietPhotoAnalysis,
                            style: const TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w600,
                              color: FigmaColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (final DietFood f in meal.items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      f.name,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF3A3A4A),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    l.unitKcalValue(f.kcal),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: FigmaColors.textSub,
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
                    for (final DietTag t in meal.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: t.over
                              ? const Color(0x1AFF5841)
                              : FigmaColors.primaryA(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: t.over
                                ? const Color(0xFFFF5841)
                                : FigmaColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
            style: const TextStyle(fontSize: 13, color: FigmaColors.textMuted),
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
          l.dietOtherDateEmpty,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: FigmaColors.textMuted,
          ),
        ),
      ),
    );
  }
}
