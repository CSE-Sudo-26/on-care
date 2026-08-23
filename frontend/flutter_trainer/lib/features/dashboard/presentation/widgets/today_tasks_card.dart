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
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// Bumped whenever [TodayTasksCard] persists a new daily snapshot, so a
/// sibling widget with no direct link to that state (the 할 일 진행률 chart)
/// knows to re-read [dailyTaskProgressStoreProvider].
final taskProgressVersionProvider = StateProvider<int>(
  (ref) => 0,
  name: 'taskProgressVersion',
);

/// 상담 요청 확인 미션이 쓰는 대기 목록 — **한 번만** 읽는다.
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

/// One concrete 오늘 할 일 item — 상담 요청 하나, 건강 신호가 있는 고객
/// 하나, 프로그램 미등록 고객 하나, 리포트 대상 고객 하나 등.
///
/// 카테고리별 그리드로 나누지 않고 한 리스트에 섞어 보여준다 — 앞의 알약
/// [keyword] 가 무슨 일인지 말해 준다.
class _Mission {
  const _Mission({
    required this.key,
    required this.keyword,
    required this.keywordColor,
    required this.title,
    this.client,
    required this.subtitle,
    required this.onTap,
  });

  /// Stable across a day — used for checked/dismissed/carry-over tracking.
  final String key;

  /// 알약에 적을 짧은 낱말(상담/식단/운동/프로그램/리포트).
  final String keyword;
  final Color keywordColor;

  /// 고객을 못 찾을 때(상담 요청 등록 회원) 쓸 표시 이름.
  final String title;

  /// 로스터에 있는 고객이면 이름 옆에 성별·나이를 회색으로 붙인다.
  final TrainerClient? client;

  final String subtitle;
  final VoidCallback onTap;
}

/// 오늘 할 일 — 상담 요청·건강 신호·프로그램 미등록·리포트 대상 고객을
/// 한 리스트로 모아 보여준다.
///
/// 체크(완료 처리, 회색+취소선)와 삭제(오늘 목록에서만 제외)는 서로 다른
/// 동작이다. 아래는 모두 이 세션이 로컬로만 기억하는 상태다: 실제 상담
/// 수락/거절, 프로그램 전송, 리포트 발송은 각 화면(상담·AI 코칭·리포트)에서
/// 해야 한다 — 여기 체크는 "확인했다"는 트레이너 자신의 표시일 뿐이다.
class TodayTasksCard extends ConsumerStatefulWidget {
  /// Creates the card. [entries] is the health-alert roster (같은 정의를
  /// 주의 고객 KPI 가 쓴다).
  const TodayTasksCard({super.key, required this.entries});

  final List<AttentionClient> entries;

  @override
  ConsumerState<TodayTasksCard> createState() => _TodayTasksCardState();
}

class _TodayTasksCardState extends ConsumerState<TodayTasksCard> {
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

  List<_Mission> _buildMissions(AppLocalizations l) {
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

    return <_Mission>[
      for (final request in consultations.where((r) => r.isPending))
        _Mission(
          key: 'consultation-${request.id}',
          keyword: l.dashTodoConsultation,
          keywordColor: AppColors.primary,
          title: request.memberName,
          subtitle: l.dashTodoConsultationSubtitle(
            request.preferredDate.month,
            request.preferredDate.day,
          ),
          onTap: () => context.go(AppRoutes.consultations),
        ),
      for (final entry in health)
        _Mission(
          key: 'feedback-${entry.primary.name}-${entry.client.id}',
          keyword: entry.primary == ClientAlert.lowCompletion
              ? l.dashTodoWorkout
              : l.dashTodoDiet,
          keywordColor: AppColors.overTarget,
          title: entry.client.name,
          client: entry.client,
          subtitle: _feedbackSubtitle(l, entry),
          onTap: () => context.go(
            AppRoutes.clientDetail(
              entry.client.id,
              section: AttentionCard.sectionFor(entry.primary),
            ),
          ),
        ),
      for (final client in missingProgram)
        _Mission(
          key: 'program-${client.id}',
          keyword: l.dashTodoProgram,
          keywordColor: AppColors.primary,
          title: client.name,
          client: client,
          subtitle: l.dashTodoProgramSubtitle,
          onTap: () => context.go(AppRoutes.coachingFor(client.id)),
        ),
      for (final client in activeClients)
        _Mission(
          key: 'report-${client.id}',
          keyword: l.dashTodoReport,
          keywordColor: AppColors.primary,
          title: client.name,
          client: client,
          subtitle: l.dashTodoReportSubtitle,
          onTap: () => context.go(AppRoutes.reportFor(client.id)),
        ),
    ];
  }

  String _feedbackSubtitle(AppLocalizations l, AttentionClient entry) {
    final client = entry.client;
    return switch (entry.primary) {
      ClientAlert.sodiumOver => l.dashTodoSodiumSubtitle(
        client.sodiumMg,
        sodiumTargetMg,
      ),
      ClientAlert.sugarOver => l.dashTodoSugarSubtitle(
        client.sugarG.round(),
        sugarTargetG,
      ),
      ClientAlert.lowCompletion ||
      ClientAlert.unanswered => l.dashTodoCompletionSubtitle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final missions = _buildMissions(l);
    final allKeys = <String>{for (final m in missions) m.key}
      ..removeAll(_dismissedKeys);
    _initializeIfNewDay(allKeys);
    final visible = missions.where((m) => allKeys.contains(m.key)).toList();

    final remaining = allKeys.difference(_checkedKeys).length;
    final allDone = allKeys.isNotEmpty && remaining == 0;

    return SectionCard(
      title: l.dashTodayTasks,
      trailing: Text(
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
      child: visible.isEmpty
          ? EmptyHint(message: l.dashTasksEmpty, icon: Icons.task_alt)
          : Column(
              children: <Widget>[
                for (final mission in visible)
                  _MissionRow(
                    key: ValueKey<String>('dashboard-mission-${mission.key}'),
                    mission: mission,
                    checked: _checkedKeys.contains(mission.key),
                    carriedOver: _carriedOverKeys.contains(mission.key),
                    onToggle: () => _toggle(mission.key, allKeys),
                    onDismiss: () => _dismiss(mission.key, allKeys),
                  ),
              ],
            ),
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
    final nameStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: checked ? AppColors.disabledForeground : AppColors.foreground,
      decoration: checked ? TextDecoration.lineThrough : null,
    );
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: mission.keywordColor.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(AppRadius.pill),
                  ),
                  child: Text(
                    mission.keyword,
                    style: TextStyle(
                      color: mission.keywordColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      mission.client == null
                          ? Text(
                              mission.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: nameStyle,
                            )
                          : ClientIdentity(
                              client: mission.client!,
                              nameStyle: nameStyle,
                              demographicsStyle: nameStyle.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.subtleForeground,
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
                      Icons.delete_outline,
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
