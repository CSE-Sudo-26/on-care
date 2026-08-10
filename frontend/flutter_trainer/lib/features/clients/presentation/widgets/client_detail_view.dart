import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_coach_sheet.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_coach_repository.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/chat_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/diet_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/workout_view.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/alert_badge.dart';
import 'package:oncare_trainer/shared/widgets/status_dot_label.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
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

/// The client detail body — a header that answers "how is this person
/// doing right now?" plus the 식단/운동 sub-tabs.
///
/// The header carries only the alert badges from the former 개요 tab. Detailed
/// nutrition values live in 식단 and workout trends live in 운동, avoiding a
/// duplicate summary while keeping actionable signals such as 나트륨 초과
/// visible from every section.
///
/// Chat rides at the end of the sub-tab row rather than being a third equal
/// tab: 식단 and 운동 are things you *read* about this person, chatting is
/// something you *do* with them, and opening it marks the thread read. It
/// hugs its content behind a divider so that difference is visible, while
/// still living in the row that owns "which section am I in". It stays
/// addressable either way (see [AppRoutes.clientChatSection]).
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

  /// The section actually being shown; unknown values fall back to the
  /// default so a stale link renders something rather than nothing.
  String get _section {
    final s = section ?? '';
    return AppRoutes.clientSections.contains(s)
        ? s
        : AppRoutes.defaultClientSection;
  }

  /// Index into [AppRoutes.clientTabSections], or `-1` while the chat is
  /// open — chat has no tab, so no tab is selected then.
  int get _tabIndex => AppRoutes.clientTabSections.indexOf(_section);

  /// Whether the chat thread is the open section.
  bool get _chatOpen => _section == AppRoutes.clientChatSection;

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

        return Column(
          children: <Widget>[
            _Header(
              client: client,
              alerts: alertsFor(client, unread: unread[client.id] ?? 0),
              showBack: showBack,
              onClose: onClose,
              onRefresh: () {
                ref.invalidate(clientsProvider);
                ref.invalidate(clientDietProvider(client.id));
                ref.invalidate(clientHistoryProvider(client.id));
              },
              onToggleActive: canManageRoster
                  ? () => ref
                        .read(clientRepositoryProvider)
                        .setClientActive(client.id, !client.active)
                  : null,
            ),
            _SubTabs(
              current: _tabIndex,
              onChanged: (i) => onSectionChange(AppRoutes.clientTabSections[i]),
              clientName: client.name,
              unread: unread[client.id] ?? 0,
              chatOpen: _chatOpen,
              onOpenChat: () => onSectionChange(AppRoutes.clientChatSection),
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
    switch (_section) {
      case AppRoutes.clientChatSection:
        return ChatView(
          key: key,
          clientId: clientId,
          clientAvatar: client.avatar,
          clientName: client.name,
        );
      case 'workout':
        return WorkoutView(key: key, client: client);
      default:
        return DietView(key: key, client: client);
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
    final AppLocalizations l = AppLocalizations.of(context);
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
          Row(
            children: <Widget>[
              Expanded(
                child: ActionButton(
                  label: l.dashCreateAiRoutine,
                  icon: Icons.auto_awesome,
                  primary: true,
                  onPressed: () => context.go(AppRoutes.coachingFor(client.id)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ActionButton(
                  label: l.clientWeeklyReport,
                  icon: Icons.insights_outlined,
                  onPressed: () => context.go(AppRoutes.reportFor(client.id)),
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
                    child: Text(
                      client.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
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
                  fontSize: 10.5,
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

/// The 채팅 entry point, rendered as the trailing segment of [_SubTabs].
///
/// Wears the tabs' selected-state language (same height, same radius, same
/// accent fill) so one row speaks one visual grammar, but hugs its content
/// instead of sharing the width — chat is a destination, not a peer view.
///
/// Carries the unread count so the trainer can see there's something
/// waiting without opening the thread (opening it marks it read).
class _ChatSegment extends StatelessWidget {
  const _ChatSegment({
    required this.clientName,
    required this.unread,
    required this.selected,
    required this.onTap,
  });

  final String clientName;
  final int unread;

  /// Whether the chat thread is the open section.
  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color fg = selected
        ? AppColors.accentForeground
        : AppColors.subtleForeground;
    return Semantics(
      button: true,
      selected: selected,
      // Same exclusive group as the content tabs — a screen reader reads all
      // three as one set of destinations, which is what they now are.
      inMutuallyExclusiveGroup: true,
      // The visible parts (l.clientChat + the bare count) would otherwise be
      // announced after this label, reading as "…채팅, 안 읽은 메시지
      // 1개, 채팅, 1". One node, one sentence — so the tap action has to
      // ride along here too, since the InkWell's own node is excluded.
      excludeSemantics: true,
      onTap: onTap,
      label: unread > 0
          ? l.clientChatWithUnread(clientName, unread)
          : l.clientChatWith(clientName),
      child: Material(
        color: selected ? AppColors.accent : AppColors.inputBackground,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: InkWell(
          key: const ValueKey<String>('client-chat-button'),
          onTap: onTap,
          borderRadius: const BorderRadius.all(AppRadius.md),
          child: Container(
            height: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.send_rounded, size: 15, color: fg),
                const SizedBox(width: 5),
                Text(
                  l.clientChat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                if (unread > 0) ...<Widget>[
                  const SizedBox(width: 5),
                  Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accentForeground
                          : AppColors.primary,
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                    ),
                    child: Text(
                      '$unread',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? AppColors.accent
                            : AppColors.primaryForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The client's navigation strip: 식단 · 운동 as equal content tabs, then the
/// chat entry point at the end of the same row.
///
/// Chat sits here rather than up in the header because it swaps the body the
/// way the tabs do — when it lived beside the name, opening it left this row
/// with nothing selected, which read as a broken tab bar. It is still not a
/// peer of 식단/운동 (those are views of this person's data; chatting is
/// something you *do*, and opening it marks the thread read), so the
/// distinction is carried by shape instead of location: the tabs share the
/// width, chat hugs its content behind a divider.
class _SubTabs extends StatelessWidget {
  const _SubTabs({
    required this.current,
    required this.onChanged,
    required this.clientName,
    required this.unread,
    required this.chatOpen,
    required this.onOpenChat,
  });

  /// Selected content tab, or -1 while the chat is open.
  final int current;
  final ValueChanged<int> onChanged;

  final String clientName;

  /// Messages waiting for a reply, shown on the chat segment.
  final int unread;
  final bool chatOpen;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('client-detail-sub-tabs'),
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < clientSectionCount; i++) ...<Widget>[
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
                          clientSectionLabels(l)[i],
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
            if (i < clientSectionCount - 1)
              const SizedBox(width: AppSpacing.xs),
          ],
          // Sets chat apart from the content tabs without leaving the row.
          const SizedBox(width: AppSpacing.sm),
          Container(width: 1, height: 16, color: AppColors.border),
          const SizedBox(width: AppSpacing.sm),
          _ChatSegment(
            clientName: clientName,
            unread: unread,
            selected: chatOpen,
            onTap: onOpenChat,
          ),
        ],
      ),
    );
  }
}
