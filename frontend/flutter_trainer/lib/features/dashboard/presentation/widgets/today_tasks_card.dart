import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/features/dashboard/data/daily_task_progress_store.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/features/dashboard/presentation/widgets/attention_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// Bumped whenever [TodayTasksCard] persists a new daily snapshot, so a
/// sibling widget with no direct link to that state (the 할 일 진행률 chart)
/// knows to re-read [dailyTaskProgressStoreProvider].
final taskProgressVersionProvider = StateProvider<int>(
  (ref) => 0,
  name: 'taskProgressVersion',
);

/// 상담 요청 확인 카테고리가 쓰는 대기 목록 — **한 번만** 읽는다.
///
/// `consultationsProvider`(인박스 화면 전용)는 [ConsultationRepository.watch]
/// 를 그대로 구독하는데, 실서버 구현은 배지처럼 몇 초마다 다시 읽는 폴링
/// 스트림이다. 대시보드 카드에 그 스트림을 그대로 물리면 대시보드를 떠나도
/// 폴링이 계속 돌아 — 스케줄 30일 조회에서 겪은 것과 같은 이유로(
/// dashboard_controller.dart 참고) — 실서버 모드 위젯 테스트에서 타이머가
/// 안 지워지는 문제가 다시 생겼다. `fetch()` 는 원래 일회성 Future라 그대로
/// 쓴다.
final _consultationMissionsProvider =
    FutureProvider.autoDispose<List<ConsultationRequest>>((ref) {
      if (!ref.watch(consultationInboxEnabledProvider)) {
        return Future.value(const <ConsultationRequest>[]);
      }
      return ref.watch(consultationRepositoryProvider).fetch();
    }, name: 'consultationMissions');

/// A category of 오늘 할 일 — the card opens on this grid; tapping one
/// drills into its own missions.
enum TodoCategory {
  /// 미처리 상담 요청.
  consultation,

  /// 건강 신호(나트륨·당류·이행률)로 확인이 필요한 고객.
  feedback,

  /// 최근 보낸 프로그램이 없는 고객.
  program,

  /// 이번 주 리포트를 챙길 고객.
  report;

  String label(AppLocalizations l) => switch (this) {
    TodoCategory.consultation => l.dashTodoConsultation,
    TodoCategory.feedback => l.dashTodoFeedback,
    TodoCategory.program => l.dashTodoProgram,
    TodoCategory.report => l.dashTodoReport,
  };

  IconData get icon => switch (this) {
    TodoCategory.consultation => Icons.event_available_outlined,
    TodoCategory.feedback => Icons.feedback_outlined,
    TodoCategory.program => Icons.fitness_center,
    TodoCategory.report => Icons.description_outlined,
  };
}

/// One concrete item inside a [TodoCategory].
class _Mission {
  const _Mission({
    required this.key,
    required this.title,
    this.subtitle = '',
    required this.onTap,
  });

  /// Stable across a day — used for checked/dismissed/carry-over tracking.
  final String key;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// 오늘 할 일 — 카테고리 4개(상담 요청 확인·고객 피드백 확인·운동 프로그램
/// 등록·리포트 작성)를 2×2 그리드로 먼저 보여주고, 하나를 고르면 그 칸 안에서
/// 해당 카테고리의 미션 목록으로 바뀐다(상단 X로 그리드로 복귀).
///
/// 체크(완료 처리, 회색+취소선)와 X(오늘 목록에서 제외)는 서로 다른
/// 동작이다 — 체크는 "했다", X는 "오늘은 안 보이게" 다. 아래는 모두 이
/// 세션이 로컬로만 기억하는 상태다: 실제 상담 수락/거절, 프로그램 전송,
/// 리포트 발송은 각 화면(상담·AI 코칭·리포트)에서 해야 한다 — 여기 체크는
/// "확인했다"는 트레이너 자신의 표시일 뿐이다.
class TodayTasksCard extends ConsumerStatefulWidget {
  /// Creates the card. [entries] is the health-alert roster (같은 정의를
  /// 주의 고객 KPI 가 쓴다).
  const TodayTasksCard({super.key, required this.entries});

  final List<AttentionClient> entries;

  @override
  ConsumerState<TodayTasksCard> createState() => _TodayTasksCardState();
}

class _TodayTasksCardState extends ConsumerState<TodayTasksCard> {
  bool _expanded = true;
  TodoCategory? _selected;
  Set<String> _checkedKeys = <String>{};
  Set<String> _dismissedKeys = <String>{};
  Set<String> _carriedOverKeys = <String>{};
  String? _initializedForDate;

  void _initializeIfNewDay(Set<String> allKeys) {
    final today = ymd(nowKst());
    if (_initializedForDate == today) return;
    _initializedForDate = today;
    final store = ref.read(dailyTaskProgressStoreProvider);
    final snapshot = store.read(today);
    final yesterday = store.read(
      ymd(nowKst().subtract(const Duration(days: 1))),
    );
    _checkedKeys = snapshot == null
        ? <String>{}
        : allKeys.where((k) => !snapshot.pendingKeys.contains(k)).toSet();
    _carriedOverKeys = yesterday == null
        ? <String>{}
        : yesterday.pendingKeys.intersection(allKeys);
    _dismissedKeys = <String>{};
  }

  void _toggle(String key, Set<String> allKeys) {
    setState(() {
      if (!_checkedKeys.remove(key)) _checkedKeys.add(key);
    });
    unawaited(_persist(allKeys));
  }

  Future<void> _dismiss(String key, Set<String> allKeys) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.dashTaskDismissTitle),
        content: Text(l.dashTaskDismissBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _dismissedKeys.add(key);
      _checkedKeys.remove(key);
    });
    unawaited(_persist(allKeys.difference(<String>{key})));
  }

  Future<void> _persist(Set<String> allKeys) async {
    final store = ref.read(dailyTaskProgressStoreProvider);
    final checked = _checkedKeys.intersection(allKeys);
    final carriedCompleted = checked.intersection(_carriedOverKeys).length;
    await store.save(
      ymd(nowKst()),
      DailyTaskSnapshot(
        total: allKeys.length,
        completedToday: checked.length - carriedCompleted,
        completedCarriedOver: carriedCompleted,
        pendingKeys: allKeys.difference(checked),
      ),
    );
    if (!mounted) return;
    ref.read(taskProgressVersionProvider.notifier).state++;
  }

  Map<TodoCategory, List<_Mission>> _buildMissions(AppLocalizations l) {
    final clients =
        ref.watch(clientsProvider).valueOrNull ?? const <TrainerClient>[];
    final consultations =
        ref.watch(_consultationMissionsProvider).valueOrNull ??
        const <ConsultationRequest>[];

    final health = widget.entries.where((e) => e.alerts.any((a) => a.isHealth));
    final missingProgram = clients.where(
      (c) =>
          c.active &&
          (c.lastRoutine.trim().isEmpty || c.lastRoutine.trim() == '-'),
    );
    final activeClients = clients.where((c) => c.active);

    return <TodoCategory, List<_Mission>>{
      TodoCategory.consultation: <_Mission>[
        for (final request in consultations.where((r) => r.isPending))
          _Mission(
            key: 'consultation-${request.id}',
            title: request.memberName,
            subtitle: l.dashTodoConsultationSubtitle,
            onTap: () => context.go(AppRoutes.consultations),
          ),
      ],
      TodoCategory.feedback: <_Mission>[
        for (final entry in health)
          _Mission(
            key: 'feedback-${entry.primary.name}-${entry.client.id}',
            title: entry.client.name,
            subtitle: entry.primary.label(l),
            onTap: () => context.go(
              AppRoutes.clientDetail(
                entry.client.id,
                section: AttentionCard.sectionFor(entry.primary),
              ),
            ),
          ),
      ],
      TodoCategory.program: <_Mission>[
        for (final client in missingProgram)
          _Mission(
            key: 'program-${client.id}',
            title: client.name,
            subtitle: l.dashTodoProgramSubtitle,
            onTap: () => context.go(AppRoutes.coachingFor(client.id)),
          ),
      ],
      TodoCategory.report: <_Mission>[
        for (final client in activeClients)
          _Mission(
            key: 'report-${client.id}',
            title: client.name,
            subtitle: l.dashTodoReportSubtitle,
            onTap: () => context.go(AppRoutes.reportFor(client.id)),
          ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final missionsByCategory = _buildMissions(l);
    final allMissions = missionsByCategory.values.expand((m) => m);
    final allKeys = <String>{for (final m in allMissions) m.key}
      ..removeAll(_dismissedKeys);
    _initializeIfNewDay(allKeys);

    final remaining = allKeys.difference(_checkedKeys).length;
    final allDone = allKeys.isNotEmpty && remaining == 0;

    return SectionCard(
      title: l.dashTodayTasks,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            allKeys.isEmpty || allDone
                ? l.dashTasksReviewed
                : l.dashTasksNeedReview(remaining),
            style: TextStyle(
              color: allKeys.isEmpty || allDone
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
          : _selected == null
          ? _CategoryGrid(
              missionsByCategory: missionsByCategory,
              checkedKeys: _checkedKeys,
              onSelect: (c) => setState(() => _selected = c),
            )
          : _MissionListView(
              category: _selected!,
              missions: missionsByCategory[_selected!]!,
              checkedKeys: _checkedKeys,
              carriedOverKeys: _carriedOverKeys,
              onBack: () => setState(() => _selected = null),
              onToggle: (key) => _toggle(key, allKeys),
              onDismiss: (key) => _dismiss(key, allKeys),
            ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.missionsByCategory,
    required this.checkedKeys,
    required this.onSelect,
  });

  final Map<TodoCategory, List<_Mission>> missionsByCategory;
  final Set<String> checkedKeys;
  final ValueChanged<TodoCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.1,
      children: <Widget>[
        for (final category in TodoCategory.values)
          _CategoryTile(
            key: ValueKey<String>('dashboard-todo-category-${category.name}'),
            category: category,
            pending: (missionsByCategory[category] ?? const <_Mission>[])
                .where((m) => !checkedKeys.contains(m.key))
                .length,
            onTap: () => onSelect(category),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.category,
    required this.pending,
    required this.onTap,
  });

  final TodoCategory category;
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: const BorderRadius.all(AppRadius.md),
          color: pending > 0
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.card,
        ),
        child: Row(
          children: <Widget>[
            Icon(category.icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                category.label(l),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (pending > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: const BorderRadius.all(AppRadius.pill),
                ),
                child: Text(
                  '+$pending',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MissionListView extends StatelessWidget {
  const _MissionListView({
    required this.category,
    required this.missions,
    required this.checkedKeys,
    required this.carriedOverKeys,
    required this.onBack,
    required this.onToggle,
    required this.onDismiss,
  });

  final TodoCategory category;
  final List<_Mission> missions;
  final Set<String> checkedKeys;
  final Set<String> carriedOverKeys;
  final VoidCallback onBack;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                category.label(l),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            InkWell(
              key: const ValueKey<String>('dashboard-todo-back'),
              borderRadius: const BorderRadius.all(AppRadius.pill),
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.subtleForeground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (missions.isEmpty)
          EmptyHint(message: l.dashTodoEmpty, icon: Icons.task_alt)
        else
          for (final mission in missions)
            _MissionRow(
              key: ValueKey<String>('dashboard-mission-${mission.key}'),
              mission: mission,
              checked: checkedKeys.contains(mission.key),
              carriedOver: carriedOverKeys.contains(mission.key),
              onToggle: () => onToggle(mission.key),
              onDismiss: () => onDismiss(mission.key),
            ),
      ],
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    super.key,
    required this.mission,
    required this.checked,
    required this.carriedOver,
    required this.onToggle,
    required this.onDismiss,
  });

  final _Mission mission;
  final bool checked;

  /// 어제 저장분에 이미 남아 있던 미션인가 — 참이면 행 배경을 이월 색으로
  /// 물들여, 오늘 새로 생긴 항목과 구분한다.
  final bool carriedOver;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: carriedOver
            ? AppColors.aiCardGradientEnd.withValues(alpha: 0.16)
            : AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: InkWell(
          onTap: mission.onTap,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        mission.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: checked ? AppColors.disabledForeground : null,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (mission.subtitle.isNotEmpty)
                        Text(
                          mission.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.subtleForeground,
                          ),
                        ),
                    ],
                  ),
                ),
                InkWell(
                  key: ValueKey<String>(
                    'dashboard-mission-dismiss-${mission.key}',
                  ),
                  onTap: onDismiss,
                  borderRadius: const BorderRadius.all(AppRadius.pill),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.disabledForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
