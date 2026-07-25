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
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';

/// The client detail body — header (avatar/name/goal/active dot) +
/// 채팅/식단/운동기록 sub-tabs. Used in two hosts:
///
/// - full-screen route (`ClientDetailPage`, [showBack] = true), and
/// - the wide-viewport master-detail panel next to the client list
///   ([showBack] = false — the list itself is the navigation).
///
/// Sub-tab state lives here and is intentionally KEPT when the host
/// swaps [clientId] (switching clients in the split view stays on the
/// same sub-tab).
class ClientDetailView extends ConsumerStatefulWidget {
  /// Creates the detail body for [clientId].
  const ClientDetailView({
    super.key,
    required this.clientId,
    this.showBack = true,
    this.onClose,
  });

  /// Id of the client being viewed.
  final String clientId;

  /// Whether to render the back button (full-screen route only).
  final bool showBack;

  /// When set (split-view panel), a close button is shown that collapses
  /// the panel back to the plain client list.
  final VoidCallback? onClose;

  @override
  ConsumerState<ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends ConsumerState<ClientDetailView> {
  int _tab = 0; // 0 채팅 · 1 식단 · 2 운동기록

  @override
  Widget build(BuildContext context) {
    // Distinguish loading / error / loaded instead of flattening them
    // into an empty list (an unknown id used to render a nameless
    // "고객" chat and never-ending 식단/운동 spinners — codex review).
    final clientsAsync = ref.watch(clientsProvider);
    return clientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _StatusView(
        message: '고객 정보를 불러오지 못했어요',
        showBack: widget.showBack,
        // Re-subscribes the stream for a fresh attempt.
        onRetry: () => ref.invalidate(clientsProvider),
      ),
      data: (clients) {
        final match = clients.where((c) => c.id == widget.clientId);
        if (match.isEmpty) {
          // Stale deep link / removed client.
          return _StatusView(
            message: '고객을 찾을 수 없어요',
            showBack: widget.showBack,
            onRetry: null,
          );
        }
        final client = match.first;

        return Column(
          children: <Widget>[
            _Header(
              client: client,
              showBack: widget.showBack,
              onClose: widget.onClose,
            ),
            _SubTabs(current: _tab, onChanged: (i) => setState(() => _tab = i)),
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
    final key = ValueKey<String>(widget.clientId);
    switch (_tab) {
      case 0:
        return ChatView(
          key: key,
          clientId: widget.clientId,
          clientAvatar: client.avatar,
          clientName: client.name,
        );
      case 1:
        return DietView(key: key, client: client);
      default:
        return WorkoutView(key: key, client: client);
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
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.clients),
              child: const Text('고객 목록으로'),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.client,
    required this.showBack,
    required this.onClose,
  });

  final TrainerClient client;
  final bool showBack;
  final VoidCallback? onClose;

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
      child: Row(
        children: <Widget>[
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              color: AppColors.accent,
              // Fall back to the 고객 tab when there's nothing to pop
              // (e.g. a web deep-link / refresh landed on the detail).
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.clients),
            ),
          ClientAvatar(label: client.avatar, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  client.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  client.goal,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.subtleForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: client.active
                  ? AppColors.success
                  : AppColors.disabledForeground,
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
      ),
    );
  }
}

class _SubTabs extends StatelessWidget {
  const _SubTabs({required this.current, required this.onChanged});

  final int current;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = <String>['채팅', '식단', '운동기록'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < _labels.length; i++) ...<Widget>[
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
                        height: 34,
                        alignment: Alignment.center,
                        child: Text(
                          _labels[i],
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
            if (i < _labels.length - 1) const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
