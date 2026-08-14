import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/charts/chart_reveal.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/motion.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/widgets/diet_flows.dart';
import 'package:oncare/features/diet/presentation/widgets/diet_period_view.dart';
import 'package:oncare/features/diet/presentation/widgets/stored_meal_photo.dart';
import 'package:oncare/features/member_coach/presentation/widgets/trainer_chat_header_button.dart';
import 'package:oncare/features/notification/presentation/controllers/notification_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/modals/schedule_calendar_sheet.dart';

/// 식단 tab, rebuilt to match the On-Care Figma redesign. The weekly date
/// strip is centred on today (per the product request); the nutrition summary /
/// AI feedback / meal log are driven by the selected date, and the "식단 추가"
/// and meal-detail flows open as full pages wired to the diet repository.
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
  // the 영양 요약 numbers stay consistent. Real-server payloads carry
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
    photoUrl: e.photoUrl,
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

/// 식단 탭이 보여주는 기간. 운동 탭의 `운동 현황` 토글과 같은 뜻·같은 순서다.
enum DietPeriodTab { day, week, month }

/// 기간 뷰가 집계할 날짜 범위. 이번 주는 월~일, 이번 달은 1일~말일이다.
/// 아직 오지 않은 날도 범위에 넣는다 — 빈 칸이 남아야 한 주·한 달의 모양이
/// 그대로 읽힌다(평균은 기록이 있는 날만으로 낸다).
///
/// 날짜를 Duration 이 아니라 성분으로 옮긴다. 로컬 시간에 Duration 을 더하면
/// 서머타임이 있는 지역에서 주 전체가 하루씩 밀린다. `DateTime(y, m + 1, 0)`
/// 은 12월이면 다음 해 1월 0일 = 12월 31일로 알아서 넘어간다.
DietDateRange dietRangeForTab(DietPeriodTab tab, DateTime today) {
  if (tab == DietPeriodTab.month) {
    return (
      from: DateTime(today.year, today.month),
      to: DateTime(today.year, today.month + 1, 0),
    );
  }
  final DateTime monday = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  return (
    from: monday,
    to: DateTime(monday.year, monday.month, monday.day + 6),
  );
}

class _DietRecordPageState extends ConsumerState<DietRecordPage> {
  int _weekShift = 0; // whole-week steps away from today
  late DateTime _selected;
  DietPeriodTab _period = DietPeriodTab.day;

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

  DietDateRange _rangeFor(DietPeriodTab tab, DateTime today) =>
      dietRangeForTab(tab, today);

  void _retryDay() {
    if (_weekShift == 0 && _selected == _today) {
      ref.invalidate(dietTodayProvider);
    } else {
      ref.invalidate(dietByDateProvider(_selected));
    }
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
    final AsyncValue<DietDay> diet = atToday
        ? ref.watch(dietTodayProvider)
        : ref.watch(dietByDateProvider(_selected));
    final UserProfile? profile = ref.watch(profileProvider).asData?.value;

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
                  onBell: () => context.push(AppRoutes.notification),
                  bellHasUnread:
                      (ref.watch(notificationUnreadProvider).valueOrNull ?? 0) >
                      0,
                  onCalendar: () => showScheduleCalendarSheet(context),
                ),
                // 날짜 스트립은 기간과 무관하게 늘 있다 — 기간 토글은 영양
                // 요약 섹션 하나만 바꾼다(운동 탭의 `운동 현황` 과 같다, #681).
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
                // 영양 요약 섹션. 제목·토글·기간 그래프는 **선택한 날짜의 요청과
                // 무관하게** 늘 그린다 — 기록이 빈 날을 누르면 주간 그래프까지
                // 통째로 사라지고 토글마저 없어져 되돌아갈 수도 없었다(#684 리뷰).
                _NutritionSectionHeader(
                  period: _period,
                  onChanged: (DietPeriodTab t) => setState(() => _period = t),
                ),
                if (_period != DietPeriodTab.day)
                  // 범위는 스트립이 보여주는 주(center)를 따른다. today 로 잡으면
                  // 주를 뒤로 넘겼을 때 스트립과 그래프가 다른 주를 가리킨다.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: DietPeriodView(
                      range: _rangeFor(_period, center),
                      weekly: _period == DietPeriodTab.week,
                      profile: profile,
                    ),
                  )
                else
                  diet.when(
                    loading: () => const _DietLoading(),
                    error: (Object e, StackTrace _) =>
                        _DietError(onRetry: _retryDay),
                    data: (DietDay day) => !atToday && day.entries.isEmpty
                        ? const _EmptyDay()
                        : NutritionSummary(
                            day: day,
                            profile: profile,
                            showHeader: false,
                          ),
                  ),
                // 아래는 선택한 날짜 기준이라 기간과 무관하다.
                diet.when(
                  loading: () => const SizedBox.shrink(),
                  error: (Object e, StackTrace _) => const SizedBox.shrink(),
                  data: (DietDay day) => !atToday && day.entries.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          children: <Widget>[
                            const SizedBox(height: 20),
                            _AiFeedback(message: day.aiCoachMessage),
                            const SizedBox(height: 20),
                            _MealLog(
                              entries: day.entries,
                              date: _selected,
                              onAdd: () => showDietAddSheet(context),
                              onEditMeal: (DietMeal m) =>
                                  openMealDetailPage(context, m),
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

// ─────────────────────────────────────────────────────── period toggle ──

/// 오늘 / 이번 주 / 이번 달.
///
/// 운동 탭 `운동 현황` 의 토글과 자리·문구뿐 아니라 **생김새까지** 같게 둔다
/// (여백·글자 크기·선택 표시·전환 시간). 같은 자리에 놓인 같은 조작이 탭마다
/// 다르게 보이면 안 된다. 한 위젯으로 합치는 것은 별 이슈로 뗀다.
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.active, required this.onChanged});

  final DietPeriodTab active;
  final ValueChanged<DietPeriodTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Map<DietPeriodTab, String> labels = <DietPeriodTab, String>{
      DietPeriodTab.day: l.exToday,
      DietPeriodTab.week: l.exThisWeek,
      DietPeriodTab.month: l.exThisMonth,
    };
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FigmaColors.statBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final DietPeriodTab tab in DietPeriodTab.values)
            GestureDetector(
              key: Key('diet-period-tab-${tab.name}'),
              onTap: () => onChanged(tab),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active == tab
                      ? FigmaColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labels[tab]!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active == tab
                        ? Colors.white
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 영양 요약 섹션의 제목 줄. 제목 + 기간 토글.
///
/// 페이지가 직접 그린다 — 하루 요청(`diet.when`) 안에 두면 기록이 빈 날이나
/// 실패한 날에 토글까지 사라져 되돌아갈 방법이 없어진다(#684 리뷰).
class _NutritionSectionHeader extends StatelessWidget {
  const _NutritionSectionHeader({
    required this.period,
    required this.onChanged,
  });

  final DietPeriodTab period;
  final ValueChanged<DietPeriodTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      // 기간 탭에서는 바로 아래가 지표 버튼 줄이다. 간격을 두면 제목·버튼이
      // 한 덩어리로 읽히지 않고 사이가 비어 보인다. 하루 탭은 아래가 기록
      // 카드라 원래 간격을 유지한다.
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        period == DietPeriodTab.day ? 10 : 0,
      ),
      child: Row(
        children: <Widget>[
          // 토글을 카드 오른쪽 끝에 붙인다 — 운동 탭 '운동 현황' 과 같은 자리라
          // 두 탭을 오가며 같은 곳에서 기간을 바꾼다.
          //
          // `Spacer` 가 아니라 `Expanded` 로 미는 이유: 좁은 화면·큰 글자 배율에서
          // 제목이 토글을 밀어내 Row 가 넘치던 문제(#684 리뷰)를 그대로 막아야
          // 한다. 제목이 남은 자리를 다 쓰되 먼저 줄어든다.
          Expanded(
            child: Text(
              l.dietNutritionSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FigmaColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _PeriodToggle(active: period, onChanged: onChanged),
        ],
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
  const NutritionSummary({
    required this.day,
    this.profile,
    this.showHeader = true,
    super.key,
  });

  final DietDay day;
  final UserProfile? profile;

  /// 식단 탭은 기간 토글과 함께 제목을 **바깥에서** 그린다(하루 요청 상태와
  /// 무관하게 늘 보여야 하므로). 이 위젯만 단독으로 쓰는 곳은 기본값을 쓴다.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int calorieGoal =
        profile?.effectiveDailyCalories ?? UserProfile.defaultDailyCalories;
    final int sodiumGoal =
        profile?.effectiveDailySodiumMg ?? UserProfile.defaultDailySodiumMg;
    final int sugarGoal =
        profile?.effectiveDailySugarG ?? UserProfile.defaultDailySugarG;
    final int carbsGoal =
        profile?.effectiveDailyCarbsG ?? UserProfile.defaultDailyCarbsG;
    final int proteinGoal =
        profile?.effectiveDailyProteinG ?? UserProfile.defaultDailyProteinG;
    final int fatGoal =
        profile?.effectiveDailyFatG ?? UserProfile.defaultDailyFatG;
    // 끼니 음식의 합을 먼저 쓰고 0이면 서버 하루 합계로 떨어진다. 규칙은
    // 기간 뷰와 공유한다([DietDayTotals]) — 두 화면의 숫자가 갈리지 않도록.
    final int kcal = day.effectiveCalories;
    final int sodium = day.effectiveSodiumMg;
    final double sugar = day.effectiveSugarG;
    final List<_NutritionSummaryItem> items = <_NutritionSummaryItem>[
      _NutritionSummaryItem(
        label: l.dietCalories,
        value: _formatInt(kcal),
        goal: _formatInt(calorieGoal),
        unit: l.unitKcal,
        ratio: _nutritionRatio(kcal, calorieGoal),
        isOverGoal: kcal > calorieGoal,
      ),
      _NutritionSummaryItem(
        label: l.dietSodium,
        value: _formatInt(sodium),
        goal: _formatInt(sodiumGoal),
        unit: l.dietUnitMg,
        ratio: _nutritionRatio(sodium, sodiumGoal),
        isOverGoal: sodium > sodiumGoal,
      ),
      _NutritionSummaryItem(
        label: l.dietSugar,
        value: _formatG(sugar),
        goal: _formatG(sugarGoal.toDouble()),
        unit: l.dietUnitG,
        ratio: _nutritionRatio(sugar, sugarGoal),
        isOverGoal: sugar > sugarGoal,
      ),
      _NutritionSummaryItem(
        label: l.homeMacroProtein,
        value: _grams(day.macros.proteinG),
        goal: _formatG(proteinGoal.toDouble()),
        unit: l.dietUnitG,
        ratio: _nutritionRatio(day.macros.proteinG, proteinGoal),
        isOverGoal: day.macros.proteinG > proteinGoal,
      ),
      _NutritionSummaryItem(
        label: l.homeMacroFat,
        value: _grams(day.macros.fatG),
        goal: _formatG(fatGoal.toDouble()),
        unit: l.dietUnitG,
        ratio: _nutritionRatio(day.macros.fatG, fatGoal),
        isOverGoal: day.macros.fatG > fatGoal,
      ),
      _NutritionSummaryItem(
        label: l.homeMacroCarbs,
        value: _grams(day.macros.carbsG),
        goal: _formatG(carbsGoal.toDouble()),
        unit: l.dietUnitG,
        ratio: _nutritionRatio(day.macros.carbsG, carbsGoal),
        isOverGoal: day.macros.carbsG > carbsGoal,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showHeader) ...<Widget>[
            Text(
              l.dietNutritionSummary,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FigmaColors.ink,
              ),
            ),
            const SizedBox(height: 10),
          ],
          _NutritionSummaryCard(
            calories: items[0],
            calorieDifference: _formatInt((kcal - calorieGoal).abs()),
            carbs: items[5],
            protein: items[3],
            fat: items[4],
          ),
          const SizedBox(height: 12),
          _NutritionStatusCards(
            sodium: items[1],
            sodiumDifference: _formatInt((sodium - sodiumGoal).abs()),
            sugar: items[2],
            sugarDifference: _formatG((sugar - sugarGoal).abs()),
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
                  // 날짜를 옮기거나 식단을 추가해 값이 바뀌면 0에서 다시
                  // 채운다 — 숫자만 조용히 갈리지 않도록.
                  child: ChartReveal(
                    duration: AppMotion.meterFill,
                    replayKey: progress,
                    builder: (BuildContext context, double t) => SizedBox(
                      width:
                          constraints.maxWidth * progress.clamp(0.0, 1.0) * t,
                      height: barHeight,
                      child: ColoredBox(color: color),
                    ),
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
    // 나트륨·당류는 같은 카드에 나란히 놓인 같은 성격의 지표다. "정상"을 서로
    // 다른 색으로 말하면 안 돼서 규칙을 하나로 맞춘다 — 정상 초록, 초과 빨강.
    final Widget sodiumCard = _NutritionStatusCard(
      key: const Key('nutrition-sodium-status'),
      item: sodium,
      difference: sodiumDifference,
      progressColor: sodium.isOverGoal
          ? FigmaColors.dangerRed
          : FigmaColors.greenText,
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
              child: ChartReveal(
                duration: AppMotion.meterFill,
                replayKey: progress,
                builder: (BuildContext context, double t) => SizedBox(
                  width: barWidth,
                  height: barHeight * progress.clamp(0.0, 1.0) * t,
                  child: ColoredBox(color: color),
                ),
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
    required this.date,
    required this.onAdd,
    required this.onEditMeal,
  });

  final List<DietEntry> entries;

  /// 이 목록이 보여 주는 날. 제목 옆에 함께 적는다.
  final DateTime date;

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
              // 제목은 날짜에 매이지 않는다. 이 목록은 늘 **선택한 날**을 보여 주므로
              // '오늘의 식단' 이면 사흘 전을 골랐을 때 제목이 거짓말이 된다(#687).
              // 대신 어느 날 기록인지를 옆에 적어 둔다 — 기간 토글을 이번 주로 두면
              // 7 일짜리 그래프 밑에 하루치 목록이 붙어서, 날짜가 없으면 그 목록이
              // 무엇인지 읽히지 않는다.
              Text(
                l.dietMealLog,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                MaterialLocalizations.of(context).formatMediumDate(date),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
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
      key: meal.id == null ? null : Key('mealCard-${meal.id}'),
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

/// Meal thumbnail: the photo the member uploaded, then the bundled demo
/// asset, then the meal-type emoji chip.
///
/// 실서버에서는 회원이 올린 사진(`photoUrl`)이 온다. 번들 자산은 실서버에 붙으면
/// 늘 비어 있던 데모 값이라 뒤로 물린다. (#699)
class _MealThumb extends StatelessWidget {
  const _MealThumb({required this.meal});
  final DietMeal meal;

  @override
  Widget build(BuildContext context) {
    final String? url = meal.photoUrl;
    if (url != null && url.isNotEmpty) {
      return StoredMealPhoto(
        path: url,
        size: 52,
        fallback: _assetOrEmojiThumb(),
      );
    }
    return _assetOrEmojiThumb();
  }

  Widget _assetOrEmojiThumb() {
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
