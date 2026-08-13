import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/ai_summary_card.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/attention_card.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/today_timeline_card.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/shared/widgets/stat_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 대시보드 — the console's home: what needs doing today.
///
/// Every number here is a link. The four KPI cards deep-link into the
/// view that explains them (예약 → 스케줄, 답장 필요 → 필터된 고객 목록),
/// because a dashboard the trainer can only read is a dashboard they
/// stop opening.
class DashboardPage extends ConsumerWidget {
  /// Creates the dashboard.
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final reservations = ref.watch(todayReservationCountProvider).valueOrNull;
    final today = DateTime.now();

    return PageScaffold(
      title: l.dashTitle,
      subtitle: dateLabel(l, today),
      actions: <Widget>[
        ActionButton(
          label: l.dashAddSchedule,
          icon: Icons.add,
          primary: true,
          onPressed: () => context.go(AppRoutes.scheduleView('day')),
        ),
      ],
      child: summaryAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _KpiRow(
                  summary: summary,
                  reservations: reservations,
                  wide: wide,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (wide) ...<Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Expanded(flex: 15, child: TodayTimelineCard()),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        flex: 10,
                        child: _TodayTasksCard(entries: summary.attention),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 15,
                        child: AttentionCard(
                          entries: summary.attention,
                          maxRows: 5,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        flex: 10,
                        child: AiSummaryCard(summary: summary),
                      ),
                    ],
                  ),
                ] else ...<Widget>[
                  const TodayTimelineCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _TodayTasksCard(entries: summary.attention),
                  const SizedBox(height: AppSpacing.lg),
                  AttentionCard(entries: summary.attention),
                  const SizedBox(height: AppSpacing.lg),
                  AiSummaryCard(summary: summary),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TodayTasksCard extends StatelessWidget {
  const _TodayTasksCard({required this.entries});

  final List<AttentionClient> entries;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tasks = entries.take(4).toList();
    return SectionCard(
      title: l.dashTodayTasks,
      trailing: Text(
        tasks.isEmpty
            ? l.dashTasksReviewed
            : l.dashTasksNeedReview(tasks.length),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: tasks.isEmpty
          ? EmptyHint(message: l.dashTasksEmpty, icon: Icons.task_alt)
          : Column(
              children: <Widget>[
                for (final entry in tasks)
                  _TaskRow(
                    entry: entry,
                    onTap: () {
                      if (entry.primary == ClientAlert.unanswered) {
                        context.go(AppRoutes.messagesFor(entry.client.id));
                        return;
                      }
                      context.go(
                        AppRoutes.clientDetail(
                          entry.client.id,
                          section: AttentionCard.sectionFor(entry.primary),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.entry, required this.onTap});

  final AttentionClient entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final alert = entry.primary;
    final tone = switch (alert) {
      ClientAlert.unanswered => AppColors.primary,
      ClientAlert.sodiumOver => AppColors.overTarget,
      ClientAlert.lowCompletion => AppColors.warning,
    };
    final type = switch (alert) {
      ClientAlert.unanswered => l.dashTaskReply,
      ClientAlert.sodiumOver => l.dashTaskDiet,
      ClientAlert.lowCompletion => l.dashTaskWorkout,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderStrong),
              borderRadius: const BorderRadius.all(AppRadius.md),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(AppRadius.pill),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: tone,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l.dashTaskReview(alert.label(l), entry.client.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.subtleForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The four KPI tiles. Wraps to two rows on narrow content areas rather
/// than shrinking to unreadable widths.
class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.summary,
    required this.reservations,
    required this.wide,
  });

  final DashboardSummary summary;
  final int? reservations;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final cards = <Widget>[
      StatCard(
        label: l.dashTodayReservations,
        // `null` means the source has no reservation data (real-API
        // mode) — showing "0건" there would be a lie, so show a dash.
        value: reservations?.toString() ?? '-',
        unit: l.dashUnitCount,
        icon: Icons.event_available_outlined,
        hint: l.dashSeeInSchedule,
        onTap: () => context.go(AppRoutes.scheduleView('day')),
      ),
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
        label: l.dashNeedsReply,
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
