import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_options_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_options.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_form_fields.dart';
import 'package:oncare_trainer/shared/widgets/labeled_field.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Conversation-style AI routine builder.
///
/// The assistant stays inside the AI routine tab when [embedded] is true.
/// After generation, A/B and the existing recommendation are presented in a
/// horizontal rail; selecting a card updates the common editor below it.
class AiRoutineOptionsFlow extends ConsumerStatefulWidget {
  const AiRoutineOptionsFlow({
    required this.client,
    this.embedded = false,
    this.recommendedExercises = const <RoutineExercise>[],
    this.recommendedReason = '',
    this.onReviewCompleted,
    super.key,
  });

  final TrainerClient client;
  final bool embedded;
  final List<RoutineExercise> recommendedExercises;
  final String recommendedReason;
  final ValueChanged<List<RoutineExercise>>? onReviewCompleted;

  @override
  ConsumerState<AiRoutineOptionsFlow> createState() =>
      _AiRoutineOptionsFlowState();
}

class _AiRoutineOptionsFlowState extends ConsumerState<AiRoutineOptionsFlow> {
  final TextEditingController _trainerMemo = TextEditingController();
  final TextEditingController _newExerciseName = TextEditingController();
  final ScrollController _optionScroll = ScrollController();

  int _minutes = 30;
  String _intensity = 'moderate';
  String _newExerciseType = '근력';
  int _newExerciseMinutes = 30;

  bool _generating = false;
  bool _sending = false;
  bool _showAddExercise = false;
  bool _sent = false;
  RoutineOptions? _options;
  int _stage = 0;
  int _maxReachedStage = 0;
  String _selectedKey = 'A';
  List<RoutineExercise> _edited = <RoutineExercise>[];

  @override
  void dispose() {
    _trainerMemo.dispose();
    _newExerciseName.dispose();
    _optionScroll.dispose();
    super.dispose();
  }

  String get _analysisSuggestion {
    final client = widget.client;
    final sodium = client.sodiumOverBudget
        ? '오늘 나트륨이 목표를 초과해 저강도 유산소 비중을 높이는 것이 좋아요.'
        : '오늘 식단 균형이 안정적이라 기존 운동 강도를 유지해도 좋아요.';
    return '${client.goal} 목표와 최근 ${client.lastRoutine} 기록을 고려했어요. '
        '$sodium';
  }

  List<_RoutineChoice> get _choices {
    final options = _options;
    if (options == null) return const <_RoutineChoice>[];
    return <_RoutineChoice>[
      _RoutineChoice.fromPlan(options.planA),
      _RoutineChoice.fromPlan(options.planB),
      if (widget.recommendedExercises.isNotEmpty)
        _RoutineChoice(
          key: '추천',
          label: '기존 AI 추천',
          intensity: '맞춤',
          exercises: widget.recommendedExercises,
          reason: widget.recommendedReason.isEmpty
              ? '고객의 최근 식단과 운동 기록을 반영한 기존 추천이에요.'
              : widget.recommendedReason,
        ),
    ];
  }

  _RoutineChoice get _selectedChoice =>
      _choices.firstWhere((choice) => choice.key == _selectedKey);

  String _optionDisplayName(String key) => switch (key) {
    'A' => '회복안',
    'B' => '강화안',
    _ => '기존안',
  };

  Future<void> _generate() async {
    if (_generating) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _generating = true;
      _sent = false;
    });
    try {
      final options = await ref
          .read(trainerRoutineOptionsRepositoryProvider)
          .generate(
            widget.client.id,
            availableMinutes: _minutes,
            intensityPreference: _intensity,
            trainerNote: _trainerMemo.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _options = options;
        _selectedKey = 'A';
        _edited = List<RoutineExercise>.of(options.planA.exercises);
        _showAddExercise = false;
        _stage = 1;
        _maxReachedStage = 1;
      });
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('AI 생성에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _selectChoice(_RoutineChoice choice) {
    setState(() {
      _selectedKey = choice.key;
      _edited = List<RoutineExercise>.of(choice.exercises);
      _showAddExercise = false;
      _sent = false;
    });
  }

  void _addExercise() {
    final name = _newExerciseName.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('운동 이름을 입력해 주세요')));
      return;
    }
    setState(() {
      _edited.add(
        RoutineExercise(
          name: name,
          minutes: _newExerciseMinutes,
          type: _newExerciseType,
        ),
      );
      _newExerciseName.clear();
      _newExerciseType = '근력';
      _newExerciseMinutes = 30;
      _showAddExercise = false;
    });
  }

  void _completeReview() {
    if (_edited.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('운동을 하나 이상 남겨 주세요')));
      return;
    }
    setState(() {
      _stage = 2;
      _maxReachedStage = 2;
      _showAddExercise = false;
    });
    widget.onReviewCompleted?.call(List<RoutineExercise>.unmodifiable(_edited));
  }

  void _goToStage(int stage) {
    if (_sending || stage > _maxReachedStage || stage == _stage) return;
    setState(() {
      _stage = stage;
      if (stage < 2) _sent = false;
    });
  }

  Future<void> _send() async {
    if (_sending || _sent) return;
    if (_edited.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('운동을 하나 이상 남겨 주세요')));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final routine = _composeRoutine();

    setState(() => _sending = true);
    try {
      // Assigning the routine IS the delivery — the member receives it via
      // /me/coach/routines. No chat note is sent here: routine delivery is
      // shown in the member's routine feed, not as a chat bubble (matches
      // the legacy single-shot editor's _send in ai_routine_page.dart).
      await ref
          .read(trainerRoutineRepositoryProvider)
          .assignRoutine(widget.client.id, routine);
    } catch (e) {
      if (!mounted) return;
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

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
    });
    messenger.showSnackBar(
      SnackBar(content: Text('${widget.client.name}님에게 루틴을 전송했어요')),
    );
  }

  AssignedRoutine _composeRoutine() {
    final total = _edited.fold<int>(0, (sum, item) => sum + item.minutes);
    final typeCounts = <String, int>{};
    for (final exercise in _edited) {
      typeCounts[exercise.type] = (typeCounts[exercise.type] ?? 0) + 1;
    }
    final primaryType = typeCounts.entries.fold<MapEntry<String, int>?>(
      null,
      (best, entry) => best == null || entry.value > best.value ? entry : best,
    );
    final exerciseSummary = _edited
        .map((exercise) => '${exercise.name} ${exercise.minutes}분')
        .join(', ');
    final memo = _trainerMemo.text.trim();
    final context = memo.isEmpty ? _selectedChoice.reason : memo;
    final optionName = _optionDisplayName(_selectedKey);

    return AssignedRoutine(
      id: '',
      name: 'AI 맞춤 루틴 ($optionName)',
      minutes: total,
      type: primaryType?.key ?? '근력',
      reason: '$exerciseSummary · $context',
      source: 'ai',
    );
  }

  void _openClientChat() {
    context.go(AppRoutes.clientDetail(widget.client.id));
  }

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      _ProgressStepper(
        stage: _stage,
        maxReachedStage: _maxReachedStage,
        onStageTap: _goToStage,
      ),
      const SizedBox(height: AppSpacing.xl),
      if (_stage == 0) ...<Widget>[
        _assistantAnalysis(),
        const SizedBox(height: AppSpacing.lg),
        _directionControls(),
        const SizedBox(height: AppSpacing.lg),
        _primaryButton(
          key: const ValueKey<String>('generate-routine-options'),
          label: _generating ? 'AI가 분석 중…' : '맞춤 루틴 후보 생성',
          icon: Icons.auto_awesome,
          busy: _generating,
          onTap: _generate,
        ),
      ] else if (_stage == 1) ...<Widget>[
        _generatedOptions(),
        const SizedBox(height: AppSpacing.xl),
        _routineEditor(),
        const SizedBox(height: AppSpacing.lg),
        _trainerMemoField(),
        const SizedBox(height: AppSpacing.xl),
        _primaryButton(
          key: const ValueKey<String>('complete-routine-review'),
          label: '검토 완료',
          icon: Icons.fact_check_outlined,
          onTap: _completeReview,
        ),
      ] else ...<Widget>[
        _reviewedRoutineList(),
        const SizedBox(height: AppSpacing.lg),
        if (_sent) ...<Widget>[
          _sentConfirmation(),
          const SizedBox(height: AppSpacing.md),
        ],
        _reviewActions(),
      ],
      const SizedBox(height: AppSpacing.xxl),
    ];

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.foreground,
        title: Text('AI 루틴 · ${widget.client.name}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: content,
        ),
      ),
    );
  }

  Widget _assistantAnalysis() {
    final client = widget.client;
    return _surfaceCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _AssistantLabel(text: '고객 데이터를 분석했어요'),
          const SizedBox(height: AppSpacing.md),
          _analysisRow('목표', client.goal),
          _analysisRow(
            '오늘 나트륨',
            '${client.sodiumMg}mg'
                '${client.sodiumOverBudget ? ' · 목표 초과' : ' · 적정'}',
            warn: client.sodiumOverBudget,
          ),
          _analysisRow('최근 루틴', client.lastRoutine),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: '트레이너 메모 · 수정 가능',
            child: TextField(
              key: const ValueKey<String>('analysis-trainer-memo'),
              controller: _trainerMemo,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: AppColors.foreground),
              decoration: _inputDecoration(hintText: _analysisSuggestion),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '회색 제안 문구는 입력 전 참고용이며, 직접 입력한 메모만 저장·전송돼요.',
            style: TextStyle(fontSize: 9.5, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _directionControls() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('생성 조건', style: _sectionTitleStyle),
          const SizedBox(height: AppSpacing.md),
          RoutineMinutesSlider(
            key: const ValueKey<String>('generation-minutes'),
            minutes: _minutes,
            onChanged: (minutes) => setState(() => _minutes = minutes),
          ),
          const SizedBox(height: AppSpacing.lg),
          RoutineIntensityChips(
            value: _intensity,
            onChanged: (intensity) => setState(() => _intensity = intensity),
          ),
        ],
      ),
    );
  }

  Widget _generatedOptions() {
    final options = _options!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _AssistantLabel(text: '맞춤 루틴 후보를 비교해 보세요'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${options.analysis.goal} · 완료율 '
          '${options.analysis.avgCompletionRate}% 기준'
          '${options.generatedBy == 'rule' ? ' · 규칙 기반 생성' : ''}',
          style: const TextStyle(
            fontSize: 10.5,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            // Side by side whenever they fit: this is a COMPARISON, and a
            // comparison you have to scroll through isn't one. The console
            // splits the workspace into two columns, so the editor column
            // is narrower than the full-width page this flow was built
            // for — a fixed 286px rail always clipped the third card.
            const double minCardWidth = 220;
            final needed =
                _choices.length * minCardWidth +
                (_choices.length - 1) * AppSpacing.md;
            if (constraints.maxWidth >= needed) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final choice in _choices) ...<Widget>[
                        Expanded(child: _optionCard(choice)),
                        if (choice != _choices.last)
                          const SizedBox(width: AppSpacing.md),
                      ],
                    ],
                  ),
                ),
              );
            }
            // Too narrow for three — fall back to the scrolling rail so
            // the cards stay readable instead of shrinking to nothing.
            return Scrollbar(
              controller: _optionScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: const ValueKey<String>(
                  'routine-options-horizontal-scroll',
                ),
                controller: _optionScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final choice in _choices) ...<Widget>[
                        SizedBox(width: 286, child: _optionCard(choice)),
                        if (choice != _choices.last)
                          const SizedBox(width: AppSpacing.md),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _optionCard(_RoutineChoice choice) {
    final selected = choice.key == _selectedKey;
    final total = choice.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.minutes,
    );
    final optionName = _optionDisplayName(choice.key);
    return Material(
      color: AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        key: ValueKey<String>('routine-option-${choice.key}'),
        onTap: () => _selectChoice(choice),
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.borderStrong,
              width: selected ? 2 : 1,
            ),
            boxShadow: kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected
                        ? AppColors.accent
                        : AppColors.mutedForeground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$optionName · ${choice.label}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '총 $total분 · 강도 ${choice.intensity}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final exercise in choice.exercises)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '· ${exercise.name} · ${exercise.minutes}분 '
                    '(${exercise.type})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                choice.reason,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.35,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _routineEditor() {
    final optionName = _optionDisplayName(_selectedKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('$optionName 수정', style: _sectionTitleStyle),
        const SizedBox(height: 3),
        const Text(
          '기존 AI 추천과 같은 방식으로 운동명·시간·구성을 수정할 수 있어요.',
          style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.md),
        for (int index = 0; index < _edited.length; index++) ...<Widget>[
          _exerciseEditor(index),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (_showAddExercise)
          _addExerciseForm()
        else
          OutlinedButton.icon(
            onPressed: () => setState(() => _showAddExercise = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
            ),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('운동 직접 등록'),
          ),
      ],
    );
  }

  Widget _exerciseEditor(int index) {
    final exercise = _edited[index];
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: RoutineCategoryChips(
                  keyPrefix: 'routine-category-$_selectedKey-$index',
                  value: exercise.type,
                  onChanged: (type) => setState(() {
                    _edited[index] = exercise.copyWith(type: type);
                  }),
                ),
              ),
              IconButton(
                tooltip: '운동 삭제',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _edited.removeAt(index)),
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.subtleForeground,
                ),
              ),
            ],
          ),
          TextFormField(
            key: ValueKey<String>(
              'routine-name-$_selectedKey-$index-${exercise.name}',
            ),
            initialValue: exercise.name,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
            onChanged: (name) {
              _edited[index] = _edited[index].copyWith(name: name);
            },
            decoration: _inputDecoration(hintText: '운동 이름'),
          ),
          const SizedBox(height: AppSpacing.sm),
          RoutineMinutesSlider(
            key: ValueKey<String>('routine-minutes-$index'),
            minutes: exercise.minutes,
            onChanged: (minutes) => setState(() {
              _edited[index] = _edited[index].copyWith(minutes: minutes);
            }),
          ),
        ],
      ),
    );
  }

  Widget _addExerciseForm() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('운동 직접 등록', style: _sectionTitleStyle),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: '운동 이름',
            child: TextField(
              key: const ValueKey<String>('new-exercise-name'),
              controller: _newExerciseName,
              style: const TextStyle(color: AppColors.foreground),
              decoration: _inputDecoration(hintText: '예: 레그프레스 3세트'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          RoutineCategoryChips(
            keyPrefix: 'new-exercise-category',
            value: _newExerciseType,
            onChanged: (type) => setState(() => _newExerciseType = type),
          ),
          const SizedBox(height: AppSpacing.sm),
          RoutineMinutesSlider(
            key: const ValueKey<String>('new-exercise-minutes'),
            minutes: _newExerciseMinutes,
            onChanged: (minutes) => setState(() {
              _newExerciseMinutes = minutes;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _showAddExercise = false),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _addExercise,
                  child: const Text('등록'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trainerMemoField() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('트레이너 메모', style: _sectionTitleStyle),
          const SizedBox(height: AppSpacing.sm),
          LabeledField(
            label: '고객에게 함께 전달할 내용',
            child: TextField(
              key: const ValueKey<String>('final-trainer-memo'),
              controller: _trainerMemo,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: AppColors.foreground),
              decoration: _inputDecoration(hintText: _analysisSuggestion),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewedRoutineList() {
    final optionName = _optionDisplayName(_selectedKey);
    final memo = _trainerMemo.text.trim();
    return Column(
      key: const ValueKey<String>('reviewed-routine-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '검토 완료 · AI 추천 루틴 ($optionName)',
                style: _sectionTitleStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          '선택하고 수정한 내용이 최종 추천 목록에 반영됐어요.',
          style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final exercise in _edited) ...<Widget>[
          _surfaceCard(
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: BorderRadius.all(AppRadius.pill),
                  ),
                  child: Text(
                    exercise.type,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                Text(
                  '${exercise.minutes}분',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (memo.isNotEmpty)
          _surfaceCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 17,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '트레이너 메모',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        memo,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reviewActions() {
    if (_sent) {
      return SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          key: const ValueKey<String>('open-client-chat'),
          onPressed: _openClientChat,
          icon: const Icon(Icons.chat_bubble_outline, size: 17),
          label: Text('${widget.client.name}님 채팅으로 이동'),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        key: const ValueKey<String>('send-selected-routine'),
        onPressed: _sending ? null : _send,
        icon: _sending
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryForeground,
                ),
              )
            : const Icon(Icons.send_rounded, size: 17),
        label: Text(_sending ? '전송 중…' : '고객에게 전송'),
      ),
    );
  }

  Widget _sentConfirmation() {
    return Container(
      key: const ValueKey<String>('routine-sent-confirmation'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            size: 34,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${widget.client.name}님에게 루틴을 전송했어요',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '아래 버튼에서 고객 채팅으로 이동해 바로 안내할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child, bool accent = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: accent ? AppColors.accentSurface : AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(
          color: accent
              ? AppColors.accent.withValues(alpha: 0.28)
              : AppColors.borderStrong,
        ),
        boxShadow: kCardShadow,
      ),
      child: child,
    );
  }

  Widget _analysisRow(String label, String value, {bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 82, child: Text(label, style: _labelStyle)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: warn ? AppColors.overTarget : AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filled, borderless input styling. Deliberately no `labelText` —
  /// see [LabeledField] for why the caption goes above the box.
  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppColors.mutedForeground,
        fontWeight: FontWeight.w400,
      ),
      isDense: true,
      filled: true,
      fillColor: AppColors.inputBackground,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(AppRadius.md),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _primaryButton({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return SizedBox(
      key: key,
      height: 50,
      child: FilledButton.icon(
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryForeground,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _RoutineChoice {
  const _RoutineChoice({
    required this.key,
    required this.label,
    required this.intensity,
    required this.exercises,
    required this.reason,
  });

  factory _RoutineChoice.fromPlan(RoutinePlan plan) {
    return _RoutineChoice(
      key: plan.key,
      label: plan.label,
      intensity: plan.intensity,
      exercises: plan.exercises,
      reason: plan.rationale,
    );
  }

  final String key;
  final String label;
  final String intensity;
  final List<RoutineExercise> exercises;
  final String reason;
}

class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({
    required this.stage,
    required this.maxReachedStage,
    required this.onStageTap,
  });

  final int stage;
  final int maxReachedStage;
  final ValueChanged<int> onStageTap;

  static const List<(String, String)> _steps = <(String, String)>[
    ('1', '조건 설정'),
    ('2', '후보 검토'),
    ('3', '추천 완료'),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '맞춤 루틴 생성 진행 단계',
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 19,
            left: 0,
            right: 0,
            child: Row(
              children: <Widget>[
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 2,
                    color: maxReachedStage >= 1
                        ? AppColors.accent
                        : AppColors.borderStrong,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 2,
                    color: maxReachedStage >= 2
                        ? AppColors.accent
                        : AppColors.borderStrong,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              for (var index = 0; index < _steps.length; index++)
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: ValueKey<String>('routine-stage-$index'),
                          customBorder: const CircleBorder(),
                          onTap: index <= maxReachedStage
                              ? () => onStageTap(index)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index <= maxReachedStage
                                    ? AppColors.accent
                                    : AppColors.inputBackground,
                                border: Border.all(
                                  color: index == stage
                                      ? AppColors.primary
                                      : AppColors.borderStrong,
                                  width: index == stage ? 2 : 1,
                                ),
                              ),
                              child: index < stage
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: AppColors.accentForeground,
                                    )
                                  : Text(
                                      _steps[index].$1,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: index <= maxReachedStage
                                            ? AppColors.accentForeground
                                            : AppColors.mutedForeground,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _steps[index].$2,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: index == stage
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: index <= maxReachedStage
                              ? AppColors.foreground
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantLabel extends StatelessWidget {
  const _AssistantLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.accent,
          child: Icon(
            Icons.auto_awesome,
            size: 14,
            color: AppColors.accentForeground,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: _sectionTitleStyle)),
      ],
    );
  }
}

const TextStyle _sectionTitleStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w800,
  color: AppColors.foreground,
);

const TextStyle _labelStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  color: AppColors.mutedForeground,
);
