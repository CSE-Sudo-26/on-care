import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays, weekdayCount, weekdayLabels;
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/bar_line_chart.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/chart_semantics.dart';

/// 주간 운동 이행률 — 요일별 막대 위에 그 주의 꺾은선.
///
/// 막대 **높이**는 그날 이행률이고, 막대 **안**은 그날 운동을 유산소·근력·
/// 스트레칭으로 나눈 몫이다. 식단의 칼로리 막대가 탄·단·지로 쌓이는 것과 같은
/// 규칙이다 — 같은 87% 라도 무엇으로 채운 87% 인지는 다른 이야기다(#1177).
class WeeklyCompletionChart extends ConsumerWidget {
  /// Creates the chart.
  const WeeklyCompletionChart({super.key, required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // 지난 날인데 기록이 없는 요일. 아직 오지 않은 날과 구분해서 그린다.
    final int elapsed = report.isCurrentWeek
        ? elapsedWeekdays(nowKst())
        : weekdayCount;
    final List<double?> values = <double?>[
      for (var i = 0; i < report.weekCompletion.length; i++)
        // 기록이 없는 날을 0% 로 그리면 '0% 수행'이라는 다른 뜻이 되고,
        // 평균에서 빠진 이유도 화면에서 사라진다.
        i < elapsed && report.weekCompletion[i] == 0
            ? null
            : report.weekCompletion[i].toDouble(),
    ];
    final period = ref
        .watch(
          clientExercisePeriodProvider((
            clientId: report.client.id,
            period: ClientPeriod.week,
            day: report.weekStart,
          )),
        )
        .valueOrNull;
    final Map<String, ClientExerciseDay> byDate = <String, ClientExerciseDay>{
      for (final day in period?.days ?? const <ClientExerciseDay>[])
        ymd(day.date): day,
    };
    return BarLineChart(
      key: const ValueKey<String>('reports-completion-chart'),
      values: values,
      labels: weekdayLabels(l),
      ceiling: 100,
      format: (double v) => '${v.round()}%',
      emptyLabel: l.chartNoRecord,
      // 아직 오지 않은 요일은 이번 주에만 있다.
      pendingFrom: report.isCurrentWeek ? elapsed : null,
      segments: <List<BarSegment>?>[
        for (var i = 0; i < values.length; i++)
          _segmentsOf(
            byDate[ymd(report.weekStart.add(Duration(days: i)))],
          ),
      ],
      semanticsLabel: chartSemanticsLabel(
        l,
        title: l.reportsCompletionByDay,
        points: chartSeriesPoints(
          l,
          values: <double>[
            for (final v in report.weekCompletion) v.toDouble(),
          ],
          dayLabels: weekdayLabels(l),
          format: (double v) => '${v.round()}%',
          upTo: elapsed - 1,
        ),
      ),
    );
  }

  /// 그날 운동을 유형별로 나눈 몫. 유형 기록이 없으면 null — 막대를 한 색으로
  /// 채운다(쌓을 것이 없는데 억지로 나누면 없는 구분을 보여 주는 셈이다).
  static List<BarSegment>? _segmentsOf(ClientExerciseDay? day) {
    if (day == null) return null;
    final segments = <BarSegment>[
      (value: day.cardioMinutes.toDouble(), color: AppColors.chartCardio),
      (value: day.strengthMinutes.toDouble(), color: AppColors.chartStrength),
      (
        value: day.stretchingMinutes.toDouble(),
        color: AppColors.chartStretching,
      ),
    ];
    return segments.every((s) => s.value <= 0) ? null : segments;
  }
}
