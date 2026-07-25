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
    final clients = ref.watch(clientsProvider).valueOrNull ?? const [];
    final match = clients.where((c) => c.id == widget.clientId);
    final client = match.isNotEmpty ? match.first : null;

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
  }

  Widget _body(TrainerClient? client) {
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
          clientAvatar: client?.avatar ?? '',
          clientName: client?.name ?? '고객',
        );
      case 1:
        return client == null
            ? const Center(child: CircularProgressIndicator())
            : DietView(key: key, client: client);
      default:
        return client == null
            ? const Center(child: CircularProgressIndicator())
            : WorkoutView(key: key, client: client);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.client,
    required this.showBack,
    required this.onClose,
  });

  final TrainerClient? client;
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
          ClientAvatar(label: client?.avatar ?? '', size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  client?.name ?? '고객',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                if (client != null)
                  Text(
                    client!.goal,
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
              color: (client?.active ?? false)
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
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: current == i
                        ? AppColors.accent
                        : AppColors.inputBackground,
                    borderRadius: const BorderRadius.all(AppRadius.md),
                  ),
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
            if (i < _labels.length - 1) const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
