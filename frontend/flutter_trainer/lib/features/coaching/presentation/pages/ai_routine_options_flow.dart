import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_options_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/routine_options.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/routine_form_fields.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/labeled_field.dart';

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
  /// 조건 설정 단계의 자연어 요청. 그대로 `trainer_note` 로 나간다 (#1028).
  ///
  /// 고객에게 함께 보낼 메모([_trainerMemo])와 **다른 칸**이다 — 하나로 묶여
  /// 있던 동안에는 "하체 부담 적은 40분으로 만들어줘" 같은 AI 지시문이 그대로
  /// 회원이 읽는 루틴 사유로 나갔다.
  final TextEditingController _prompt = TextEditingController();
  final TextEditingController _trainerMemo = TextEditingController();
  final TextEditingController _newExerciseName = TextEditingController();
  final ScrollController _optionScroll = ScrollController();

  /// 이 화면의 맨 위(진행 단계 표시줄) 를 가리킨다 — [_scrollToTop] 이 이
  /// 위젯을 뷰포트 위쪽으로 끌어올릴 때 기준으로 쓴다.
  final GlobalKey _topKey = GlobalKey();

  /// `RoutineOptionsRequest.trainer_note` 의 서버 상한(#1028). 여기서 막으면
  /// 긴 요청이 422 왕복 없이 그 자리에서 잘린다.
  static const int _promptMaxLength = 500;

  int _minutes = 30;
  String _intensity = 'moderate';
  String _newExerciseType = '근력';
  int _newExerciseMinutes = 30;
  // 근력만 세트·횟수를 받는다(#1029) — 그 외 유형은 [_newExerciseMinutes]
  // 를 그대로 쓴다.
  final TextEditingController _newExerciseSets = TextEditingController(
    text: '3',
  );
  final TextEditingController _newExerciseReps = TextEditingController(
    text: '10',
  );

  /// Whether the trainer has touched minutes/intensity directly (#776),
  /// tracked separately — touching one must not silently pin the other to
  /// its stale display value. Until touched, [_minutes]/[_intensity] only
  /// hold pre-fill display values and generation sends no explicit condition
  /// for that field — the server derives it from history (or a fixed
  /// default) instead. Once touched, whatever the trainer set always wins.
  bool _minutesTouched = false;
  bool _intensityTouched = false;

  bool _generating = false;
  bool _showAddExercise = false;
  RoutineOptions? _options;
  int _stage = 0;
  int _maxReachedStage = 0;
  String _selectedKey = 'A';
  List<RoutineExercise> _edited = <RoutineExercise>[];

  @override
  void dispose() {
    _prompt.dispose();
    _trainerMemo.dispose();
    _newExerciseName.dispose();
    _newExerciseSets.dispose();
    _newExerciseReps.dispose();
    _optionScroll.dispose();
    super.dispose();
  }

  String _analysisSuggestion(AppLocalizations l) {
    final client = widget.client;
    final sodium = client.sodiumOverBudget
        ? l.aiReasonSodium
        : l.aiReasonBalanced;
    return '${l.aiReasonGoal(client.goal, client.lastRoutine)} '
        '$sodium';
  }

  List<_RoutineChoice> _choicesOf(AppLocalizations l) {
    final options = _options;
    if (options == null) return const <_RoutineChoice>[];
    return <_RoutineChoice>[
      _RoutineChoice.fromPlan(options.planA),
      _RoutineChoice.fromPlan(options.planB),
      if (widget.recommendedExercises.isNotEmpty)
        _RoutineChoice(
          // key 는 화면 문구가 아니라 선택 식별자다('A'/'B' 와 같은 층).
          // 번역하면 _selectedKey 비교가 로케일마다 달라져 선택이 깨진다. (#501)
          key: _recommendedKey,
          label: l.aiTagExisting,
          intensity: l.aiTagCustom,
          exercises: widget.recommendedExercises,
          reason: widget.recommendedReason.isEmpty
              ? l.aiExistingBlurb
              : widget.recommendedReason,
        ),
    ];
  }

  /// 기존 추천 후보의 선택 식별자. 'A'/'B' 와 같은 층의 값이라 번역하지 않는다.
  static const String _recommendedKey = 'recommended';

  String _optionDisplayName(AppLocalizations l, String key) => switch (key) {
    'A' => l.aiOptionRecovery,
    'B' => l.aiOptionPush,
    _ => l.aiOptionExisting,
  };

  Future<void> _generate() async {
    if (_generating) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generating = true);
    try {
      final options = await ref
          .read(trainerRoutineOptionsRepositoryProvider)
          .generate(
            widget.client.id,
            availableMinutes: _minutesTouched ? _minutes : null,
            intensityPreference: _intensityTouched ? _intensity : null,
            // 자연어 요청은 백엔드가 실제로 읽는 유일한 자유 텍스트 필드로
            // 나간다 — 새 필드를 지어내지 않는다(#1028).
            trainerNote: _prompt.text.trim(),
          );
      if (!mounted) return;
      final analysis = options.analysis;
      setState(() {
        _options = options;
        _selectedKey = 'A';
        _edited = List<RoutineExercise>.of(options.planA.exercises);
        _showAddExercise = false;
        _stage = 1;
        _maxReachedStage = 1;
        // 트레이너가 아직 건드리지 않은 조건만 서버가 실제로 쓴 값(또는
        // 기본값)으로 채운다 — 트레이너가 시간만 고쳤다면 강도는 그대로
        // 서버가 계산하도록 둬야 하고, 그 반대도 마찬가지다(#776).
        if (!_minutesTouched) {
          _minutes = analysis.suggestedAvailableMinutes ?? _minutes;
        }
        if (!_intensityTouched) {
          _intensity = analysis.suggestedIntensity ?? _intensity;
        }
      });
      _scrollToTop();
    } catch (e) {
      if (!mounted) return;
      final AppLocalizations l = AppLocalizations.of(context);
      // 한도 초과는 고장이 아니라 잠시 뒤 되는 상태다. 다른 오류와 같은 문구를
      // 쓰면 트레이너가 기능이 깨진 것으로 읽는다(#582).
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is RateLimitedError
                ? l.aiGenerateRateLimited
                : l.aiGenerateFailed,
          ),
        ),
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
    });
  }

  void _addExercise() {
    final name = _newExerciseName.text.trim();
    if (name.isEmpty) {
      final AppLocalizations l = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.aiExerciseNameRequired)));
      return;
    }
    final isStrength = _newExerciseType == '근력';
    setState(() {
      _edited.add(
        RoutineExercise(
          name: name,
          minutes: _newExerciseMinutes,
          type: _newExerciseType,
          sets: isStrength
              ? (int.tryParse(_newExerciseSets.text.trim()) ?? 0)
              : 0,
          reps: isStrength ? _newExerciseReps.text.trim() : '',
        ),
      );
      _newExerciseName.clear();
      _newExerciseType = '근력';
      _newExerciseMinutes = 30;
      _newExerciseSets.text = '3';
      _newExerciseReps.text = '10';
      _showAddExercise = false;
    });
  }

  void _completeReview() {
    if (_edited.isEmpty) {
      final AppLocalizations l = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.aiKeepOneExercise)));
      return;
    }
    setState(() {
      _stage = 2;
      _maxReachedStage = 2;
      _showAddExercise = false;
    });
    _scrollToTop();
  }

  void _goToStage(int stage) {
    if (stage > _maxReachedStage || stage == _stage) return;
    setState(() => _stage = stage);
    _scrollToTop();
  }

  /// 1·2·3단계를 넘나들 때마다 이 화면을 담고 있는 스크롤을 맨 위로 되돌린다
  /// — 이전 단계에서 아래로 많이 내려가 있었어도, 다음 단계는 늘 위에서부터
  /// 보인다.
  ///
  /// 편집기 안에 넣을 때(embedded)는 자기 `Scrollable` 이 없어 코칭 페이지
  /// 전체를 담은 바깥 스크롤을 그대로 쓰는데, 그 스크롤은 이 화면 위로도
  /// (회원 요약 등) 카드가 더 있는 좁은 화면에서는 `ListView` 로 지연 빌드된다
  /// — `position.animateTo(0)` 처럼 절대 위치 0으로 보내면 이 화면이 뷰포트
  /// 밖으로 밀려나 통째로 언빌드된다. [_topKey] 를 이 화면 맨 위(진행 단계
  /// 표시줄)에 붙여 두고 `Scrollable.ensureVisible` 로 "그 카드가 이미 있는
  /// 스크롤에서, 그 카드의 맨 위가 뷰포트 맨 위에 오도록" 만큼만 옮긴다.
  void _scrollToTop() {
    // 다음 프레임(새 단계가 이미 빌드된 뒤)까지 미룬다 — 이 호출은 늘
    // `setState` 직후라, 그 자리에서 바로 스크롤을 건드리면 아직 끝나지
    // 않은 빌드/레이아웃 도중에 스크롤 위치를 바꾸는 셈이 된다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final topContext = _topKey.currentContext;
      if (topContext == null) return;
      Scrollable.ensureVisible(
        topContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// 최종 검토에서 확정한 구성을 **바로 고객에게 보내지 않고**, 2열의
  /// (지금은 비어 있는) `프로그램 정보` 박스로만 반영한다.
  ///
  /// 실제 전송은 프로그램 탭의 단일 `보내기`(최종 검토 단계, `ProgramFinalReviewCard`)
  /// 에서만 일어난다 — 여기서는 서버를 호출하지 않는다. 반영은
  /// [CoachingPage]가 넘겨준 [AiRoutineOptionsFlow.onReviewCompleted] 콜백을
  /// 통해 편집기의 `aiSuggestions` 로 흘러가고, 편집기가 그 값이 바뀔 때마다
  /// 세션 1에 병합한다(`ProgramEditorWorkspace.didUpdateWidget`).
  void _applyToTemplate() {
    final AppLocalizations l = AppLocalizations.of(context);
    if (_edited.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.aiKeepOneExercise)));
      return;
    }
    widget.onReviewCompleted?.call(List<RoutineExercise>.unmodifiable(_edited));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.aiAppliedToTemplate)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final content = <Widget>[
      KeyedSubtree(
        key: _topKey,
        child: _ProgressStepper(
          stage: _stage,
          maxReachedStage: _maxReachedStage,
          onStageTap: _goToStage,
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      if (_stage == 0) ...<Widget>[
        _assistantAnalysis(),
        const SizedBox(height: AppSpacing.lg),
        _promptField(),
        const SizedBox(height: AppSpacing.lg),
        _directionControls(),
        const SizedBox(height: AppSpacing.lg),
        _primaryButton(
          key: const ValueKey<String>('generate-routine-options'),
          label: _generating ? l.aiAnalysing : _generateButtonLabel(l),
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
          label: l.aiReviewDone,
          icon: Icons.fact_check_outlined,
          onTap: _completeReview,
        ),
      ] else ...<Widget>[
        _reviewedRoutineList(),
        const SizedBox(height: AppSpacing.lg),
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
        title: Text(l.aiRoutineFor(widget.client.name)),
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
    final AppLocalizations l = AppLocalizations.of(context);
    final client = widget.client;
    return _surfaceCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _AssistantLabel(text: l.aiAnalysedData),
          const SizedBox(height: AppSpacing.md),
          _analysisRow(l.aiGoal, client.goal),
          // 목표를 넘겼을 때만 꼬리표를 붙인다. 넘기지 않았다고 "적정" 이라
          // 말하면, 목표에 한참 못 미친 값까지 적정이 된다(#1070).
          _analysisRow(
            l.aiTodaySodium,
            '${client.sodiumMg}mg'
            '${client.sodiumOverBudget ? l.aiOverTarget : ''}',
            warn: client.sodiumOverBudget,
          ),
          _analysisRow(l.aiRecentRoutine, client.lastRoutine),
        ],
      ),
    );
  }

  /// 조건 설정 단계의 자연어 요청 칸 (#1028).
  ///
  /// 슬라이더·칩으로는 표현할 수 없는 요구("무릎 부담 적게", "유산소 비중 높게")를
  /// 트레이너가 쓰던 말 그대로 적는 자리다. 이 값은 지어낸 새 필드가 아니라
  /// 백엔드 `RoutineOptionsRequest.trainer_note` 로 그대로 나간다 — 서버가
  /// 실제로 읽는 유일한 자유 텍스트라 화면이 거짓말을 하지 않는다.
  Widget _promptField() {
    final AppLocalizations l = AppLocalizations.of(context);
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _AssistantLabel(text: l.aiPromptTitle),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: l.aiPromptLabel,
            child: TextField(
              key: const ValueKey<String>('ai-natural-language-prompt'),
              controller: _prompt,
              minLines: 3,
              maxLines: 5,
              maxLength: _promptMaxLength,
              style: _inputTextStyle,
              decoration: _inputDecoration(hintText: l.aiPromptHint),
            ),
          ),
          Text(
            l.aiPromptBlurb,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _directionControls() {
    final AppLocalizations l = AppLocalizations.of(context);
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.aiGenerateConditions, style: _sectionTitleStyle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.aiConditionsAutoHint,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          RoutineMinutesSlider(
            key: const ValueKey<String>('generation-minutes'),
            minutes: _minutes,
            label: l.routineFieldTotalMinutes,
            onChanged: (minutes) => setState(() {
              _minutes = minutes;
              _minutesTouched = true;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          RoutineIntensityChips(
            value: _intensity,
            onChanged: (intensity) => setState(() {
              _intensity = intensity;
              _intensityTouched = true;
            }),
          ),
        ],
      ),
    );
  }

  /// 데모(`USE_MOCK_API=true`)에서는 목표 기반 기본 추천 상태를 내보이지 않는다.
  /// (#1028)
  ///
  /// 데모 회원은 축적된 운동 기록이 아예 없어 생성기가 늘
  /// [RecommendationStatus.template] 을 돌려준다 — 그래서 데모를 열면 언제나
  /// `목표 기반 루틴 생성`·`목표 기반 기본 추천`만 보였고, 정작 보여 줘야 할
  /// **데이터 기반 맞춤 흐름**이 화면에 한 번도 나오지 않았다. 실 API 모드는
  /// 그대로다 — 기록이 적은 실제 회원에게는 그 사실을 계속 말해야 한다.
  bool get _hideTemplateState => ref.watch(appConfigProvider).useMockApi;

  /// Only known after the first generation — before that we haven't seen
  /// the member's analysis yet, so the button stays generic (#776).
  String _generateButtonLabel(AppLocalizations l) {
    final status = _options?.analysis.recommendationStatus;
    return status == RecommendationStatus.template && !_hideTemplateState
        ? l.aiGenerateGoalBased
        : l.aiGenerateCandidates;
  }

  Widget _generatedOptions() {
    final AppLocalizations l = AppLocalizations.of(context);
    final options = _options!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _AssistantLabel(text: l.aiCompareCandidates),
        const SizedBox(height: AppSpacing.sm),
        // 데모에서는 목표 기반 기본 추천 안내를 띄우지 않는다 —
        // [_hideTemplateState] 참고.
        if (!(_hideTemplateState &&
            options.analysis.recommendationStatus ==
                RecommendationStatus.template)) ...<Widget>[
          _RecommendationStatusBanner(analysis: options.analysis),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          l.aiBasisGoalCompletion(
                options.analysis.goal,
                options.analysis.avgCompletionRate,
              ) +
              (options.generatedBy == 'rule' ? l.aiBasisRuleBased : ''),
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.mutedForeground,
          ),
        ),
        // Only when the AI actually generated these plans. The rule-based
        // fallback ignores chat entirely, so showing "참고한 최근 대화" next to a
        // rule plan would claim an input that was never used — the trainer
        // would think a knee complaint was accounted for when it wasn't.
        if (options.generatedBy == 'ai' &&
            options.analysis.recentMessages.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _ChatEvidence(lines: options.analysis.recentMessages),
        ],
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
                _choicesOf(l).length * minCardWidth +
                (_choicesOf(l).length - 1) * AppSpacing.md;
            if (constraints.maxWidth >= needed) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final choice in _choicesOf(l)) ...<Widget>[
                        Expanded(child: _optionCard(choice)),
                        if (choice != _choicesOf(l).last)
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
                      for (final choice in _choicesOf(l)) ...<Widget>[
                        SizedBox(width: 286, child: _optionCard(choice)),
                        if (choice != _choicesOf(l).last)
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
    final AppLocalizations l = AppLocalizations.of(context);
    final selected = choice.key == _selectedKey;
    final total = choice.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.minutes,
    );
    final optionName = _optionDisplayName(l, choice.key);
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.aiTotalAndIntensity(total, choice.intensity),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final exercise in choice.exercises)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${l.aiBulletExercise(exercise.name, exercise.minutes)}'
                    '(${routineTypeLabel(l, exercise.type)})',
                    style: const TextStyle(
                      fontSize: 12,
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
                  fontSize: 11,
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
    final AppLocalizations l = AppLocalizations.of(context);
    final optionName = _optionDisplayName(l, _selectedKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l.aiEditOption(optionName), style: _sectionTitleStyle),
        const SizedBox(height: 3),
        Text(
          l.aiEditBlurb,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.mutedForeground,
          ),
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
            key: const ValueKey<String>('show-add-exercise-form'),
            onPressed: () => setState(() => _showAddExercise = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
            ),
            icon: const Icon(Icons.add, size: 17),
            label: Text(l.aiAddExerciseManually),
          ),
      ],
    );
  }

  Widget _exerciseEditor(int index) {
    final AppLocalizations l = AppLocalizations.of(context);
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
                tooltip: l.progDeleteExercise,
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
          SizedBox(
            key: ValueKey<String>('routine-category-name-gap-$index'),
            height: AppSpacing.md,
          ),
          TextFormField(
            key: ValueKey<String>(
              'routine-name-$_selectedKey-$index-${exercise.name}',
            ),
            initialValue: exercise.name,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
            onChanged: (name) {
              _edited[index] = _edited[index].copyWith(name: name);
            },
            decoration: _inputDecoration(hintText: l.progExerciseName),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 근력은 세트·횟수로, 그 외 유형은 시간으로 잰다(#1029).
          if (exercise.type == '근력')
            Row(
              children: <Widget>[
                Expanded(
                  child: LabeledField(
                    label: l.programEditorSets,
                    child: TextFormField(
                      key: ValueKey<String>('routine-sets-$_selectedKey-$index'),
                      initialValue: exercise.sets == 0
                          ? ''
                          : '${exercise.sets}',
                      keyboardType: TextInputType.number,
                      style: _inputTextStyle,
                      onChanged: (value) => setState(() {
                        _edited[index] = _edited[index].copyWith(
                          sets: int.tryParse(value) ?? 0,
                        );
                      }),
                      decoration: _inputDecoration(hintText: '3'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: LabeledField(
                    label: l.programEditorReps,
                    child: TextFormField(
                      key: ValueKey<String>('routine-reps-$_selectedKey-$index'),
                      initialValue: exercise.reps,
                      keyboardType: TextInputType.number,
                      style: _inputTextStyle,
                      onChanged: (value) => setState(() {
                        _edited[index] = _edited[index].copyWith(reps: value);
                      }),
                      decoration: _inputDecoration(hintText: '10'),
                    ),
                  ),
                ),
              ],
            )
          else
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
    final AppLocalizations l = AppLocalizations.of(context);
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.aiAddExerciseManually, style: _sectionTitleStyle),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: l.progExerciseName,
            child: TextField(
              key: const ValueKey<String>('new-exercise-name'),
              controller: _newExerciseName,
              style: _inputTextStyle,
              decoration: _inputDecoration(hintText: l.aiExerciseNameExample),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          RoutineCategoryChips(
            keyPrefix: 'new-exercise-category',
            value: _newExerciseType,
            onChanged: (type) => setState(() => _newExerciseType = type),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 근력은 세트·횟수로, 그 외 유형은 시간으로 잰다(#1029).
          if (_newExerciseType == '근력')
            Row(
              children: <Widget>[
                Expanded(
                  child: LabeledField(
                    label: l.programEditorSets,
                    child: TextField(
                      key: const ValueKey<String>('new-exercise-sets'),
                      controller: _newExerciseSets,
                      keyboardType: TextInputType.number,
                      style: _inputTextStyle,
                      decoration: _inputDecoration(hintText: '3'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: LabeledField(
                    label: l.programEditorReps,
                    child: TextField(
                      key: const ValueKey<String>('new-exercise-reps'),
                      controller: _newExerciseReps,
                      keyboardType: TextInputType.number,
                      style: _inputTextStyle,
                      decoration: _inputDecoration(hintText: '10'),
                    ),
                  ),
                ),
              ],
            )
          else
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
                  key: const ValueKey<String>('hide-add-exercise-form'),
                  onPressed: () => setState(() => _showAddExercise = false),
                  child: Text(l.actionCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _addExercise,
                  child: Text(l.aiRegister),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trainerMemoField() {
    final AppLocalizations l = AppLocalizations.of(context);
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.schedNote, style: _sectionTitleStyle),
          const SizedBox(height: AppSpacing.sm),
          LabeledField(
            label: l.aiNoteForClient,
            child: TextField(
              key: const ValueKey<String>('final-trainer-memo'),
              controller: _trainerMemo,
              minLines: 2,
              maxLines: 4,
              style: _inputTextStyle,
              decoration: _inputDecoration(hintText: _analysisSuggestion(l)),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.aiNotePlaceholderHint,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewedRoutineList() {
    final AppLocalizations l = AppLocalizations.of(context);
    final korean = Localizations.localeOf(context).languageCode == 'ko';
    final optionName = _optionDisplayName(l, _selectedKey);
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
                l.aiReviewedSuggestion(optionName),
                style: _sectionTitleStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          l.aiEditsApplied,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.mutedForeground,
          ),
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
                    routineTypeLabel(l, exercise.type),
                    style: const TextStyle(
                      fontSize: 10.5,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                Text(
                  // 근력은 트레이너가 세트·횟수로 정했다 — 시간(minutes)은 그
                  // 경우 편집 화면에 아예 없어 값이 바뀌지 않으니, 요약도
                  // 세트·횟수로 보여줘야 방금 고친 값과 어긋나지 않는다.
                  exercise.type == '근력'
                      ? (korean
                            ? '${exercise.sets}세트 × ${exercise.reps}회'
                            : '${exercise.sets} sets × ${exercise.reps} reps')
                      : l.minutesShort(exercise.minutes),
                  style: const TextStyle(
                    fontSize: 12.5,
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
                  // 메모다. 주의가 아니므로 빨강으로 올리지 않는다(#690).
                  color: AppColors.brandOrange,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l.schedNote,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandOrange,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        memo,
                        style: const TextStyle(
                          fontSize: 12.5,
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

  /// 3단계의 유일한 동작 — **고객에게 바로 전송하지 않는다**. 확정한 구성을
  /// 2열의 `프로그램 정보` 박스에 반영만 하고, 실제 전송은 그 박스를 확인·
  /// 수정한 뒤 프로그램 탭의 단일 `보내기`(최종 검토)에서 이뤄진다.
  Widget _reviewActions() {
    final AppLocalizations l = AppLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        key: const ValueKey<String>('apply-routine-to-template'),
        onPressed: _applyToTemplate,
        icon: const Icon(Icons.playlist_add_check_rounded, size: 17),
        label: Text(l.aiApplyToTemplate),
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
                fontSize: 13.5,
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

  /// (번호, 라벨). 라벨이 로케일을 따르므로 const 로 둘 수 없다. (#501)
  static List<(String, String)> _steps(AppLocalizations l) =>
      <(String, String)>[
        ('1', l.aiStepConditions),
        ('2', l.aiStepReview),
        ('3', l.aiStepDone),
      ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Semantics(
      label: l.aiStepperLabel,
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
              for (var index = 0; index < _steps(l).length; index++)
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
                                      _steps(l)[index].$1,
                                      style: TextStyle(
                                        fontSize: 12,
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
                        _steps(l)[index].$2,
                        style: TextStyle(
                          fontSize: 10.5,
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

/// The trainer↔member chat lines the generation was grounded on (#580).
///
/// Shown because the trainer is the one who has to trust the routine: if the
/// AI quietly ignored "무릎이 아파요", the only way to notice is to see which
/// utterances it was given. Lines arrive speaker-labelled from the server, so
/// this widget only handles layout.
class _ChatEvidence extends StatelessWidget {
  const _ChatEvidence({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.aiChatEvidenceTitle, style: _labelStyle),
          const SizedBox(height: AppSpacing.xs),
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// States how much this generation actually reflects the member's own
/// history (#776) — so a thin-history member never reads as "personalized"
/// when the AI had nothing personal to go on, and a settled member sees
/// what pattern the candidates are grounded in.
class _RecommendationStatusBanner extends StatelessWidget {
  const _RecommendationStatusBanner({required this.analysis});

  final MemberAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final (String title, String body) = switch (analysis.recommendationStatus) {
      RecommendationStatus.template => (
        l.aiStatusTemplateTitle,
        l.aiStatusTemplateBody,
      ),
      RecommendationStatus.learning => (
        l.aiStatusLearningTitle,
        l.aiStatusLearningBody,
      ),
      RecommendationStatus.personalized => (
        l.aiStatusPersonalizedTitle,
        l.aiStatusPersonalizedBody(
          analysis.historySessionCount,
          analysis.analysisPeriodDays,
        ),
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: _labelStyle),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.mutedForeground,
            ),
          ),
          if (analysis.frequentExercises.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l.aiFrequentExercisesLabel}: '
              '${analysis.frequentExercises.join(', ')}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const TextStyle _sectionTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w800,
  color: AppColors.foreground,
);

const TextStyle _labelStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w700,
  color: AppColors.mutedForeground,
);

/// 프로그램 탭의 다른 입력창(`_DraftField`, `program_editor_workspace.dart`)과
/// 같은 크기다 — 이 화면의 본문 기본 크기(테마 `bodyLarge`, 17px)를 그대로
/// 쓰면 같은 탭의 다른 입력창보다 눈에 띄게 커 보인다.
const TextStyle _inputTextStyle = TextStyle(
  color: AppColors.foreground,
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
);
