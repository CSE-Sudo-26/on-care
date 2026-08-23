import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_invite_repository.dart';
import 'package:oncare_trainer/features/clients/domain/client_filter.dart';
import 'package:oncare_trainer/features/clients/domain/repositories/client_data_refresher.dart';
import 'package:oncare_trainer/features/clients/presentation/controllers/roster_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_detail_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_invite_sheet.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
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
class ClientsPage extends ConsumerStatefulWidget {
  /// Creates the roster page. [selectedId]/[section] come from the path,
  /// [filter] from the `f` query parameter.
  const ClientsPage({super.key, this.selectedId, this.section, this.filter});

  /// Client whose detail is open, or null for the plain list.
  final String? selectedId;

  /// Which detail sub-tab is open (see [AppRoutes.clientSections]).
  final String? section;

  /// Roster filter from the URL.
  final String? filter;

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  void _clearFilters() {
    ref.read(rosterViewProvider.notifier).state = const RosterView();
    context.go(AppRoutes.clients);
  }

  Future<void> _openAddClientSheet(BuildContext context) =>
      _openSheet(context, const _AddClientSheet());

  /// 실 API 에서 고객이 생기는 길 — 회원에게 담당 요청을 보낸다. (#919)
  ///
  /// 데모의 '신규 고객 등록' 과 버튼은 같은 자리지만 하는 일이 다르다. 데모는
  /// 로컬 명단에 바로 넣고, 실 API 는 회원의 수락을 기다린다 — 담당 관계는
  /// 상대의 기록을 여는 권한이라 트레이너 혼자 만들 수 없다.
  Future<void> _openInviteSheet(BuildContext context) =>
      _openSheet(context, const ClientInviteSheet());

  Future<void> _openSheet(BuildContext context, Widget sheet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.card),
      ),
      builder: (context) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 정렬·관리 필터는 이 화면이 아니라 provider 가 들고 있다 — 목록과 상세가
    // 서로 다른 라우트라, 지역 상태로 두면 고객을 여는 순간 초기화된다(#816).
    final view = ref.watch(rosterViewProvider);
    // Priority ordering: sodium-over clients first, then recent chat.
    final clientsAsync = ref.watch(prioritizedClientsProvider);
    final unread =
        ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};
    final lastChatAt =
        ref.watch(lastChatAtProvider).valueOrNull ?? const <String, DateTime>{};
    // Roster mutations exist only in demo/mock mode — the real backend has
    // no add-client endpoint (the roster is derived from trainer↔member
    // links), so hide the 신규 고객 등록 entry when hitting the real API.
    final canManageRoster = ref
        .watch(clientRepositoryProvider)
        .supportsRosterMutations;
    // 실 API 에는 명단에 직접 넣는 경로가 없는 대신 담당 요청이 있다. 둘 다
    // 없는 빌드에서는 진입점 자체를 그리지 않는다. (#919)
    final canInvite = ref.watch(clientInvitesEnabledProvider);
    final activeFilter = clientFilterFrom(widget.filter);

    final Widget page = clientsAsync.when(
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
              Text(
                l.clientsLoadFailed,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: AppSpacing.md),
              // A failed roster with no way to retry leaves the trainer
              // with a dead page — re-subscribing is one tap.
              TextButton(
                onPressed: () => ref.invalidate(clientsProvider),
                child: Text(l.actionRetry),
              ),
            ],
          ),
        ),
      ),
      data: (all) {
        final AppLocalizations l = AppLocalizations.of(context);
        var list = applyClientFilter(all, activeFilter, unread: unread);
        list = list
            .where(
              (client) => _matchesManagementFilters(
                client,
                view.filters,
                unread: unread,
              ),
            )
            .toList(growable: false);
        list = _sortRoster(
          list,
          view.sort,
          lastChatAt: lastChatAt,
          unread: unread,
        );
        // An id that isn't on the roster (deleted client, stale link) is
        // NOT collapsed away: the detail view says "고객을 찾을 수 없어요"
        // instead. Silently showing the roster while the URL still names
        // a client reads as data loss.
        final selected = widget.selectedId;

        return _Frame(
          subtitle: l.clientsCountSummary(
            all.length,
            all.where((c) => c.active).length,
          ),
          actions: <Widget>[
            if (canManageRoster || canInvite)
              ActionButton(
                label: l.clientsNew,
                icon: Icons.person_add_alt,
                primary: true,
                onPressed: () => canManageRoster
                    ? _openAddClientSheet(context)
                    : _openInviteSheet(context),
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
                trailingPadding: wide ? AppSpacing.sm : 0,
                onOpen: (id) => context.go(
                  AppRoutes.clientDetail(
                    id,
                    section: widget.section,
                    filter: widget.filter,
                  ),
                ),
                onClearFilter: _clearFilters,
              );
              final Widget body;
              if (!wide && selected != null) {
                body = ClientDetailView(
                  clientId: selected,
                  section: widget.section,
                  onSectionChange: (next) => context.go(
                    AppRoutes.clientDetail(
                      selected,
                      section: next,
                      filter: widget.filter,
                    ),
                  ),
                  onClose: () => context.go(AppRoutes.clients),
                );
              } else if (!wide) {
                body = listView;
              } else {
                body = Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(width: AppLayout.splitListWidth, child: listView),
                    const SizedBox(
                      key: ValueKey<String>('clients-master-detail-gap'),
                      width: AppSpacing.sm,
                    ),
                    Expanded(
                      child: selected == null
                          ? const _NoSelection()
                          : ClientDetailView(
                              clientId: selected,
                              section: widget.section,
                              showBack: false,
                              onSectionChange: (next) => context.go(
                                AppRoutes.clientDetail(
                                  selected,
                                  section: next,
                                  filter: widget.filter,
                                ),
                              ),
                              onClose: () => context.go(AppRoutes.clients),
                            ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (wide || selected == null)
                    _MemberManagementToolbar(
                      managementFilters: view.filters,
                      sort: view.sort,
                      onFiltersChanged: (value) =>
                          ref.read(rosterViewProvider.notifier).state = view
                              .copyWith(filters: value),
                      onSortChanged: (value) =>
                          ref.read(rosterViewProvider.notifier).state = view
                              .copyWith(sort: value),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppLayout.pagePadding,
                        AppSpacing.md,
                        AppLayout.pagePadding,
                        0,
                      ),
                      child: body,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    return _RefreshOnBranchResume(
      onResume: () {
        final ClientRepository repository = ref.read(clientRepositoryProvider);
        if (repository case final ClientDataRefresher refresher) {
          refresher.refreshAllClientData();
        }
      },
      child: page,
    );
  }
}

/// The client this row would need to match for [filter] to select it —
/// shared by the toolbar's filtering and its "n개 선택" chip labels so the
/// two can never disagree about what a filter means.
bool _matchesManagementFilter(
  TrainerClient client,
  RosterManagementFilter filter, {
  required Map<String, int> unread,
}) {
  final alerts = alertsFor(client, unread: unread[client.id] ?? 0);
  switch (filter) {
    case RosterManagementFilter.attention:
      return alerts.isNotEmpty;
    case RosterManagementFilter.active:
      return client.active;
    case RosterManagementFilter.dormant:
      return !client.active;
    case RosterManagementFilter.sodiumOver:
      return alerts.contains(ClientAlert.sodiumOver);
    case RosterManagementFilter.sugarOver:
      return alerts.contains(ClientAlert.sugarOver);
    case RosterManagementFilter.lowCompletion:
      return alerts.contains(ClientAlert.lowCompletion);
    case RosterManagementFilter.unanswered:
      return alerts.contains(ClientAlert.unanswered);
  }
}

/// A client passes an empty selection (전체 보기) or any one of the chosen
/// filters — OR, not AND: `active`+`dormant` selected together reads as
/// "show me both states", which only OR can produce.
bool _matchesManagementFilters(
  TrainerClient client,
  Set<RosterManagementFilter> filters, {
  required Map<String, int> unread,
}) {
  if (filters.isEmpty) return true;
  return filters.any(
    (filter) => _matchesManagementFilter(client, filter, unread: unread),
  );
}

/// Applies only sorts whose keys are present in the roster contract.
///
/// Management priority first groups clients with real health/unread alerts,
/// preserving the incoming sodium/chat priority within each group. For recent
/// messages, local demo data supplies the grouped chat timestamp through
/// [lastChatAt], while API rows carry [TrainerClient.lastMessageAt]. Decorating
/// with the original index makes equal/missing keys stable.
List<TrainerClient> _sortRoster(
  List<TrainerClient> clients,
  RosterSort sort, {
  required Map<String, DateTime> lastChatAt,
  required Map<String, int> unread,
}) {
  final decorated = <(TrainerClient client, int index)>[
    for (var i = 0; i < clients.length; i++) (clients[i], i),
  ];
  final epoch = DateTime.utc(1970);
  decorated.sort((a, b) {
    final int result;
    switch (sort) {
      case RosterSort.priority:
        final aNeedsAttention = alertsFor(
          a.$1,
          unread: unread[a.$1.id] ?? 0,
        ).isNotEmpty;
        final bNeedsAttention = alertsFor(
          b.$1,
          unread: unread[b.$1.id] ?? 0,
        ).isNotEmpty;
        result = (bNeedsAttention ? 1 : 0).compareTo(aNeedsAttention ? 1 : 0);
      case RosterSort.nameAscending:
        result = a.$1.name.compareTo(b.$1.name);
      case RosterSort.nameDescending:
        result = b.$1.name.compareTo(a.$1.name);
      case RosterSort.recentMessage:
        final aAt = lastChatAt[a.$1.id] ?? a.$1.lastMessageAt ?? epoch;
        final bAt = lastChatAt[b.$1.id] ?? b.$1.lastMessageAt ?? epoch;
        result = bAt.compareTo(aAt);
      case RosterSort.activeFirst:
        result = (b.$1.active ? 1 : 0).compareTo(a.$1.active ? 1 : 0);
    }
    return result != 0 ? result : a.$2.compareTo(b.$2);
  });
  return <TrainerClient>[for (final item in decorated) item.$1];
}

class _MemberManagementToolbar extends StatelessWidget {
  const _MemberManagementToolbar({
    required this.managementFilters,
    required this.sort,
    required this.onFiltersChanged,
    required this.onSortChanged,
  });

  final Set<RosterManagementFilter> managementFilters;
  final RosterSort sort;
  final ValueChanged<Set<RosterManagementFilter>> onFiltersChanged;
  final ValueChanged<RosterSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        AppSpacing.sm,
        AppLayout.pagePadding,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _FilterMenuButton(
            filters: managementFilters,
            labelFor: (value) => _managementLabel(l, value),
            onChanged: onFiltersChanged,
          ),
          _SortMenuButton<RosterSort>(
            key: const ValueKey<String>('clients-sort-button'),
            value: sort,
            label: '${l.clientsSortLabel}: ${_sortLabel(l, sort)}',
            items: RosterSort.values,
            itemLabel: (value) => _sortLabel(l, value),
            onSelected: onSortChanged,
          ),
        ],
      ),
    );
  }

  String _managementLabel(AppLocalizations l, RosterManagementFilter value) {
    switch (value) {
      case RosterManagementFilter.attention:
        return l.clientsManagementAttention;
      case RosterManagementFilter.active:
        return l.clientActive;
      case RosterManagementFilter.dormant:
        return l.clientDormant;
      case RosterManagementFilter.sodiumOver:
        return l.alertSodiumOver;
      case RosterManagementFilter.sugarOver:
        return l.alertSugarOver;
      case RosterManagementFilter.lowCompletion:
        return l.alertLowCompletion;
      case RosterManagementFilter.unanswered:
        return l.alertAwaitingReply;
    }
  }

  String _sortLabel(AppLocalizations l, RosterSort value) {
    switch (value) {
      case RosterSort.priority:
        return l.clientsSortPriority;
      case RosterSort.nameAscending:
        return l.clientsSortName;
      case RosterSort.nameDescending:
        return l.clientsSortNameDescending;
      case RosterSort.recentMessage:
        return l.clientsSortRecentMessage;
      case RosterSort.activeFirst:
        return l.clientsSortActiveFirst;
    }
  }
}

class _FilterMenuButton extends StatelessWidget {
  const _FilterMenuButton({
    required this.filters,
    required this.labelFor,
    required this.onChanged,
  });

  final Set<RosterManagementFilter> filters;
  final String Function(RosterManagementFilter value) labelFor;
  final ValueChanged<Set<RosterManagementFilter>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selected = Set<RosterManagementFilter>.of(filters);
    return MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(AppColors.card),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(AppRadius.md),
            side: BorderSide(color: AppColors.borderStrong),
          ),
        ),
      ),
      menuChildren: <Widget>[
        StatefulBuilder(
          builder: (context, setMenuState) => SizedBox(
            width: 360,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        l.clientsFilterLabel,
                        style: const TextStyle(
                          color: AppColors.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (selected.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setMenuState(selected.clear);
                            onChanged(const <RosterManagementFilter>{});
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.mutedForeground,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(l.clientsFiltersClearAll),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final value in RosterManagementFilter.values)
                        _ManagementFilterChip(
                          key: ValueKey<String>(
                            'management-filter-${value.name}',
                          ),
                          label: labelFor(value),
                          selected: selected.contains(value),
                          onTap: () {
                            setMenuState(() {
                              if (!selected.remove(value)) {
                                selected.add(value);
                              }
                            });
                            onChanged(Set<RosterManagementFilter>.of(selected));
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => _PillToolbarButton(
        key: const ValueKey<String>('clients-filter-button'),
        label: filters.isEmpty
            ? l.clientsFilterLabel
            : '${l.clientsFilterLabel} ${filters.length}',
        expanded: controller.isOpen,
        onTap: controller.isOpen ? controller.close : controller.open,
      ),
    );
  }
}

/// One multi-select filter option, shown and removed as a chip/tag (#1026).
///
/// Selected chips stay in the same quiet navy/neutral family as unselected
/// chips, using border, fill and text color instead of a heavy button fill or
/// check icon. Toggling a chip therefore never shifts the surrounding options.
class _ManagementFilterChip extends StatelessWidget {
  const _ManagementFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        hoverColor: selected ? AppColors.bannerEnd : AppColors.accentSurface,
        focusColor: AppColors.bannerEnd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSurface : AppColors.card,
            borderRadius: const BorderRadius.all(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderStrong,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortMenuButton<T> extends StatelessWidget {
  const _SortMenuButton({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
  });

  final T value;
  final String label;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(AppColors.card),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(AppRadius.md),
            side: BorderSide(color: AppColors.borderStrong),
          ),
        ),
      ),
      menuChildren: <Widget>[
        for (final item in items)
          MenuItemButton(
            onPressed: () => onSelected(item),
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll<Size>(Size(220, 40)),
              padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              overlayColor: WidgetStatePropertyAll<Color>(
                AppColors.accentSurface,
              ),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 22,
                  child: item == value
                      ? const Icon(
                          Icons.check,
                          size: 15,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                Text(
                  itemLabel(item),
                  style: TextStyle(
                    color: item == value
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                    fontSize: 12.5,
                    fontWeight: item == value
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
      builder: (context, controller, child) => _PillToolbarButton(
        label: label,
        expanded: controller.isOpen,
        onTap: controller.isOpen ? controller.close : controller.open,
      ),
    );
  }
}

class _PillToolbarButton extends StatelessWidget {
  const _PillToolbarButton({
    super.key,
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        hoverColor: AppColors.accentSurface,
        focusColor: AppColors.bannerEnd,
        child: _PillToolbarSurface(
          label: label,
          active: expanded,
          trailing: Icon(
            expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            size: 18,
            color: AppColors.foreground,
          ),
        ),
      ),
    );
  }
}

class _PillToolbarSurface extends StatelessWidget {
  const _PillToolbarSurface({
    required this.label,
    required this.trailing,
    this.active = false,
  });

  final String label;
  final Widget trailing;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.accentSurface : AppColors.inputBackground,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          trailing,
        ],
      ),
    );
  }
}

/// The router keeps every primary branch mounted in an indexed stack. This
/// observes that stack's [TickerMode] so returning to the clients branch
/// revalidates server-backed data even though [ClientsPage] was not rebuilt
/// from scratch.
class _RefreshOnBranchResume extends StatefulWidget {
  const _RefreshOnBranchResume({required this.onResume, required this.child});

  final VoidCallback onResume;
  final Widget child;

  @override
  State<_RefreshOnBranchResume> createState() => _RefreshOnBranchResumeState();
}

class _RefreshOnBranchResumeState extends State<_RefreshOnBranchResume> {
  bool? _active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool active = TickerMode.valuesOf(context).enabled;
    if (active && _active == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onResume();
      });
    }
    _active = active;
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    final AppLocalizations l = AppLocalizations.of(context);
    return PageScaffold(
      title: l.clientsTitle,
      subtitle: subtitle,
      headerCenter: const ClientSearchBar(),
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
    final AppLocalizations l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.person_search_outlined,
            size: 34,
            color: AppColors.disabledForeground,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.clientsPickHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
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
    required this.trailingPadding,
    required this.onOpen,
    required this.onClearFilter,
  });

  final List<TrainerClient> clients;
  final Map<String, int> unread;
  final String? selectedId;
  final ClientFilter filter;
  final int totalCount;
  final double trailingPadding;
  final ValueChanged<String> onOpen;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        0,
        trailingPadding,
        AppLayout.pagePadding,
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
                ? l.clientsEmpty
                : l.clientsEmptyForFilter(filter.label(l)),
            icon: Icons.people_outline,
          )
        else
          for (final client in clients) ...<Widget>[
            ClientCard(
              key: ValueKey<String>('client-${client.id}'),
              client: client,
              selected: client.id == selectedId,
              unread: unread[client.id] ?? 0,
              compact: true,
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
    final AppLocalizations l = AppLocalizations.of(context);
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
              l.clientsFilterSummary(filter.label(l), shown, total),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: const BorderRadius.all(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                l.clientsSeeAll,
                style: const TextStyle(
                  fontSize: 12,
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
    // await 전에 잡아 둔다 — 뒤 실패 경로에서 context 를 다시 만지면 async gap
    // 을 건너 쓰게 된다(navigator 를 미리 잡아 두는 것과 같은 이유).
    final AppLocalizations l = AppLocalizations.of(context);
    if (name.isEmpty) {
      setState(() => _nameError = l.clientsNameRequired);
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
      if (mounted) setState(() => _nameError = l.clientsAddFailed);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (!added) {
      final AppLocalizations l = AppLocalizations.of(context);
      // Duplicate name — schedules resolve their client by name, so
      // allowing it would misattribute chat/운동기록 (review PR 243).
      setState(() => _nameError = l.clientsDuplicateName);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
          Text(
            l.clientsAddTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              hintText: l.clientsNameLabel,
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
            decoration: InputDecoration(
              hintText: l.clientsGoalLabel,
              hintStyle: const TextStyle(color: AppColors.subtleForeground),
              isDense: true,
              filled: true,
              fillColor: AppColors.inputBackground,
              contentPadding: const EdgeInsets.symmetric(
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
                child: Text(
                  l.clientsAddAction,
                  style: const TextStyle(
                    fontSize: 14,
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
