import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/ai_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_options.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';
import 'package:oncare_trainer/features/coaching/presentation/pages/ai_routine_options_flow.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_form_fields.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/metric_tile.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';

/// A trainer-added exercise (kept in-memory like the mock).
class _CustomExercise {
  const _CustomExercise({
    required this.name,
    required this.minutes,
    required this.type,
  });
  final String name;
  final int minutes;
  final String type;
}

/// AI 코칭 — the workspace where a client's data becomes a routine.
///
/// Pick a client, read the AI's take on their diet and its reasoning,
/// tweak names/minutes, drop suggestions, add your own exercises, then
/// send it two ways: as homework to the member's app, or as the program
/// attached to a PT session on the schedule.
///
/// This is a top-level destination rather than an action buried in the
/// client detail because it is the product's differentiator, and because
/// the trainer plans several clients in one sitting. Arriving from a
/// client (`?client=<id>`) preselects them.
class CoachingPage extends ConsumerStatefulWidget {
  /// Creates the AI coaching workspace.
  const CoachingPage({super.key, this.clientId});

  /// Client to preselect, from the `client` query parameter.
  final String? clientId;

  @override
  ConsumerState<CoachingPage> createState() => _CoachingPageState();
}

class _CoachingPageState extends ConsumerState<CoachingPage> {
  /// Selected client; null until clients load (defaults to the first).
  late String? _clientId = widget.clientId;
  final Map<String, int> _minuteEdits = <String, int>{};
  final Map<String, String> _nameEdits = <String, String>{};
  final Map<String, String> _typeEdits = <String, String>{};

  /// AI suggestions the trainer removed for this round (in-memory,
  /// like the other edits).
  final Set<String> _removed = <String>{};
  String? _editingNameId;
  final List<_CustomExercise> _custom = <_CustomExercise>[];
  final Map<String, List<AiRoutineItem>> _generatedRecommendations =
      <String, List<AiRoutineItem>>{};
  bool _showAddForm = false;
  bool _showOptionsFlow = false;
  bool _sent = false;
  Timer? _sentTimer;

  /// A homework send is in flight (blocks re-entry, disables the button).
  bool _sending = false;

  /// A schedule registration just succeeded (drives the 3s flash).
  bool _registered = false;
  // The client whose registration is in flight (null when none). Tracked
  // per-client — not a plain bool — so switching away and back can't let
  // the SAME client's registration be triggered twice while the first is
  // still saving (review PR 220).
  String? _registeringClientId;
  Timer? _registerTimer;

  /// Day offset (0 = 오늘 … 6) the routine gets registered on.
  int _registerOffset = 0;

  @override
  void dispose() {
    _sentTimer?.cancel();
    _registerTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(CoachingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Following a second "AI 루틴 만들기" link (from another client's
    // 개요) must switch the workspace, not silently keep the old one.
    if (widget.clientId != null && widget.clientId != oldWidget.clientId) {
      _selectClient(widget.clientId!);
    }
  }

  void _selectClient(String id) {
    if (_clientId == id) return;
    setState(() {
      _clientId = id;
      // A different client gets a clean slate, like the mock.
      _minuteEdits.clear();
      _nameEdits.clear();
      _typeEdits.clear();
      _removed.clear();
      _editingNameId = null;
      _custom.clear();
      _showAddForm = false;
      _showOptionsFlow = false;
      _sent = false;
      _sending = false;
      _registered = false;
      _registerOffset = 0;
      // NOTE: _registeringClientId is intentionally NOT cleared — a
      // registration in flight for another client keeps being tracked,
      // so returning to it still blocks a duplicate (review PR 220).
    });
    _sentTimer?.cancel();
    _registerTimer?.cancel();
  }

  Future<void> _send(TrainerClient client, List<AiRoutineItem> items) async {
    if (_sent || _sending) return;
    final program = _composeProgram(items);
    if (program.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    // messenger 와 같이 await 전에 잡아 둔다.
    final AppLocalizations l = AppLocalizations.of(context);
    final total = items
        .where((i) => !_removed.contains(i.id))
        .fold<int>(0, (sum, i) => sum + (_minuteEdits[i.id] ?? i.minutes));
    final custom = _custom.fold<int>(0, (sum, c) => sum + c.minutes);

    // Capture who this send is for: the trainer can switch clients while
    // it saves, and the 전송 완료 flash + edit-reset timer must land on
    // the starting client, not whoever is on screen when it resolves
    // (review PR 239).
    final sentFor = client.id;
    setState(() => _sending = true);
    try {
      // Assigning the routine IS the delivery — the member receives it via
      // /me/coach/routines (and, in demo mode, MockTrainerRoutineRepository
      // succeeds silently). No chat note is sent here: routine delivery is
      // shown in the member's routine feed, not as a chat bubble.
      await ref
          .read(trainerRoutineRepositoryProvider)
          .assignRoutine(client.id, _summaryRoutine(items, total + custom));
    } catch (e) {
      if (!mounted || !_isStillSelected(sentFor)) return;
      setState(() => _sending = false);
      // A network/timeout failure is AMBIGUOUS: the backend may already
      // have committed the assign before the client gave up waiting for a
      // response (POST /routines is not idempotent — every attempt inserts
      // a new row). Blindly telling the trainer to "다시 시도" risks a
      // duplicate routine landing on the member's app, so this case gets a
      // different message asking them to verify first (review; a real
      // fix needs a backend idempotency/dedup key — tracked separately).
      final ambiguousOutcome = e is NetworkError;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ambiguousOutcome
                ? l.coachSendNoResponse
                : l.coachSendFailed,
          ),
        ),
      );
      return;
    }
    if (!mounted || !_isStillSelected(sentFor)) return;
    setState(() {
      _sending = false;
      _sent = true;
    });
    _sentTimer?.cancel();
    // Mock: after the confirmation, reset the edits for the next round.
    _sentTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _sent = false;
        _custom.clear();
        _minuteEdits.clear();
        _nameEdits.clear();
        _typeEdits.clear();
        _removed.clear();
        // Close any editing UI too — otherwise an open name editor or
        // add-form would survive the "next round" reset (PR review).
        _editingNameId = null;
        _showAddForm = false;
      });
    });
  }

  /// The composed routine (edited AI items minus removed, plus custom)
  /// in the schedule programJson shape.
  List<Map<String, Object?>> _composeProgram(List<AiRoutineItem> items) {
    final AppLocalizations l = AppLocalizations.of(context);
    return <Map<String, Object?>>[
      for (final item in items)
        if (!_removed.contains(item.id))
          <String, Object?>{
            'name': _nameEdits[item.id] ?? item.name,
            'sets': 1,
            'reps': l.minutesShort(_minuteEdits[item.id] ?? item.minutes),
            'weight': '-',
          },
      for (final c in _custom)
        <String, Object?>{
          'name': c.name,
          'sets': 1,
          'reps': l.minutesShort(c.minutes),
          'weight': '-',
        },
    ];
  }

  /// A single summary [AssignedRoutine] for the real routine-assign API
  /// (`RoutineOut` is one routine, not a per-exercise program): [type] and
  /// [source] come from [summaryTypeAndSource] (extracted so the
  /// all-custom-exercises path is directly unit-testable — review) and the
  /// reason lists the exercise names.
  AssignedRoutine _summaryRoutine(List<AiRoutineItem> items, int totalMinutes) {
    final AppLocalizations l = AppLocalizations.of(context);
    final active = items.where((i) => !_removed.contains(i.id)).toList();
    final result = summaryTypeAndSource(
      aiItemTypes: <String>[for (final i in active) _typeEdits[i.id] ?? i.type],
      customItemTypes: <String>[for (final c in _custom) c.type],
    );
    final names = <String>[
      for (final i in active) _nameEdits[i.id] ?? i.name,
      for (final c in _custom) c.name,
    ];
    return AssignedRoutine(
      id: '',
      name: l.coachCustomRoutine,
      minutes: totalMinutes,
      type: result.type,
      reason: names.join(', '),
      source: result.source,
    );
  }

  /// Writes the routine onto today's schedule (attach to the client's
  /// 예정 session, or book a new slot) and flashes a confirmation.
  /// Whether [clientId] is still the client on screen. `_clientId` is
  /// null until the trainer picks someone (the first client is shown by
  /// default), so null means "still the initial selection".
  bool _isStillSelected(String clientId) =>
      _clientId == null || _clientId == clientId;

  Future<void> _registerToSchedule(
    TrainerClient client,
    List<AiRoutineItem> items,
  ) async {
    // Block a duplicate for THIS client — either just registered, or one
    // is already in flight for them.
    if (_registered || _registeringClientId == client.id) return;
    final messenger = ScaffoldMessenger.of(context);
    final program = _composeProgram(items);
    if (program.isEmpty) {
      final AppLocalizations l = AppLocalizations.of(context);
      // Every exercise was removed — tell the trainer instead of a
      // silent no-op (review PR 220).
      messenger.showSnackBar(
        SnackBar(content: Text(l.coachNeedOneExercise)),
      );
      return;
    }
    final date = ymd(DateTime.now().add(Duration(days: _registerOffset)));
    // Remember who this write is for — the trainer can switch clients
    // while it saves, and the result must not be attributed to the new
    // one (review PR 220).
    final registeredFor = client.id;
    setState(() => _registeringClientId = registeredFor);
    try {
      await ref
          .read(aiRoutineRepositoryProvider)
          .registerToSchedule(
            date: date,
            clientName: client.name,
            program: program,
          );
    } catch (_) {
      if (!mounted) return;
      // Clear the guard for this client so it can be retried.
      if (_registeringClientId == registeredFor) {
        setState(() => _registeringClientId = null);
      }
      // Only surface the error if that client is still on screen.
      if (_isStillSelected(registeredFor)) {
        final AppLocalizations l = AppLocalizations.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text(l.coachScheduleFailed)),
        );
      }
      return;
    }
    if (!mounted) return;
    if (_registeringClientId == registeredFor) {
      setState(() => _registeringClientId = null);
    }
    // Attribute the success flash only to the client it was started for.
    if (!_isStillSelected(registeredFor)) return;
    setState(() => _registered = true);
    _registerTimer?.cancel();
    _registerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _registered = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final clientsAsync = ref.watch(clientsProvider);

    return PageScaffold(
      title: l.coachTitle,
      subtitle: l.coachSubtitle,
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      child: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            l.clientsLoadFailed,
            style: TextStyle(color: AppColors.mutedForeground),
          ),
        ),
        data: (clients) {
          if (clients.isEmpty) {
            return Center(
              child: Text(
                l.coachNoClients,
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            );
          }
          final selected = clients.firstWhere(
            (c) => c.id == _clientId,
            orElse: () => clients.first,
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AppLayout.splitBreakpoint;
              if (!wide) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.pagePadding,
                    AppSpacing.lg,
                    AppLayout.pagePadding,
                    AppSpacing.xxl,
                  ),
                  children: <Widget>[
                    // Single column: context, then the editor, then the
                    // library. The editor is the task — pushing it below
                    // the templates would bury it.
                    ..._contextChildren(l, clients, selected),
                    const SizedBox(height: AppSpacing.lg),
                    ..._editorChildren(selected),
                    const SizedBox(height: AppSpacing.lg),
                    ..._libraryChildren(selected),
                  ],
                );
              }
              // Wide: client/diet overview docks left, the routine
              // editor gets its own column.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: AppLayout.splitListWidth,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppLayout.pagePadding,
                        AppSpacing.lg,
                        AppLayout.pagePadding,
                        AppSpacing.xxl,
                      ),
                      children: <Widget>[
                        ..._contextChildren(l, clients, selected),
                        const SizedBox(height: AppSpacing.lg),
                        ..._libraryChildren(selected),
                      ],
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    color: AppColors.borderStrong,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppLayout.pagePadding,
                        AppSpacing.lg,
                        AppLayout.pagePadding,
                        AppSpacing.xxl,
                      ),
                      children: _editorChildren(selected),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Who the routine is for, and what their day looks like — the
  /// context the editor is read against.
  List<Widget> _contextChildren(
    AppLocalizations l,
    List<TrainerClient> clients,
    TrainerClient client,
  ) {
    return <Widget>[
      _sectionLabel(l.reportsPickClient),
      const SizedBox(height: AppSpacing.sm),
      // Horizontal scroll instead of one cramped Row — stays usable as
      // the roster grows past the seeded three (codex review).
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final c in clients) ...<Widget>[
              SizedBox(
                width: 104,
                child: _ClientChip(
                  client: c,
                  selected: c.id == client.id,
                  onTap: () => _selectClient(c.id),
                ),
              ),
              if (c != clients.last) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      _sectionLabel(l.coachTodayDiet),
      const SizedBox(height: AppSpacing.sm),
      _DietSummaryCard(client: client),
    ];
  }

  /// Reusable blocks and what this client already received — reference
  /// material, secondary to the editor.
  List<Widget> _libraryChildren(TrainerClient client) {
    return <Widget>[
      _TemplateCard(
        onApply: (template) => setState(() {
          // Templates append to whatever is already composed rather than
          // replacing it — the trainer usually wants the AI's base plus a
          // known block, not one or the other.
          for (final exercise in template.exercises) {
            _custom.add(
              _CustomExercise(
                name: exercise.name,
                minutes: exercise.minutes,
                type: exercise.type,
              ),
            );
          }
          _registered = false;
          _sent = false;
        }),
      ),
      const SizedBox(height: AppSpacing.lg),
      _SendHistoryCard(client: client),
    ];
  }

  /// The routine editor column (right column on wide).
  List<Widget> _editorChildren(TrainerClient client) {
    final AppLocalizations l = AppLocalizations.of(context);
    final routineAsync = ref.watch(
      aiRoutineProvider((id: client.id, name: client.name)),
    );

    return <Widget>[
      Row(
        children: <Widget>[
          _sectionLabel(l.coachRecommended),
          if (_showOptionsFlow) ...<Widget>[
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _showOptionsFlow = false),
              icon: const Icon(Icons.close, size: 16),
              label: Text(l.coachBackToList),
            ),
          ],
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      routineAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          l.routinesLoadFailed,
          style: TextStyle(color: AppColors.mutedForeground),
        ),
        data: (items) => _showOptionsFlow
            ? AiRoutineOptionsFlow(
                key: ValueKey<String>('routine-options-${client.id}'),
                client: client,
                embedded: true,
                recommendedExercises: items
                    .map(
                      (item) => RoutineExercise(
                        name: item.name,
                        minutes: item.minutes,
                        type: _typeEdits[item.id] ?? item.type,
                      ),
                    )
                    .toList(growable: false),
                recommendedReason: items.isEmpty
                    ? ''
                    : items.map((item) => item.reason).join(' · '),
                onReviewCompleted: (exercises) {
                  setState(() {
                    _generatedRecommendations[client.id] = <AiRoutineItem>[
                      for (var index = 0; index < exercises.length; index++)
                        AiRoutineItem(
                          id: 'generated-${client.id}-$index',
                          name: exercises[index].name,
                          minutes: exercises[index].minutes,
                          type: exercises[index].type,
                          reason: l.coachReviewed,
                        ),
                    ];
                  });
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _AiAssistantPrompt(
                    clientName: client.name,
                    onTap: () => setState(() => _showOptionsFlow = true),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final item
                      in _generatedRecommendations[client.id] ?? items)
                    if (!_removed.contains(item.id)) ...<Widget>[
                      _RoutineCard(
                        name: _nameEdits[item.id] ?? item.name,
                        minutes: _minuteEdits[item.id] ?? item.minutes,
                        type: item.type,
                        reason: item.reason,
                        isCustom: false,
                        editingName: _editingNameId == item.id,
                        onNameTap: () =>
                            setState(() => _editingNameId = item.id),
                        onNameChanged: (v) => _nameEdits[item.id] = v,
                        onNameDone: () => setState(() => _editingNameId = null),
                        onMinutes: (m) =>
                            setState(() => _minuteEdits[item.id] = m),
                        onType: (type) =>
                            setState(() => _typeEdits[item.id] = type),
                        // AI suggestions can be dropped from this round too.
                        onDelete: () => setState(() {
                          _removed.add(item.id);
                          if (_editingNameId == item.id) _editingNameId = null;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  for (var i = 0; i < _custom.length; i++) ...<Widget>[
                    _RoutineCard(
                      name: _custom[i].name,
                      minutes: _custom[i].minutes,
                      type: _custom[i].type,
                      reason: l.coachTrainerAdded,
                      isCustom: true,
                      editingName: _editingNameId == 'custom-$i',
                      onNameTap: () =>
                          setState(() => _editingNameId = 'custom-$i'),
                      onNameChanged: (name) {
                        final current = _custom[i];
                        _custom[i] = _CustomExercise(
                          name: name,
                          minutes: current.minutes,
                          type: current.type,
                        );
                      },
                      onNameDone: () => setState(() => _editingNameId = null),
                      onMinutes: (minutes) => setState(() {
                        final current = _custom[i];
                        _custom[i] = _CustomExercise(
                          name: current.name,
                          minutes: minutes,
                          type: current.type,
                        );
                      }),
                      onType: (type) => setState(() {
                        final current = _custom[i];
                        _custom[i] = _CustomExercise(
                          name: current.name,
                          minutes: current.minutes,
                          type: type,
                        );
                      }),
                      onDelete: () => setState(() => _custom.removeAt(i)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  _showAddForm
                      ? _AddExerciseForm(
                          onCancel: () => setState(() => _showAddForm = false),
                          onAdd: (name, minutes, type) => setState(() {
                            _custom.add(
                              _CustomExercise(
                                name: name,
                                minutes: minutes,
                                type: type,
                              ),
                            );
                            _showAddForm = false;
                          }),
                        )
                      : _AddExerciseButton(
                          onTap: () => setState(() => _showAddForm = true),
                        ),
                  const SizedBox(height: AppSpacing.lg),
                  // Two destinations: homework to the client's app (mock),
                  // or today's PT session program (real drift write that the
                  // 스케줄 탭 picks up live).
                  _SendButton(
                    clientName: client.name,
                    // Disabled while routine delivery is in flight so a
                    // second tap cannot create a duplicate assignment.
                    sent: _sent || _sending,
                    onSend: () => _send(
                      client,
                      _generatedRecommendations[client.id] ?? items,
                    ),
                  ),
                  if (_sent)
                    Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        l.coachClientNotified,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  // Which day the routine lands on (오늘 … +6일).
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        for (var i = 0; i < 7; i++) ...<Widget>[
                          _DateChip(
                            offset: i,
                            selected: _registerOffset == i,
                            onTap: () => setState(() {
                              _registerOffset = i;
                              _registered = false;
                            }),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _RegisterButton(
                    // Disabled just after registering, or while THIS client's
                    // registration is in flight, so a second tap can't queue a
                    // duplicate session (review PR 220).
                    registered:
                        _registered || _registeringClientId == client.id,
                    icon: _registered
                        ? Icons.check_rounded
                        : Icons.calendar_today_outlined,
                    label: _registered
                        ? l.coachRegisteredOn(_dateChipLabel(l, _registerOffset))
                        : l.coachRegisterOn(_dateChipLabel(l, _registerOffset)),
                    onTap: () => _registerToSchedule(
                      client,
                      _generatedRecommendations[client.id] ?? items,
                    ),
                  ),
                  if (_registered)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        // Match the button's day label — 오늘/내일/'M/D' — so a
                        // future-day registration isn't described as 오늘
                        // (CodeRabbit review).
                        l.coachFindInSchedule(_dateChipLabel(l, _registerOffset)),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ];
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: AppColors.subtleForeground,
      ),
    );
  }
}

class _ClientChip extends StatelessWidget {
  const _ClientChip({
    required this.client,
    required this.selected,
    required this.onTap,
  });

  final TrainerClient client;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: selected ? null : Border.all(color: AppColors.borderStrong),
          ),
          child: Column(
            children: <Widget>[
              selected
                  ? Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryForeground.withValues(
                          alpha: 0.25,
                        ),
                      ),
                      child: Text(
                        client.avatar,
                        style: const TextStyle(
                          color: AppColors.primaryForeground,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ClientAvatar(label: client.avatar, size: 32),
              const SizedBox(height: AppSpacing.xs),
              Text(
                client.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.primaryForeground
                      : AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diet summary — the shared metric tiles + the AI's verdict line.
class _DietSummaryCard extends StatelessWidget {
  const _DietSummaryCard({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final over = client.sodiumOverBudget;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              MetricTile(
                label: l.metricCalories,
                value: client.calories,
                unit: 'kcal',
                color: AppColors.accentDark,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: l.metricSodium,
                value: client.sodiumMg,
                unit: 'mg',
                color: AppColors.accentDark,
                warn: over,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: l.metricSugar,
                value: client.sugarG,
                unit: 'g',
                color: AppColors.accentDark,
                warn: client.sugarG > sugarTargetG,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.accentSurface,
              borderRadius: BorderRadius.all(AppRadius.md),
            ),
            child: IconLabel(
              icon: Icons.auto_awesome,
              label: over
                  ? l.coachVerdictSodium
                  : l.coachVerdictBalanced,
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width, conversation-style entry to the inline routine assistant.
///
/// This deliberately reads like a suggested AI prompt instead of a tiny
/// utility chip: the trainer can understand what will happen before opening
/// the flow, and the flow remains inside the current AI routine tab.
class _AiAssistantPrompt extends StatelessWidget {
  const _AiAssistantPrompt({required this.clientName, required this.onTap});

  final String clientName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Material(
      color: AppColors.accentSurface,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent,
                child: Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.accentForeground,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.coachRequestCustom,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l.coachRequestBlurb(clientName),
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// One routine card — AI and trainer-added items share the same editor.
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.name,
    required this.minutes,
    required this.type,
    required this.reason,
    required this.isCustom,
    this.editingName = false,
    this.onNameTap,
    this.onNameChanged,
    this.onNameDone,
    this.onMinutes,
    this.onType,
    this.onDelete,
  });

  final String name;
  final int minutes;
  final String type;
  final String reason;
  final bool isCustom;
  final bool editingName;
  final VoidCallback? onNameTap;
  final ValueChanged<String>? onNameChanged;
  final VoidCallback? onNameDone;
  final ValueChanged<int>? onMinutes;
  final ValueChanged<String>? onType;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    const accent = AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (onType == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(AppRadius.pill),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              if (onType == null) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: editingName
                    ? _NameEditField(
                        initial: name,
                        onChanged: onNameChanged,
                        onDone: onNameDone,
                      )
                    : GestureDetector(
                        onTap: onNameTap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                            if (!isCustom)
                              Text(
                                l.coachTapToEdit,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: AppColors.disabledForeground,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.subtleForeground,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 12,
                  color: AppColors.subtleForeground,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.subtleForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (onType != null) ...<Widget>[
            RoutineCategoryChips(
              keyPrefix: 'routine-card-$name-category',
              value: type,
              onChanged: onType!,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (onMinutes != null)
            RoutineMinutesSlider(
              key: ValueKey<String>('routine-minutes-$name'),
              minutes: minutes,
              onChanged: onMinutes!,
            )
          else
            Text(
              l.minutesShort(minutes),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline name editor with a properly owned controller (creating a
/// TextEditingController inside build leaks it and resets state on
/// rebuild — /code-review finding).
class _NameEditField extends StatefulWidget {
  const _NameEditField({
    required this.initial,
    required this.onChanged,
    required this.onDone,
  });

  final String initial;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onDone;

  @override
  State<_NameEditField> createState() => _NameEditFieldState();
}

class _NameEditFieldState extends State<_NameEditField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  )..selection = TextSelection.collapsed(offset: widget.initial.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onDone?.call(),
      onTapOutside: (_) => widget.onDone?.call(),
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.accentSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Material(
      color: AppColors.accentSurface,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: Text(
            l.coachAddExerciseManually,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "운동 추가" form — member-app style type chips and duration slider.
class _AddExerciseForm extends StatefulWidget {
  const _AddExerciseForm({required this.onCancel, required this.onAdd});

  final VoidCallback onCancel;
  final void Function(String name, int minutes, String type) onAdd;

  @override
  State<_AddExerciseForm> createState() => _AddExerciseFormState();
}

class _AddExerciseFormState extends State<_AddExerciseForm> {
  final TextEditingController _name = TextEditingController();
  String _type = '근력';
  int _minutes = 30;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.progAddExercise,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey<String>('custom-exercise-name'),
            controller: _name,
            decoration: InputDecoration(
              hintText: l.coachExerciseNameHint,
              hintStyle: const TextStyle(color: AppColors.mutedForeground),
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          RoutineCategoryChips(
            keyPrefix: 'custom-exercise-category',
            value: _type,
            onChanged: (type) => setState(() => _type = type),
          ),
          const SizedBox(height: AppSpacing.sm),
          RoutineMinutesSlider(
            key: const ValueKey<String>('custom-exercise-minutes'),
            minutes: _minutes,
            onChanged: (minutes) => setState(() {
              _minutes = minutes;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _FormButton(
                  label: l.actionCancel,
                  background: AppColors.inputBackground,
                  foreground: AppColors.subtleForeground,
                  onTap: widget.onCancel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FormButton(
                  label: l.schedAddAction,
                  background: AppColors.accent,
                  foreground: AppColors.accentForeground,
                  onTap: () {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    widget.onAdd(name, _minutes, _type);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormButton extends StatelessWidget {
  const _FormButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Label for a register-day offset (오늘/내일/M/D).
String _dateChipLabel(AppLocalizations l, int offset) {
  if (offset == 0) return l.labelToday;
  if (offset == 1) return l.labelTomorrow;
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.month}/${d.day}';
}

/// One selectable register-day chip.
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.offset,
    required this.selected,
    required this.onTap,
  });

  final int offset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.inputBackground,
          borderRadius: const BorderRadius.all(AppRadius.pill),
        ),
        child: Text(
          _dateChipLabel(AppLocalizations.of(context), offset),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: selected
                ? AppColors.primaryForeground
                : AppColors.subtleForeground,
          ),
        ),
      ),
    );
  }
}

/// Secondary action — registers the routine as the chosen day's PT
/// session program on the 스케줄 tab.
class _RegisterButton extends StatelessWidget {
  const _RegisterButton({
    required this.registered,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool registered;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = registered ? AppColors.success : AppColors.accent;
    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: registered ? null : onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.clientName,
    required this.sent,
    required this.onSend,
  });

  final String clientName;
  final bool sent;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Material(
      color: sent ? AppColors.success : AppColors.primary,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: sent ? null : onSend,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: IconLabel(
            icon: sent ? Icons.check_circle : Icons.send_outlined,
            label: sent ? l.coachSentToClient(clientName) : l.coachReviewAndSend(clientName),
            color: AppColors.primaryForeground,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// 프로그램 템플릿 — the trainer's own reusable blocks, one tap away.
///
/// The AI covers "what does this client's data suggest?"; templates
/// cover "what do I always do for this kind of client?". Applying one
/// appends its exercises to the composed routine.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.onApply});

  final ValueChanged<ProgramTemplate> onApply;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SectionCard(
      title: l.coachTemplates,
      icon: Icons.dashboard_customize_outlined,
      dense: true,
      child: Column(
        children: <Widget>[
          for (final template in programTemplates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Material(
                color: AppColors.inputBackground,
                borderRadius: const BorderRadius.all(AppRadius.md),
                child: InkWell(
                  onTap: () => onApply(template),
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                template.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.foreground,
                                ),
                              ),
                              Text(
                                l.coachTemplateSummaryWithGoal(
                                  template.goal,
                                  template.exercises.length,
                                  template.totalMinutes,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.subtleForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.add_circle_outline,
                          size: 17,
                          color: AppColors.primary,
                        ),
                      ],
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

/// 전송 이력 — what this client has already been given.
///
/// Without it the workspace has no memory: the trainer can't tell
/// whether they already sent today's routine, and repeats it. Sourced
/// from the schedule (PT 프로그램) and, on the real API, the member's
/// assigned routines.
class _SendHistoryCard extends ConsumerWidget {
  const _SendHistoryCard({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final sessions = ref.watch(
      clientSessionsProvider((id: client.id, name: client.name)),
    );
    // Homework goes out via `assignRoutine`, which writes no schedule row.
    // Watching only the schedule left this card empty right after a send,
    // so the trainer could send the same routine again believing nothing
    // had gone out.
    final assigned = ref.watch(assignedRoutinesProvider(client.id));
    final today = ymd(DateTime.now());

    return SectionCard(
      title: l.coachSentHistory,
      icon: Icons.history,
      dense: true,
      child: sessions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => EmptyHint(message: l.coachHistoryFailed),
        data: (list) {
          final withProgram = list
              .where((s) => s.program.isNotEmpty)
              .take(4)
              .toList();
          final routines = assigned.valueOrNull ?? const <AssignedRoutine>[];
          if (withProgram.isEmpty && routines.isEmpty) {
            return EmptyHint(
              message: l.coachHistoryEmpty,
              icon: Icons.outbox_outlined,
            );
          }
          return Column(
            children: <Widget>[
              for (final routine in routines.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 46,
                        child: Text(
                          l.coachHomework,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandOrange,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l.coachRoutineSummary(routine.name, routine.minutes),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      routine.source == 'ai'
                          ? const IconLabel(
                              icon: Icons.auto_awesome,
                              label: 'AI',
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            )
                          : Text(
                              l.coachTrainer,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                    ],
                  ),
                ),
              for (final s in withProgram)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 46,
                        child: Text(
                          s.date == today
                              ? l.labelToday
                              : s.date.substring(5).replaceAll('-', '/'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: s.date == today
                                ? AppColors.primary
                                : AppColors.subtleForeground,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l.coachSessionExercises(sessionTypeLabel(l, s.type), s.program.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      Text(
                        s.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: s.isDone
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
