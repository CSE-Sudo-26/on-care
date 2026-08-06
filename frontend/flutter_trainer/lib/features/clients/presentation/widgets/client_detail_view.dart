import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/chat_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/diet_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/workout_view.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/alert_badge.dart';
import 'package:oncare_trainer/shared/widgets/metric_tile.dart';
import 'package:oncare_trainer/shared/widgets/status_dot_label.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';

/// Labels for [AppRoutes.clientSections], in the same order.
const List<String> clientSectionLabels = <String>['채팅', '식단', '운동'];

/// The client detail body — a header that answers "how is this person
/// doing right now?" plus the 채팅/식단/운동 sub-tabs.
///
/// The header carries what used to be the 개요 tab: the alert badges and
/// today's calorie/sodium/sugar numbers. Those are the questions the
/// trainer has on *every* tab, so paying a tab for them meant the answer
/// was missing exactly when they were reading the chat or the diet. The
/// two trends 개요 also drew (주간 이행률, 나트륨 추이) now live only where
/// they belong — 운동, 식단, and the 리포트 tab that renders the same
/// charts for the week.
///
/// The active sub-tab is **owned by the URL**, not by this widget: the
/// dashboard links straight to a client's 식단 when sodium is over, and
/// that only works if the section is addressable. [onSectionChange] asks
/// the host to navigate; this widget never holds tab state.
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

  /// Index into [AppRoutes.clientSections] for the current [section].
  int get _index {
    final i = AppRoutes.clientSections.indexOf(section ?? '');
    return i < 0
        ? AppRoutes.clientSections.indexOf(AppRoutes.defaultClientSection)
        : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        message: '고객 정보를 불러오지 못했어요',
        showBack: showBack,
        // Re-subscribes the stream for a fresh attempt.
        onRetry: () => ref.invalidate(clientsProvider),
      ),
      data: (clients) {
        final match = clients.where((c) => c.id == clientId);
        if (match.isEmpty) {
          // Stale deep link / removed client.
          return _StatusView(
            message: '고객을 찾을 수 없어요',
            showBack: showBack,
            onRetry: null,
          );
        }
        final client = match.first;

        return Column(
          children: <Widget>[
            _Header(
              client: client,
              alerts: alertsFor(client, unread: unread[client.id] ?? 0),
              showBack: showBack,
              onClose: onClose,
              onToggleActive: canManageRoster
                  ? () => ref
                        .read(clientRepositoryProvider)
                        .setClientActive(client.id, !client.active)
                  : null,
            ),
            _SubTabs(
              current: _index,
              onChanged: (i) => onSectionChange(AppRoutes.clientSections[i]),
            ),
            Expanded(child: _body(client)),
          ],
        );
      },
    );
  }

  Widget _body(TrainerClient client) {
    // Key the sub-views by client so per-client state (chat draft,
    // scroll position) resets when the split view swaps clients —
    // otherwise a message drafted for one client would linger in
    // another client's composer.
    final key = ValueKey<String>(clientId);
    switch (AppRoutes.clientSections[_index]) {
      case 'diet':
        return DietView(key: key, client: client);
      case 'workout':
        return WorkoutView(key: key, client: client);
      default:
        return ChatView(
          key: key,
          clientId: clientId,
          clientAvatar: client.avatar,
          clientName: client.name,
        );
    }
  }
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          if (showBack)
            TextButton(
              onPressed: () => context.go(AppRoutes.clients),
              child: const Text('고객 목록으로'),
            ),
        ],
      ),
    );
  }
}

/// Identity, why this client is flagged, today's numbers, and the two
/// things the trainer most often does next — above the tabs, so all of it
/// stays on screen no matter which tab is open.
class _Header extends StatelessWidget {
  const _Header({
    required this.client,
    required this.alerts,
    required this.showBack,
    required this.onClose,
    required this.onToggleActive,
  });

  final TrainerClient client;

  /// Why this client is flagged; empty when they're fine today.
  final List<ClientAlert> alerts;

  final bool showBack;
  final VoidCallback? onClose;

  /// Flips the client between 활성 and 휴면.
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: <Widget>[
              MetricTile(
                label: '칼로리',
                value: client.calories,
                unit: 'kcal',
                color: AppColors.foreground,
              ),
              const SizedBox(width: AppSpacing.xs),
              MetricTile(
                label: '나트륨',
                value: client.sodiumMg,
                unit: 'mg',
                color: AppColors.foreground,
                warn: client.sodiumOverBudget,
              ),
              const SizedBox(width: AppSpacing.xs),
              MetricTile(
                label: '당류',
                value: client.sugarG,
                unit: 'g',
                color: AppColors.foreground,
                warn: client.sugarG > sugarTargetG,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: ActionButton(
                  label: 'AI 루틴 만들기',
                  icon: Icons.auto_awesome,
                  primary: true,
                  onPressed: () => context.go(AppRoutes.coachingFor(client.id)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ActionButton(
                  label: '주간 리포트',
                  icon: Icons.insights_outlined,
                  onPressed: () => context.go(AppRoutes.reportFor(client.id)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identityRow(BuildContext context) {
    return Row(
      children: <Widget>[
        if (showBack)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: AppColors.accent,
            tooltip: '고객 목록',
            onPressed: () => context.go(AppRoutes.clients),
          ),
        ClientAvatar(label: client.avatar, size: 36),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                client.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              Text(
                client.goal,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.subtleForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // The backend roster has no status mutation endpoint yet. Keep the
        // status visible in real mode, but only make it interactive when
        // the selected repository supports roster mutations.
        Material(
          color:
              (client.active ? AppColors.success : AppColors.disabledForeground)
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
                label: client.active ? '활성' : '휴면',
                filled: client.active,
                color: client.active
                    ? AppColors.success
                    : AppColors.disabledForeground,
              ),
            ),
          ),
        ),
        if (onClose != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.subtleForeground,
            tooltip: '패널 닫기',
            onPressed: onClose,
          ),
      ],
    );
  }
}

class _SubTabs extends StatelessWidget {
  const _SubTabs({required this.current, required this.onChanged});

  final int current;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < clientSectionLabels.length; i++) ...<Widget>[
            Expanded(
              // InkWell (over a Material) instead of GestureDetector so the
              // sub-tabs are keyboard-focusable and activate on Enter/Space
              // — desktop/web users can traverse them (CodeRabbit review).
              //
              // MergeSemantics folds this into the InkWell's own tap/focus
              // node so a screen reader announces the selected state on the
              // node it actually reads (review PR 216).
              child: MergeSemantics(
                child: Semantics(
                  button: true,
                  selected: current == i,
                  inMutuallyExclusiveGroup: true,
                  child: Material(
                    color: current == i
                        ? AppColors.accent
                        : AppColors.inputBackground,
                    borderRadius: const BorderRadius.all(AppRadius.md),
                    child: InkWell(
                      onTap: () => onChanged(i),
                      borderRadius: const BorderRadius.all(AppRadius.md),
                      child: Container(
                        height: 32,
                        alignment: Alignment.center,
                        child: Text(
                          clientSectionLabels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: current == i
                                ? AppColors.accentForeground
                                : AppColors.subtleForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (i < clientSectionLabels.length - 1)
              const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
