import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_coach_sheet.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_coach_repository.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/diet_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/member_health_profile_dialog.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/workout_view.dart';
import 'package:oncare_trainer/features/clients/domain/repositories/client_data_refresher.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/alert_badge.dart';
import 'package:oncare_trainer/shared/widgets/status_dot_label.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// Labels for [AppRoutes.clientTabSections], in the same order.
///
/// 함수인 이유: const 리스트로 두면 생성 시점에 로케일을 알 수 없다. 개수는
/// 라우트 개수와 맞아야 하므로 [clientSectionCount] 로 따로 센다. (#501)
List<String> clientSectionLabels(AppLocalizations l) => <String>[
  l.clientTabDiet,
  l.clientTabWorkout,
];

/// 탭 개수 — 라우트(`AppRoutes.clientTabSections`)와 맞물리는 값이라
/// 로케일과 무관하다.
const int clientSectionCount = 2;

/// The trainer-only 360° detail: identity and actions stay above one scroll
/// containing workout and diet evidence. The route section only determines
/// which evidence appears first, so existing deep links remain meaningful
/// without duplicating the full chat surface owned by `/messages`.
class ClientDetailView extends ConsumerWidget {
  /// Creates the detail body for [clientId].
  const ClientDetailView({
    super.key,
    required this.clientId,
    required this.section,
    required this.onSectionChange,
    this.showBack = true,
    this.onClose,
  });

  /// Id of the client being viewed.
  final String clientId;

  /// Active sub-section; unknown values fall back to the default.
  final String? section;

  /// Asks the host to navigate to another section.
  final ValueChanged<String> onSectionChange;

  /// Whether to render the back button (narrow, detail-only layout).
  final bool showBack;

  /// Closes the panel and returns to the plain list.
  final VoidCallback? onClose;

  /// The section actually being shown; unknown values fall back to the
  /// default so a stale link renders something rather than nothing.
  String get _section {
    final s = section ?? '';
    return AppRoutes.clientSections.contains(s)
        ? s
        : AppRoutes.defaultClientSection;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    // Distinguish loading / error / loaded instead of flattening them
    // into an empty list (an unknown id used to render a nameless
    // "고객" chat and never-ending 식단/운동 spinners — codex review).
    final clientsAsync = ref.watch(clientsProvider);
    final canManageRoster = ref
        .watch(clientRepositoryProvider)
        .supportsRosterMutations;
    // The unread count has to come along: without it `alertsFor` always
    // sees 0 and 답장 대기 could never appear here — so a client the
    // dashboard flagged in red would lose its reason on arrival.
    final unread =
        ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};

    return clientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _StatusView(
        message: l.clientsLoadFailed,
        showBack: showBack,
        // Re-subscribes the stream for a fresh attempt.
        onRetry: () => ref.invalidate(clientsProvider),
      ),
      data: (clients) {
        final match = clients.where((c) => c.id == clientId);
        if (match.isEmpty) {
          // Stale deep link / removed client.
          return _StatusView(
            message: l.clientNotFound,
            showBack: showBack,
            onRetry: null,
          );
        }
        final client = match.first;

        final workoutFirst = _section == 'workout';
        final diet = DietView(
          key: ValueKey<String>('diet-$clientId'),
          client: client,
          embedded: true,
        );
        final workout = WorkoutView(
          key: ValueKey<String>('workout-$clientId'),
          client: client,
          embedded: true,
        );

        return Column(
          children: <Widget>[
            _Header(
              client: client,
              alerts: alertsFor(client, unread: unread[client.id] ?? 0),
              showBack: showBack,
              onClose: onClose,
              onRefresh: () {
                final ClientRepository repository = ref.read(
                  clientRepositoryProvider,
                );
                if (repository case final ClientDataRefresher refresher) {
                  refresher.refreshClientData(client.id);
                }
              },
              onToggleActive: canManageRoster
                  ? () => ref
                        .read(clientRepositoryProvider)
                        .setClientActive(client.id, !client.active)
                  : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey<String>('client-detail-scroll-$clientId'),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _DetailSectionLabel(
                      label: workoutFirst
                          ? l.clientTabWorkout
                          : l.clientTabDiet,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    workoutFirst ? workout : diet,
                    const SizedBox(height: AppSpacing.xl),
                    _DetailSectionLabel(
                      label: workoutFirst
                          ? l.clientTabDiet
                          : l.clientTabWorkout,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    workoutFirst ? diet : workout,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailSectionLabel extends StatelessWidget {
  const _DetailSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: AppColors.foreground,
      fontSize: 15,
      fontWeight: FontWeight.w800,
    ),
  );
}

/// Fallback body for the error and not-found states: a message, an
/// optional 다시 시도 button, and a way back to the 고객 list.
class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.message,
    required this.showBack,
    required this.onRetry,
  });

  final String message;
  final bool showBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(l.actionRetry)),
          if (showBack)
            TextButton(
              onPressed: () => context.go(AppRoutes.clients),
              child: Text(l.clientBackToList),
            ),
        ],
      ),
    );
  }
}

/// Identity, why this client is flagged, and the two things the trainer most
/// often does next — above the tabs, so actionable context stays visible no
/// matter which tab is open without duplicating the tab-specific summaries.
class _Header extends ConsumerWidget {
  const _Header({
    required this.client,
    required this.alerts,
    required this.showBack,
    required this.onClose,
    required this.onRefresh,
    required this.onToggleActive,
  });

  final TrainerClient client;

  /// Why this client is flagged; empty when they're fine today.
  final List<ClientAlert> alerts;

  final bool showBack;
  final VoidCallback? onClose;
  final VoidCallback onRefresh;

  /// Flips the client between 활성 and 휴면.
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _identityRow(context),
          if (alerts.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final alert in alerts) AlertBadge(alert: alert),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              ActionButton(
                label: l.clientQuickMessages,
                icon: Icons.chat_bubble_outline,
                onPressed: () => context.go(AppRoutes.messagesFor(client.id)),
              ),
              ActionButton(
                label: l.clientQuickProgram,
                icon: Icons.fitness_center_outlined,
                primary: true,
                onPressed: () => context.go(AppRoutes.coachingFor(client.id)),
              ),
              ActionButton(
                label: l.clientQuickSchedule,
                icon: Icons.calendar_month_outlined,
                onPressed: () => context.go(AppRoutes.scheduleView('week')),
              ),
              ActionButton(
                label: l.clientWeeklyReport,
                icon: Icons.insights_outlined,
                onPressed: () => context.go(AppRoutes.reportFor(client.id)),
              ),
              ActionButton(
                label: l.clientHealthGoals,
                icon: Icons.badge_outlined,
                onPressed: () => showMemberHealthProfileDialog(
                  context,
                  memberId: client.id,
                  repository: ref.read(clientRepositoryProvider),
                ),
              ),
              Tooltip(
                message: l.clientTrainerMemoUnsupported,
                child: ActionButton(
                  label: l.clientTrainerMemo,
                  icon: Icons.edit_note_outlined,
                  onPressed: null,
                ),
              ),
            ],
          ),
          // AI 코칭 상담(#497)은 실 API 모드에서만 — 데모에는 근거로 삼을 회원
          // 기록이 없어 무엇을 물어도 의미 있는 답이 나오지 않는다. 기존 두
          // 버튼 행은 그대로 두고 아래에 붙여, 데모 헤더가 지금과 같게 남는다.
          if (ref.watch(clientCoachEnabledProvider)) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ActionButton(
              label: l.clientAskAi,
              icon: Icons.psychology_outlined,
              onPressed: () => showClientCoachSheet(
                context,
                memberId: client.id,
                clientName: client.name,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _identityRow(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        if (showBack)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: AppColors.accent,
            tooltip: l.clientList,
            onPressed: () => context.go(AppRoutes.clients),
          ),
        ClientAvatar(label: client.avatar, size: 36),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Status sits with the name — it describes the person, so
              // it belongs to their identity line rather than to the
              // corner the actions live in.
              Row(
                children: <Widget>[
                  Flexible(
                    child: ClientIdentity(
                      client: client,
                      nameStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // The backend roster has no status mutation endpoint
                  // yet. Keep the status visible in real mode, but only
                  // make it interactive when the selected repository
                  // supports roster mutations.
                  Material(
                    color:
                        (client.active
                                ? AppColors.success
                                : AppColors.disabledForeground)
                            .withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(AppRadius.pill),
                    child: InkWell(
                      key: const ValueKey<String>('client-status-toggle'),
                      onTap: onToggleActive,
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 3,
                        ),
                        child: StatusDotLabel(
                          label: client.active
                              ? l.clientActive
                              : l.clientDormant,
                          filled: client.active,
                          color: client.active
                              ? AppColors.success
                              : AppColors.disabledForeground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                client.goal,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.subtleForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey<String>('client-data-refresh'),
          icon: const Icon(Icons.refresh, size: 18),
          color: AppColors.subtleForeground,
          tooltip: l.actionRefresh,
          onPressed: onRefresh,
        ),
        if (onClose != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.subtleForeground,
            tooltip: l.clientClosePanel,
            onPressed: onClose,
          ),
      ],
    );
  }
}
