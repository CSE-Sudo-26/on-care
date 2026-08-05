import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/client_filter.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_detail_view.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 고객 — the roster and, beside it, the selected client's detail.
///
/// One widget owns both halves so the layout choice is made in one
/// place: a master-detail split when there's room, the detail alone
/// when there isn't. Selection lives in the URL
/// (`/clients/<id>/<section>`), so refresh, back/forward and shared
/// links all restore the same view — including which sub-tab was open.
class ClientsPage extends ConsumerWidget {
  /// Creates the roster page. [selectedId]/[section] come from the path,
  /// [filter] from the `f` query parameter.
  const ClientsPage({super.key, this.selectedId, this.section, this.filter});

  /// Client whose detail is open, or null for the plain list.
  final String? selectedId;

  /// Which detail sub-tab is open (see [AppRoutes.clientSections]).
  final String? section;

  /// Roster filter from the URL.
  final String? filter;

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
    final clientsAsync = ref.watch(prioritizedClientsProvider);
    final unread =
        ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};
    // Roster mutations exist only in demo/mock mode — the real backend has
    // no add-client endpoint (the roster is derived from trainer↔member
    // links), so hide the 신규 고객 등록 entry when hitting the real API.
    final canManageRoster = ref
        .watch(clientRepositoryProvider)
        .supportsRosterMutations;
    final activeFilter = clientFilterFrom(filter);

    return clientsAsync.when(
      loading: () => const _Frame(
        subtitle: null,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _Frame(
        subtitle: null,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                '고객 정보를 불러오지 못했어요',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: AppSpacing.md),
              // A failed roster with no way to retry leaves the trainer
              // with a dead page — re-subscribing is one tap.
              TextButton(
                onPressed: () => ref.invalidate(clientsProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
      data: (all) {
        final list = applyClientFilter(all, activeFilter, unread: unread);
        // An id that isn't on the roster (deleted client, stale link) is
        // NOT collapsed away: the detail view says "고객을 찾을 수 없어요"
        // instead. Silently showing the roster while the URL still names
        // a client reads as data loss.
        final selected = selectedId;

        return _Frame(
          subtitle: '${all.length}명 · 활성 ${all.where((c) => c.active).length}명',
          actions: <Widget>[
            if (canManageRoster)
              ActionButton(
                label: '신규 고객',
                icon: Icons.person_add_alt,
                primary: true,
                onPressed: () => _openAddClientSheet(context),
              ),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AppLayout.splitBreakpoint;

              final listView = _RosterList(
                clients: list,
                unread: unread,
                selectedId: selected,
                filter: activeFilter,
                totalCount: all.length,
                onOpen: (id) =>
                    context.go(AppRoutes.clientDetail(id, section: section)),
                onClearFilter: () => context.go(AppRoutes.clients),
              );

              if (!wide) {
                // Narrow: the detail replaces the list entirely — a
                // 340px column plus a panel would leave neither usable.
                if (selected == null) return listView;
                return ClientDetailView(
                  clientId: selected,
                  section: section,
                  showBack: true,
                  onSectionChange: (next) => context.go(
                    AppRoutes.clientDetail(selected, section: next),
                  ),
                  onClose: () => context.go(AppRoutes.clients),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(width: AppLayout.splitListWidth, child: listView),
                  const VerticalDivider(
                    width: 1,
                    color: AppColors.borderStrong,
                  ),
                  Expanded(
                    child: selected == null
                        ? const _NoSelection()
                        : ClientDetailView(
                            clientId: selected,
                            section: section,
                            showBack: false,
                            onSectionChange: (next) => context.go(
                              AppRoutes.clientDetail(selected, section: next),
                            ),
                            onClose: () => context.go(AppRoutes.clients),
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Shared page chrome so the loading/error/data states keep the same
/// header instead of the title flickering in after the stream resolves.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.subtitle,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '고객',
      subtitle: subtitle,
      actions: actions,
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      child: child,
    );
  }
}

/// Placeholder shown in the split panel before a client is picked.
class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.person_search_outlined,
            size: 34,
            color: AppColors.disabledForeground,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '왼쪽에서 고객을 선택하면\n대화·식단·운동 기록이 여기에 열려요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: AppColors.subtleForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.clients,
    required this.unread,
    required this.selectedId,
    required this.filter,
    required this.totalCount,
    required this.onOpen,
    required this.onClearFilter,
  });

  final List<TrainerClient> clients;
  final Map<String, int> unread;
  final String? selectedId;
  final ClientFilter filter;
  final int totalCount;
  final ValueChanged<String> onOpen;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        if (filter != ClientFilter.all) ...<Widget>[
          _FilterBanner(
            filter: filter,
            shown: clients.length,
            total: totalCount,
            onClear: onClearFilter,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (clients.isEmpty)
          EmptyHint(
            message: filter == ClientFilter.all
                ? '아직 담당 고객이 없어요'
                : '${filter.label}에 해당하는 고객이 없어요',
            icon: Icons.people_outline,
          )
        else
          for (final client in clients) ...<Widget>[
            ClientCard(
              client: client,
              selected: client.id == selectedId,
              unread: unread[client.id] ?? 0,
              onTap: () => onOpen(client.id),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

/// Tells the trainer the list is filtered — and how to get out. A
/// silently filtered roster reads as "I've lost clients".
class _FilterBanner extends StatelessWidget {
  const _FilterBanner({
    required this.filter,
    required this.shown,
    required this.total,
    required this.onClear,
  });

  final ClientFilter filter;
  final int shown;
  final int total;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.filter_alt_outlined,
            size: 15,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${filter.label} · $shown/$total명',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: const BorderRadius.all(AppRadius.sm),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '전체 보기',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
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
