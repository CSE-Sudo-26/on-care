import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show weekdayCount;
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/four_week_compliance_trend.dart';
import 'package:oncare_trainer/shared/widgets/exercise_line.dart';

/// 요일별 운동 내역 — 막대 아래에 하루하루를 이행률·운동 이름과 함께 적는다.
///
/// 예전에는 이행률·PT 세션·나트륨 초과를 큰 숫자로 보여 주는 카드가 따로
/// 있었다. 그 세 숫자는 트레이너 피드백 초안에 문장으로 이미 적혀 있어 같은
/// 값을 두 번 보여 주는 셈이었고, 정작 "87% 가 어디서 나왔나" 는 어디에도
/// 없었다. 막대 바로 아래에 표로 두면 같은 카드 안에서 답이 난다(#754).
class ReportDailyDetail extends StatelessWidget {
  const ReportDailyDetail({super.key, required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 막대 아래에 요일 칸을 그대로 이어 붙인다 — 월요일 막대 밑에
        // 월요일에 한 운동이 온다.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < weekdayCount; i++)
              _DailyDetailColumn(
                day: i < report.days.length ? report.days[i] : null,
              ),
          ],
        ),
        if (report.completionAvg != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          // 마지막 줄에 이번 주를 앞선 세 주 옆에 놓는다. 며칠을 나눈
          // 값인지는 따로 적지 않는다 — 값이 있는 막대를 세면 나온다(#754).
          FourWeekComplianceTrend(report: report),
        ],
      ],
    );
  }
}

/// 요일 한 칸의 내역 — 막대 바로 아래에 그날 한 일을 세로로 적는다.
class _DailyDetailColumn extends StatelessWidget {
  const _DailyDetailColumn({required this.day});

  final ReportDay? day;

  @override
  Widget build(BuildContext context) {
    final names = day?.exercises ?? const <String>[];
    return Expanded(
      // 막대와 같은 좌우 여백을 써야 칸이 세로로 맞는다.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 이행률과 몇 개 중 몇 개인지는 적지 않는다 — 퍼센트는 바로 위
            // 막대가 이미 말하고, 개수는 아래 ✓/✗ 를 세면 나온다. 기록이 없는
            // 날은 막대 쪽에 '기록 없음' 이 적히고, 아직 오지 않은 날은 비워
            // 둔다 — 빈칸이 곧 "아직" 이다.
            for (final name in names)
              ExerciseLine(line: name, fontSize: 11.5, maxLines: 2),
          ],
        ),
      ),
    );
  }
}
