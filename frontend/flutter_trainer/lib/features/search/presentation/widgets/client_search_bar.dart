import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/search/domain/client_search.dart';
import 'package:oncare_trainer/features/search/domain/client_search_scope.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// Widest the inline field grows. Past this it stops looking like a
/// header control and starts competing with the page title.
const double _fieldMaxWidth = 360;

/// Narrowest space the inline field is worth rendering in.
///
/// Measured against what the header's title and actions leave over, not
/// against the viewport: a page with four actions runs out of room long
/// before a page with one does.
const double _minInlineWidth = 240;

/// Height cap of the results card (≈ five rows plus the footer).
const double _dropdownMaxHeight = 300;

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

/// What a pick resolved to: the client, and the route to open (null when
/// this tab has nothing for them).
typedef _Pick = ({TrainerClient client, String? route});

/// The tab-specific facts behind [results], read from the streams the
/// rest of the console already uses.
///
/// A plain function rather than a provider: it needs the current match
/// list, and it must subscribe to nothing until there is something to
/// describe — otherwise every 스케줄 page load would hold a four-week
/// range query open just in case someone searches.
ClientSearchFacts watchClientSearchFacts(
  WidgetRef ref,
  ClientSearchScope scope,
  List<TrainerClient> results,
) {
  if (results.isEmpty) return ClientSearchFacts.none;
  switch (scope) {
    case ClientSearchScope.dashboard:
    case ClientSearchScope.clients:
      return ClientSearchFacts(
        unread:
            ref.watch(unreadCountsProvider).valueOrNull ??
            const <String, int>{},
      );
    case ClientSearchScope.schedule:
      final today = DateTime.now();
      final range = (
        from: ymd(today),
        to: ymd(today.add(const Duration(days: clientSearchUpcomingDays - 1))),
      );
      final sessions =
          ref.watch(scheduleRangeProvider(range)).valueOrNull ??
          const <ScheduleSession>[];
      return ClientSearchFacts(
        nextSession: nextSessionsByClient(results, sessions),
      );
    case ClientSearchScope.coaching:
    case ClientSearchScope.reports:
      // Everything these rows show already lives on the roster row.
      return ClientSearchFacts.none;
  }
}

/// 고객 검색 — the console header's client picker.
///
/// Sits in the middle of every main tab's header and always searches the
/// same roster, but the rows and the destination follow [scope]: on
/// 스케줄 it shows the next booking and jumps to that day, on 리포트 the
/// week's completion and opens the report, and so on
/// ([clientSearchDetail] / [clientSearchDestination]).
///
/// Two forms: the inline field with a dropdown, and an icon opening the
/// same search in a dialog. The icon is used when the shell is in its
/// drawer form, or when the header's own actions leave no room.
class ClientSearchBar extends ConsumerStatefulWidget {
  /// Creates the search bar for [scope].
  const ClientSearchBar({super.key, required this.scope, this.clientSection});

  /// Which tab this bar is on — decides the rows and the destination.
  final ClientSearchScope scope;

  /// The 고객 sub-tab currently open (`diet` | `workout` | `chat`), so a
  /// pick from the 고객 tab stays on the section the trainer was reading.
  /// Ignored by every other scope.
  final String? clientSection;

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
        widget.scope,
        client,
        facts,
        clientSection: widget.clientSection,
      ),
    ));
  }

  /// Navigates, or explains why it can't. A row that silently does
  /// nothing reads as a broken search.
  void _apply(_Pick pick) {
    final route = pick.route;
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).searchNoUpcomingFor(pick.client.name),
          ),
        ),
      );
      return;
    }
    context.go(route);
  }

  Future<void> _openDialog() async {
    final pick = await showDialog<_Pick>(
      context: context,
      builder: (_) => _ClientSearchDialog(
        scope: widget.scope,
        clientSection: widget.clientSection,
      ),
    );
    if (pick == null || !mounted) return;
    _apply(pick);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final facts = watchClientSearchFacts(ref, widget.scope, _results);

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
                  child: _field(l, facts),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _field(AppLocalizations l, ClientSearchFacts facts) {
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
        style: const TextStyle(fontSize: 13, color: AppColors.foreground),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.inputBackground,
          hintText: l.searchClientsHint,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.subtleForeground,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.subtleForeground,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
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
                  iconSize: 16,
                  splashRadius: 16,
                  color: AppColors.subtleForeground,
                  icon: const Icon(Icons.close),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 36),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          border: _fieldBorder,
          enabledBorder: _fieldBorder,
          focusedBorder: _fieldBorder,
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
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, AppSpacing.xs),
      child: Align(
        alignment: Alignment.topLeft,
        child: TapRegion(
          groupId: this,
          child: _ResultsCard(
            width: width,
            scope: widget.scope,
            query: _query,
            results: _results,
            facts: facts,
            highlighted: _highlight,
            onPick: (client) => _pick(client, facts),
          ),
        ),
      ),
    );
  }
}

/// Pill field with no visible border — the fill alone separates it from
/// the header canvas, the way the roster's inputs do.
const OutlineInputBorder _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(AppRadius.pill),
  borderSide: BorderSide.none,
);

/// The dropdown (and the dialog's body): matches, or why there are none,
/// plus the footer that says what picking one does on this tab.
class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.width,
    required this.scope,
    required this.query,
    required this.results,
    required this.facts,
    required this.highlighted,
    required this.onPick,
  });

  final double width;
  final ClientSearchScope scope;
  final String query;
  final List<TrainerClient> results;
  final ClientSearchFacts facts;
  final int highlighted;
  final ValueChanged<TrainerClient> onPick;

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
                  fontSize: 12,
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
                    detail: clientSearchDetail(l, scope, results[i], facts),
                    highlighted: i == highlighted,
                    onTap: () => onPick(results[i]),
                  ),
                ),
              ),
            ),
          _Footer(text: clientSearchFooter(l, scope)),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.client,
    required this.detail,
    required this.highlighted,
    required this.onTap,
  });

  final TrainerClient client;
  final String detail;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.accentSurface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              ClientAvatar(label: client.avatar, size: 30),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      client.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      detail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
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
            size: 13,
            color: AppColors.subtleForeground,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
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
  const _ClientSearchDialog({required this.scope, this.clientSection});

  final ClientSearchScope scope;
  final String? clientSection;

  @override
  ConsumerState<_ClientSearchDialog> createState() =>
      _ClientSearchDialogState();
}

class _ClientSearchDialogState extends ConsumerState<_ClientSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  List<TrainerClient> _results = const <TrainerClient>[];
  String _query = '';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final facts = watchClientSearchFacts(ref, widget.scope, _results);
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
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 13,
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
                    size: 18,
                    color: AppColors.subtleForeground,
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 36),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  border: _fieldBorder,
                  enabledBorder: _fieldBorder,
                  focusedBorder: _fieldBorder,
                ),
                onChanged: _onQueryChanged,
                onSubmitted: (_) {
                  if (_results.isNotEmpty) _pop(_results.first, facts);
                },
              ),
            ),
            if (_query.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _ResultsCard(
                width: width,
                scope: widget.scope,
                query: _query,
                results: _results,
                facts: facts,
                // Touch surface: no keyboard cursor to show.
                highlighted: -1,
                onPick: (client) => _pop(client, facts),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pop(TrainerClient client, ClientSearchFacts facts) {
    Navigator.of(context).pop<_Pick>((
      client: client,
      route: clientSearchDestination(
        widget.scope,
        client,
        facts,
        clientSection: widget.clientSection,
      ),
    ));
  }
}
