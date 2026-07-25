import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_detail_view.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/content_frame.dart';
import 'package:oncare_trainer/shared/widgets/oni_avatar.dart';

/// 고객 관리 tab — reservation badge, AI summary, and the client list.
///
/// Responsive: from [AppLayout.splitBreakpoint] the tab becomes a
/// master-detail split — list on the left, the selected client's
/// 채팅/식단/운동기록 panel on the right. The selection is mirrored to
/// the URL (`/clients?c=<id>`) so a refresh restores the same state.
/// Narrower viewports keep the full-screen push to `/client/:id`.
class ClientsPage extends ConsumerWidget {
  /// Creates the clients tab.
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Priority ordering: sodium-over clients first, then recent chat.
    final clients = ref.watch(prioritizedClientsProvider);
    final reservations = ref.watch(todayReservationCountProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: clients.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(
            child: Text(
              '고객 정보를 불러오지 못했어요',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ),
          data: (list) => LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= AppLayout.splitBreakpoint &&
                  list.isNotEmpty;

              // Restore the selection from the URL (?c=<id>). Absent or
              // stale means the panel is closed — the tab starts as a
              // plain list until a client is picked.
              final query = GoRouterState.of(context).uri.queryParameters['c'];
              final selected = wide && list.any((c) => c.id == query)
                  ? query
                  : null;

              if (selected == null) {
                return ContentFrame(
                  child: _ClientsView(
                    clients: list,
                    reservations: reservations,
                    selectedId: null,
                    // Wide: open the side panel via the URL. Narrow:
                    // keep the full-screen push.
                    onOpen: (id) => wide
                        ? context.go(_clientsLocation(id))
                        : context.push(AppRoutes.clientDetail(id)),
                  ),
                );
              }

              return ContentFrame(
                maxWidth: AppLayout.wideMaxWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: AppLayout.splitListWidth,
                      child: _ClientsView(
                        clients: list,
                        reservations: reservations,
                        selectedId: selected,
                        // Selecting swaps the right panel (and the URL)
                        // instead of pushing a new screen.
                        onOpen: (id) => context.go(_clientsLocation(id)),
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      color: AppColors.borderStrong,
                    ),
                    Expanded(
                      child: ClientDetailView(
                        clientId: selected,
                        showBack: false,
                        onClose: () => context.go(AppRoutes.clients),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The `?c=` location for [clientId], built through [Uri] so the id is
/// percent-encoded — string concatenation would break on a `?`/`&`/
/// non-ASCII id once ids stop being seed-generated.
String _clientsLocation(String clientId) => Uri(
  path: AppRoutes.clients,
  queryParameters: <String, String>{'c': clientId},
).toString();

class _ClientsView extends StatelessWidget {
  const _ClientsView({
    required this.clients,
    required this.reservations,
    required this.selectedId,
    required this.onOpen,
  });

  final List<TrainerClient> clients;
  final int? reservations;

  /// Highlighted client in the split layout (null on narrow viewports).
  final String? selectedId;

  /// Invoked with the tapped client's id.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sodiumOver = clients.where((c) => c.sodiumOverBudget).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Text(
                '고객 관리',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (reservations != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentSurface,
                  borderRadius: const BorderRadius.all(AppRadius.pill),
                ),
                child: Text(
                  '오늘 $reservations명 예약',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _AiSummaryCard(sodiumOver: sodiumOver),
        const SizedBox(height: AppSpacing.lg),
        for (final client in clients) ...<Widget>[
          ClientCard(
            client: client,
            selected: client.id == selectedId,
            onTap: () => onOpen(client.id),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// The "✦ AI 요약" card summarising how many clients are over their
/// sodium target today.
class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard({required this.sodiumOver});

  final int sodiumOver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.aiCardGradientStart,
            AppColors.aiCardGradientEnd,
          ],
        ),
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: <Widget>[
          // The On-Care mascot — same AI identity as the user app redesign.
          const OniAvatar(size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.all(AppRadius.pill),
                  ),
                  child: const Text(
                    '✦ AI 요약',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      const TextSpan(text: '오늘 나트륨 초과 고객 '),
                      TextSpan(
                        text: '$sodiumOver명',
                        style: const TextStyle(color: AppColors.warning),
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                Text(
                  sodiumOver > 0 ? '루틴 조정이 필요할 수 있어요.' : '모든 고객이 목표 범위 안에 있어요.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
