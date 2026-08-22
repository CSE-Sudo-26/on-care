import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/design_system/charts/chart_reveal.dart';
import 'package:oncare/design_system/charts/goal_line.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/figma/section_title.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/motion.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_load.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/services/exercise_burn_goal_provider.dart';

/// `운동 현황` 의 기본 기간 — 0 = 오늘, 1 = 이번 주, 2 = 전체.
const int kExerciseActivityPeriodDefault = 0;

/// 오늘/이번 주/전체 토글. 탭을 벗어났다 들어오면 기본값으로 돌아가야 하는
/// 임시 UI 상태라 Riverpod 에 둔다(#861).
final exerciseActivityPeriodProvider = StateProvider<int>(
  (ref) => kExerciseActivityPeriodDefault,
  name: 'exerciseActivityPeriod',
);

/// 세 기간 카드의 **공통 높이**. 토글을 눌러도 카드가 커졌다 작아졌다 하지
/// 않도록 셋을 같은 높이로 고정한다.
const double kActivityCardHeight = 218;
const double _kCardPadding = 14;

/// 카드 안쪽 **좌우** 여백. 세로보다 넉넉하게 둔다.
const double _kCardPaddingH = 28;

// ── 유형별 색·라벨·단위 ────────────────────────────────────────────────

Color kindColor(ExerciseLoadKind kind) => switch (kind) {
  ExerciseLoadKind.cardio => FigmaColors.primary,
  ExerciseLoadKind.strength => const Color(0xFF1B6FA8),
  ExerciseLoadKind.flexibility => const Color(0xFF8FD9F2),
};

String kindLabel(AppLocalizations l, ExerciseLoadKind kind) => switch (kind) {
  ExerciseLoadKind.cardio => l.exTypeCardio,
  ExerciseLoadKind.strength => l.exTypeStrength,
  ExerciseLoadKind.flexibility => l.exTypeStretching,
};

/// 유형의 **원래 단위**로 읽는다 — 유산소·스트레칭은 분, 근력은 세트.
String kindValueText(AppLocalizations l, ExerciseLoadKind kind, double v) =>
    switch (kind) {
      ExerciseLoadKind.cardio ||
      ExerciseLoadKind.flexibility => l.unitMinutesValue(v.round()),
      ExerciseLoadKind.strength => l.exProgramSets(v.round()),
    };

/// 소모 칼로리 색. 유산소·근력·스트레칭 세 유형과 **다른 색**이어야 한다
/// (#1127) — 도넛과 링이 재는 것은 유형이 아니라 그 셋이 함께 만든 결과다.
/// 트레이너 앱의 메인 색(#2E7DAB)을 빌려 온다.
const Color kBurnColor = Color(0xFF2E7DAB);

DateTime _thisMonday() {
  final DateTime n = nowKst();
  final DateTime d = DateTime(n.year, n.month, n.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

DateTime _today() {
  final DateTime n = nowKst();
  return DateTime(n.year, n.month, n.day);
}

/// `397/500` — 값과 목표를 한 덩어리로. 목표를 따로 떼어 적으면 머리 줄이
/// 길어져 카드 폭을 다 먹는다.
String _valueOfGoal(String locale, double value, double goal) {
  final NumberFormat nf = NumberFormat.decimalPattern(locale);
  return '${nf.format(value.round())}/${nf.format(goal.round())}';
}

/// 원호의 **끝(캡)** 아래에 깔 그림자. 넓고 흐린 것 위에 좁고 진한 것을 겹쳐
/// 찍어, 끝이 아래 트랙(또는 한 바퀴 돈 같은 색 원)에 묻히지 않게 한다.
///
/// 그리기 전에 캔버스를 **그 링의 두께**로 자른다 — 자르지 않으면 흐린 가장자리가
/// 링 밖으로 번져 도넛 주위에 얼룩이 남는다.
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
    ..drawCircle(
      cap,
      stroke / 2 + 1,
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    )
    ..drawCircle(
      cap,
      stroke / 2,
      Paint()
        ..color = const Color(0x4D000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    )
    ..restore();
}

/// 그 달의 몇 번째 주인지 — `8월 1주차` 의 1.
int _weekOfMonth(DateTime monday) => ((monday.day - 1) ~/ 7) + 1;

/// 운동 현황 — 오늘 / 이번 주 / 전체.
///
/// 세 화면이 보는 축은 **소모 칼로리**다. 유산소는 분, 근력은 세트, 스트레칭은
/// 분으로 재는 값이라 서로 더할 수 없는데, 칼로리는 셋이 함께 만든 하나의
/// 결과라서 도넛과 막대의 높이로 쓸 수 있다. 유형별 값은 언제나 **제 단위**로
/// 따로 적는다.
class ExerciseActivityStatus extends ConsumerStatefulWidget {
  const ExerciseActivityStatus({required this.week, super.key});

  /// 오늘 체크한 AI 루틴까지 반영된 이번 주 기록(`exerciseWeekViewProvider`).
  final ExerciseWeek week;

  @override
  ConsumerState<ExerciseActivityStatus> createState() =>
      _ExerciseActivityStatusState();
}

class _ExerciseActivityStatusState
    extends ConsumerState<ExerciseActivityStatus> {
  /// MY 건강 목표에서 저장한 값. 저장한 적이 없으면 권장값이다 (#1139).
  ExerciseLoadGoals get _goals => ref.watch(exerciseLoadGoalsProvider);

  List<ExerciseDayLoad> get _loads =>
      dayLoadsOfWeek(widget.week, _thisMonday());

  ExerciseDayLoad get _todayLoad {
    final DateTime d = _today();
    return _loads.firstWhere(
      (ExerciseDayLoad e) => e.date == d,
      orElse: () => ExerciseDayLoad(date: d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int period = ref.watch(exerciseActivityPeriodProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 제목과 기간 토글은 한 줄에. 식단 탭 `영양 요약` 과 같은 자리다.
        Row(
          key: const ValueKey<String>('exercise-section-header'),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SectionTitle(
                  // 하단 탭의 운동 아이콘과 같은 것을 쓴다 (#1126) — 이 화면이
                  // 어느 탭의 것인지 제목 줄에서 바로 읽힌다.
                  icon: Icons.fitness_center,
                  label: l.exActivityTitle,
                ),
              ),
            ),
            Flexible(
              flex: 2,
              child: _PeriodToggle(
                active: period,
                labels: <String>[l.exToday, l.exThisWeek, l.exPeriodAll],
                onChanged: (int i) =>
                    ref.read(exerciseActivityPeriodProvider.notifier).state = i,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (period == 0)
          ExerciseDayLoadCard(
            load: _todayLoad,
            goals: _goals,
            streakDays: widget.week.streakDays,
          )
        else if (period == 1)
          _WeekView(loads: _loads, goals: _goals)
        else
          _AllPeriodView(goals: _goals),
      ],
    );
  }
}

// ── 오늘 ──────────────────────────────────────────────────────────────

/// 오늘 = **소모 칼로리 도넛 하나** + 유형별로 얼마나 했는지 적은 줄.
///
/// 유형마다 목표를 세워 링 셋을 겹치던 때보다 읽을 것이 적다. 오늘 답해야 할
/// 질문은 "얼마나 태웠나" 하나이고, 유산소 몇 분·근력 몇 세트는 그 숫자의
/// 내역이라 글자로 충분하다.
class ExerciseDayLoadCard extends StatelessWidget {
  const ExerciseDayLoadCard({
    required this.load,
    this.goals = kDefaultExerciseLoadGoals,
    this.isToday = true,
    this.streakDays,
    super.key,
  });

  final ExerciseDayLoad load;
  final ExerciseLoadGoals goals;

  /// 지난 날짜 상세에서도 같은 카드를 쓴다.
  final bool isToday;

  /// 며칠 연속 운동 중인지. **오늘 카드에만** 있다. null 이면 그리지 않는다.
  final int? streakDays;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final int? streak = streakDays;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (streak != null) ...<Widget>[
            _StreakLine(days: streak),
            const SizedBox(height: 6),
          ],
          // 소모 칼로리는 도넛 **안에서** 말한다 (#1127) — 링 옆에 같은 숫자를
          // 또 적으면 한 화면에서 같은 말이 두 번 나온다. 도넛은 오른쪽,
          // 유형별 값은 왼쪽에 두고 라벨과 값이 멀어지지 않도록 폭을 묶는다.
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double donut = math.min(
                  c.maxHeight,
                  (c.maxWidth - 170).clamp(96.0, 150.0),
                );
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          // 라벨과 값이 카드 양 끝으로 벌어지지 않게 묶는다.
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              for (final ExerciseLoadKind k
                                  in ExerciseLoadKind.values)
                                _KindTextRow(
                                  label: kindLabel(l, k),
                                  value: kindValueText(l, k, load.valueOf(k)),
                                ),
                              if (load.otherMinutes > 0)
                                _KindTextRow(
                                  label: l.exTypeOtherChip,
                                  value: l.unitMinutesValue(
                                    load.otherMinutes.round(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _BurnDonut(
                      calories: load.calories,
                      goal: goals.dailyBurnKcal,
                      size: donut,
                      locale: locale,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// `🔥 5일 연속 운동 중이에요!`
class _StreakLine extends StatelessWidget {
  const _StreakLine({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        const Icon(
          Icons.local_fire_department_rounded,
          size: 16,
          color: FigmaColors.heartOrange,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            days > 0 ? l.exStreakCheer(days) : l.exStreakStart,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: FigmaColors.heartOrange,
            ),
          ),
        ),
      ],
    );
  }
}

/// `▪ 유산소     15분` — 목표 없이 **한 값만** 적는 줄.
class _KindTextRow extends StatelessWidget {
  const _KindTextRow({
    required this.label,
    required this.value,
    this.color,
    this.goal,
  });

  final String label;
  final String value;

  /// 색 점. 옆에 같은 색의 링이 있는 화면(이번 주)에서만 준다 — 오늘 카드는
  /// 도넛이 하나뿐이라 점이 가리킬 데가 없다.
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
                  color: FigmaColors.textBody,
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
                        style: const TextStyle(color: FigmaColors.textBody),
                      ),
                  ],
                ),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.ink,
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

/// 링 머리에 얹는 기호 (#1128).
///
/// 애플 액티비티 링처럼 **어디서 시작해 어디까지 왔는지**를 12시 방향의 작은
/// 기호로 알린다. 링이 한 바퀴를 넘겨 겹칠 때도 이 기호는 맨 위에 그려 가려지지
/// 않는다. 기호는 링 두께 안에 들어가도록 두께에 맞춰 줄인다.
const IconData _kBurnStartIcon = Icons.local_fire_department_rounded;

IconData ringStartIcon(ExerciseLoadKind kind) => switch (kind) {
  ExerciseLoadKind.cardio => Icons.directions_run_rounded,
  ExerciseLoadKind.strength => Icons.fitness_center,
  ExerciseLoadKind.flexibility => Icons.self_improvement_rounded,
};

void paintRingStartIcon(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required double stroke,
  required IconData icon,
}) {
  final double glyph = stroke * 0.78;
  if (glyph < 6) return;
  final TextPainter tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: glyph,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
    canvas,
    Offset(center.dx - tp.width / 2, center.dy - radius - tp.height / 2),
  );
}

/// 소모 칼로리 도넛 하나. 목표를 넘기면 **한 바퀴를 넘어 계속 돈다**(끝이
/// 앞으로 나가고 그 아래 그림자가 깔린다).
class _BurnDonut extends StatelessWidget {
  const _BurnDonut({
    required this.calories,
    required this.goal,
    required this.size,
    required this.locale,
  });

  final double calories;
  final double goal;
  final double size;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final double ratio = goal <= 0 ? 0 : calories / goal;
    return Semantics(
      label:
          '${l.exBurnTodayTitle} ${l.unitKcalValue(calories.round())}, '
          '${l.exGoalValue(l.unitKcalValue(goal.round()))}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: ChartReveal(
            duration: AppMotion.chartGrow,
            curve: Curves.linear,
            replayKey: calories,
            builder: (BuildContext context, double t) => CustomPaint(
              painter: _DonutPainter(
                ratio: ratio,
                t: t,
                color: kBurnColor,
                center: NumberFormat.decimalPattern(
                  locale,
                ).format(calories.round()),
                // 도넛 안에서 `411` 아래 `/300kcal` 로 읽힌다 (#1127) —
                // 목표는 한 단계 작고 흐리게.
                unit:
                    '/${NumberFormat.decimalPattern(locale).format(goal.round())}'
                    '${l.unitKcal}',
                startIcon: _kBurnStartIcon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.ratio,
    required this.t,
    required this.color,
    required this.center,
    required this.unit,
    this.startIcon,
  });

  final double ratio;
  final double t;
  final Color color;
  final String center;
  final String unit;

  /// 12시 방향 링 머리에 얹을 기호. null 이면 그리지 않는다. (#1128)
  final IconData? startIcon;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double stroke = size.width * 0.13;
    final double r = size.width / 2 - stroke / 2;
    final Rect rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.16),
    );
    final double filled = ratio * t;
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (filled >= 1) {
      // 한 바퀴는 **끝이 없는 원**으로. 2π 원호에 둥근 끝을 주면 시작과 끝의
      // 캡이 같은 자리에 겹쳐 혹처럼 튀어나온다.
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color,
      );
      final double over = math.min(filled - 1, 1);
      final double capAngle = -math.pi / 2 + math.pi * 2 * over;
      _paintCapShadow(canvas, c, r, stroke, capAngle);
      if (over > 0) {
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * over, false, arc);
      }
    } else if (filled > 0) {
      final double capAngle = -math.pi / 2 + math.pi * 2 * filled;
      _paintCapShadow(canvas, c, r, stroke, capAngle);
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * filled, false, arc);
    }
    // 안쪽 구멍의 지름. 두 줄 다 이 폭 안에 들어간다.
    final double inner = (r - stroke / 2) * 1.75;
    _text(
      canvas,
      c.translate(0, -size.width * 0.09),
      center,
      size.width * 0.2,
      FontWeight.w800,
      FigmaColors.ink,
      maxWidth: inner,
    );
    _text(
      canvas,
      c.translate(0, size.width * 0.1),
      unit,
      size.width * 0.105,
      FontWeight.w700,
      FigmaColors.textMuted,
      maxWidth: inner,
    );
    // 링이 어디서 시작하는지 12시 방향에 작은 기호로 알린다 (#1128).
    final IconData? icon = startIcon;
    if (icon != null) {
      paintRingStartIcon(
        canvas,
        center: c,
        radius: r,
        stroke: stroke,
        icon: icon,
      );
    }
  }

  void _text(
    Canvas canvas,
    Offset center,
    String s,
    double size,
    FontWeight w,
    Color color, {
    double? maxWidth,
  }) {
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
    if (maxWidth != null && tp.width > maxWidth) {
      tp = layout(size * (maxWidth / tp.width));
    }
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.t != t ||
      old.ratio != ratio ||
      old.center != center ||
      old.unit != unit;
}

// ── 이번 주 ────────────────────────────────────────────────────────────

/// 이번 주 = **유형별 목표를 채우는 3중 링** + 요일별 소모 칼로리 막대.
///
/// 링은 셋이 크기 순으로 겹친다(바깥 유산소 → 근력 → 스트레칭). 단위가 서로
/// 다르니 높이를 나란히 두지 않고, 각자의 주간 목표에 대한 **달성률**만 같은
/// 모양으로 겹쳐 보여 준다.
class _WeekView extends StatefulWidget {
  const _WeekView({required this.loads, required this.goals});

  final List<ExerciseDayLoad> loads;
  final ExerciseLoadGoals goals;

  @override
  State<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<_WeekView> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final List<ExerciseDayLoad> loads = widget.loads;
    if (loads.isEmpty) {
      return _Card(child: Center(child: _Muted(l.exLoadEmpty)));
    }
    final ExerciseLoadGoals g = widget.goals;
    final double weekKcal = loads.fold<double>(
      0,
      (double a, ExerciseDayLoad d) => a + d.calories,
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _HeadlineLine(
            caption: l.exBurnWeekTitle,
            value: _valueOfGoal(locale, weekKcal, g.weeklyBurnKcal),
            unit: l.unitKcal,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) => Row(
                children: <Widget>[
                  _GoalRings(
                    loads: loads,
                    goals: g,
                    size: math.min(
                      c.maxHeight,
                      (c.maxWidth - 170).clamp(96.0, 150.0),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (final ExerciseLoadKind k
                            in ExerciseLoadKind.values)
                          _KindTextRow(
                            color: kindColor(k),
                            label: kindLabel(l, k),
                            value: '${_sum(loads, k).round()}',
                            goal: '/${kindValueText(l, k, g.weeklyGoalOf(k))}',
                          ),
                        // 기타는 목표가 없다 — 오늘 카드와 같이 분만 적는다.
                        if (_otherSum(loads) > 0)
                          _KindTextRow(
                            color: const Color(0xFFCBD6DE),
                            label: l.exTypeOtherChip,
                            value: l.unitMinutesValue(_otherSum(loads).round()),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _sum(List<ExerciseDayLoad> loads, ExerciseLoadKind k) =>
      loads.fold<double>(0, (double a, ExerciseDayLoad d) => a + d.valueOf(k));

  double _otherSum(List<ExerciseDayLoad> loads) => loads.fold<double>(
    0,
    (double a, ExerciseDayLoad d) => a + d.otherMinutes,
  );
}

/// 크기가 다른 세 링. 바깥부터 유산소 → 근력 → 스트레칭.
class _GoalRings extends StatelessWidget {
  const _GoalRings({
    required this.loads,
    required this.goals,
    required this.size,
  });

  final List<ExerciseDayLoad> loads;
  final ExerciseLoadGoals goals;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<double> ratios = <double>[
      for (final ExerciseLoadKind k in ExerciseLoadKind.values)
        () {
          final double goal = goals.weeklyGoalOf(k);
          if (goal <= 0) return 0.0;
          return loads.fold<double>(
                0,
                (double a, ExerciseDayLoad d) => a + d.valueOf(k),
              ) /
              goal;
        }(),
    ];
    return Semantics(
      label: <String>[
        for (int i = 0; i < ExerciseLoadKind.values.length; i++)
          '${kindLabel(l, ExerciseLoadKind.values[i])} ${(ratios[i] * 100).round()}%',
      ].join(', '),
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: ChartReveal(
            duration: AppMotion.chartGrow,
            curve: Curves.linear,
            replayKey: ratios.join(','),
            builder: (BuildContext context, double t) => CustomPaint(
              painter: _RingsPainter(ratios: ratios, t: t),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.ratios, required this.t});

  final List<double> ratios;
  final double t;

  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    final double hole = radius * 0.22;
    final double stroke = (radius - _gap * 2 - hole) / 3;
    double r = radius - stroke / 2;
    for (int i = 0; i < ratios.length; i++) {
      final Color color = kindColor(ExerciseLoadKind.values[i]);
      final Rect rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color.withValues(alpha: 0.16),
      );
      final double ratio = ratios[i] * chartStagger(t, i, 3);
      final Paint arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      if (ratio >= 1) {
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = color,
        );
        final double over = math.min(ratio - 1, 1);
        final double capAngle = -math.pi / 2 + math.pi * 2 * over;
        _paintCapShadow(canvas, c, r, stroke, capAngle);
        if (over > 0) {
          canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * over, false, arc);
        }
      } else if (ratio > 0) {
        final double capAngle = -math.pi / 2 + math.pi * 2 * ratio;
        _paintCapShadow(canvas, c, r, stroke, capAngle);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * ratio, false, arc);
      }
      // 링마다 12시 방향에 그 유형의 기호를 얹는다 (#1128) — 세 링이 어디서
      // 출발했는지, 어느 링이 무엇인지 색만으로 재지 않아도 된다.
      paintRingStartIcon(
        canvas,
        center: c,
        radius: r,
        stroke: stroke,
        icon: ringStartIcon(ExerciseLoadKind.values[i]),
      );
      r -= stroke + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) =>
      old.t != t || old.ratios != ratios;
}

/// 막대 하나. 기록이 없는 칸은 0 짜리 막대가 아니라 **그루터기**로 그린다 —
/// 0 높이 막대는 아무것도 없는 것처럼 보여, 쉰 주와 아직 오지 않은 주가
/// 구분되지 않는다.
class _BurnBar extends StatelessWidget {
  const _BurnBar({
    required this.value,
    required this.max,
    required this.height,
    required this.width,
    required this.t,
    required this.dimmed,
  });

  final double value;
  final double max;
  final double height;
  final double width;
  final double t;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    if (value <= 0) {
      return Container(
        width: width,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE6ECF1),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Container(
        width: width,
        height: math.max((value / max).clamp(0.0, 1.0) * height * t, 3),
        decoration: const BoxDecoration(
          color: kBurnColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ),
    );
  }
}

// ── 전체 ───────────────────────────────────────────────────────────────

/// 한 주치 묶음 — 전체 그래프의 막대 하나.
class _WeekBucket {
  const _WeekBucket({
    required this.monday,
    required this.calories,
    required this.cardioMinutes,
    required this.strengthSets,
    required this.flexibilityMinutes,
    required this.otherMinutes,
  });

  final DateTime monday;
  final double calories;
  final double cardioMinutes;
  final int strengthSets;
  final double flexibilityMinutes;

  /// 목표가 없는 나머지 운동. 오늘·이번 주와 같이 분만 적는다.
  final double otherMinutes;

  double valueOf(ExerciseLoadKind kind) => switch (kind) {
    ExerciseLoadKind.cardio => cardioMinutes,
    ExerciseLoadKind.strength => strengthSets.toDouble(),
    ExerciseLoadKind.flexibility => flexibilityMinutes,
  };
}

/// 전체 = **주 하나가 막대 하나**인 얇은 막대 그래프.
///
/// 하루 단위로 그리면 열두 주가 여든네 칸이 되어 어느 주가 좋았는지 읽히지
/// 않는다. 주로 묶으면 오르내림이 그대로 보이고, 한 칸을 누르면 그 주의
/// 유산소·근력·스트레칭이 아래에 펼쳐진다.
class _AllPeriodView extends ConsumerWidget {
  const _AllPeriodView({required this.goals});

  final ExerciseLoadGoals goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ref
        .watch(exerciseAllPeriodProvider)
        .when(
          loading: () => const _Card(
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (Object _, StackTrace _) =>
              _Card(child: Center(child: _Muted(l.exLoadError))),
          data: (List<ExerciseDayBar> days) {
            if (days.isEmpty) {
              return _Card(child: Center(child: _Muted(l.exLoadEmpty)));
            }
            final Map<DateTime, List<ExerciseDayBar>> byWeek =
                <DateTime, List<ExerciseDayBar>>{};
            for (final ExerciseDayBar d in days) {
              final DateTime monday = d.date.subtract(
                Duration(days: d.date.weekday - 1),
              );
              byWeek.putIfAbsent(monday, () => <ExerciseDayBar>[]).add(d);
            }
            final List<DateTime> mondays = byWeek.keys.toList()..sort();
            final List<_WeekBucket> weeks = <_WeekBucket>[
              for (final DateTime m in mondays)
                _WeekBucket(
                  monday: m,
                  calories: byWeek[m]!.fold<double>(
                    0,
                    (double a, ExerciseDayBar d) => a + d.calories,
                  ),
                  cardioMinutes: byWeek[m]!.fold<double>(
                    0,
                    (double a, ExerciseDayBar d) => a + d.cardio,
                  ),
                  strengthSets: byWeek[m]!.fold<int>(
                    0,
                    (int a, ExerciseDayBar d) => a + d.strengthSets.round(),
                  ),
                  flexibilityMinutes: byWeek[m]!.fold<double>(
                    0,
                    (double a, ExerciseDayBar d) => a + d.stretching,
                  ),
                  otherMinutes: byWeek[m]!.fold<double>(
                    0,
                    (double a, ExerciseDayBar d) => a + d.other,
                  ),
                ),
            ];
            return _AllPeriodBody(weeks: weeks, goals: goals);
          },
        );
  }
}

class _AllPeriodBody extends StatefulWidget {
  const _AllPeriodBody({required this.weeks, required this.goals});

  final List<_WeekBucket> weeks;
  final ExerciseLoadGoals goals;

  @override
  State<_AllPeriodBody> createState() => _AllPeriodBodyState();
}

class _AllPeriodBodyState extends State<_AllPeriodBody> {
  int? _selected;

  /// 지금 화면에 들어와 있는 주의 범위. 옆으로 밀면 머리의 평균이 **보이는
  /// 구간**을 따라간다 — 여덟 달치를 통째로 평균 내면 어느 달을 보고 있든
  /// 같은 숫자라, 그래프를 미는 의미가 없다.
  int _firstVisible = 0;
  int _lastVisible = 0;

  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final List<_WeekBucket> weeks = widget.weeks;
    final int? sel = _selected;
    final _WeekBucket? picked = sel == null ? null : weeks[sel];
    final int from = _firstVisible.clamp(0, weeks.length - 1);
    final int to = _lastVisible.clamp(from, weeks.length - 1);
    final List<_WeekBucket> visible = weeks.sublist(from, to + 1);
    final double visibleAverage = visible.isEmpty
        ? 0
        : visible.fold<double>(0, (double a, _WeekBucket w) => a + w.calories) /
              visible.length;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 6,
                child: _HeadlineLine(
                  caption: picked == null
                      ? l.exBurnAllTitle
                      : l.exWeekOfMonthLabel(
                          picked.monday.month,
                          _weekOfMonth(picked.monday),
                        ),
                  // 고른 주가 없으면 **지금 보이는 구간의 주 평균**이다.
                  value: _valueOfGoal(
                    locale,
                    picked?.calories ?? visibleAverage,
                    widget.goals.weeklyBurnKcal,
                  ),
                  unit: l.unitKcal,
                ),
              ),
              // 고른 주의 내역은 kcal **오른쪽**에 붙는다 (#1129) — 그래프
              // 아래에 따로 두면 구분선까지 필요해져 카드가 셋으로 갈렸다.
              // 색 네모는 뺐다. 옆의 막대가 이미 색으로 말한다.
              if (picked != null) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      for (final ExerciseLoadKind k in ExerciseLoadKind.values)
                        _AllPeriodDetailLine(
                          text:
                              '${kindLabel(l, k)} '
                              '${kindValueText(l, k, picked.valueOf(k))}',
                        ),
                      if (picked.otherMinutes > 0)
                        _AllPeriodDetailLine(
                          text:
                              '${l.exTypeOtherChip} '
                              '${l.unitMinutesValue(picked.otherMinutes.round())}',
                        ),
                    ],
                  ),
                ),
              ],
              if (picked == null && visible.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                // 평균이 어느 구간의 것인지 숫자만으로는 알 수 없다 — 밀 때마다
                // 바뀌는 값이라 기간을 옆에 붙여 둔다.
                Expanded(
                  flex: 4,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${DateFormat.Md(locale).format(visible.first.monday)}'
                      ' ~ '
                      '${DateFormat.Md(locale).format(visible.last.monday.add(const Duration(days: 6)))}',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.textBody,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _WeeklyBurnChart(
              controller: _scroll,
              weeks: weeks,
              goal: widget.goals.weeklyBurnKcal,
              selected: _selected,
              onTap: (int i) =>
                  setState(() => _selected = _selected == i ? null : i),
              onVisibleChanged: (int first, int last) {
                if (first == _firstVisible && last == _lastVisible) return;
                setState(() {
                  _firstVisible = first;
                  _lastVisible = last;
                });
              },
              locale: locale,
            ),
          ),
        ],
      ),
    );
  }
}

/// 고른 주의 유형별 내역 한 줄 — `유산소 195분`. 색 네모 없이 글자만 쓴다
/// (#1129) — 색은 바로 옆 막대가 이미 말하고 있다.
class _AllPeriodDetailLine extends StatelessWidget {
  const _AllPeriodDetailLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 1),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: FigmaColors.textBody,
        ),
      ),
    ),
  );
}

class _WeeklyBurnChart extends StatelessWidget {
  const _WeeklyBurnChart({
    required this.controller,
    required this.weeks,
    required this.goal,
    required this.selected,
    required this.onTap,
    required this.onVisibleChanged,
    required this.locale,
  });

  final ScrollController controller;
  final List<_WeekBucket> weeks;
  final double goal;
  final int? selected;
  final ValueChanged<int> onTap;

  /// 화면에 들어온 주의 [첫, 마지막] 인덱스.
  final void Function(int first, int last) onVisibleChanged;
  final String locale;

  /// 한 주가 차지하는 가로. 화면에 다 안 들어가면 **옆으로 밀어** 본다 —
  /// 폭에 맞춰 칸을 좁히면 주가 늘어날수록 막대가 실오라기가 된다.
  static const double _slot = 26;

  @override
  Widget build(BuildContext context) {
    final double peak = <double>[
      goal,
      for (final _WeekBucket w in weeks) w.calories,
    ].fold<double>(1, (double a, double b) => b > a ? b : a);
    final double max = peak * 1.12;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double chartH = c.maxHeight - 16;
        final double width = math.max(_slot * weeks.length, c.maxWidth);

        /// 뒤집힌 스크롤이라 offset 0 이 **오른쪽 끝**(가장 최근 주)이다.
        void notify(double offset) {
          if (weeks.isEmpty) return;
          final double right = width - offset;
          final double left = right - c.maxWidth;
          onVisibleChanged(
            (left / _slot).floor().clamp(0, weeks.length - 1),
            ((right / _slot).ceil() - 1).clamp(0, weeks.length - 1),
          );
        }

        // 첫 프레임에도 맞게. **지금 스크롤 위치**를 봐야 한다 — 0 을 넣으면
        // 밀어 놓은 화면이 다시 최신 구간 평균으로 돌아간다.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => notify(controller.hasClients ? controller.offset : 0),
        );
        final Widget scroller = NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification n) {
            if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
              notify(n.metrics.pixels);
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            // 오른쪽 끝(가장 최근 주)에서 시작한다.
            reverse: true,
            child: SizedBox(
              width: width,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: chartH,
                    child: Stack(
                      children: <Widget>[
                        // 눈금선과 달 경계는 막대 **뒤에** 깔린다.
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ChartGridPainter(
                              monthBreaks: <int>[
                                for (int i = 1; i < weeks.length; i++)
                                  if (weeks[i].monday.month !=
                                      weeks[i - 1].monday.month)
                                    i,
                              ],
                              count: weeks.length,
                              goalRatio: (goal / max).clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: ChartReveal(
                            replayKey: 'all-burn',
                            duration: AppMotion.chartGrow,
                            curve: Curves.linear,
                            builder: (BuildContext context, double t) => Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                for (int i = 0; i < weeks.length; i++)
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => onTap(i),
                                      child: Semantics(
                                        label:
                                            '${weeks[i].monday.month}/${weeks[i].monday.day} ${weeks[i].calories.round()}',
                                        child: ExcludeSemantics(
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: _BurnBar(
                                              value: weeks[i].calories,
                                              max: max,
                                              height: chartH,
                                              width: 12,
                                              t: chartStagger(
                                                t,
                                                i,
                                                weeks.length,
                                              ),
                                              dimmed:
                                                  selected != null &&
                                                  selected != i,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 12,
                    child: Row(
                      children: <Widget>[
                        for (int i = 0; i < weeks.length; i++)
                          Expanded(
                            child: Text(
                              // 달이 바뀌는 칸에만 적는다 — 모든 칸에 적으면 글자가
                              // 서로 겹쳐 아무것도 읽히지 않는다.
                              i == 0 ||
                                      weeks[i].monday.month !=
                                          weeks[i - 1].monday.month
                                  ? DateFormat.MMM(
                                      locale,
                                    ).format(weeks[i].monday)
                                  : '',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: i == selected
                                    ? FigmaColors.ink
                                    : FigmaColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        // 목표치는 그래프 왼쪽 칸에 두 줄로 적는다 — 홈 탭 식단 영양 그래프와
        // 같은 자리다. 예전에는 점선 오른쪽 끝에 알약 라벨로 얹혀 있어, 그래프
        // 마다 목표치가 다른 자리에 있었다. (#1071)
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ChartGoalAxis(
              height: chartH,
              label:
                  '${AppLocalizations.of(context).homeGoal}\n${goal.round()}',
              lineBottom: chartH * (goal / max).clamp(0.0, 1.0),
            ),
            const SizedBox(width: chartGoalAxisGap),
            Expanded(
              child: SizedBox(
                height: c.maxHeight,
                child: Stack(
                  key: const Key('exerciseAllPeriodChart'),
                  children: <Widget>[
                    Positioned.fill(child: scroller),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (chartH * (1 - (goal / max).clamp(0.0, 1.0))) - 6,
                      child: const IgnorePointer(child: _GoalLine()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 주간 목표선 — 점선만 긋는다. 목표치는 왼쪽 [ChartGoalAxis] 칸이 적는다.
class _GoalLine extends StatelessWidget {
  const _GoalLine();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 1),
    painter: _DashPainter(),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = const Color(0xFFB9C7D2)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 4, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChartGridPainter extends CustomPainter {
  _ChartGridPainter({
    required this.monthBreaks,
    required this.count,
    required this.goalRatio,
  });

  /// 달이 바뀌는 칸의 인덱스.
  final List<int> monthBreaks;
  final int count;
  final double goalRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = const Color(0xFFEDF1F4)
      ..strokeWidth = 1;
    for (final double f in <double>[0, 0.5, 1]) {
      final double y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    if (count <= 0) return;
    final double step = size.width / count;
    final Paint dash = Paint()
      ..color = const Color(0xFFD8E1E8)
      ..strokeWidth = 1;
    for (final int i in monthBreaks) {
      final double x = step * i;
      for (double y = 0; y < size.height; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 3), dash);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartGridPainter old) =>
      old.count != count ||
      old.goalRatio != goalRatio ||
      old.monthBreaks != monthBreaks;
}

// ── 공통 조각 ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('exerciseActivityCard'),
    width: double.infinity,
    // 높이는 고정이되 **글자 배율을 따라간다**. 세 기간 카드가 같은 높이여야
    // 토글을 눌러도 화면이 출렁이지 않는데, 배율만 커지면 그 고정 높이 안에서
    // 내용이 넘친다(#766 계열). 배율 배수를 곱하고 1.6 에서 멈춘다.
    height:
        kActivityCardHeight *
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
    padding: const EdgeInsets.symmetric(
      horizontal: _kCardPaddingH,
      vertical: _kCardPadding,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: kCardShadow,
    ),
    child: child,
  );
}

/// `오늘 소모  320 kcal   목표 500 kcal` — 한 줄짜리 머리.
class _HeadlineLine extends StatelessWidget {
  const _HeadlineLine({
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
    alignment: Alignment.centerLeft,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          caption,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: FigmaColors.textBody,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FigmaColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: FigmaColors.textMuted,
    ),
  );
}

/// 오늘 / 이번 주 / 전체 세그먼트.
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.active,
    required this.labels,
    required this.onChanged,
  });

  final int active;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('exercise-period-toggle'),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: FigmaColors.statBg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < labels.length; i++)
          Flexible(
            child: Semantics(
              button: true,
              selected: active == i,
              child: GestureDetector(
                key: ValueKey<String>('exercise-period-tab-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  // 식단 탭 기간 토글과 **같은 크기**다 (#1126) — 같은 자리에
                  // 놓인 같은 조작이 탭마다 다르게 보이면 안 된다. 글자를 키운
                  // 화면에서 세 탭이 줄을 넘기지 않도록 좁히는 규칙까지 같다.
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.textScalerOf(context).scale(1) > 1.3
                        ? 12
                        : 18,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active == i
                        ? FigmaColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active == i
                          ? Colors.white
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
