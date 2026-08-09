import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/ai_summary_card.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/attention_card.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/today_timeline_card.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';
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
      subtitle: koreanDateLabel(today),
      actions: <Widget>[
        ActionButton(
          label: l.dashAddSchedule,
          icon: Icons.add,
          onPressed: () => context.go(AppRoutes.scheduleView('day')),
        ),
        ActionButton(
          label: l.dashCreateAiRoutine,
          icon: Icons.auto_awesome,
          primary: true,
          onPressed: () => context.go(AppRoutes.coaching),
        ),
      ],
      child: summaryAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
          child: Center(
            child: Text(
              l.dashLoadFailed,
              style: const TextStyle(color: AppColors.mutedForeground),
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
                if (wide)
                  // Deliberately NOT IntrinsicHeight: the two columns are
                  // independent card stacks, `start` already stops them
                  // stretching, and the weekday chart uses a LayoutBuilder
                  // — which reports a 0 intrinsic height, so IntrinsicHeight
                  // sized the row short and the chart overflowed it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 15, child: _LeftColumn(summary: summary)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(flex: 10, child: _RightColumn(summary: summary)),
                    ],
                  )
                else ...<Widget>[
                  _LeftColumn(summary: summary),
                  const SizedBox(height: AppSpacing.lg),
                  _RightColumn(summary: summary),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const TodayTimelineCard(),
        const SizedBox(height: AppSpacing.lg),
        _WeeklyCompletionCard(values: summary.weeklyCompletion),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AttentionCard(entries: summary.attention),
        const SizedBox(height: AppSpacing.lg),
        AiSummaryCard(summary: summary),
      ],
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
        onTap: () => context.go(AppRoutes.clientsFiltered('unread')),
      ),
      StatCard(
        label: l.dashAttentionClients,
        value: '${summary.healthAttentionCount}',
        unit: l.dashUnitPeople,
        icon: Icons.report_gmailerrorred_outlined,
        tone: summary.healthAttentionCount == 0
            ? StatTone.positive
            : StatTone.warn,
        hint: summary.healthAttentionCount == 0 ? l.dashNoIssues : l.dashCheckSodiumCompletion,
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
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (var i = 0; i < cards.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: cards[i]),
                const SizedBox(width: AppSpacing.md),
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

/// Mean routine completion per weekday across the roster.
class _WeeklyCompletionCard extends StatelessWidget {
  const _WeeklyCompletionCard({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 평균도 지난 요일만으로 낸다. 아직 오지 않은 날을 0으로 함께 나누면
    // 주 초반에는 실제보다 낮은 이행률이 나온다.
    final elapsed = elapsedWeekdays(DateTime.now());
    final counted = values.take(elapsed).toList();
    final average = counted.isEmpty
        ? null
        : (counted.reduce((a, b) => a + b) / counted.length).round();
    return SectionCard(
      title: l.dashWeeklyCompletion,
      icon: Icons.bar_chart,
      trailing: average == null
          ? null
          : Text(
              l.dashAveragePercent(average),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
      child: values.isEmpty
          ? EmptyHint(
              message: l.dashNoRecordsThisWeek,
              icon: Icons.bar_chart_outlined,
            )
          : BarSeriesChart(
              values: values,
              labels: weekdayLabels(l),
              maxValue: 100,
              showValues: true,
              valueSuffix: '%',
              highlightIndex: elapsed - 1,
              pendingFromIndex: elapsed,
            ),
    );
  }
}
