import 'package:flutter/material.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays, weekdayCount, weekdayLabels;
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/metric_trend_section.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_ai_card.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_daily_detail.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_feedback_editor.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/week_comparison.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// One client's week, ready to send.
class ClientReportView extends StatelessWidget {
  const ClientReportView({
    super.key,
    required this.report,
    required this.showSummary,
    required this.draftEpoch,
    required this.canRestoreDraft,
    required this.onRestoreDraft,
    required this.initialFeedback,
    required this.onUseSummaryAsDraft,
    required this.onFeedbackChanged,
    required this.savingFeedback,
    required this.onSaveFeedback,
  });

  final WeeklyReport report;

  /// 요약 카드를 이 흐름 안에 그릴 것인가. 넓은 화면에서는 왼쪽 고객 열이
  /// 가져가므로 `false` 다.
  final bool showSummary;

  /// 입력창에 채워 둘 문구. 트레이너가 고치던 중이면 그 내용이다.
  /// 바뀌면 입력창을 새 문구로 다시 만든다.
  final int draftEpoch;

  /// 입력창이 자동 생성 초안과 달라져 되돌릴 것이 있는가.
  final bool canRestoreDraft;

  /// 입력창을 자동 생성 초안으로 되돌린다.
  final VoidCallback onRestoreDraft;

  final String initialFeedback;

  /// 요약을 피드백 초안으로 옮긴다.
  final ValueChanged<String> onUseSummaryAsDraft;

  /// 입력창이 바뀔 때마다 현재 문구를 올려 준다 — 전송은 헤더 공유 메뉴가 한다.
  final ValueChanged<String> onFeedbackChanged;

  /// 초안을 서버에 저장하는 중이다. (#821)
  final bool savingFeedback;

  /// 입력창의 현재 문구를 그 주의 초안으로 저장한다. (#821)
  final VoidCallback onSaveFeedback;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final client = report.client;
    // 지난 날인데 기록이 없는 요일. 아직 오지 않은 날과 구분해서 그린다.
    final elapsed = report.isCurrentWeek
        ? elapsedWeekdays(nowKst())
        : weekdayCount;
    final unlogged = <int>{
      for (var i = 0; i < elapsed && i < report.weekCompletion.length; i++)
        if (report.weekCompletion[i] == 0) i,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: l.reportsClientWeekly(client.name),
          icon: Icons.description_outlined,
          trailing: Text(
            report.rangeLabel(l),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ClientIdentity(
                client: client,
                nameStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              WeekComparison(report: report),
            ],
          ),
        ),
        if (showSummary) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          ReportAiCard(report: report, onUseAsDraft: onUseSummaryAsDraft),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l.reportsFeedbackTitle,
          // 저장 버튼을 제목 행에 둔다 — 입력창 위에 버튼만 있는 줄이 따로
          // 있으면 카드가 그만큼 세로로 늘어난다.
          // 되돌리기를 저장 옆에 둔다 — 입력창을 되돌릴 수단이 그 입력창 바로
          // 위에 있어야 한다.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ActionButton(
                label: l.reportsFeedbackRestore,
                icon: Icons.undo,
                onPressed: canRestoreDraft ? onRestoreDraft : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              ActionButton(
                key: const ValueKey<String>('report-feedback-save'),
                label: savingFeedback
                    ? l.reportsFeedbackSaving
                    : l.reportsFeedbackSave,
                icon: Icons.save_outlined,
                onPressed: savingFeedback ? null : onSaveFeedback,
              ),
            ],
          ),
          child: ReportFeedbackEditor(
            key: ValueKey<String>(
              'feedback-${report.client.id}-'
              '${report.weekStart.toIso8601String()}-$draftEpoch',
            ),
            initialText: initialFeedback,
            onChanged: onFeedbackChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 운동과 식단을 카드로 나눈다. 예전에는 나트륨 추이 그래프가 '요일별
        // 운동 이행률' 카드 안에 있어 제목과 내용이 서로 다른 말을 했다(#754).
        SectionCard(
          title: l.reportsCompletionByDay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 계열은 리포트가 자기 주의 것을 들고 온다 — 보고 있는 주가
              // 어디든 같은 규칙으로 그린다(#752).
              if (report.weekCompletion.length == weekdayCount)
                BarSeriesChart(
                  title: l.reportsCompletionByDay,
                  values: report.weekCompletion,
                  labels: weekdayLabels(AppLocalizations.of(context)),
                  maxValue: 100,
                  height: 80,
                  showValues: true,
                  valueSuffix: '%',
                  // 아직 오지 않은 요일은 이번 주에만 있다.
                  pendingFromIndex: report.isCurrentWeek
                      ? elapsedWeekdays(nowKst())
                      : null,
                  // 기록이 없는 날을 0% 로 그리면 '0% 수행'이라는 다른 뜻이
                  // 되고, 평균에서 빠진 이유도 화면에서 사라진다.
                  missingIndices: unlogged,
                )
              else
                EmptyHint(message: l.reportsNoWorkoutsThisWeek),
              if (report.weekCompletion.length == weekdayCount) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                // 막대 바로 아래에 그날의 운동 내역. 67% 가 어디서 나온
                // 값인지 같은 카드 안에서 답이 난다(#754).
                ReportDailyDetail(report: report),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l.reportsDietTrend,
          trailing: Text(
            l.reportsSodiumOverInline(report.sodiumOverDays ?? 0),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: (report.sodiumOverDays ?? 0) > 2
                  ? AppColors.overTarget
                  : AppColors.subtleForeground,
            ),
          ),
          child: MetricTrendSection(report: report),
        ),
      ],
    );
  }
}
