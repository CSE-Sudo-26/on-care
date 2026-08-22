import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/request_id.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_diet_period_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_exercise_status_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_period_toggle.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/nutrition_summary_card.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/program_draft_dtos.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/ai_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_program_draft_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_program_template_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_options.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/trainer_program_draft.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';
import 'package:oncare_trainer/features/coaching/presentation/pages/ai_routine_options_flow.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_editor_workspace.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_template_dialog.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_suggestion_review_card.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays, weekdayCount, weekdayLabels;
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

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

  /// The saved draft currently open in the editor; null means the editor is
  /// working on a new program. Saving overwrites this one instead of piling
  /// up a copy per click (#708).
  String? _openDraftId;

  /// Contents to seed the editor with when a saved draft is opened. Kept
  /// here (not in the editor) so opening another draft can rebuild it.
  ProgramEditorState? _openDraftSeed;

  /// A draft save is in flight — blocks re-entry so one click is one draft.
  bool _savingDraft = false;

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

  /// Saves the editor's current contents as a program draft. (#708)
  ///
  /// A draft that was opened from the saved list is overwritten; otherwise a
  /// new one is created and the editor switches to editing it, so pressing
  /// 저장 twice does not leave two copies behind.
  ///
  /// On failure nothing in the editor changes — the trainer keeps what they
  /// typed and can press 저장 again.
  Future<void> _saveDraft(ProgramEditorState draft) async {
    if (_savingDraft) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final repository = ref.read(trainerProgramDraftRepositoryProvider);
    final payload = programDraftToJson(draft);
    final openId = _openDraftId;
    setState(() => _savingDraft = true);
    try {
      final saved = openId == null
          ? await repository.create(payload)
          : await repository.update(openId, payload);
      ref.invalidate(trainerProgramDraftsProvider);
      if (!mounted) return;
      setState(() {
        _savingDraft = false;
        _openDraftId = saved.id;
      });
      messenger.showSnackBar(SnackBar(content: Text(l.programDraftSaved)));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _savingDraft = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is AppError
                ? serverDetailOr(l, error.message, l.programDraftSaveFailed)
                : l.programDraftSaveFailed,
          ),
        ),
      );
    }
  }

  /// Loads a saved draft into the editor.
  ///
  /// Bumping [_editorRevision] rebuilds the workspace so it initialises from
  /// the saved contents rather than merging them into whatever was on screen.
  Future<void> _openDraft(TrainerProgramDraftSummary summary) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final draft = await ref
          .read(trainerProgramDraftRepositoryProvider)
          .read(summary.id);
      if (!mounted) return;
      setState(() {
        _openDraftId = draft.id;
        _openDraftSeed = draft.toEditorState(
          fallbackSessionName: l.programEditorDefaultSession,
        );
        _editorRevision++;
        // 불러온 구성은 이 초안이 결정한 내용이다 — 템플릿·전송 배너는 초기화한다.
        _appliedTemplate = null;
        _sent = false;
        _registered = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(l.programDraftLoaded(draft.name))),
      );
    } on Object catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is AppError
                ? serverDetailOr(l, error.message, l.programDraftLoadFailed)
                : l.programDraftLoadFailed,
          ),
        ),
      );
    }
  }

  /// Starts a fresh program, leaving the saved one untouched on the server.
  void _startNewDraft() {
    setState(() {
      _openDraftId = null;
      _openDraftSeed = null;
      _editorRevision++;
      _appliedTemplate = null;
      _sent = false;
      _registered = false;
    });
  }

  Future<void> _deleteDraft(TrainerProgramDraftSummary summary) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.programDraftDeleteTitle),
        content: Text(l.programDraftDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(trainerProgramDraftRepositoryProvider).delete(summary.id);
      ref.invalidate(trainerProgramDraftsProvider);
      if (!mounted) return;
      // 편집기가 그 초안을 열고 있었다면 이제 새 프로그램을 쓰는 셈이다 —
      // 저장을 누르면 없는 초안을 덮어쓰려다 실패한다.
      if (_openDraftId == summary.id) setState(() => _openDraftId = null);
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.programDraftDeleteFailed)),
      );
    }
  }

  Future<void> _assignDraft(
    TrainerClient client,
    ProgramEditorState draft,
  ) async {
    if (_sent || _sending || !draft.supportsAssignment) return;
    final sentFor = client.id;
    if (_sendRequestId == null || _sendRequestFor != sentFor) {
      _sendRequestId = newClientRequestId();
      _sendRequestFor = sentFor;
    }
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      // 세션이 몇 개든 프로그램 배정 한 번으로 보낸다 — 세션당 루틴 한 건이
      // 되고, 세션이 하나뿐이면 예전 단일 배정과 같은 결과다(#709).
      await ref
          .read(trainerRoutineRepositoryProvider)
          .assignProgram(
            client.id,
            programAssignToJson(draft, clientRequestId: _sendRequestId),
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
    if (!draft.supportsAssignment ||
        _registered ||
        _registeringClientIds.contains(client.id)) {
      return;
    }
    final registeredFor = client.id;
    final date = ymd(nowKst().add(Duration(days: _registerOffset)));
    final now = nowKst();
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

  /// The draft flattened into schedule items, each tagged with its session.
  ///
  /// 세션 이름은 항목마다 붙는다(#709) — 일정은 평면 목록이지만 이 값으로 다시
  /// 세션별로 묶어 보여 줄 수 있고, 세션이 하나뿐이면 빈 문자열이라 예전 일정과
  /// 같은 모양이다.
  List<ProgramItem> _draftProgram(ProgramEditorState draft) {
    final multi = draft.sessions.length > 1;
    return <ProgramItem>[
      for (final session in draft.sessions)
        for (final exercise in session.exercises)
          ProgramItem(
            name: exercise.name.trim(),
            sets: int.parse(exercise.sets.trim()),
            reps: exercise.duration.trim().isNotEmpty
                ? '${exercise.duration}분'
                : exercise.reps,
            weight: exercise.weight.trim().isEmpty ? '-' : exercise.weight,
            session: multi ? capSessionName(session.name) : '',
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final clientsAsync = ref.watch(clientsProvider);

    return PageScaffold(
      title: l.coachTitle,
      subtitle: l.coachSubtitle,
      headerCenter: const ClientSearchBar(),
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      child: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            l.clientsLoadFailed,
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
        ),
        data: (clients) {
          if (clients.isEmpty) {
            return Center(
              child: Text(
                l.coachNoClients,
                style: const TextStyle(color: AppColors.mutedForeground),
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
              // 3열의 고정 폭(목록 260 + 우측 360 + 간격 48)과 페이지 여백을
              // 빼고도 편집기가 최소 600px을 가져야 한다.
              final fullWidth = constraints.maxWidth >= 1320;
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
                    ..._suggestionChildren(selected),
                    ..._editorChildren(selected),
                    const SizedBox(height: AppSpacing.lg),
                    ..._libraryChildren(selected),
                  ],
                );
              }
              // 넓은 화면은 **세 열이 각자 스크롤한다.** 왼쪽(고객 · 템플릿)은
              // #958 이후로 이미 그랬고, 이번에는 오른쪽 고객 데이터 열도
              // 가운데 편집기 스크롤에서 떼어 냈다(#1027) — 편집기를 아래로
              // 읽는 동안 지금 고른 고객의 식단·운동이 함께 밀려 올라가면,
              // 정작 그 데이터를 근거로 짜야 할 프로그램을 쓰면서 근거를 볼
              // 수 없다. 열을 나누면 오른쪽 열은 제자리에 머무른다.
              return Padding(
                padding: const EdgeInsets.all(AppLayout.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 260,
                            // 고객 목록(5줄 고정)에 템플릿 카드가 더해지면
                            // 짧은 창에서는 열이 화면보다 길어진다. 이 열
                            // 안에서만 스크롤하게 두어 오른쪽과 따로 움직인다.
                            child: SingleChildScrollView(
                              key: const ValueKey<String>(
                                'coaching-sidebar-scroll',
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  _MemberProgramList(
                                    clients: clients,
                                    selectedId: selected.id,
                                    onSelect: _selectClient,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _TemplateCard(
                                    key: const ValueKey<String>(
                                      'program-template-sidebar',
                                    ),
                                    onApply: _applyTemplate,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: SingleChildScrollView(
                              key: const ValueKey<String>(
                                'coaching-program-page-scroll',
                              ),
                              child: Column(
                                key: const ValueKey<String>(
                                  'coaching-wide-main-column',
                                ),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  // 오른쪽 열을 세울 만큼 넓지 않은 창에서는
                                  // 식단·운동이 가운데 열 **맨 위**에 온다 —
                                  // 넓은 화면의 오른쪽 열 맨 위와 같은 자리다.
                                  // 예전에는 고객 요약 카드가 그 자리를 차지하고
                                  // 데이터는 그 옆(또는 아래)이었다. 좁은 화면
                                  // (`_contextChildren`)도 이미 이 순서다.
                                  if (!fullWidth) ...<Widget>[
                                    _ClientDataSwitcher(
                                      key: const ValueKey<String>(
                                        'coaching-wide-client-overview',
                                      ),
                                      client: selected,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],
                                  if (!_showOptionsFlow) ...<Widget>[
                                    _AiAssistantPrompt(
                                      key: const ValueKey<String>(
                                        'coaching-wide-ai-prompt',
                                      ),
                                      clientName: selected.name,
                                      onTap: () => setState(
                                        () => _showOptionsFlow = true,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],
                                  ..._suggestionChildren(selected),
                                  ..._editorChildren(
                                    selected,
                                    showAssistant: false,
                                  ),
                                  // 좁은 화면은 _libraryChildren 이 같은 카드들을 붙인다.
                                  ...?_savedProgramsCard(),
                                  // 전송 이력은 오른쪽 열이 있으면 그쪽이 든다.
                                  // 열이 없는 폭에서만 여기 아래에 남는다.
                                  if (!fullWidth) ...<Widget>[
                                    const SizedBox(height: AppSpacing.lg),
                                    _SendHistoryCard(client: selected),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (fullWidth) ...<Widget>[
                            const SizedBox(width: AppSpacing.lg),
                            SizedBox(
                              key: const ValueKey<String>(
                                'coaching-wide-client-overview',
                              ),
                              width: 360,
                              // 가운데 열과 **다른 스크롤**이다 — 편집기를 아래로
                              // 읽어도 이 열은 제자리에 머문다. 열 자체가 화면보다
                              // 길어질 때만 이 안에서 따로 움직인다.
                              child: SingleChildScrollView(
                                key: const ValueKey<String>(
                                  'coaching-client-rail-scroll',
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    // 식단·운동이 열의 맨 위다. 고객을 고른 뒤
                                    // 가장 자주 보는 값이 가장 먼저 온다.
                                    _ClientDataSwitcher(client: selected),
                                    const SizedBox(height: AppSpacing.lg),
                                    _SendHistoryCard(client: selected),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
      // 좁은 화면도 넓은 화면과 같은 것을 본다 — 오늘의 영양 카드 하나만
      // 붙여 두면 이 폭에서는 운동 데이터를 볼 길이 아예 없었다.
      _ClientDataSwitcher(client: client),
    ];
  }

  /// Reusable blocks and what this client already received — reference
  /// material, secondary to the editor.
  List<Widget> _libraryChildren(TrainerClient client) {
    return <Widget>[
      _TemplateCard(onApply: _applyTemplate),
      // 저장한 프로그램이 하나도 없으면 카드 자체가 나오지 않는다 — 아직
      // 저장한 적 없는 트레이너의 화면은 지금과 같다.
      ...?_savedProgramsCard(),
      const SizedBox(height: AppSpacing.lg),
      _SendHistoryCard(client: client),
    ];
  }

  void _applyTemplate(ProgramTemplate template) => setState(() {
    _appliedTemplate = template;
    _templateRevision++;
    _registered = false;
    _sent = false;
  });

  /// The saved-program list, or null when the trainer has saved none.
  ///
  /// Returning null (rather than an empty card) keeps the tab exactly as it
  /// is today for anyone who has never used 저장 (#708).
  List<Widget>? _savedProgramsCard() {
    final AppLocalizations l = AppLocalizations.of(context);
    final drafts = ref.watch(trainerProgramDraftsProvider).valueOrNull;
    if (drafts == null || drafts.isEmpty) return null;
    return <Widget>[
      const SizedBox(height: AppSpacing.lg),
      SectionCard(
        key: const ValueKey<String>('saved-programs-card'),
        title: l.programSavedTitle,
        icon: Icons.bookmark_outline,
        dense: true,
        trailing: _openDraftId == null
            ? null
            : TextButton(
                key: const ValueKey<String>('saved-programs-new'),
                onPressed: _startNewDraft,
                child: Text(l.programSavedNew),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final draft in drafts)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: draft.id == _openDraftId
                      ? AppColors.accentSurface
                      : AppColors.inputBackground,
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  child: InkWell(
                    key: ValueKey<String>('saved-program-${draft.id}'),
                    onTap: () => _openDraft(draft),
                    borderRadius: const BorderRadius.all(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  draft.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  <String>[
                                    if (draft.goal.isNotEmpty) draft.goal,
                                    if (draft.period.isNotEmpty) draft.period,
                                    l.programSavedExerciseCount(
                                      draft.exerciseCount,
                                    ),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.subtleForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: ValueKey<String>(
                              'saved-program-delete-${draft.id}',
                            ),
                            tooltip: l.actionDelete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _deleteDraft(draft),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// AI 가 준비한 개인운동 제안 — 정규 프로그램 편집기 **위**에 둔다. (#790)
  ///
  /// 위치가 뜻이다. 개인운동은 PT 사이를 메우는 짧은 운동이고 정규 프로그램은
  /// 기간 전체의 계획이라, 같은 프로그램 탭 안에 두더라도 편집기에 섞지 않는다 —
  /// 여기서 하는 일은 편집이 아니라 판단(추천/수정 후 추천/추천 안 함)이다.
  ///
  /// A/B 후보 생성 흐름을 펼친 동안에는 감춘다. 그때 트레이너는 정규 프로그램을
  /// 만들고 있고, 화면에 판단할 것이 둘이면 어느 쪽 작업인지 흐려진다.
  List<Widget> _suggestionChildren(TrainerClient client) {
    if (_showOptionsFlow) return const <Widget>[];
    return <Widget>[
      RoutineSuggestionReviewCard(
        key: ValueKey<String>('routine-suggestions-${client.id}'),
        clientId: client.id,
        clientName: client.name,
      ),
      const SizedBox(height: AppSpacing.lg),
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
          style: const TextStyle(color: AppColors.mutedForeground),
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
                    initialDraft: _openDraftSeed,
                    onSave: _saveDraft,
                    saving: _savingDraft,
                    editingSaved: _openDraftId != null,
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
  /// 한 줄 높이. 이름 · 목표 · 이행률 세 줄이 들어간다.
  ///
  /// 예전에는 `오늘`/`5일 전` 같은 마지막 루틴 시각이 한 줄 더 있었다. 지웠다
  /// (#1027) — 목록을 훑는 이유는 누가 처지는지 견주려는 것이고, 그 답은
  /// 이행률 막대가 한다. 상대시간은 그 옆에서 시선만 가져갔다.
  ///
  /// 웹에서는 줄 안의 글이 브라우저 기본 글꼴로 몇 px 넘쳐 줄무늬가 뜬 적이
  /// 있다(#958) — 테스트 글꼴보다 줄 높이가 살짝 크다. 그만큼 여유를 둔다.
  static const double _baseRowHeight = 88;
  static const int _visibleRows = 5;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(_MemberProgramList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId ||
        oldWidget.clients.length != widget.clients.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealSelected() {
    if (!_scroll.hasClients) return;
    final rowHeight = _rowHeight(context);
    final index = widget.clients.indexWhere(
      (client) => client.id == widget.selectedId,
    );
    if (index < 0) return;
    final top = index * rowHeight;
    final bottom = top + rowHeight;
    final viewportTop = _scroll.offset;
    final viewportBottom = viewportTop + _scroll.position.viewportDimension;
    final target = top < viewportTop
        ? top
        : bottom > viewportBottom
        ? bottom - _scroll.position.viewportDimension
        : viewportTop;
    if (target == viewportTop) return;
    _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rowHeight = _rowHeight(context);
    return SectionCard(
      // 리포트 탭 좌측 고객 카드와 같은 제목·아이콘을 쓴다 — 두 탭이 같은
      // `왼쪽 고객 열 + 오른쪽 작업 영역` 구조라, 카드가 서로 다른 이름을
      // 달고 있으면 같은 목록인지 매번 다시 읽어야 한다. (#958)
      title: l.navClients,
      icon: Icons.people_outline,
      dense: true,
      child: SizedBox(
        height: rowHeight * _visibleRows,
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: widget.clients.length > _visibleRows,
          child: ListView.builder(
            key: const ValueKey<String>('program-client-list-scroll'),
            controller: _scroll,
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            itemCount: widget.clients.length,
            itemExtent: rowHeight,
            itemBuilder: (context, index) {
              final client = widget.clients[index];
              final selected = client.id == widget.selectedId;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Material(
                  key: ValueKey<String>('program-client-${client.id}'),
                  color: selected
                      ? AppColors.accentSurface
                      : Colors.transparent,
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  child: InkWell(
                    onTap: () => widget.onSelect(client.id),
                    borderRadius: const BorderRadius.all(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClientAvatar(label: client.avatar, size: 32),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                ClientIdentity(
                                  client: client,
                                  nameStyle: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.foreground,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // 목표는 늘 보인다. 전에는 `lastRoutine` 이
                                // 비었을 때만 그 자리를 빌려 써서, 루틴을 한
                                // 번이라도 보낸 고객은 목표가 사라졌다(#898).
                                ClientGoalLabel(client: client),
                                const SizedBox(height: 4),
                                // 이행률은 막대로 그린다 — 숫자만 적혀 있으면
                                // 목록을 훑으며 누가 처지는지 견주려고 다섯
                                // 개를 눈으로 비교해야 했다(#899). `고객 관리`
                                // 탭 카드가 이미 쓰던 [라벨][막대][값] 모양을
                                // 그대로 가져온다.
                                //
                                // 라벨은 고정 폭 안에서 줄여 그린다. 한 줄
                                // 글로 두었을 때 영어의 `Workout completion
                                // 72%` 가 배율 1.3 에서 접혀 고정 행 높이를
                                // 넘긴 적이 있다(#849).
                                //
                                // 이행률이 낮아도 **빨강으로 칠하지 않는다**
                                // (#913). 이 앱에서 빨강은 `목표 초과` 다 —
                                // 나트륨·당류가 기준을 넘었다는 뜻으로 회원
                                // 앱과 색을 맞춰 둔 상태다(#690). 이행률이
                                // 낮은 것은 초과가 아니라 아직 덜 한 것이고,
                                // 그 사실은 막대 길이와 값이 이미 말한다.
                                // 같은 카드의 `요일별 운동 이행률` 도 남색
                                // 계열로만 그린다.
                                () {
                                  final mean = recordedCompletionMean(client);
                                  return InlineBarValue(
                                    label: l.reportsCompletionAvg,
                                    fraction: mean == null ? null : mean / 100,
                                    // 기록이 없으면 `-` 가 아니라 왜 빈지를
                                    // 적는다. 줄 전체가 흐려져 읽거나 누를
                                    // 것이 없다는 뜻이 함께 전해진다.
                                    text: mean == null
                                        ? l.reportsDataInsufficient
                                        : '${mean.round()}%',
                                    // `데이터 부족` 이 들어갈 폭.
                                    valueWidth: mean == null ? 60 : 40,
                                  );
                                }(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _rowHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final extraScale = (scale - 1).clamp(0.0, 2.0);
    return _baseRowHeight + 84 * extraScale;
  }
}

/// 요일별 운동 이행률(월→일). (#899)
///
/// 프로그램을 짜는 화면인데 이 회원의 한 주가 어떻게 흘렀는지가 없었다 —
/// 어느 요일이 비었는지가 다음 주 프로그램을 정하는 자료다.
///
/// 리포트 탭이 쓰는 [BarSeriesChart] 를 그대로 쓴다. 두 탭이 같은 그림으로
/// 말해야 트레이너가 같은 값을 두 번 읽지 않는다.
///
/// 요약 카드가 사라진 뒤로는 `운동` 쪽 아래에 선다(#1027). 제목은 카드가
/// 들므로 그래프 위에 같은 문구를 한 번 더 적지 않는다.
class _WeekCompletionBars extends StatelessWidget {
  const _WeekCompletionBars({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final week = client.weekCompletion;
    return SectionCard(
      title: l.reportsCompletionByDay,
      icon: Icons.calendar_view_week_outlined,
      dense: true,
      child: week.length != weekdayCount
          ? EmptyHint(message: l.reportsNoWorkoutsThisWeek)
          : BarSeriesChart(
            key: const ValueKey<String>('program-week-completion-chart'),
            title: l.reportsCompletionByDay,
            values: week,
            labels: weekdayLabels(l),
            maxValue: 100,
            height: 72,
            showValues: true,
            valueSuffix: '%',
            // 로스터의 계열은 늘 이번 주다 — 아직 오지 않은 요일을 0% 로
            // 그리면 `0% 수행` 이라는 다른 뜻이 된다.
            pendingFromIndex: elapsedWeekdays(nowKst()),
            // 지난 날인데 기록이 없는 요일도 0% 가 아니다.
            missingIndices: <int>{
              for (var i = 0; i < elapsedWeekdays(nowKst()); i++)
                if (i < week.length && week[i] == 0) i,
            },
          ),
    );
  }
}

enum _ClientDataView { diet, workout }

/// 고른 고객의 식단 · 운동 — 프로그램 탭에서 가장 자주 보는 값이다.
///
/// 넓은 화면에서는 오른쪽 열의 맨 위, 좁은 화면에서는 페이지 맨 위에 온다.
/// 예전에는 고객 요약 카드가 그 자리를 차지하고 이 영역이 그 아래(또는
/// 옆)였다 — 요약 카드가 말하던 것(이름 · 목표 · 최근 세션 · 초과 배지)은
/// 왼쪽 고객 목록과 아래 카드들이 이미 하고 있어, 카드를 지우고 자리를
/// 넘겼다(#1027).
class _ClientDataSwitcher extends ConsumerStatefulWidget {
  const _ClientDataSwitcher({super.key, required this.client});

  final TrainerClient client;

  @override
  ConsumerState<_ClientDataSwitcher> createState() =>
      _ClientDataSwitcherState();
}

class _ClientDataSwitcherState extends ConsumerState<_ClientDataSwitcher> {
  _ClientDataView _view = _ClientDataView.diet;

  /// 프로그램 탭에서도 `오늘 / 이번 주 / 이번 달` 을 고를 수 있다(#914).
  /// 다음 주 프로그램을 짜는 화면인데 오늘 하루만 보이면, 무엇을 근거로 짜야
  /// 하는지가 화면 밖에 있다.
  ClientPeriod _period = ClientPeriod.today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      key: const ValueKey<String>('program-client-data-switcher'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 기간 토글은 전환 스트립과 **한 줄**에 둔다(#943).
        //
        // 회원 앱처럼 카드 위에 `제목 + 토글` 한 줄을 따로 두면 고객 데이터 열이
        // 그만큼 길어져, 폭 1552px·높이 900px 에서 당류 카드가 화면 밖으로 7.8px
        // 밀렸다. 스트립이 이미 `식단`/`운동` 이라는 제목 노릇을 하고 있으므로
        // 그 줄의 오른쪽 끝을 빌려 쓴다 — 세로 자리를 한 픽셀도 더 쓰지 않고,
        // 기간을 바꿔도 토글이 움직이지 않는다.
        Row(
          children: <Widget>[
            Expanded(child: _dataTabs(l)),
            const SizedBox(width: AppSpacing.sm),
            // 토글은 줄어들되 잘리지는 않는다. 영어 `Today / This week /
            // This month` 는 배율 1.3 · 폭 1024 에서 줄을 115px 넘겼다 —
            // FittedBox 가 세 칸을 다 보여 준 채 통째로 작게 그린다.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: ClientPeriodToggle(
                  active: _period,
                  onChanged: (ClientPeriod p) => setState(() => _period = p),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // 전환에 애니메이션을 두지 않는다(#1027). 식단 그래프는 움직이지 않는
        // 그림이어야 한다는 것이 이번 결정이고, 카드를 페이드로 바꾸면 기간을
        // 옮길 때마다 그 그래프가 다시 떠오른다.
        if (_view == _ClientDataView.diet)
          if (_period == ClientPeriod.today)
            NutritionSummaryCard(
              key: ValueKey<String>('program-diet-${widget.client.id}'),
              client: widget.client,
            )
          else
            ClientDietPeriodCard(
              // 키에 기간을 넣지 않는다. 넣으면 주 ↔ 달을 옮길 때마다 카드가
              // 새로 만들어져, 나트륨을 보다 기간만 넓힌 트레이너가 지표를
              // 다시 골라야 했다.
              key: ValueKey<String>(
                'program-diet-period-${widget.client.id}',
              ),
              clientId: widget.client.id,
              period: _period,
            )
        else ...<Widget>[
          ClientExerciseStatusCard(
            key: ValueKey<String>('program-workout-${widget.client.id}'),
            clientId: widget.client.id,
            period: _period,
            // 운동 그래프 아래에 세트 · 횟수 · 시간을 붙인다. 그래프는 "얼마나
            // 오래" 만 말해서, 다음 프로그램을 짤 때 정작 필요한 "무엇을 몇
            // 세트" 가 화면 밖에 있었다.
            clientName: widget.client.name,
          ),
          const SizedBox(height: AppSpacing.md),
          // 요약 카드가 들고 있던 그림이다. 카드는 지웠지만 이 그래프는
          // 운동 데이터라 운동 쪽으로 옮겼다 — 어느 요일이 비었는지가 다음
          // 주 프로그램을 정하는 자료다.
          _WeekCompletionBars(client: widget.client),
        ],
      ],
    );
  }

  /// 식단 ↔ 운동 전환 스트립.
  Widget _dataTabs(AppLocalizations l) => Container(
    key: const ValueKey<String>('program-client-data-tabs'),
    height: 44,
    padding: EdgeInsets.zero,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: const BorderRadius.all(AppRadius.pill),
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: const BorderRadius.all(AppRadius.pill),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: _ClientDataTab(
            label: l.clientTabDiet,
            icon: Icons.restaurant_outlined,
            selected: _view == _ClientDataView.diet,
            onTap: () => setState(() {
              _view = _ClientDataView.diet;
            }),
          ),
        ),
        Expanded(
          child: _ClientDataTab(
            label: l.clientTabWorkout,
            icon: Icons.fitness_center_outlined,
            selected: _view == _ClientDataView.workout,
            onTap: () => setState(() {
              _view = _ClientDataView.workout;
            }),
          ),
        ),
      ],
    ),
  );
}

class _ClientDataTab extends StatelessWidget {
  const _ClientDataTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primary : AppColors.mutedForeground;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? AppColors.card : const Color(0x00000000),
          borderRadius: const BorderRadius.all(AppRadius.pill),
          border: selected ? Border.all(color: AppColors.card) : null,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: const Color(0x00000000),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              ClientIdentity(
                client: client,
                stacked: true,
                nameStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.primaryForeground
                      : AppColors.foreground,
                ),
                demographicsStyle: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.primaryForeground.withValues(alpha: 0.8)
                      : AppColors.subtleForeground,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
  const _AiAssistantPrompt({
    super.key,
    required this.clientName,
    required this.onTap,
  });

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
                      style: const TextStyle(
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
  final d = nowKst().add(Duration(days: offset));
  return '${d.month}/${d.day}';
}

/// One selectable register-day chip.
class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({super.key, required this.onApply});

  final ValueChanged<ProgramTemplate> onApply;

  /// 만들기·편집 다이얼로그. 시작 구성을 열면 저장이 '새로 만들기' 가 된다.
  Future<void> _edit(BuildContext context, {ProgramTemplate? template}) {
    return showDialog<void>(
      context: context,
      builder: (_) => ProgramTemplateDialog(template: template),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ProgramTemplate template,
  ) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l.coachTemplateDeleteConfirm(template.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.coachTemplateDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(trainerProgramTemplateRepositoryProvider)
          .delete(template.id);
      ref.invalidate(programTemplatesProvider);
    } on AppError {
      messenger.showSnackBar(
        SnackBar(content: Text(l.coachTemplateDeleteFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final templatesAsync = ref.watch(programTemplatesProvider);
    // 데모는 읽기 전용이다 — 저장할 백엔드가 없어, 만든 것이 새로고침 한 번에
    // 사라지면 만들 수 있다고 말한 화면이 거짓이 된다. (#920)
    final canEdit = ref.watch(programTemplateEditingEnabledProvider);
    final templates = templatesAsync.valueOrNull ?? const <ProgramTemplate>[];
    if (templatesAsync.hasError && templates.isEmpty) {
      return SectionCard(
        title: l.coachTemplates,
        icon: Icons.dashboard_customize_outlined,
        dense: true,
        child: Text(
          l.coachTemplateLoadFailed,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }
    return SectionCard(
      title: l.coachTemplates,
      icon: Icons.dashboard_customize_outlined,
      dense: true,
      trailing: canEdit
          ? TextButton.icon(
              key: const ValueKey<String>('template-new'),
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.coachTemplateNew),
            )
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 3 : 1;
          final width =
              (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final template in templates)
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
                                if (canEdit)
                                  _TemplateMenu(
                                    template: template,
                                    onEdit: () =>
                                        _edit(context, template: template),
                                    onDelete: template.isStarter
                                        ? null
                                        : () => _delete(context, ref, template),
                                  )
                                else
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

/// 템플릿 한 장의 편집·삭제 메뉴.
///
/// 시작 구성에는 삭제가 없다 — 저장된 행이 아니라 지울 것이 없고, 지운 것처럼
/// 보였다가 다음 조회에서 되돌아오면 화면이 거짓말을 한 것이 된다. (#920)
class _TemplateMenu extends StatelessWidget {
  const _TemplateMenu({
    required this.template,
    required this.onEdit,
    this.onDelete,
  });

  final ProgramTemplate template;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      key: ValueKey<String>('template-menu-${template.id}'),
      tooltip: '',
      padding: EdgeInsets.zero,
      iconSize: 17,
      icon: const Icon(Icons.more_horiz, color: AppColors.subtleForeground),
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete?.call(),
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'edit',
          child: Text(
            template.isStarter
                ? l.coachTemplateSaveAsMine
                : l.coachTemplateEdit,
          ),
        ),
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: Text(l.coachTemplateDelete),
          ),
      ],
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
    final today = ymd(nowKst());

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
                          style: const TextStyle(
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
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                      // 보낸 뒤 물리는 자리. 여기 목록이 배정된 개인운동을
                      // 보여 주는 유일한 곳인데 취소가 없어서, 잘못 보냈을 때
                      // 고객 탭까지 옮겨 가야 지울 수 있었다. (#1020)
                      _CancelRoutineButton(
                        clientId: client.id,
                        routine: routine,
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

/// 배정한 개인운동을 물리는 버튼. (#1020)
///
/// 지운다고 회원이 이미 수행한 기록까지 사라지지는 않는다 — 지우는 것은
/// **배정**이지 한 일이 아니다.
class _CancelRoutineButton extends ConsumerStatefulWidget {
  const _CancelRoutineButton({required this.clientId, required this.routine});

  final String clientId;
  final AssignedRoutine routine;

  @override
  ConsumerState<_CancelRoutineButton> createState() =>
      _CancelRoutineButtonState();
}

class _CancelRoutineButtonState extends ConsumerState<_CancelRoutineButton> {
  bool _busy = false;

  Future<void> _cancel() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l.routineDeleteTitle),
        content: Text(l.routineDeleteBody(widget.routine.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            key: const ValueKey<String>('confirm-cancel-routine'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.actionDelete,
              style: const TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(trainerRoutineRepositoryProvider)
          .deleteRoutine(widget.clientId, widget.routine.id);
      messenger.showSnackBar(SnackBar(content: Text(l.routineDeleted)));
    } on StateError {
      // 404 — 이미 없는 것을 지우려 했다. 목적은 이뤄진 셈이라 목록만 다시 읽고
      // 그 줄을 화면에서 걷어낸다.
      messenger.showSnackBar(SnackBar(content: Text(l.routineAlreadyGone)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.routineDeleteFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(assignedRoutinesProvider(widget.clientId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.only(left: AppSpacing.sm),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      key: ValueKey<String>('history-cancel-routine-${widget.routine.id}'),
      onPressed: _cancel,
      icon: const Icon(Icons.close_rounded, size: 15),
      color: AppColors.mutedForeground,
      tooltip: AppLocalizations.of(context).routineDelete,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: EdgeInsets.zero,
    );
  }
}
