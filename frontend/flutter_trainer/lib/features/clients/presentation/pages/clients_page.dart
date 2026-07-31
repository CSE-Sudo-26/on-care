import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_detail_view.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/content_frame.dart';
import 'package:oncare_trainer/shared/widgets/oni_avatar.dart';
import 'package:oncare_trainer/shared/widgets/outlined_action_button.dart';

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

  Future<void> _openAddClientSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.card),
      ),
      builder: (context) => const _AddClientSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Priority ordering: sodium-over clients first, then recent chat.
    final clients = ref.watch(prioritizedClientsProvider);
    final reservations = ref.watch(todayReservationCountProvider).valueOrNull;
    final unread =
        ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};
    // Roster mutations exist only in demo/mock mode — the real backend has
    // no add-client endpoint (the roster is derived from trainer↔member
    // links), so hide the 신규 고객 등록 entry when hitting the real API.
    final canManageRoster = ref
        .watch(clientRepositoryProvider)
        .supportsRosterMutations;

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
                    unread: unread,
                    selectedId: null,
                    // Wide: open the side panel via the URL. Narrow:
                    // keep the full-screen push.
                    onOpen: (id) => wide
                        ? context.go(_clientsLocation(id))
                        : context.push(AppRoutes.clientDetail(id)),
                    onAddClient: canManageRoster
                        ? () => _openAddClientSheet(context)
                        : null,
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
                        unread: unread,
                        selectedId: selected,
                        // Selecting swaps the right panel (and the URL)
                        // instead of pushing a new screen.
                        onOpen: (id) => context.go(_clientsLocation(id)),
                        onAddClient: canManageRoster
                            ? () => _openAddClientSheet(context)
                            : null,
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
    required this.unread,
    required this.selectedId,
    required this.onOpen,
    required this.onAddClient,
  });

  final List<TrainerClient> clients;
  final int? reservations;

  /// Unread chat counts by client id (absent = 0).
  final Map<String, int> unread;

  /// Highlighted client in the split layout (null on narrow viewports).
  final String? selectedId;

  /// Invoked with the tapped client's id.
  final ValueChanged<String> onOpen;

  /// Opens the 신규 고객 등록 sheet, or `null` to hide the entry (real-API
  /// mode has no add-client endpoint).
  final VoidCallback? onAddClient;

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
            unread: unread[client.id] ?? 0,
            onTap: () => onOpen(client.id),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (onAddClient != null)
          OutlinedActionButton(
            label: '＋ 신규 고객 등록',
            color: AppColors.accent,
            onTap: onAddClient!,
          ),
      ],
    );
  }
}

/// 신규 고객 등록 시트의 입력칸 공통 테두리 — 검정 밑줄 대신 둥근 네모.
const OutlineInputBorder _sheetInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(AppRadius.lg),
  borderSide: BorderSide.none,
);

/// Bottom sheet collecting the new client's 이름/목표.
class _AddClientSheet extends ConsumerStatefulWidget {
  const _AddClientSheet();

  @override
  ConsumerState<_AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends ConsumerState<_AddClientSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _goal = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    super.dispose();
  }

  /// Set when the entered name is blank or already taken.
  String? _nameError;

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '이름을 입력해 주세요');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    final navigator = Navigator.of(context);
    bool added;
    try {
      added = await ref
          .read(clientRepositoryProvider)
          .addClient(name: name, goal: _goal.text);
    } catch (_) {
      // An unexpected DB failure must not leave the sheet silently stuck —
      // surface it inline like the duplicate case. `finally` clears the
      // saving flag on every path (CodeRabbit review).
      if (mounted) setState(() => _nameError = '등록에 실패했어요. 다시 시도해 주세요');
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (!added) {
      // Duplicate name — schedules resolve their client by name, so
      // allowing it would misattribute chat/운동기록 (review PR 243).
      setState(() => _nameError = '이미 같은 이름의 고객이 있어요');
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '신규 고객 등록',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              hintText: '고객 이름',
              hintStyle: const TextStyle(color: AppColors.subtleForeground),
              isDense: true,
              filled: true,
              fillColor: AppColors.inputBackground,
              errorText: _nameError,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              border: _sheetInputBorder,
              enabledBorder: _sheetInputBorder,
              focusedBorder: _sheetInputBorder,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _goal,
            decoration: const InputDecoration(
              hintText: '목표 (예: 체중 감량 · 근력 향상)',
              hintStyle: TextStyle(color: AppColors.subtleForeground),
              isDense: true,
              filled: true,
              fillColor: AppColors.inputBackground,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              border: _sheetInputBorder,
              enabledBorder: _sheetInputBorder,
              focusedBorder: _sheetInputBorder,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Material(
            color: AppColors.primary,
            borderRadius: const BorderRadius.all(AppRadius.lg),
            child: InkWell(
              onTap: _saving ? null : _save,
              borderRadius: const BorderRadius.all(AppRadius.lg),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: const Text(
                  '등록하기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryForeground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
        boxShadow: kCardShadow,
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
