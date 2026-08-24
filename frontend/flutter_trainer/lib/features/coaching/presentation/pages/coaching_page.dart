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
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/ai_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_program_template_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_options.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';
import 'package:oncare_trainer/features/coaching/presentation/pages/ai_routine_options_flow.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_editor_workspace.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_final_review_card.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_template_dialog.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_suggestion_review_card.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays, weekdayCount, weekdayLabels;
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
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

  /// PT 스케줄에 등록할 날. 기본값은 오늘.
  DateTime _registerDate = _todayKst();

  /// PT 스케줄에 등록할 시각. 기본값은 오전 10시 — 날짜 선택 박스 옆에서
  /// 함께 고른다.
  TimeOfDay _registerTime = const TimeOfDay(hour: 10, minute: 0);

  /// A template save is in flight — blocks re-entry so one click is one
  /// template (#1028).
  bool _savingTemplate = false;

  /// 최종 검토 중인 구성 — 이것이 곧 **전송 게이트**다 (#1028).
  ///
  /// null 이면 편집 중이라는 뜻이고, 그때는 [_assignReviewedDraft] 도
  /// [_registerReviewedDraft] 도 아무 일도 하지 않는다. 두 함수가 인자로 초안을
  /// 받지 않고 이 값만 읽는 것이 핵심이다 — 어떤 위젯도 "임의의 초안"을 전송
  /// 경로에 밀어 넣을 수 없고, 트레이너가 최종 검토에서 실제로 보고 있는 그
  /// 스냅샷만 나간다. 화면에 그려진 내용과 payload 가 같은 객체다.
  ProgramEditorState? _reviewDraft;

  /// 최종 검토를 연다. **전송이 아니다** — 편집기가 넘긴 스냅샷을 붙잡아 둘 뿐.
  void _openFinalReview(ProgramEditorState draft) {
    setState(() {
      _reviewDraft = draft;
      _sent = false;
      _registered = false;
    });
  }

  /// 편집기로 돌아간다. 검토하던 구성이 그대로 다시 열린다 — 편집기는 검토 중
  /// 접혀 있을 뿐 트리에 남아 있어(아래 [Offstage]) 편집 내용을 잃지 않는다.
  void _closeFinalReview() {
    if (_reviewDraft == null) return;
    setState(() => _reviewDraft = null);
  }

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
      _sent = false;
      _sending = false;
      _registered = false;
      _registerDate = _todayKst();
      _registerTime = const TimeOfDay(hour: 10, minute: 0);
      _appliedTemplate = null;
      _templateRevision = 0;
      _editorRevision = 0;
      // 다른 회원의 최종 검토를 물려받지 않는다 — 검토는 늘 지금 고른
      // 회원의 구성이어야 한다 (#1028).
      _reviewDraft = null;
      // NOTE: _registeringClientIds is intentionally NOT cleared — writes
      // for other clients keep being tracked while the selection changes.
    });
    _sentTimer?.cancel();
    _registerTimer?.cancel();
  }

  bool _isStillSelected(String clientId) =>
      _clientId == null || _clientId == clientId;

  /// 지금 편집기 구성을 프로그램 템플릿으로 저장한다 (#1028).
  ///
  /// 저장 대상은 항상 "고객 리스트 아래 프로그램 템플릿" 목록이다 — 눌렀던
  /// 자리가 곧 저장된 위치라 별도의 "저장한 프로그램" 보관함을 따로 두지
  /// 않는다. 템플릿은 세션 없이 운동 이름·시간·종류만 담는 가벼운 블록이라
  /// (`program_template_dialog.dart` 참고), 세트·횟수·중량 같은 값은 여기서
  /// 저장되지 않는다 — 회원마다 달라지는 값은 템플릿을 적용한 뒤 편집기에서
  /// 다시 정한다는 기존 템플릿 개념을 그대로 따른다.
  ///
  /// 누를 때마다 새 템플릿을 만든다 — "수정 저장" 같은 덮어쓰기 개념을 따로
  /// 두지 않아, 버튼은 항상 `저장`으로 남는다.
  Future<void> _saveTemplate(ProgramEditorState draft) async {
    if (_savingTemplate) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final exercises = <TemplateExercise>[
      for (final session in draft.sessions)
        for (final exercise in session.exercises)
          if (exercise.name.trim().isNotEmpty)
            TemplateExercise(
              name: exercise.name.trim(),
              // 시간 기반 운동만 `duration` 을 채운다 — 세트·중량 기반
              // 운동은 비어 있어, 빈 블록이 되지 않도록 기본값을 둔다(다이얼로그의
              // 새 운동 줄 기본값과 같다, `program_template_dialog.dart`).
              minutes: _templateMinutes(exercise.duration),
              type: kRoutineTypes.contains(exercise.type)
                  ? exercise.type
                  : kRoutineTypes.first,
            ),
    ];
    if (exercises.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.coachTemplateExerciseRequired)),
      );
      return;
    }
    setState(() => _savingTemplate = true);
    try {
      await ref
          .read(trainerProgramTemplateRepositoryProvider)
          .create(
            name: draft.name.trim(),
            goal: draft.goal.trim(),
            exercises: exercises,
          );
      ref.invalidate(programTemplatesProvider);
      if (!mounted) return;
      setState(() => _savingTemplate = false);
      messenger.showSnackBar(SnackBar(content: Text(l.programDraftSaved)));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _savingTemplate = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is AppError
                ? serverDetailOr(l, error.message, l.coachTemplateSaveFailed)
                : l.coachTemplateSaveFailed,
          ),
        ),
      );
    }
  }

  /// 최종 검토 중인 구성을 회원에게 배정한다 (#1028).
  ///
  /// 초안을 인자로 받지 않는다 — [_reviewDraft] 가 비어 있으면(= 최종 검토
  /// 밖이면) 호출 자체가 아무 일도 하지 않는다. 편집기·제안 카드 등 다른
  /// 화면에서 이 경로로 들어올 방법이 없다.
  Future<void> _assignReviewedDraft(TrainerClient client) async {
    final draft = _reviewDraft;
    if (draft == null) return;
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
    // 배정은 여기서 이미 끝났다 — 3열 `전송 이력`(`assignedRoutinesProvider`)
    // 은 실 API 모드에서 1회성 fetch 라 다시 읽으라고 말해 줘야 한다(#1029).
    // 데모의 `assignedRoutinesProvider`/PT 등록이 읽는 `clientSessionsProvider`
    // 는 로컬 DB를 그대로 지켜보는 스트림이라 여기서 손대지 않아도 된다.
    ref.invalidate(assignedRoutinesProvider(client.id));
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
        // 보낸 뒤에는 검토를 닫고 편집기를 새로 세운다 — 이미 나간 구성이
        // 검토 화면에 그대로 남아 있으면 한 번 더 보낼 수 있는 것처럼 읽힌다.
        _reviewDraft = null;
        _editorRevision++;
      });
    });
    // `고객에게 배정` 버튼 하나가 배정과 PT 등록을 함께 한다(#1029) —
    // `assignProgram`/`registerProgram` 은 여전히 서로 다른 API 라 억지로
    // 합치지 않고 순서대로 부른다. 배정이 이미 됐으니 등록이 실패해도
    // 배정 자체를 취소하지 않는다 — [_registerReviewedDraft] 는 자기
    // 몫의 실패만 그 자리에서 따로 알린다(`coachScheduleFailed`), 방금
    // 보인 배정 성공을 덮어쓰지 않는다.
    await _registerReviewedDraft(client);
  }

  /// [_assignReviewedDraft] 가 배정 성공 뒤에만 부른다(#1029) — 이 앱에
  /// PT 등록 버튼은 따로 없다.
  Future<void> _registerReviewedDraft(TrainerClient client) async {
    final draft = _reviewDraft;
    if (draft == null) return;
    if (!draft.supportsAssignment ||
        _registered ||
        _registeringClientIds.contains(client.id)) {
      return;
    }
    final registeredFor = client.id;
    final date = ymd(_registerDate);
    final time =
        '${_registerTime.hour.toString().padLeft(2, '0')}:'
        '${_registerTime.minute.toString().padLeft(2, '0')}';
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
                                  // 오른쪽 열을 세울 만큼 넓지 않은 창에서는 식단·운동이 가운데
                                  // 열 **맨 위**에 온다 — 넓은 화면의 오른쪽 열 맨 위와 같은
                                  // 자리다(#1027). 좁은 화면(`_contextChildren`)도 이미 이
                                  // 순서다.
                                  if (!fullWidth) ...<Widget>[
                                    _ClientDataSwitcher(
                                      key: const ValueKey<String>(
                                        'coaching-wide-client-overview',
                                      ),
                                      client: selected,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    // 3열이 따로 생기지 않는 너비에서도 AI 개인운동 제안은
                                    // 고객 데이터 바로 아래, 작은 카드로 유지한다.
                                    _suggestionColumn(selected),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],
                                  // `AI에게 맞춤 루틴 요청하기` 는 더 이상 클릭해야 나타나지
                                  // 않는다 — `_editorChildren` 이 프로그램 정보 박스 위에 늘
                                  // 붙여 둔다(#1028).
                                  ..._editorChildren(selected),
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
                                    // AI 개인운동 제안은 식단·운동 바로
                                    // 아래, 전송 이력 위에 둔다 — 고객
                                    // 데이터를 본 직후 판단하는 흐름이다.
                                    _suggestionColumn(selected),
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
  ///
  /// 저장한 프로그램을 위한 별도 보관함은 없다 — `저장` 이 곧장 `_TemplateCard`
  /// 목록에 쓰기 때문에, 방금 저장한 결과도 이 카드에서 바로 보인다 (#1028).
  List<Widget> _libraryChildren(TrainerClient client) {
    return <Widget>[
      _TemplateCard(onApply: _applyTemplate),
      const SizedBox(height: AppSpacing.lg),
      _SendHistoryCard(client: client),
    ];
  }

  void _applyTemplate(ProgramTemplate template) => setState(() {
    _appliedTemplate = template;
    _templateRevision++;
    _registered = false;
    _sent = false;
    // 템플릿을 얹으면 구성이 달라진다 — 이미 검토하던 스냅샷은 더 이상 지금
    // 구성이 아니므로 편집기로 돌려보내 다시 검토하게 한다 (#1028).
    _reviewDraft = null;
  });

  /// AI 가 준비한 개인운동 제안. (#790)
  ///
  /// 개인운동은 PT 사이를 메우는 짧은 운동이고 정규 프로그램은 기간 전체의
  /// 계획이라, 같은 프로그램 탭 안에 두더라도 편집기에 섞지 않는다 — 여기서
  /// 하는 일은 편집이 아니라 판단(추천/수정 후 추천/추천 안 함)이다. 넓은
  /// 화면에서는 오른쪽 고객 데이터 열의 식단·운동 바로 아래, 전송 이력 위에
  /// 작은 카드로 두고(호출부 참고), 열을 나눌 폭이 없는 화면에서만 이
  /// 목록으로 편집기 위에 쌓인다.
  List<Widget> _suggestionChildren(TrainerClient client) {
    return <Widget>[
      _suggestionColumn(client),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  Widget _suggestionColumn(TrainerClient client) => RoutineSuggestionReviewCard(
    key: ValueKey<String>('routine-suggestions-${client.id}'),
    clientId: client.id,
    clientName: client.name,
  );

  /// The routine editor column (right column on wide).
  ///
  /// `AI에게 맞춤 루틴 요청하기` 는 더 이상 클릭해야 나타나지 않는다 —
  /// `프로그램 정보` 박스([ProgramEditorWorkspace]) 바로 위에 항상 붙인다.
  /// 3단계 최종 검토의 `템플릿에 반영` 이 그 결과를 [ProgramEditorWorkspace]
  /// 의 `aiSuggestions` 로 넘기면 편집기가 세션 1에 병합할 뿐, 이 흐름도
  /// 편집기도 여기서 회원에게 직접 전송하지 않는다 — 실제 전송은
  /// [ProgramFinalReviewCard] 하나뿐이다.
  List<Widget> _editorChildren(TrainerClient client) {
    final AppLocalizations l = AppLocalizations.of(context);
    final routineAsync = ref.watch(
      aiRoutineProvider((id: client.id, name: client.name)),
    );

    return <Widget>[
      routineAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          l.routinesLoadFailed,
          style: const TextStyle(color: AppColors.mutedForeground),
        ),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 최종 검토 중에는 편집기와 함께 접어 둔다 — 상태(단계·입력값)는
            // 잃지 않되(Offstage) 검토 화면과 동시에 조작하지 못하게 한다.
            Offstage(
              offstage: _reviewDraft != null,
              child: AiRoutineOptionsFlow(
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
                          sets: exercises[index].sets,
                          reps: exercises[index].reps,
                        ),
                    ];
                  });
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 최종 검토 중에는 편집기를 접어 둔다 — **트리에서 빼지
            // 않는 이유**는 편집 상태가 편집기 State 에 있기 때문이다.
            // 빼면 돌아왔을 때 트레이너가 쓴 내용이 사라진다. 접힌
            // 동안에는 hit test 도 되지 않아 저장·검토 버튼이 눌리지
            // 않는다. 애초에 이 편집기에는 전송 버튼이 없다 (#1028).
            Offstage(
              offstage: _reviewDraft != null,
              child: ProgramEditorWorkspace(
                key: ValueKey<String>(
                  'program-editor-${client.id}-$_editorRevision',
                ),
                clientGoal: client.goal,
                aiSuggestions: _generatedRecommendations[client.id] ?? items,
                template: _appliedTemplate,
                templateRevision: _templateRevision,
                onReview: _openFinalReview,
                onSave: _saveTemplate,
                saving: _savingTemplate,
              ),
            ),
            // 프로그램 편집기 경로에서 회원에게 실제로 보낼 수 있는
            // 유일한 화면.
            if (_reviewDraft != null)
              ProgramFinalReviewCard(
                draft: _reviewDraft!,
                clientName: client.name,
                registerDate: _registerDate,
                onRegisterDateChanged: (date) => setState(() {
                  _registerDate = date;
                  _registered = false;
                }),
                registerTime: _registerTime,
                onRegisterTimeChanged: (time) => setState(() {
                  _registerTime = time;
                  _registered = false;
                }),
                onBack: _closeFinalReview,
                onAssign: () => _assignReviewedDraft(client),
                assigning: _sending || _sent,
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
                        _dateChipLabel(l, _registerDate),
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      l.coachFindInSchedule(
                        _dateChipLabel(l, _registerDate),
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
  /// 한 줄 높이. 이름 · 목표 두 줄이 들어간다.
  ///
  /// 이행률 막대는 뺐다(#1029) — 이 목록은 회원을 고르는 자리고, 이행률
  /// 비교는 리포트 탭의 몫이다. 예전에는 `오늘`/`5일 전` 같은 마지막 루틴
  /// 시각도 있었는데 그것도 지운 채였다(#1027).
  ///
  /// 웹에서는 줄 안의 글이 브라우저 기본 글꼴로 몇 px 넘쳐 줄무늬가 뜬 적이
  /// 있다(#958) — 테스트 글꼴보다 줄 높이가 살짝 크다. 그만큼 여유를 둔다.
  static const double _baseRowHeight = 64;
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
    return _baseRowHeight + 56 * extraScale;
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

/// 운동 한 줄을 템플릿에 담을 때 쓸 시간(분). `duration` 이 비어 있거나
/// 0 이하면(세트·중량 위주 운동) 새 운동 줄의 기본값(10분, 다이얼로그와 동일)을
/// 대신 쓴다 — 값이 없다고 그 운동째로 템플릿에서 빠지지 않게 한다.
int _templateMinutes(String duration) {
  final parsed = int.tryParse(duration.trim());
  return parsed != null && parsed > 0 ? parsed : 10;
}

/// 오늘 자정(KST) — PT 등록 날짜의 기본값이자 고를 수 있는 가장 이른 날.
DateTime _todayKst() {
  final now = nowKst();
  return DateTime(now.year, now.month, now.day);
}

/// [date] 를 사람이 읽는 짧은 라벨로 — 오늘/내일은 그렇게, 그 뒤는 `M/D`.
String _dateChipLabel(AppLocalizations l, DateTime date) {
  final today = _todayKst();
  if (ymd(date) == ymd(today)) return l.labelToday;
  if (ymd(date) == ymd(today.add(const Duration(days: 1)))) {
    return l.labelTomorrow;
  }
  return '${date.month}/${date.day}';
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
      // 아이콘만 쓴다(#1028) — 이 카드는 260px 고정 폭 사이드바에 있어,
      // 영어·큰 글자 배율에서 "새 템플릿" 글자가 제목과 함께 넘친다.
      trailing: canEdit
          ? IconButton(
              key: const ValueKey<String>('template-new'),
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add, size: 18),
              tooltip: l.coachTemplateNew,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
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

/// 템플릿 한 장의 편집·삭제 메뉴 — 기본 템플릿(시작 구성)도 사용자 템플릿과
/// 같은 두 항목을 보여 준다(#1029).
///
/// 시작 구성은 삭제만 항목 자체가 아니라 **비활성**으로 남긴다 — 서버 행이
/// 아예 없어(합성 `starter:` id) 지울 것이 없다. 항목을 통째로 숨기면 두
/// 템플릿 종류가 다른 기능을 가진 것처럼 보이지만, 회색으로 남기면 "이건 못
/// 하는 동작" 이라는 뜻이 그대로 전해진다 — 지운 것처럼 보였다가 다음 조회에
/// 되돌아오는 거짓말은 여전히 만들지 않는다(#920).
///
/// 고친다는 동작 자체는 같지만 결과가 다르다 — 시작 구성은 고치면 내 첫
/// 템플릿으로 **새로 저장**되고, 내 템플릿은 그 행을 그대로 고친다. 그래서
/// 라벨도 다르게 남긴다 — 같은 말로 두면 실제로 무슨 일이 일어나는지 감춘다.
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
      color: AppColors.card,
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.md),
        side: BorderSide(color: AppColors.borderStrong),
      ),
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete?.call(),
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'edit',
          child: _TemplateMenuLabel(
            icon: Icons.edit_outlined,
            label: l.coachTemplateEdit,
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          enabled: onDelete != null,
          child: _TemplateMenuLabel(
            icon: Icons.delete_outline,
            label: l.coachTemplateDelete,
            destructive: true,
          ),
        ),
      ],
    );
  }
}

/// 팝업 메뉴 한 줄 — 아이콘 + 글자. 프로그램 편집기의 세션·운동 메뉴
/// (`_MenuLabel`)와 같은 모양을 쓴다.
class _TemplateMenuLabel extends StatelessWidget {
  const _TemplateMenuLabel({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.destructive : AppColors.foreground;
    return Row(
      children: <Widget>[
        Icon(icon, size: 17, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: TextStyle(color: color, fontSize: 12.5)),
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
