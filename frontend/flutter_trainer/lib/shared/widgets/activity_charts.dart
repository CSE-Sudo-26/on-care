/// 운동 그래프 — 회원 앱 운동 탭 `운동 현황` 과 **같은 그림**이다. (#943, #1077,
/// #1168)
///
/// 회원 앱 `features/exercise/presentation/widgets/exercise_activity_status.dart`
/// 의 도넛·링·막대를 트레이너 콘솔 토큰으로 옮긴 것이다. 두 앱은 패키지가 갈라져
/// 있어 코드를 공유할 수 없으므로, 규칙을 여기에도 적어 둔다 —
/// `metric_trend_chart` 를 옮겨 둔 것과 같은 방식이다. 한쪽만 고치면 회원이 보는
/// 그래프와 트레이너가 보는 그래프가 다른 이야기를 한다.
///
///  * 축은 **소모 칼로리**다. 유산소는 분, 근력은 세트, 스트레칭은 분으로 재는
///    값이라 서로 더할 수 없는데, 칼로리는 셋이 함께 만든 하나의 결과다.
///  * 유형 순서는 언제나 유산소 → 근력 → 스트레칭이다. 링도 목록도 같은 순서라,
///    색을 외우지 않아도 자리로 읽힌다.
///  * 목표가 없는 `기타` 는 그리지 않고 분 수만 적는다.
///  * 기록이 없는 칸은 3px 짜리 회색 그루터기다. 0 을 아예 안 그리면 그 칸이
///    빠진 것처럼 보이고, 색을 주면 짧은 운동을 한 것처럼 보인다.
///  * 링 12시에는 그 링이 무엇인지 말하는 흰 기호를, 원호 **끝**에는 그림자와
///    얇은 `>` 를 얹는다 — 한 바퀴를 넘겨 겹쳐도 어디서 멈췄는지 읽힌다.
///
/// 회원 앱에는 진입 애니메이션이 있지만 여기서는 정적으로 그린다. 트레이너
/// 콘솔의 다른 차트(`BarSeriesChart`)도 정적이라, 한 화면에서 어떤 그래프는
/// 자라고 어떤 그래프는 이미 서 있으면 그게 더 튄다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/exercise_burn_goals.dart';
import 'package:oncare_trainer/shared/widgets/chart_semantics.dart';
import 'package:oncare_trainer/shared/widgets/period_scroll_chart.dart';

/// 소모 칼로리 색. **트레이너 메인 색**이다 (#1168).
///
/// 유형 셋이 쓰는 램프([AppColors.chartCardio] 이하)보다 한 단계 진하다 — 도넛과
/// 링이 재는 것은 유형이 아니라 그 셋이 함께 만든 결과라, 램프의 어느 단계와도
/// 겹치면 안 된다. 흰 글자 대비로 4.5 : 3.4 : 2.0 : 1.4 로 네 값이 차례로
/// 벌어진다(회원 앱과 같은 간격).
const Color kBurnColor = AppColors.exerciseChart;

/// 유형 색 — 회원 앱과 같은 순서·같은 농담이다.
Color kindColor(ExerciseKind kind) => switch (kind) {
  ExerciseKind.cardio => AppColors.chartCardio,
  ExerciseKind.strength => AppColors.chartStrength,
  ExerciseKind.stretching => AppColors.chartStretching,
};

/// 유형 이름.
String kindLabel(AppLocalizations l, ExerciseKind kind) => switch (kind) {
  ExerciseKind.cardio => l.routineTypeCardio,
  ExerciseKind.strength => l.routineTypeStrength,
  ExerciseKind.stretching => l.routineTypeStretching,
};

/// 유형의 값을 **그 유형의 단위**로 — 유산소·스트레칭은 분, 근력은 세트.
String kindValueText(AppLocalizations l, ExerciseKind kind, num value) =>
    switch (kind) {
      ExerciseKind.cardio ||
      ExerciseKind.stretching => l.minutesShort(value.round()),
      ExerciseKind.strength => l.exSetsValue(value.round()),
    };

/// 링 12시에 얹는 유형 기호 (회원 앱 #1128).
///
/// 이 링이 무엇인지(유산소·근력·스트레칭)와 어디서 출발했는지를 말한다. 자리를
/// 고정해 두어야 링끼리 견줄 수 있다 — 어디까지 왔는지는 원호 끝의 그림자가
/// 짚는다.
IconData ringStartIcon(ExerciseKind kind) => switch (kind) {
  ExerciseKind.cardio => Icons.directions_run_rounded,
  ExerciseKind.strength => Icons.fitness_center,
  ExerciseKind.stretching => Icons.self_improvement_rounded,
};

/// 소모 칼로리 도넛의 12시 기호.
const IconData kBurnStartIcon = Icons.local_fire_department_rounded;

/// 세 기간 카드의 **공통 높이**. 토글을 눌러도 카드가 커졌다 작아졌다 하지
/// 않도록 셋을 같은 높이로 둔다. 회원 앱과 같은 값이다.
const double kActivityCardHeight = 218;

/// `397/500` — 값과 목표를 한 덩어리로. 목표를 따로 떼어 적으면 머리 줄이
/// 길어져 카드 폭을 다 먹는다.
String activityValueOfGoal(String locale, num value, num goal) {
  final NumberFormat nf = NumberFormat.decimalPattern(locale);
  return '${nf.format(value.round())}/${nf.format(goal.round())}';
}

/// 하루/기간의 유형별 값 한 벌. 단위가 서로 다르므로 더하지 않는다.
class ActivitySplit {
  /// Creates one split.
  const ActivitySplit({
    this.cardioMinutes = 0,
    this.strengthSets = 0,
    this.stretchingMinutes = 0,
    this.otherMinutes = 0,
  });

  final num cardioMinutes;
  final num strengthSets;
  final num stretchingMinutes;

  /// 목표가 없는 나머지 운동. 그래프에는 그리지 않는다.
  final num otherMinutes;

  num valueOf(ExerciseKind kind) => switch (kind) {
    ExerciseKind.cardio => cardioMinutes,
    ExerciseKind.strength => strengthSets,
    ExerciseKind.stretching => stretchingMinutes,
  };
}

/// `오늘` — 소모 칼로리 도넛 하나 + 유형별로 얼마나 했는지 적은 줄.
///
/// 도넛은 **왼쪽**, 유형별 값은 오른쪽이다. 둘을 한 덩어리로 카드 가운데에
/// 세운다 (회원 앱 #1151·#1159). 소모 칼로리는 도넛 **안에서** 말한다 — 링 옆에
/// 같은 숫자를 또 적으면 한 화면에서 같은 말이 두 번 나온다 (#1127).
class BurnDonut extends StatelessWidget {
  /// Creates the donut.
  const BurnDonut({
    super.key,
    required this.calories,
    required this.goal,
    required this.split,
    required this.title,
    this.streakDays,
  });

  final int calories;

  /// 하루 소모 목표(kcal). 0 이면 트랙만 그린다.
  final double goal;
  final ActivitySplit split;

  /// 시맨틱 라벨이 부르는 이름 — `오늘 소모`.
  final String title;

  /// 며칠 연속 운동 중인지. null 이면 그 줄을 그리지 않는다.
  final int? streakDays;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final int? streak = streakDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (streak != null) ...<Widget>[
          ActivityStreakLine(days: streak),
          const SizedBox(height: 6),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final double size = math.min(
                c.maxHeight,
                (c.maxWidth - 170).clamp(96.0, 150.0),
              );
              return Row(
                // 도넛과 상세를 한 덩어리로 **카드 가운데**에 세운다.
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Semantics(
                    container: true,
                    label: chartSemanticsLabel(
                      l,
                      title: title,
                      points: calories == 0
                          ? const <String>[]
                          : <String>['$calories${l.unitKcal}'],
                    ),
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: CustomPaint(
                          painter: _DonutPainter(
                            ratio: goal <= 0 ? 0 : calories / goal,
                            center: NumberFormat.decimalPattern(
                              locale,
                            ).format(calories),
                            // 도넛 안에서 `411` 아래 `/300kcal` 로 읽힌다
                            // (#1127) — 목표는 한 단계 작고 흐리게.
                            unit:
                                '/${NumberFormat.decimalPattern(locale).format(goal.round())}'
                                '${l.unitKcal}',
                            startIcon: kBurnStartIcon,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 상세는 폭을 못 박아 줄들이 서로 붙어 읽힌다. 자리가
                  // 모자라면(좁은 사이드바·큰 글자) `Flexible` 이 그만큼 줄여
                  // 준다 — 못 박기만 하면 카드 밖으로 밀려난다.
                  Flexible(
                    child: SizedBox(
                      width: 150,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (final ExerciseKind kind
                                  in ExerciseKind.values)
                                ActivityValueRow(
                                  label: kindLabel(l, kind),
                                  value: kindValueText(
                                    l,
                                    kind,
                                    split.valueOf(kind),
                                  ),
                                ),
                              if (split.otherMinutes > 0)
                                ActivityValueRow(
                                  label: l.exTypeOther,
                                  value: l.minutesShort(
                                    split.otherMinutes.round(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// `🔥 5일 연속 운동 중이에요!` — 응원 문구 한 줄. (회원 앱 #1160)
///
/// 옅은 주황 알약을 깔아 **응원**임을 표시한다. 배경은 글자 색을 그대로 옅게 쓴
/// 것이라 색이 하나 더 늘지 않는다.
class ActivityStreakLine extends StatelessWidget {
  /// Creates the streak line.
  const ActivityStreakLine({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.brandOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 불꽃은 소모 칼로리 도넛이 쓴다 — 연속은 '기세' 쪽 기호로 갈라
            // 둔다. 한 화면에서 같은 그림이 두 가지를 뜻하면 안 된다.
            const Icon(
              Icons.bolt_rounded,
              size: 16,
              color: AppColors.brandOrange,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                days > 0 ? l.exStreakCheer(days) : l.exStreakStart,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandOrange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `이번 주` — 유형별 주간 목표를 크기 순으로 겹친 세 링 + 유형별 진행.
///
/// 단위가 서로 다르니 높이를 나란히 두지 않고, 각자의 주간 목표에 대한
/// **달성률**만 같은 모양으로 겹쳐 보여 준다.
class BurnGoalRings extends StatelessWidget {
  /// Creates the rings.
  const BurnGoalRings({
    super.key,
    required this.calories,
    required this.split,
    required this.title,
  });

  final int calories;
  final ActivitySplit split;
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final List<double> ratios = <double>[
      for (final ExerciseKind kind in ExerciseKind.values)
        split.valueOf(kind) / weeklyGoalOf(kind),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ActivityHeadlineLine(
          caption: title,
          value: activityValueOfGoal(locale, calories, kWeeklyBurnKcal),
          unit: l.unitKcal,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final double size = math.min(
                c.maxHeight,
                (c.maxWidth - 170).clamp(96.0, 150.0),
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Semantics(
                    container: true,
                    label: chartSemanticsLabel(
                      l,
                      title: title,
                      points: <String>[
                        for (int i = 0; i < ExerciseKind.values.length; i++)
                          '${kindLabel(l, ExerciseKind.values[i])} ${(ratios[i] * 100).round()}%',
                      ],
                    ),
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: CustomPaint(painter: _GoalRingsPainter(ratios)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: SizedBox(
                      width: 150,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (final ExerciseKind kind
                                  in ExerciseKind.values)
                                ActivityValueRow(
                                  color: kindColor(kind),
                                  label: kindLabel(l, kind),
                                  value: '${split.valueOf(kind).round()}',
                                  goal:
                                      '/${kindValueText(l, kind, weeklyGoalOf(kind))}',
                                ),
                              if (split.otherMinutes > 0)
                                ActivityValueRow(
                                  color: AppColors.borderStrong,
                                  label: l.exTypeOther,
                                  value: l.minutesShort(
                                    split.otherMinutes.round(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// `소모  411/300 kcal` — 한 줄짜리 머리.
class ActivityHeadlineLine extends StatelessWidget {
  /// Creates the headline.
  const ActivityHeadlineLine({
    super.key,
    required this.caption,
    required this.value,
    required this.unit,
  });

  final String caption;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          caption,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.subtleForeground,
          ),
        ),
      ],
    ),
  );
}

/// `▪ 유산소   145/150분` — 유형 한 줄.
class ActivityValueRow extends StatelessWidget {
  /// Creates one row.
  const ActivityValueRow({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.goal,
  });

  final String label;
  final String value;

  /// 색 점. 옆에 같은 색 링이 있는 화면에서만 준다 — 오늘 카드는 도넛이
  /// 하나뿐이라 점이 가리킬 데가 없다.
  final Color? color;

  /// `/150분` 처럼 값 뒤에 붙는 목표. 값보다 연하게 적어, 눈이 앞의 숫자를
  /// 먼저 읽고 뒤의 기준을 나중에 보게 한다.
  final String? goal;

  @override
  Widget build(BuildContext context) {
    final Color? c = color;
    final String? g = goal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 10, right: 10),
      child: Row(
        children: <Widget>[
          if (c != null) ...<Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
          ],
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: value),
                    if (g != null)
                      TextSpan(
                        text: g,
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 범례 한 줄 — 색 사각형 + 이름. 식단 기간 카드가 함께 쓴다.
class ActivityLegend extends StatelessWidget {
  /// Creates one legend entry.
  const ActivityLegend({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(AppRadius.xs),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedForeground,
        ),
      ),
    ],
  );
}

/// [BurnBarChart] 가 막대 영역 **밖에** 더 쓰는 세로 크기(간격 + 날짜 라벨 줄).
/// 남는 자리를 그래프에 넘길 때 이만큼을 빼야 카드가 넘치지 않는다.
const double kBurnBarChartExtraHeight = 20;

/// `전체` — **한 칸이 한 주**인 소모 칼로리 막대. 한 칸을 고르면 그 주의
/// 내역이 카드 머리 오른쪽에 뜬다.
class BurnBarChart extends StatelessWidget {
  /// Creates the chart.
  const BurnBarChart({
    super.key,
    required this.calories,
    required this.splits,
    required this.dates,
    required this.title,
    required this.selection,
    this.goalKcal = kDailyBurnKcal,
    this.height = 132,
  });

  final List<int> calories;
  final List<ActivitySplit> splits;
  final List<DateTime> dates;

  /// 그래프가 무엇을 그린 것인지 — 기록이 하나도 없는 기간에 비어 있다고 말할
  /// 때 이 이름으로 부른다(#972).
  final String title;
  final PeriodChartSelection selection;

  /// 한 칸의 소모 목표(kcal). 칸이 하루면 하루 목표, 한 주면 주간 목표다.
  /// 0 이면 목표선을 그리지 않는다.
  final double goalKcal;

  /// **막대 영역**의 세로 크기. 아래 날짜 라벨 줄은 여기에 들어가지 않는다 —
  /// 남는 자리에 맞춰 넘겨줄 때는 [kBurnBarChartExtraHeight] 를 빼야 한다.
  final double height;

  /// 한 화면에 보일 칸 수. 칸 하나가 한 주라, 한 화면이 대략 석 달이다.
  static const int _slotsPerScreen = 13;

  /// 막대 하나의 툴팁 — 소모 칼로리와 그 주의 유형별 내역.
  List<InlineSpan> _tipSpans(AppLocalizations l, int i) {
    final ActivitySplit s = splits[i];
    final List<String> rows = <String>[
      for (final ExerciseKind kind in ExerciseKind.values)
        if (s.valueOf(kind) > 0)
          '${kindLabel(l, kind)}   ${kindValueText(l, kind, s.valueOf(kind))}',
      if (s.otherMinutes > 0)
        '${l.exTypeOther}   ${l.minutesShort(s.otherMinutes.round())}',
    ];
    if (calories[i] <= 0 && rows.isEmpty) {
      return <InlineSpan>[TextSpan(text: l.chartNoRecord)];
    }
    return <InlineSpan>[
      TextSpan(text: '${calories[i]}${l.unitKcal}'),
      if (rows.isNotEmpty) TextSpan(text: '\n${rows.join('\n')}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool empty = calories.every((int c) => c <= 0);
    final double chartHeight = height;
    final double peak = <double>[
      goalKcal,
      for (final int c in calories) c.toDouble(),
    ].fold<double>(1, (double a, double b) => math.max(a, b));
    final double max = peak * 1.15;
    final String locale = Localizations.localeOf(context).toString();

    return Semantics(
      container: true,
      label: empty
          ? chartSemanticsLabel(l, title: title, points: const <String>[])
          : null,
      child: ExcludeSemantics(
        excluding: empty,
        child: ListenableBuilder(
          listenable: selection,
          builder: (BuildContext context, Widget? _) => PeriodScrollChart(
            count: calories.length,
            height: chartHeight,
            selectedIndex: selection.selected,
            onSelected: selection.select,
            onVisibleRangeChanged: selection.setVisible,
            daysPerScreen: _slotsPerScreen,
            // 목표치는 왼쪽 칸에 두 줄로 적는다 (#1071).
            goalBottom: goalKcal > 0
                ? chartHeight * (goalKcal / max).clamp(0.0, 1.0)
                : null,
            goalLabel:
                '${l.clientPeriodGoal}\n${goalKcal.round()}${l.unitKcal}',
            // 달이 바뀌는 칸에만 적는다 — 모든 칸에 적으면 글자가 서로 겹쳐
            // 아무것도 읽히지 않는다. 회원 앱 `전체` 그래프와 같은 규칙이다.
            labelBuilder: (int i) =>
                i < dates.length &&
                    (i == 0 || dates[i].month != dates[i - 1].month)
                ? DateFormat.MMM(locale).format(dates[i])
                : '',
            calloutBuilder: (BuildContext context, int i) =>
                const SizedBox.shrink(),
            barBuilder: (BuildContext context, int i) => Tooltip(
              key: Key('client-exercise-bar-$i'),
              richMessage: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                  height: 1.35,
                ),
                children: _tipSpans(l, i),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderStrong),
                boxShadow: kCardShadow,
              ),
              child: _BurnBarColumn(
                value: calories[i].toDouble(),
                max: max,
                height: chartHeight,
                dimmed: selection.selected != null && selection.selected != i,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 막대 한 칸.
class _BurnBarColumn extends StatelessWidget {
  const _BurnBarColumn({
    required this.value,
    required this.max,
    required this.height,
    required this.dimmed,
  });

  final double value;
  final double max;
  final double height;
  final bool dimmed;

  /// 칸에서 막대가 차지하는 비율. 나머지가 이웃과의 사이가 된다.
  static const double _fill = 0.56;

  @override
  Widget build(BuildContext context) {
    if (value <= 0) {
      // 기록이 없는 칸은 0 짜리 막대가 아니라 그루터기다.
      return Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: _fill,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Opacity(
        opacity: dimmed ? 0.35 : 1,
        // 칸 폭을 다 채우면 막대가 서로 붙어 한 덩어리로 보인다 — 어디까지가
        // 한 주인지 눈으로 셀 수 있어야 한다.
        child: FractionallySizedBox(
          widthFactor: _fill,
          child: Container(
            height: math.max((value / max).clamp(0.0, 1.0) * height, 3),
            decoration: const BoxDecoration(
              color: kBurnColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 소모 칼로리 도넛. 목표를 넘기면 한 바퀴를 넘어 계속 돈다. 가운데에 값과
/// 목표를 두 줄로 적는다 (#1127).
class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.ratio,
    required this.center,
    required this.unit,
    this.startIcon,
  });

  final double ratio;
  final String center;
  final String unit;

  /// 12시 방향 링 머리에 얹을 기호. null 이면 그리지 않는다.
  final IconData? startIcon;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double stroke = size.width * 0.13;
    final double r = size.width / 2 - stroke / 2;
    paintRing(canvas, c, r, stroke, ratio, kBurnColor, startIcon: startIcon);
    // 안쪽 구멍의 지름. 두 줄 다 이 폭 안에 들어간다.
    final double inner = (r - stroke / 2) * 1.75;
    _text(
      canvas,
      c.translate(0, -size.width * 0.09),
      center,
      size.width * 0.2,
      FontWeight.w800,
      AppColors.foreground,
      inner,
    );
    _text(
      canvas,
      c.translate(0, size.width * 0.1),
      unit,
      size.width * 0.105,
      FontWeight.w700,
      AppColors.subtleForeground,
      inner,
    );
  }

  void _text(
    Canvas canvas,
    Offset center,
    String s,
    double size,
    FontWeight w,
    Color color,
    double maxWidth,
  ) {
    TextPainter layout(double fontSize) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: w,
          color: color,
          letterSpacing: -0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    TextPainter tp = layout(size);
    // 도넛 **안**에 들어가야 한다. 넘치면 그만큼 글자를 줄인다 — 링 밖으로
    // 삐져나온 글씨는 어느 링의 값인지 알려 주지 못한다. (#1127)
    if (tp.width > maxWidth) tp = layout(size * (maxWidth / tp.width));
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.ratio != ratio || old.center != center || old.unit != unit;
}

/// 유형별 주간 목표를 크기 순으로 겹친 세 링.
class _GoalRingsPainter extends CustomPainter {
  _GoalRingsPainter(this.ratios);

  final List<double> ratios;

  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    final double hole = radius * 0.22;
    final double stroke = (radius - _gap * 2 - hole) / 3;
    double r = radius - stroke / 2;
    for (int i = 0; i < ratios.length; i++) {
      final ExerciseKind kind = ExerciseKind.values[i];
      paintRing(
        canvas,
        c,
        r,
        stroke,
        ratios[i],
        kindColor(kind),
        startIcon: ringStartIcon(kind),
      );
      r -= stroke + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _GoalRingsPainter old) => old.ratios != ratios;
}

/// 링 하나 — 트랙 + 채운 호. 목표를 넘기면 한 바퀴를 넘어 이어 그리고, 겹친
/// 끝 아래에 그림자를 깔아 어디서 멈췄는지 보이게 한다. 그림자는 그 링의
/// 두께로 잘라 밖으로 번지지 않는다.
///
/// [startIcon] 을 주면 12시에 흰 기호를 얹는다 — 이 링이 무엇인지와 어디서
/// 출발했는지를 말한다. 원호의 **끝**에는 얇은 `>` 를 얹어 어디까지 왔는지와
/// 어느 쪽으로 도는지를 함께 짚는다.
void paintRing(
  Canvas canvas,
  Offset center,
  double radius,
  double stroke,
  double ratio,
  Color color, {
  IconData? startIcon,
}) {
  final Rect rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.16),
  );
  double capAngle = -math.pi / 2;
  final Paint arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..color = color;
  if (ratio >= 1) {
    // 한 바퀴는 **끝이 없는 원**으로. 2π 원호에 둥근 끝을 주면 시작과 끝의
    // 캡이 같은 자리에 겹쳐 혹처럼 튀어나온다.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color,
    );
    final double over = math.min(ratio - 1, 1);
    capAngle = -math.pi / 2 + math.pi * 2 * over;
    _paintCapShadow(canvas, center, radius, stroke, capAngle);
    if (over > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * over, false, arc);
    }
  } else if (ratio > 0) {
    capAngle = -math.pi / 2 + math.pi * 2 * ratio;
    _paintCapShadow(canvas, center, radius, stroke, capAngle);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * ratio, false, arc);
  }
  if (ratio > 0) {
    _paintCapChevron(canvas, center, radius, stroke, capAngle);
  }
  // 유형 기호는 12시에 고정한다 — 링이 한 바퀴를 넘겨 겹쳐도 가려지지 않게
  // 맨 위에 그린다.
  if (startIcon != null) {
    _paintStartIcon(canvas, center, radius, stroke, startIcon);
  }
}

/// 원호의 **끝(캡)** 아래에 깔 그림자. 넓고 흐린 것 위에 좁고 진한 것을 겹쳐
/// 찍어, 끝이 아래 트랙(또는 한 바퀴 돈 같은 색 원)에 묻히지 않게 한다.
///
/// 그리기 전에 캔버스를 **그 링의 두께**로 자른다 — 자르지 않으면 흐린
/// 가장자리가 링 밖으로 번져 도넛 주위에 얼룩이 남는다.
void _paintCapShadow(
  Canvas canvas,
  Offset center,
  double radius,
  double stroke,
  double capAngle,
) {
  final Path ring = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: center, radius: radius + stroke / 2))
    ..addOval(Rect.fromCircle(center: center, radius: radius - stroke / 2));
  final Offset cap =
      center + Offset(math.cos(capAngle), math.sin(capAngle)) * radius;
  canvas
    ..save()
    ..clipPath(ring)
    // 두 겹으로 깐다. 넓고 흐린 것이 링 위에 얹힌 느낌을 만들고, 좁고 진한
    // 것이 끝의 위치를 못 박는다. 가장 연한 링(스트레칭) 위에서도 보여야
    // 하므로 진하고 넓게 둔다. (회원 앱 #1161 과 같은 값)
    ..drawCircle(
      cap,
      stroke / 2 + 4,
      Paint()
        ..color = const Color(0xBF000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    )
    ..drawCircle(
      cap,
      stroke / 2 + 1,
      Paint()
        ..color = const Color(0xA6000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    )
    ..restore();
}

/// 원호의 **끝**에 얹는 얇고 작은 흰 `>`. 어디까지 왔는지와 어느 쪽으로 도는지를
/// 함께 짚는다. 링이 너무 얇으면 기호가 링을 다 덮으므로 그리지 않는다.
void _paintCapChevron(
  Canvas canvas,
  Offset center,
  double radius,
  double stroke,
  double angle,
) {
  final double arm = stroke * 0.16;
  if (arm < 1.4) return;
  final Offset at =
      center + Offset(math.cos(angle), math.sin(angle)) * radius;
  canvas
    ..save()
    ..translate(at.dx, at.dy)
    // 접선 방향으로 눕힌다 — 시계 방향으로 도는 원호에서는 각도 + 90도다.
    ..rotate(angle + math.pi / 2)
    ..drawPath(
      Path()
        ..moveTo(-arm * 0.55, -arm)
        ..lineTo(arm * 0.55, 0)
        ..lineTo(-arm * 0.55, arm),
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(stroke * 0.07, 1)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    )
    ..restore();
}

/// 링 12시에 흰 기호를 얹는다. 링 두께 안에 들어가도록 두께에 맞춰 줄인다.
void _paintStartIcon(
  Canvas canvas,
  Offset center,
  double radius,
  double stroke,
  IconData icon,
) {
  final double glyph = stroke * 0.78;
  if (glyph < 6) return;
  final TextPainter tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: glyph,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: const Color(0xFFFFFFFF),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final Offset at = center + const Offset(0, -1) * radius;
  tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
}
