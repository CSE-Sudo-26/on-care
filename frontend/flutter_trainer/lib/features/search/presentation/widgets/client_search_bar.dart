import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/search/domain/client_search.dart';
import 'package:oncare_trainer/features/search/domain/client_search_facts.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';

/// Width cap that keeps the full search scope readable without letting the
/// field compete with the page title.
const double _fieldMaxWidth = 520;

/// Narrowest space the inline field is worth rendering in.
///
/// Measured against what the header's title and actions leave over, not
/// against the viewport: a page with four actions runs out of room long
/// before a page with one does.
const double _minInlineWidth = 400;

/// Height cap of the results card (≈ five rows plus the footer).
const double _dropdownMaxHeight = 360;

/// Key of the search input, so a test can type into it without guessing
/// which of the page's fields it is.
const ValueKey<String> clientSearchFieldKey = ValueKey<String>(
  'client-search-field',
);

/// Key of the results card. Names appear in the roster behind it too, so
/// asserting on a dropdown row means scoping to this.
const ValueKey<String> clientSearchResultsKey = ValueKey<String>(
  'client-search-results',
);

/// Key of the collapsed form's button.
const ValueKey<String> clientSearchIconKey = ValueKey<String>(
  'client-search-icon',
);

/// Key of one result row's cross-tab destination menu.
ValueKey<String> clientSearchQuickActionsKey(String clientId) =>
    ValueKey<String>('client-search-quick-actions-$clientId');

/// Key of a destination inside a result row's cross-tab menu.
ValueKey<String> clientSearchDestinationKey(
  String clientId,
  String destination,
) => ValueKey<String>('client-search-destination-$clientId-$destination');

/// What a pick resolved to: the client and the route to open.
typedef _Pick = ({TrainerClient client, String route});

enum _SearchDestination { clients, schedule, messages, coaching, reports }

String? _destinationRoute(
  _SearchDestination destination,
  TrainerClient client,
  ClientSearchFacts facts,
) => switch (destination) {
  _SearchDestination.clients => AppRoutes.clientDetail(client.id),
  _SearchDestination.schedule => switch (facts.nextSession[client.id]) {
    final next? => AppRoutes.scheduleAt(date: next.date),
    null => null,
  },
  _SearchDestination.messages => AppRoutes.messagesFor(client.id),
  _SearchDestination.coaching => AppRoutes.coachingFor(client.id),
  _SearchDestination.reports => AppRoutes.reportFor(client.id),
};

/// The shared facts behind [results], read from the streams the rest of the
/// console already uses.
///
/// The same fact set powers the unified result summary and every destination.
/// It subscribes to nothing until a query has matches, so an idle header keeps
/// no search-only streams open.
ClientSearchFacts watchClientSearchFacts(
  WidgetRef ref,
  List<TrainerClient> results,
) {
  if (results.isEmpty) return ClientSearchFacts.none;
  final unread =
      ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};
  final today = nowKst();
  final range = (
    from: ymd(today),
    to: ymd(today.add(const Duration(days: clientSearchUpcomingDays - 1))),
  );
  final sessions =
      ref.watch(scheduleRangeProvider(range)).valueOrNull ??
      const <ScheduleSession>[];
  return ClientSearchFacts(
    unread: unread,
    nextSession: nextSessionsByClient(results, sessions),
  );
}

/// 고객 검색 — the console header's client picker.
///
/// Sits in the middle of every main tab's header and always searches the same
/// roster and related records. A direct pick opens the customer inside the
/// current tab; explicit actions can still cross to another tab.
///
/// Two forms: the inline field with a dropdown, and an icon opening the
/// same search in a dialog. The icon is used when the shell is in its
/// drawer form, or when the header's own actions leave no room.
class ClientSearchBar extends ConsumerStatefulWidget {
  /// Creates the unified search bar.
  const ClientSearchBar({super.key});

  @override
  ConsumerState<ClientSearchBar> createState() => _ClientSearchBarState();
}

class _ClientSearchBarState extends ConsumerState<ClientSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final OverlayPortalController _dropdown = OverlayPortalController();
  final LayerLink _link = LayerLink();

  /// Matches for the current query, recomputed on each keystroke rather
  /// than on every rebuild — the roster is a live stream, and a header
  /// that reshuffled its dropdown under the trainer's finger would be
  /// worse than one that is a keystroke stale.
  List<TrainerClient> _results = const <TrainerClient>[];
  String _query = '';

  /// Row the keyboard is on (↑/↓ move it, Enter opens it).
  int _highlight = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _hasQuery => _query.trim().isNotEmpty;

  void _onQueryChanged(String value) {
    final clients =
        ref.read(clientsProvider).valueOrNull ?? const <TrainerClient>[];
    setState(() {
      _query = value;
      _results = searchClients(clients, value);
      _highlight = 0;
    });
    if (_hasQuery) {
      _dropdown.show();
    } else {
      _dropdown.hide();
    }
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(
      () => _highlight = (_highlight + delta).clamp(0, _results.length - 1),
    );
  }

  /// Closes the dropdown, optionally emptying the field. Kept after a
  /// pick: the query the trainer typed has been answered, and leaving it
  /// there means the next search starts by clearing someone's name.
  void _close({bool clear = false}) {
    _dropdown.hide();
    if (clear) {
      _controller.clear();
      _focus.unfocus();
      setState(() {
        _query = '';
        _results = const <TrainerClient>[];
        _highlight = 0;
      });
    }
  }

  void _submit(ClientSearchFacts facts) {
    if (_results.isEmpty) return;
    final index = _highlight.clamp(0, _results.length - 1);
    _pick(_results[index], facts);
  }

  void _pick(TrainerClient client, ClientSearchFacts facts) {
    _close(clear: true);
    _apply((
      client: client,
      route: clientSearchDestination(
        GoRouterState.of(context).uri,
        client,
        facts,
      ),
    ));
  }

  void _apply(_Pick pick) {
    context.go(pick.route);
  }

  void _openDestination(TrainerClient client, String route) {
    _close(clear: true);
    _apply((client: client, route: route));
  }

  Future<void> _openDialog() async {
    final location = GoRouterState.of(context).uri;
    final pick = await showDialog<_Pick>(
      context: context,
      builder: (_) => _ClientSearchDialog(location: location),
    );
    if (pick == null || !mounted) return;
    _apply(pick);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final facts = watchClientSearchFacts(ref, _results);

    // Below the shell's drawer breakpoint the console is in its
    // phone/tablet-portrait form — a 52px app bar over a page header that
    // already carries the title and every action. An inline field there
    // would squeeze both, so the icon + dialog is the only form.
    final compactShell =
        MediaQuery.sizeOf(context).width < AppLayout.sidebarDrawerBreakpoint;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (compactShell || constraints.maxWidth < _minInlineWidth) {
          // Right-aligned so it reads as one group with the header's
          // actions rather than floating in the gap.
          return Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: clientSearchIconKey,
              onPressed: _openDialog,
              tooltip: l.searchClients,
              icon: const Icon(Icons.search, size: 20),
              color: AppColors.mutedForeground,
            ),
          );
        }

        final width = math.min(_fieldMaxWidth, constraints.maxWidth);
        return Center(
          child: SizedBox(
            width: width,
            child: CompositedTransformTarget(
              link: _link,
              child: OverlayPortal(
                controller: _dropdown,
                overlayChildBuilder: (context) => _overlay(width, facts),
                child: TapRegion(
                  groupId: this,
                  onTapOutside: (_) => _close(),
                  child: _field(l, facts, width),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 긴 검색 범위 안내가 들어갈 만한 폭. 이보다 좁으면 짧은 안내로 바꾼다 —
  /// 줄임표로 끝이 잘리면(`…마지막 루틴 전송…`) 무엇까지 찾아 주는지가 사라진다.
  /// 글씨를 키운 뒤 1280 폭에서 실제로 그렇게 됐다. (#1004)
  static const double _longHintMinWidth = 460;

  Widget _field(AppLocalizations l, ClientSearchFacts facts, double width) {
    final String hint = width >= _longHintMinWidth
        ? l.searchClientsHint
        : l.searchClients;
    return CallbackShortcuts(
      // The same keys the dropdown implies: ↑/↓ walk the rows, Esc backs
      // out. Enter is the field's own submit.
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: TextField(
        key: clientSearchFieldKey,
        controller: _controller,
        focusNode: _focus,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.foreground,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.card,
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.subtleForeground,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.subtleForeground,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: _hasQuery
              ? IconButton(
                  // The controller has to be emptied too — clearing only
                  // the state would leave the typed name on screen with
                  // the search behind it already reset.
                  onPressed: () {
                    _controller.clear();
                    _onQueryChanged('');
                  },
                  tooltip: l.searchClear,
                  iconSize: 18,
                  splashRadius: 18,
                  color: AppColors.subtleForeground,
                  icon: const Icon(Icons.close),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 40),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          border: _inlineFieldBorder,
          enabledBorder: _inlineFieldBorder,
          focusedBorder: _inlineFieldFocusedBorder,
        ),
        onChanged: _onQueryChanged,
        onSubmitted: (_) => _submit(facts),
        onTap: () {
          if (_hasQuery) _dropdown.show();
        },
      ),
    );
  }

  Widget _overlay(double width, ClientSearchFacts facts) {
    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, AppSpacing.xs),
      child: Align(
        alignment: Alignment.topLeft,
        child: TapRegion(
          groupId: this,
          child: _ResultsCard(
            width: width,
            query: _query,
            results: _results,
            facts: facts,
            highlighted: _highlight,
            footer: clientSearchFooter(
              AppLocalizations.of(context),
              GoRouterState.of(context).uri,
            ),
            onPick: (client) => _pick(client, facts),
            onOpenDestination: _openDestination,
          ),
        ),
      ),
    );
  }
}

/// Pill field with no visible border — used in the dialog form, where the
/// field floats on the dimmed backdrop and needs nothing to stand out.
const OutlineInputBorder _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(AppRadius.pill),
  borderSide: BorderSide.none,
);

/// The inline form's border. The header canvas is [AppColors.background]
/// (`#F5F7FA`) and the input fill used to be [AppColors.inputBackground]
/// (`#F2F4F7`) — two greys three steps apart, so the field read as a hint of
/// a shape rather than a place to type. White fill plus a hairline is what
/// separates it now.
const OutlineInputBorder _inlineFieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(AppRadius.pill),
  borderSide: BorderSide(color: AppColors.borderStrong),
);

/// Focus state of the inline field — the brand navy, as elsewhere.
const OutlineInputBorder _inlineFieldFocusedBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(AppRadius.pill),
  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
);

/// The dropdown (and the dialog's body): matches, or why there are none,
/// plus the footer that explains the consistent default destination.
class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.width,
    required this.query,
    required this.results,
    required this.facts,
    required this.highlighted,
    required this.footer,
    required this.onPick,
    required this.onOpenDestination,
  });

  final double width;
  final String query;
  final List<TrainerClient> results;
  final ClientSearchFacts facts;
  final int highlighted;
  final String footer;
  final ValueChanged<TrainerClient> onPick;
  final void Function(TrainerClient client, String route) onOpenDestination;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: clientSearchResultsKey,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: Text(
                l.searchNoResults(query.trim()),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
            )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: _dropdownMaxHeight,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, i) => _ResultRow(
                    client: results[i],
                    detail: clientSearchDetail(l, results[i], facts),
                    routes: <_SearchDestination, String?>{
                      for (final destination in _SearchDestination.values)
                        destination: _destinationRoute(
                          destination,
                          results[i],
                          facts,
                        ),
                    },
                    highlighted: i == highlighted,
                    onTap: () => onPick(results[i]),
                    onOpenDestination: (route) =>
                        onOpenDestination(results[i], route),
                  ),
                ),
              ),
            ),
          _Footer(text: footer),
        ],
      ),
    );
  }
}

class _ResultRow extends StatefulWidget {
  const _ResultRow({
    required this.client,
    required this.detail,
    required this.routes,
    required this.highlighted,
    required this.onTap,
    required this.onOpenDestination,
  });

  final TrainerClient client;
  final String detail;
  final Map<_SearchDestination, String?> routes;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<String> onOpenDestination;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _showDestinations = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.highlighted ? AppColors.accentSurface : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      top: AppSpacing.md,
                      bottom: AppSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        ClientAvatar(label: widget.client.avatar, size: 36),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              ClientIdentity(
                                client: widget.client,
                                nameStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                widget.detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.subtleForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Semantics(
                label: AppLocalizations.of(context).searchQuickActions,
                button: true,
                child: IconButton(
                  key: clientSearchQuickActionsKey(widget.client.id),
                  onPressed: () =>
                      setState(() => _showDestinations = !_showDestinations),
                  icon: Icon(
                    _showDestinations ? Icons.expand_less : Icons.more_horiz,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          if (_showDestinations) _destinations(context),
        ],
      ),
    );
  }

  Widget _destinations(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          for (final destination in _SearchDestination.values)
            _destinationButton(context, destination),
        ],
      ),
    );
  }

  Widget _destinationButton(
    BuildContext context,
    _SearchDestination destination,
  ) {
    final l = AppLocalizations.of(context);
    final route = widget.routes[destination];
    final (label, icon, keyName) = switch (destination) {
      _SearchDestination.clients => (
        l.navClients,
        Icons.people_outline,
        'clients',
      ),
      _SearchDestination.schedule => (
        l.navSchedule,
        Icons.calendar_today_outlined,
        'schedule',
      ),
      _SearchDestination.messages => (
        l.navMessages,
        Icons.chat_bubble_outline,
        'messages',
      ),
      _SearchDestination.coaching => (
        l.navCoaching,
        Icons.auto_awesome_outlined,
        'coaching',
      ),
      _SearchDestination.reports => (
        l.navReports,
        Icons.assessment_outlined,
        'reports',
      ),
    };
    return Semantics(
      label: route == null ? '$label · ${l.searchDetailNoUpcoming}' : label,
      button: true,
      enabled: route != null,
      child: OutlinedButton.icon(
        key: clientSearchDestinationKey(widget.client.id, keyName),
        onPressed: route == null ? null : () => widget.onOpenDestination(route),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        icon: Icon(icon, size: 17),
        label: Text(label),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.subdirectory_arrow_left,
            size: 15,
            color: AppColors.subtleForeground,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.subtleForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The compact form: the same search as a top-anchored dialog.
///
/// Pops with the resolved [_Pick] instead of navigating itself — the
/// caller owns the page context, so the snackbar and the `go` both land
/// on the console rather than on a route that is being dismissed.
class _ClientSearchDialog extends ConsumerStatefulWidget {
  const _ClientSearchDialog({required this.location});

  final Uri location;

  @override
  ConsumerState<_ClientSearchDialog> createState() =>
      _ClientSearchDialogState();
}

class _ClientSearchDialogState extends ConsumerState<_ClientSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  List<TrainerClient> _results = const <TrainerClient>[];
  String _query = '';
  int _highlight = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final clients =
        ref.read(clientsProvider).valueOrNull ?? const <TrainerClient>[];
    setState(() {
      _query = value;
      _results = searchClients(clients, value);
      _highlight = 0;
    });
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(
      () => _highlight = (_highlight + delta).clamp(0, _results.length - 1),
    );
  }

  void _submit(ClientSearchFacts facts) {
    if (_results.isEmpty) return;
    final index = _highlight.clamp(0, _results.length - 1);
    _pop(_results[index], facts);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final facts = watchClientSearchFacts(ref, _results);
    final width = math.min(
      _fieldMaxWidth + AppSpacing.xl,
      MediaQuery.sizeOf(context).width - AppSpacing.xxl,
    );

    return Dialog(
      alignment: Alignment.topCenter,
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.only(
        top: AppSpacing.xxl,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Material(
              color: AppColors.card,
              borderRadius: const BorderRadius.all(AppRadius.pill),
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _move(1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _move(-1),
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      Navigator.of(context).pop(),
                },
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.card,
                    hintText: l.searchClientsHint,
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.subtleForeground,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.subtleForeground,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 40),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    border: _fieldBorder,
                    enabledBorder: _fieldBorder,
                    focusedBorder: _fieldBorder,
                  ),
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) => _submit(facts),
                ),
              ),
            ),
            if (_query.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _ResultsCard(
                width: width,
                query: _query,
                results: _results,
                facts: facts,
                highlighted: _highlight,
                footer: clientSearchFooter(l, widget.location),
                onPick: (client) => _pop(client, facts),
                onOpenDestination: (client, route) => _popRoute(client, route),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pop(TrainerClient client, ClientSearchFacts facts) {
    _popRoute(client, clientSearchDestination(widget.location, client, facts));
  }

  void _popRoute(TrainerClient client, String route) {
    Navigator.of(context).pop<_Pick>((client: client, route: route));
  }
}
