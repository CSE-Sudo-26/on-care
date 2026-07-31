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
import 'package:oncare_trainer/features/ai_routine/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/ai_routine_repository.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/ai_routine/domain/entities/routine_options.dart';
import 'package:oncare_trainer/features/ai_routine/presentation/pages/ai_routine_options_flow.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/content_frame.dart';
import 'package:oncare_trainer/shared/widgets/metric_tile.dart';

/// Minute options offered for every routine item (mock: 10~45분 chips).
const List<int> _minuteOptions = <int>[10, 15, 20, 30, 45];

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

/// AI 루틴 tab — pick a client, review their diet summary + the AI's
/// suggested routine, tweak names/minutes, add custom exercises, and
/// send. Edits and the sent state are in-memory (mock), matching the
/// Figma behaviour.
class AiRoutinePage extends ConsumerStatefulWidget {
  /// Creates the AI routine tab.
  const AiRoutinePage({super.key});

  @override
  ConsumerState<AiRoutinePage> createState() => _AiRoutinePageState();
}

class _AiRoutinePageState extends ConsumerState<AiRoutinePage> {
  String? _clientId; // null until clients load (defaults to the first)
  final Map<String, int> _minuteEdits = <String, int>{};
  final Map<String, String> _nameEdits = <String, String>{};

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

  void _selectClient(String id) {
    if (_clientId == id) return;
    setState(() {
      _clientId = id;
      // A different client gets a clean slate, like the mock.
      _minuteEdits.clear();
      _nameEdits.clear();
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
    final total = items
        .where((i) => !_removed.contains(i.id))
        .fold<int>(0, (sum, i) => sum + (_minuteEdits[i.id] ?? i.minutes));
    final custom = _custom.fold<int>(0, (sum, c) => sum + c.minutes);

    // Capture who this send is for: the trainer can switch clients while
    // it saves, and the '전송 완료' flash + edit-reset timer must land on
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
                ? '응답을 받지 못했어요. 고객의 받은 루틴을 확인한 뒤 필요한 경우에만 다시 보내주세요'
                : '전송에 실패했어요. 다시 시도해 주세요',
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
    return <Map<String, Object?>>[
      for (final item in items)
        if (!_removed.contains(item.id))
          <String, Object?>{
            'name': _nameEdits[item.id] ?? item.name,
            'sets': 1,
            'reps': '${_minuteEdits[item.id] ?? item.minutes}분',
            'weight': '-',
          },
      for (final c in _custom)
        <String, Object?>{
          'name': c.name,
          'sets': 1,
          'reps': '${c.minutes}분',
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
    final active = items.where((i) => !_removed.contains(i.id)).toList();
    final result = summaryTypeAndSource(
      aiItemTypes: <String>[for (final i in active) i.type],
      customItemTypes: <String>[for (final c in _custom) c.type],
    );
    final names = <String>[
      for (final i in active) _nameEdits[i.id] ?? i.name,
      for (final c in _custom) c.name,
    ];
    return AssignedRoutine(
      id: '',
      name: 'AI 맞춤 루틴',
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
      // Every exercise was removed — tell the trainer instead of a
      // silent no-op (review PR 220).
      messenger.showSnackBar(
        const SnackBar(content: Text('운동을 하나 이상 추가해 주세요')),
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
        messenger.showSnackBar(
          const SnackBar(content: Text('스케줄 등록에 실패했어요. 다시 시도해 주세요')),
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
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(
            child: Text(
              '고객 정보를 불러오지 못했어요',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ),
          data: (clients) {
            if (clients.isEmpty) {
              return const Center(
                child: Text(
                  '등록된 고객이 없어요',
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
                  return ContentFrame(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.xxl,
                      ),
                      children: <Widget>[
                        ..._overviewChildren(clients, selected),
                        const SizedBox(height: AppSpacing.lg),
                        ..._editorChildren(selected),
                      ],
                    ),
                  );
                }
                // Wide: client/diet overview docks left, the routine
                // editor gets its own column.
                return ContentFrame(
                  maxWidth: AppLayout.wideMaxWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: AppLayout.splitListWidth,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.lg,
                            AppSpacing.xl,
                            AppSpacing.xxl,
                          ),
                          children: _overviewChildren(clients, selected),
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        color: AppColors.borderStrong,
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.lg,
                            AppSpacing.xl,
                            AppSpacing.xxl,
                          ),
                          children: _editorChildren(selected),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Title, client picker, and diet summary (left column on wide).
  List<Widget> _overviewChildren(
    List<TrainerClient> clients,
    TrainerClient client,
  ) {
    return <Widget>[
      Text(
        'AI 루틴 생성',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const Text(
        '고객 식단 · 건강 데이터 기반',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: AppColors.subtleForeground,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      _sectionLabel('고객 선택'),
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
      _sectionLabel('오늘 식단 요약'),
      const SizedBox(height: AppSpacing.sm),
      _DietSummaryCard(client: client),
    ];
  }

  /// The routine editor column (right column on wide).
  List<Widget> _editorChildren(TrainerClient client) {
    final routineAsync = ref.watch(
      aiRoutineProvider((id: client.id, name: client.name)),
    );

    return <Widget>[
      Row(
        children: <Widget>[
          _sectionLabel('AI 추천 루틴'),
          if (_showOptionsFlow) ...<Widget>[
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _showOptionsFlow = false),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('추천 목록으로'),
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
        error: (e, _) => const Text(
          '루틴을 불러오지 못했어요',
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
                        type: item.type,
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
                          reason: 'AI 생성 후 트레이너 검토 완료',
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
                      reason: '트레이너 추가',
                      isCustom: true,
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
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        '고객 앱에 알림이 전송됐어요',
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
                        ? '${_dateChipLabel(_registerOffset)} 스케줄에 등록됨'
                        : '${_dateChipLabel(_registerOffset)} PT 스케줄에 등록',
                    onTap: () => _registerToSchedule(
                      client,
                      _generatedRecommendations[client.id] ?? items,
                    ),
                  ),
                  if (_registered)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        // Match the button's day label — '오늘'/'내일'/'M/D' —
                        // so a future-day registration isn't described as '오늘'
                        // (CodeRabbit review).
                        '스케줄 탭에서 ${_dateChipLabel(_registerOffset)} '
                        '세션의 프로그램으로 확인할 수 있어요',
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
                label: '칼로리',
                value: client.calories,
                unit: 'kcal',
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: '나트륨',
                value: client.sodiumMg,
                unit: 'mg',
                color: AppColors.accentDark,
                warn: over,
              ),
              const SizedBox(width: AppSpacing.sm),
              MetricTile(
                label: '당류',
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
            child: Text(
              over
                  ? '✦ AI 판단: 나트륨 초과 → 유산소 강화 권장'
                  : '✦ AI 판단: 식단 균형 양호 → 근력 중심 루틴 유지',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
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
                    const Text(
                      'AI에게 맞춤 루틴 요청하기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$clientName님의 데이터를 분석해 회복형·강화형 후보를 만들고 '
                      '이 화면에서 비교·수정할 수 있어요.',
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

/// One routine card — AI items are editable (name + minutes); custom
/// items carry the orange trainer accent and a delete button.
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
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = isCustom ? AppColors.warning : AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(
          color: isCustom
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
              const SizedBox(width: AppSpacing.sm),
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
                              const Text(
                                '탭하여 수정',
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
                      color: AppColors.destructive,
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
          Row(
            children: <Widget>[
              for (final m in _minuteOptions) ...<Widget>[
                _MinuteChip(
                  minutes: m,
                  selected: minutes == m,
                  accent: accent,
                  onTap: onMinutes == null ? null : () => onMinutes!(m),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              const Spacer(),
              Text(
                '$minutes분',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
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

class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.minutes,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected ? accent : AppColors.inputBackground,
          borderRadius: const BorderRadius.all(AppRadius.pill),
        ),
        child: Text(
          '$minutes분',
          style: TextStyle(
            fontSize: 10,
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

class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning.withValues(alpha: 0.04),
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: const Text(
            '＋ 운동 직접 추가',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "운동 추가" form — name, type, minutes, 취소/추가하기. Keeps the
/// orange trainer accent from the mock to distinguish manual additions.
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
  int _minutes = 15;

  static const List<String> _types = <String>['유산소', '근력', '스트레칭'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '운동 추가',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              hintText: '운동 이름 (예: 레그프레스 3세트)',
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
          Row(
            children: <Widget>[
              for (final t in _types) ...<Widget>[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _type == t
                            ? AppColors.warning
                            : AppColors.inputBackground,
                        borderRadius: const BorderRadius.all(AppRadius.md),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _type == t
                              ? AppColors.warningForeground
                              : AppColors.subtleForeground,
                        ),
                      ),
                    ),
                  ),
                ),
                if (t != _types.last) const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final m in _minuteOptions) ...<Widget>[
                GestureDetector(
                  onTap: () => setState(() => _minutes = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _minutes == m
                          ? AppColors.warning
                          : AppColors.inputBackground,
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                    ),
                    child: Text(
                      '$m분',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _minutes == m
                            ? AppColors.warningForeground
                            : AppColors.subtleForeground,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _FormButton(
                  label: '취소',
                  background: AppColors.inputBackground,
                  foreground: AppColors.subtleForeground,
                  onTap: widget.onCancel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FormButton(
                  label: '추가하기',
                  background: AppColors.warning,
                  foreground: AppColors.warningForeground,
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
String _dateChipLabel(int offset) {
  if (offset == 0) return '오늘';
  if (offset == 1) return '내일';
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
          _dateChipLabel(offset),
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
    return Material(
      color: sent ? AppColors.success : AppColors.primary,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: sent ? null : onSend,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: Text(
            sent ? '✓ $clientName님에게 전송 완료!' : '검토 완료 · $clientName님에게 전송',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}
