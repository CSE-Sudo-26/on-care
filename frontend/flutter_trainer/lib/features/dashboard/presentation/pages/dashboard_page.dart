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
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final reservations = ref.watch(todayReservationCountProvider).valueOrNull;
    final today = DateTime.now();

    return PageScaffold(
      title: '대시보드',
      subtitle: koreanDateLabel(today),
      actions: <Widget>[
        ActionButton(
          label: '일정 추가',
          icon: Icons.add,
          onPressed: () => context.go(AppRoutes.scheduleView('day')),
        ),
        ActionButton(
          label: 'AI 루틴 만들기',
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
        error: (e, _) => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
          child: Center(
            child: Text(
              '대시보드를 불러오지 못했어요',
              style: TextStyle(color: AppColors.mutedForeground),
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
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 15,
                          child: _LeftColumn(summary: summary),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          flex: 10,
                          child: _RightColumn(summary: summary),
                        ),
                      ],
                    ),
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
    final cards = <Widget>[
      StatCard(
        label: '오늘 예약',
        // `null` means the source has no reservation data (real-API
        // mode) — showing "0건" there would be a lie, so show a dash.
        value: reservations?.toString() ?? '-',
        unit: '건',
        icon: Icons.event_available_outlined,
        hint: '스케줄에서 보기',
        onTap: () => context.go(AppRoutes.scheduleView('day')),
      ),
      StatCard(
        label: '담당 고객',
        value: '${summary.activeClients}',
        unit: '명',
        icon: Icons.groups_outlined,
        hint: summary.totalClients > summary.activeClients
            ? '휴면 ${summary.totalClients - summary.activeClients}명'
            : '전원 활성',
        onTap: () => context.go(AppRoutes.clients),
      ),
      StatCard(
        label: '답장 필요',
        value: '${summary.unreadTotal}',
        unit: '건',
        icon: Icons.mark_chat_unread_outlined,
        tone: summary.unreadTotal > 0 ? StatTone.info : StatTone.positive,
        hint: summary.unreadTotal > 0
            ? '고객 ${summary.unreadClients}명 대기 중'
            : '모두 답장했어요',
        onTap: () => context.go(AppRoutes.clientsFiltered('unread')),
      ),
      StatCard(
        label: '주의 고객',
        value: '${summary.healthAttentionCount}',
        unit: '명',
        icon: Icons.report_gmailerrorred_outlined,
        tone: summary.healthAttentionCount == 0
            ? StatTone.positive
            : StatTone.warn,
        hint: summary.healthAttentionCount == 0 ? '이상 없음' : '나트륨·이행률 확인',
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
    // 평균도 지난 요일만으로 낸다. 아직 오지 않은 날을 0으로 함께 나누면
    // 주 초반에는 실제보다 낮은 이행률이 나온다.
    final elapsed = elapsedWeekdays(DateTime.now());
    final counted = values.take(elapsed).toList();
    final average = counted.isEmpty
        ? null
        : (counted.reduce((a, b) => a + b) / counted.length).round();
    return SectionCard(
      title: '주간 세션 이행률',
      icon: Icons.bar_chart,
      trailing: average == null
          ? null
          : Text(
              '평균 $average%',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
      child: values.isEmpty
          ? const EmptyHint(
              message: '아직 이번 주 기록이 없어요',
              icon: Icons.bar_chart_outlined,
            )
          : BarSeriesChart(
              values: values,
              labels: weekdayLabels,
              maxValue: 100,
              showValues: true,
              valueSuffix: '%',
              highlightIndex: elapsed - 1,
              pendingFromIndex: elapsed,
            ),
    );
  }
}
