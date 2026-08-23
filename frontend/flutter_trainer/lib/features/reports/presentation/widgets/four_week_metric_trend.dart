import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/week_trend_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/metric_trend_chart.dart';

/// 선택한 영양 지표의 최근 4주 주간 평균 — 운동 카드의 같은 블록과 짝이다.
///
/// 이번 주 꺾은선은 "이번 주에 언제 튀었나"만 말한다. 트레이너가 정말 알고
/// 싶은 건 **코칭이 먹히고 있나**이고, 그건 주 단위 평균 넷을 나란히 놓아야
/// 보인다(#754).
///
/// 새로 받아 오는 값이 없다 — 운동 카드가 이미 지난 세 주의 리포트를 보고
/// 있고, 그 리포트가 각자 자기 주의 계열을 들고 있다.
class FourWeekMetricTrend extends ConsumerWidget {
  const FourWeekMetricTrend({
    super.key,
    required this.report,
    required this.label,
    required this.values,
    required this.goal,
    required this.unit,
  });

  final WeeklyReport report;

  /// 지표 이름(칼로리·나트륨·당류).
  final String label;

  /// 한 주의 리포트에서 이 지표의 요일별 계열을 꺼내는 방법.
  final List<num> Function(WeeklyReport) values;

  /// 목표. 눈금과 주의 색의 기준을 겸한다.
  final double goal;

  /// 눈금 끝은 목표의 1.5배. 목표를 눈금 끝으로 삼으면 — 김민수의 나트륨처럼
  /// 네 주가 모두 목표를 넘은 경우 — 막대 넷이 전부 꽉 차 버려 어느 주가 더
  /// 나빴는지가 사라진다. 여유를 두면 주별 차이가 길이로 드러난다.
  ///
  /// 2/3 지점에 긋던 목표선은 지웠다. 그 선이 무엇인지 말해 주던 `│ 목표 …`
  /// 표기와 함께 사라졌고, 설명 없는 세로선은 눈금처럼 읽힌다. 목표를 넘긴
  /// 주는 막대가 빨갛다 — 초과 여부는 색이 말한다(#1177).
  static const double _headroom = 1.5;

  /// 값 뒤에 붙는 단위.
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final weeks = <AsyncValue<WeeklyReport>>[
      for (var offset = 3; offset >= 0; offset--)
        ref.watch(
          weeklyReportProvider((
            client: report.client,
            weekStart: report.weekStart.subtract(Duration(days: 7 * offset)),
          )),
        ),
    ];
    final labels = <String>[
      l.reportsWeeksAgo(3),
      l.reportsWeeksAgo(2),
      l.reportsLastWeek,
      report.isCurrentWeek ? l.reportsThisWeek : l.reportsSelectedWeek,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 목표 표기는 적지 않는다. 눈금 위 세로선과 초과한 주의 빨간 막대가
        // 이미 같은 말을 하고 있었고, 줄 끝의 `│ 목표 2,000mg` 은 그 세로선과
        // 겹쳐 읽혀 오히려 눈금처럼 보였다(#1177).
        Text(
          '${l.reportsRecentWeeks} · $label',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < weeks.length; i++)
          () {
            final week = weeks[i].valueOrNull;
            // 기록한 날만 평균한다 — 아직 오지 않은 날을 0 으로 세면 이번 주가
            // 늘 나아 보인다. 화면 곳곳이 같은 규칙을 쓴다.
            final mean = week == null ? null : recordedMean(values(week));
            return WeekTrendBar(
              label: labels[i],
              fraction: mean == null ? null : mean / (goal * _headroom),
              text: mean == null
                  ? '-'
                  : '${metricTrendNumber(mean.round())}$unit',
              loading: weeks[i].isLoading,
              current: i == weeks.length - 1,
              warn: mean != null && mean > goal,
              valueWidth: 62,
            );
          }(),
      ],
    );
  }
}
