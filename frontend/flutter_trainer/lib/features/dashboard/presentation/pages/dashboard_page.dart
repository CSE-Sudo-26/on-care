import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/data/daily_task_progress_store.dart';
import 'package:oncare_trainer/features/dashboard/domain/churn_risk.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/ai_summary_card.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/attention_card.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/churn_risk_dialog.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/follow_up_card.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/task_progress_chart.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/today_timeline_card.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/shared/widgets/stat_card.dart';

/// Bumped whenever `_TodayTasksCardState` persists a new daily snapshot, so
/// [_TaskProgressCard] (a sibling with no direct link to that state) knows
/// to re-read [dailyTaskProgressStoreProvider].
final _taskProgressVersionProvider = StateProvider<int>(
  (ref) => 0,
  name: 'taskProgressVersion',
);

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
    final coachingSummary = ref.watch(dashboardAiCoachingSummaryProvider);
    // 30일 스케줄 구간을 도는 별도 provider — 대시보드 화면에 있을 때만
    // 구독하려고 `dashboardSummaryProvider` 밖에 둔다(dashboard_controller.dart
    // 참고).
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _KpiRow(summary: summary, churnRisk: churnRisk, wide: wide),
                const SizedBox(height: AppSpacing.lg),
                if (wide) ...<Widget>[
                  Row(
                    key: const ValueKey<String>('dashboard-action-row'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Expanded(child: TodayTimelineCard()),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: AttentionCard(entries: summary.attention),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _TodayTasksCard(entries: summary.attention),
                            const SizedBox(height: AppSpacing.lg),
                            const _TaskProgressCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // 파생된 신호(`오늘 할 일`) 아래에 트레이너가 직접 남긴 업무
                  // 큐를 둔다 — 위는 "무엇이 눈에 띄나", 아래는 "무엇을 하기로
                  // 했나"다(#869).
                  const FollowUpCard(),
                  const SizedBox(height: AppSpacing.lg),
                  AiSummaryCard(
                    summary: coachingSummary,
                    activityFeedback: activityFeedback,
                    onRetry: () =>
                        ref.invalidate(dashboardAiCoachingSummaryProvider),
                  ),
                ] else ...<Widget>[
                  const TodayTimelineCard(),
                  const SizedBox(height: AppSpacing.lg),
                  AttentionCard(entries: summary.attention),
                  const SizedBox(height: AppSpacing.lg),
                  _TodayTasksCard(entries: summary.attention),
                  const SizedBox(height: AppSpacing.lg),
                  const _TaskProgressCard(),
                  const SizedBox(height: AppSpacing.lg),
                  const FollowUpCard(),
                  const SizedBox(height: AppSpacing.lg),
                  AiSummaryCard(
                    summary: coachingSummary,
                    activityFeedback: activityFeedback,
                    onRetry: () =>
                        ref.invalidate(dashboardAiCoachingSummaryProvider),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TodayTasksCard extends ConsumerStatefulWidget {
  const _TodayTasksCard({required this.entries});

  final List<AttentionClient> entries;

  @override
  ConsumerState<_TodayTasksCard> createState() => _TodayTasksCardState();
}

class _TodayTasksCardState extends ConsumerState<_TodayTasksCard> {
  bool _expanded = true;
  Set<String> _checkedKeys = <String>{};
  String? _loadedForDate;

  @override
  void initState() {
    super.initState();
    _loadForToday();
  }

  @override
  void didUpdateWidget(covariant _TodayTasksCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadForToday();
  }

  static String _keyFor(_DashboardTask task) =>
      '${task.alert.name}-${task.entry.client.id}';

  static Set<String> _keysFor(List<_DashboardTask> tasks) =>
      tasks.map(_keyFor).toSet();

  /// Rehydrates today's checked state from what was last persisted —
  /// **only on a date change**. Re-reading on every incidental rebuild
  /// (roster refresh, unread count tick) would throw away a check the
  /// trainer just made before this widget's own write lands.
  void _loadForToday() {
    final today = ymd(nowKst());
    if (_loadedForDate == today) return;
    _loadedForDate = today;
    final snapshot = ref.read(dailyTaskProgressStoreProvider).read(today);
    final keys = _keysFor(_buildTodayTasks(widget.entries));
    final restored = snapshot == null
        ? const <String>{}
        : keys.where((k) => !snapshot.pendingKeys.contains(k)).toSet();
    if (!mounted) return;
    setState(() => _checkedKeys = restored);
  }

  void _toggle(String key) {
    setState(() {
      if (!_checkedKeys.remove(key)) _checkedKeys.add(key);
    });
    unawaited(_persist());
  }

  /// Saves today's snapshot — including which keys were already pending
  /// yesterday, so a check made today can be told apart as a genuine
  /// carry-over rather than a fresh task (#[dashboard]).
  Future<void> _persist() async {
    final store = ref.read(dailyTaskProgressStoreProvider);
    final keys = _keysFor(_buildTodayTasks(widget.entries));
    final checked = _checkedKeys.intersection(keys);
    final yesterday = store.read(
      ymd(nowKst().subtract(const Duration(days: 1))),
    );
    final carriedOverKeys = yesterday == null
        ? const <String>{}
        : yesterday.pendingKeys.intersection(keys);
    final carriedCompleted = checked.intersection(carriedOverKeys).length;
    await store.save(
      ymd(nowKst()),
      DailyTaskSnapshot(
        total: keys.length,
        completedToday: checked.length - carriedCompleted,
        completedCarriedOver: carriedCompleted,
        pendingKeys: keys.difference(checked),
      ),
    );
    if (!mounted) return;
    ref.read(_taskProgressVersionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tasks = _buildTodayTasks(widget.entries);
    final keys = _keysFor(tasks);
    final checkedCount = _checkedKeys.intersection(keys).length;
    final allDone = tasks.isNotEmpty && checkedCount == tasks.length;

    return SectionCard(
      title: l.dashTodayTasks,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            tasks.isEmpty || allDone
                ? l.dashTasksReviewed
                : l.dashTasksNeedReview(tasks.length - checkedCount),
            style: TextStyle(
              color: tasks.isEmpty || allDone
                  ? AppColors.success
                  : AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          InkWell(
            key: const ValueKey<String>('dashboard-tasks-toggle'),
            borderRadius: const BorderRadius.all(AppRadius.sm),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: AppColors.subtleForeground,
              ),
            ),
          ),
        ],
      ),
      child: !_expanded
          ? const SizedBox.shrink()
          : tasks.isEmpty
          ? EmptyHint(message: l.dashTasksEmpty, icon: Icons.task_alt)
          : Column(
              children: <Widget>[
                for (final task in tasks)
                  _TaskRow(
                    key: ValueKey<String>('dashboard-task-${_keyFor(task)}'),
                    task: task,
                    checked: _checkedKeys.contains(_keyFor(task)),
                    onToggle: () => _toggle(_keyFor(task)),
                    onTap: () {
                      if (task.alert == ClientAlert.unanswered) {
                        context.go(AppRoutes.messagesFor(task.entry.client.id));
                        return;
                      }
                      context.go(
                        AppRoutes.clientDetail(
                          task.entry.client.id,
                          section: AttentionCard.sectionFor(task.alert),
                        ),
                      );
                    },
                  ),
              ],
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
    ref.watch(_taskProgressVersionProvider);
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

/// Selects at most one task per action type so a sodium-heavy roster does not
/// turn the whole checklist into duplicate diet reviews.
List<_DashboardTask> _buildTodayTasks(List<AttentionClient> entries) {
  const order = <ClientAlert>[
    ClientAlert.unanswered,
    ClientAlert.lowCompletion,
    ClientAlert.sodiumOver,
  ];
  final usedClientIds = <String>{};
  final tasks = <_DashboardTask>[];
  for (final alert in order) {
    final matching = entries
        .where((entry) => entry.alerts.contains(alert))
        .toList(growable: false);
    final entry = matching
        .where((candidate) => !usedClientIds.contains(candidate.client.id))
        .firstOrNull;
    final selected = entry ?? matching.firstOrNull;
    if (selected == null) continue;
    tasks.add(_DashboardTask(entry: selected, alert: alert));
    usedClientIds.add(selected.client.id);
  }
  return tasks;
}

class _DashboardTask {
  const _DashboardTask({required this.entry, required this.alert});

  final AttentionClient entry;
  final ClientAlert alert;
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.checked,
    required this.onToggle,
    required this.onTap,
  });

  final _DashboardTask task;

  /// Ticked by the trainer — stays on the list, greyed out with a
  /// strikethrough, rather than disappearing (#[dashboard]).
  final bool checked;

  /// Toggles [checked]. Lives on the leading circle only — the rest of the
  /// row keeps navigating via [onTap], same as before checking existed.
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final alert = task.alert;
    final entry = task.entry;
    final tone = checked
        ? AppColors.disabledForeground
        : switch (alert) {
            ClientAlert.unanswered => AppColors.primary,
            ClientAlert.sodiumOver => AppColors.overTarget,
            ClientAlert.sugarOver => AppColors.overTarget,
            ClientAlert.lowCompletion => AppColors.warning,
          };
    final type = switch (alert) {
      ClientAlert.unanswered => l.dashTaskReply,
      ClientAlert.sodiumOver => l.dashTaskDiet,
      ClientAlert.sugarOver => l.dashTaskDiet,
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
                InkWell(
                  key: ValueKey<String>(
                    'dashboard-task-check-${task.alert.name}-${entry.client.id}',
                  ),
                  onTap: onToggle,
                  borderRadius: const BorderRadius.all(AppRadius.pill),
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: checked ? AppColors.success : Colors.transparent,
                      border: Border.all(
                        color: checked
                            ? AppColors.success
                            : AppColors.borderStrong,
                      ),
                    ),
                    child: checked
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.primaryForeground,
                          )
                        : null,
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
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: checked ? AppColors.disabledForeground : null,
                      decoration: checked ? TextDecoration.lineThrough : null,
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
            : StatTone.caution,
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
        tone: churnRisk.isEmpty ? StatTone.positive : StatTone.alert,
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
