import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/request_id.dart';
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
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/features/coaching/presentation/pages/ai_routine_options_flow.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_editor_workspace.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/metric_tile.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

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
  final Map<String, String> _typeEdits = <String, String>{};
  final Map<String, List<AiRoutineItem>> _generatedRecommendations =
      <String, List<AiRoutineItem>>{};
  ProgramTemplate? _appliedTemplate;
  int _templateRevision = 0;
  int _editorRevision = 0;
  bool _showOptionsFlow = false;
  bool _sent = false;
  Timer? _sentTimer;

  /// A homework send is in flight (blocks re-entry, disables the button).
  bool _sending = false;

  /// 진행 중인 전송 시도의 멱등키와 그 대상 회원. 실패 후 재시도는 같은 키를
  /// 다시 쓰고(중복 배정 방지), 성공하거나 대상이 바뀌면 새로 잡는다(#581).
  String? _sendRequestId;
  String? _sendRequestFor;

  /// A schedule registration just succeeded (drives the 3s flash).
  bool _registered = false;
  // Every client whose registration is in flight. Multiple clients may save
  // concurrently, but each client may have only one pending write.
  final Set<String> _registeringClientIds = <String>{};
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
      _typeEdits.clear();
      _showOptionsFlow = false;
      _sent = false;
      _sending = false;
      _registered = false;
      _registerOffset = 0;
      _appliedTemplate = null;
      _templateRevision = 0;
      _editorRevision = 0;
      // NOTE: _registeringClientIds is intentionally NOT cleared — writes
      // for other clients keep being tracked while the selection changes.
    });
    _sentTimer?.cancel();
    _registerTimer?.cancel();
  }

  bool _isStillSelected(String clientId) =>
      _clientId == null || _clientId == clientId;
  Future<void> _assignDraft(
    TrainerClient client,
    ProgramEditorState draft,
  ) async {
    if (_sent || _sending || !draft.supportsFlatRoutine) return;
    final sentFor = client.id;
    if (_sendRequestId == null || _sendRequestFor != sentFor) {
      _sendRequestId = newClientRequestId();
      _sendRequestFor = sentFor;
    }
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      await ref
          .read(trainerRoutineRepositoryProvider)
          .assignRoutine(
            client.id,
            _draftRoutine(draft),
            clientRequestId: _sendRequestId,
          );
    } catch (_) {
      if (!mounted || !_isStillSelected(sentFor)) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(l.coachSendFailed)));
      return;
    }
    if (!mounted || !_isStillSelected(sentFor)) return;
    setState(() {
      _sending = false;
      _sent = true;
      _sendRequestId = null;
      _sendRequestFor = null;
    });
    _sentTimer?.cancel();
    _sentTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _sent = false;
        _editorRevision++;
      });
    });
  }

  Future<void> _registerDraft(
    TrainerClient client,
    ProgramEditorState draft,
  ) async {
    if (!draft.supportsFlatRoutine ||
        _registered ||
        _registeringClientIds.contains(client.id)) {
      return;
    }
    final registeredFor = client.id;
    final date = ymd(DateTime.now().add(Duration(days: _registerOffset)));
    final now = DateTime.now();
    final hour = date == ymd(now) ? (now.hour + 1).clamp(6, 23) : 10;
    final time = '${hour.toString().padLeft(2, '0')}:00';
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    setState(() => _registeringClientIds.add(registeredFor));
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .registerProgram(
            date: date,
            clientId: client.id,
            clientName: client.name,
            time: time,
            program: _draftProgram(draft),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _registeringClientIds.remove(registeredFor));
      if (_isStillSelected(registeredFor)) {
        messenger.showSnackBar(SnackBar(content: Text(l.coachScheduleFailed)));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _registeringClientIds.remove(registeredFor);
      if (_isStillSelected(registeredFor)) _registered = true;
    });
    _registerTimer?.cancel();
    _registerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _registered = false);
    });
  }

  List<ProgramItem> _draftProgram(ProgramEditorState draft) => <ProgramItem>[
    for (final exercise in draft.sessions.single.exercises)
      ProgramItem(
        name: exercise.name.trim(),
        sets: int.parse(exercise.sets.trim()),
        reps: exercise.duration.trim().isNotEmpty
            ? '${exercise.duration}분'
            : exercise.reps,
        weight: exercise.weight.trim().isEmpty ? '-' : exercise.weight,
      ),
  ];

  AssignedRoutine _draftRoutine(ProgramEditorState draft) {
    final exercises = draft.sessions.single.exercises;
    final summary = summaryTypeAndSource(
      aiItemTypes: <String>[
        for (final exercise in exercises)
          if (exercise.source == 'ai') exercise.type,
      ],
      customItemTypes: <String>[
        for (final exercise in exercises)
          if (exercise.source != 'ai') exercise.type,
      ],
    );
    final minutes = exercises.fold<int>(
      0,
      (total, exercise) =>
          total + (int.tryParse(exercise.duration.trim()) ?? 0),
    );
    return AssignedRoutine(
      id: '',
      name: draft.name,
      minutes: minutes,
      type: summary.type,
      reason: exercises.map((exercise) => exercise.name).join(', '),
      source: summary.source,
    );
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
                    AppLayout.pagePadding,
                    AppLayout.pagePadding,
                    AppLayout.pagePadding,
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
              return ListView(
                key: const ValueKey<String>('coaching-program-page-scroll'),
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.pagePadding,
                  AppLayout.pagePadding,
                  AppLayout.pagePadding,
                  AppLayout.pagePadding,
                ),
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 260,
                        child: _MemberProgramList(
                          clients: clients,
                          selectedId: selected.id,
                          onSelect: _selectClient,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            ..._editorChildren(selected, showAssistant: false),
                            const SizedBox(height: AppSpacing.lg),
                            _TemplateCard(
                              onApply: (template) => setState(() {
                                _appliedTemplate = template;
                                _templateRevision++;
                                _registered = false;
                                _sent = false;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      SizedBox(
                        width: 260,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _ProgramMemberSummary(client: selected),
                            const SizedBox(height: AppSpacing.lg),
                            _DietSummaryCard(client: selected),
                            const SizedBox(height: AppSpacing.lg),
                            _AiAssistantPrompt(
                              clientName: selected.name,
                              onTap: () =>
                                  setState(() => _showOptionsFlow = true),
                            ),
                          ],
                        ),
                      ),
                    ],
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
          _appliedTemplate = template;
          _templateRevision++;
          _registered = false;
          _sent = false;
        }),
      ),
      const SizedBox(height: AppSpacing.lg),
      _SendHistoryCard(client: client),
    ];
  }

  /// The routine editor column (right column on wide).
  List<Widget> _editorChildren(
    TrainerClient client, {
    bool showAssistant = true,
  }) {
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
                  if (showAssistant) ...<Widget>[
                    _AiAssistantPrompt(
                      clientName: client.name,
                      onTap: () => setState(() => _showOptionsFlow = true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  ProgramEditorWorkspace(
                    key: ValueKey<String>(
                      'program-editor-${client.id}-$_editorRevision',
                    ),
                    clientGoal: client.goal,
                    aiSuggestions:
                        _generatedRecommendations[client.id] ?? items,
                    template: _appliedTemplate,
                    templateRevision: _templateRevision,
                    assigning: _sending || _sent,
                    registering:
                        _registered ||
                        _registeringClientIds.contains(client.id),
                    registerOffset: _registerOffset,
                    onRegisterOffsetChanged: (offset) => setState(() {
                      _registerOffset = offset;
                      _registered = false;
                    }),
                    onAssignFlat: (draft) => _assignDraft(client, draft),
                    onRegisterFlat: (draft) => _registerDraft(client, draft),
                  ),
                  if (_sent)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Column(
                        children: <Widget>[
                          Text(
                            l.coachSentToClient(client.name),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            l.coachClientNotified,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_registered)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Column(
                        children: <Widget>[
                          Text(
                            l.coachRegisteredOn(
                              _dateChipLabel(l, _registerOffset),
                            ),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            l.coachFindInSchedule(
                              _dateChipLabel(l, _registerOffset),
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
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
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.subtleForeground,
      ),
    );
  }
}

class _MemberProgramList extends StatefulWidget {
  const _MemberProgramList({
    required this.clients,
    required this.selectedId,
    required this.onSelect,
  });

  final List<TrainerClient> clients;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<_MemberProgramList> createState() => _MemberProgramListState();
}

class _MemberProgramListState extends State<_MemberProgramList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final clients = widget.clients
        .where((client) => client.name.toLowerCase().contains(query))
        .toList(growable: false);
    return SectionCard(
      title: l.coachMemberPrograms,
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('program-member-search'),
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: l.searchClientsHint,
              prefixIcon: const Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final client in clients)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Material(
                color: client.id == widget.selectedId
                    ? AppColors.accentSurface
                    : Colors.transparent,
                borderRadius: const BorderRadius.all(AppRadius.md),
                child: InkWell(
                  onTap: () => widget.onSelect(client.id),
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          client.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          client.lastRoutine == '-'
                              ? client.goal
                              : client.lastRoutine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.mutedForeground,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          recordedCompletionMean(client) == null
                              ? l.reportsDataInsufficient
                              : '${l.reportsCompletionAvg} ${recordedCompletionMean(client)!.round()}%',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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

class _ProgramMemberSummary extends StatelessWidget {
  const _ProgramMemberSummary({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final alerts = healthAlertsFor(client);
    final completion = recordedCompletionMean(client)?.round();
    return SectionCard(
      title: l.coachMemberSummary,
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClientAvatar(label: client.avatar, size: 42),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      client.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      client.goal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryLine(
            label: l.dashAttentionClients,
            value: alerts.isEmpty ? '-' : alerts.first.label(l),
            warning: alerts.isNotEmpty,
          ),
          _SummaryLine(label: l.aiGoal, value: client.goal),
          _SummaryLine(
            label: l.reportsCompletionAvg,
            value: completion == null ? '-' : '$completion%',
          ),
          _SummaryLine(label: l.aiRecentRoutine, value: client.lastRoutine),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.subtleForeground,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: warning ? AppColors.overTarget : AppColors.foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ClientAvatar(label: client.avatar, size: 32),
              const SizedBox(height: AppSpacing.xs),
              Text(
                client.name,
                style: TextStyle(
                  fontSize: 12,
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
                warn: client.sugarOverBudget,
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
              label: over ? l.coachVerdictSodium : l.coachVerdictBalanced,
              color: AppColors.accent,
              fontSize: 12,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l.coachRequestBlurb(clientName),
                      style: const TextStyle(
                        fontSize: 11.5,
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
String _dateChipLabel(AppLocalizations l, int offset) {
  if (offset == 0) return l.labelToday;
  if (offset == 1) return l.labelTomorrow;
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.month}/${d.day}';
}

/// One selectable register-day chip.
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 3 : 1;
          final width =
              (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final template in programTemplates)
                SizedBox(
                  width: width,
                  child: Material(
                    color: AppColors.inputBackground,
                    borderRadius: const BorderRadius.all(AppRadius.md),
                    child: InkWell(
                      onTap: () => onApply(template),
                      borderRadius: const BorderRadius.all(AppRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    template.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.add_circle_outline,
                                  size: 17,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l.coachTemplateSummaryWithGoal(
                                template.goal,
                                template.exercises.length,
                                template.totalMinutes,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: AppColors.subtleForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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
                            fontSize: 11.5,
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
                            fontSize: 12.5,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            )
                          : Text(
                              l.coachTrainer,
                              style: TextStyle(
                                fontSize: 11,
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
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: s.date == today
                                ? AppColors.primary
                                : AppColors.subtleForeground,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l.coachSessionExercises(
                            sessionTypeLabel(l, s.type),
                            s.program.length,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      Text(
                        scheduleStatusLabel(l, s.status),
                        style: TextStyle(
                          fontSize: 11,
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
