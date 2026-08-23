import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/data/daily_task_progress_store.dart';
import 'package:oncare_trainer/features/dashboard/domain/churn_risk.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/ai_summary_card.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/churn_risk_dialog.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/task_progress_chart.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/today_tasks_card.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/today_timeline_card.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/shared/widgets/stat_card.dart';

/// 대시보드 — the console's home: what needs doing today.
///
/// Every number here is a link. The four KPI cards deep-link into the
/// view that explains them (담당 고객 → 고객 명단, 메시지 → 안읽음 필터,
/// 주의 고객/이탈 위험 → 해당 목록/다이얼로그), because a dashboard the
/// trainer can only read is a dashboard they stop opening.
class DashboardPage extends ConsumerWidget {
  /// Creates the dashboard.
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    // 이탈 위험·활동 피드백은 대시보드 화면에 있을 때만 구독하는 별도
    // provider다(dashboard_controller.dart 참고 — 30일 스케줄 구간을 도는
    // 조회라 `dashboardSummaryProvider`처럼 앱 내내 살아 있으면 안 된다).
    final churnRisk = ref.watch(dashboardChurnRiskProvider);
    final activityFeedback = ref.watch(dashboardActivityFeedbackProvider);
    final today = nowKst();

    return PageScaffold(
      title: l.dashTitle,
      subtitle: dateLabel(l, today),
      headerCenter: const ClientSearchBar(),
      actions: <Widget>[
        ActionButton(
          label: l.dashAddSchedule,
          icon: Icons.add,
          primary: true,
          onPressed: () => context.go(AppRoutes.scheduleAt()),
        ),
      ],
      child: summaryAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxxl),
          child: EmptyHint(
            message: l.dashLoadFailed,
            icon: Icons.error_outline,
            action: ActionButton(
              key: const ValueKey<String>('dashboard-retry'),
              label: l.actionRetry,
              onPressed: summaryAsync.isLoading
                  ? null
                  : () => ref.invalidate(clientsProvider),
            ),
          ),
        ),
        data: (summary) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= AppLayout.twoColumnBreakpoint;
            // 왼쪽: 오늘의 일정 + (그 아래) AI 진단. 오른쪽: 오늘 할 일 +
            // (그 아래) 할 일 진행률 — AI 진단이 그래프와 나란한 줄에 오도록
            // 왼쪽 칸에 둔다.
            final leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const TodayTimelineCard(),
                const SizedBox(height: AppSpacing.lg),
                AiSummaryCard(activityFeedback: activityFeedback),
              ],
            );
            final rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TodayTasksCard(entries: summary.attention),
                const SizedBox(height: AppSpacing.lg),
                const _TaskProgressCard(),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _KpiRow(summary: summary, churnRisk: churnRisk, wide: wide),
                const SizedBox(height: AppSpacing.lg),
                if (wide)
                  Row(
                    key: const ValueKey<String>('dashboard-action-row'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 5:4 — 딱 반반은 아니다.
                      Expanded(flex: 5, child: leftColumn),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(flex: 4, child: rightColumn),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      leftColumn,
                      const SizedBox(height: AppSpacing.lg),
                      rightColumn,
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 오늘 할 일 진행률 — this week's daily completion, 지난 할일(carried-over)
/// stacked in a different colour.
class _TaskProgressCard extends ConsumerWidget {
  const _TaskProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 값 자체는 안 쓰지만, 오늘 할 일 카드가 새로 저장할 때마다 이 카드도
    // 다시 그리게 만드는 구독이다 — SharedPreferences 는 스트림이 아니다.
    ref.watch(taskProgressVersionProvider);
    final l = AppLocalizations.of(context);
    final store = ref.watch(dailyTaskProgressStoreProvider);
    final today = nowKst();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final dates = <String>[
      for (var i = 0; i < weekdayCount; i++) ymd(monday.add(Duration(days: i))),
    ];
    return SectionCard(
      title: l.dashTaskProgressTitle,
      icon: Icons.stacked_bar_chart_outlined,
      child: TaskProgressChart(
        snapshots: <DailyTaskSnapshot?>[for (final d in dates) store.read(d)],
        labels: weekdayLabels(l),
        todayIndex: elapsedWeekdays(today) - 1,
      ),
    );
  }
}

/// The four KPI tiles. Wraps to two rows on narrow content areas rather
/// than shrinking to unreadable widths.
class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.summary,
    required this.churnRisk,
    required this.wide,
  });

  final DashboardSummary summary;
  final List<ChurnRiskClient> churnRisk;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final cards = <Widget>[
      StatCard(
        label: l.dashMyClients,
        value: '${summary.activeClients}',
        unit: l.dashUnitPeople,
        icon: Icons.groups_outlined,
        hint: summary.totalClients > summary.activeClients
            ? l.dashDormantClients(summary.totalClients - summary.activeClients)
            : l.dashAllActive,
        onTap: () => context.go(AppRoutes.clients),
      ),
      StatCard(
        label: l.dashMessages,
        value: '${summary.unreadTotal}',
        unit: l.dashUnitCount,
        icon: Icons.mark_chat_unread_outlined,
        tone: summary.unreadTotal > 0 ? StatTone.info : StatTone.positive,
        hint: summary.unreadTotal > 0
            ? l.dashWaitingClients(summary.unreadClients)
            : l.dashAllReplied,
        onTap: () => context.go(AppRoutes.messagesFor(null, filter: 'unread')),
      ),
      StatCard(
        label: l.dashAttentionClients,
        value: '${summary.healthAttentionCount}',
        unit: l.dashUnitPeople,
        icon: Icons.report_gmailerrorred_outlined,
        tone: summary.healthAttentionCount == 0
            ? StatTone.positive
            : StatTone.warn,
        hint: summary.healthAttentionCount == 0
            ? l.dashNoIssues
            : l.dashCheckSodiumCompletion,
        onTap: () => context.go(AppRoutes.clientsFiltered('attention')),
      ),
      StatCard(
        label: l.dashChurnRisk,
        value: '${churnRisk.length}',
        unit: l.dashUnitPeople,
        icon: Icons.person_off_outlined,
        tone: churnRisk.isEmpty ? StatTone.positive : StatTone.severe,
        hint: churnRisk.isEmpty ? l.dashChurnRiskNone : l.dashChurnRiskCheck,
        onTap: () => showChurnRiskDialog(context, entries: churnRisk),
      ),
    ];

    // IntrinsicHeight so the tiles line up: the hint line is present on
    // some and absent on others, which otherwise staggers the row.
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < cards.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.lg),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (var i = 0; i < cards.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: cards[i]),
                const SizedBox(width: AppSpacing.lg),
                if (i + 1 < cards.length)
                  Expanded(child: cards[i + 1])
                else
                  const Spacer(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
