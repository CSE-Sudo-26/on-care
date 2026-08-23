import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/request_id.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_options_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
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

  /// `RoutineOptionsRequest.trainer_note` 의 서버 상한(#1028). 여기서 막으면
  /// 긴 요청이 422 왕복 없이 그 자리에서 잘린다.
  static const int _promptMaxLength = 500;

  int _minutes = 30;
  String _intensity = 'moderate';
  String _newExerciseType = '근력';
  int _newExerciseMinutes = 30;

  /// Whether the trainer has touched minutes/intensity directly (#776),
  /// tracked separately — touching one must not silently pin the other to
  /// its stale display value. Until touched, [_minutes]/[_intensity] only
  /// hold pre-fill display values and generation sends no explicit condition
  /// for that field — the server derives it from history (or a fixed
  /// default) instead. Once touched, whatever the trainer set always wins.
  bool _minutesTouched = false;
  bool _intensityTouched = false;

  bool _generating = false;
  bool _sending = false;
  bool _showAddExercise = false;
  bool _sent = false;

  /// 진행 중인 전송 시도의 멱등키. 실패 후 재시도는 이 값을 그대로 다시 쓰고,
  /// 전송이 성공하면 비운다 — 그래야 재시도가 중복 배정을 만들지 않으면서도
  /// 다음 전송은 별개의 배정이 된다(#581).
  String? _sendRequestId;
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

  _RoutineChoice _selectedChoiceOf(AppLocalizations l) =>
      _choicesOf(l).firstWhere((choice) => choice.key == _selectedKey);

  String _optionDisplayName(AppLocalizations l, String key) => switch (key) {
    'A' => l.aiOptionRecovery,
    'B' => l.aiOptionPush,
    _ => l.aiOptionExisting,
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
      _sent = false;
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
    // messenger 와 l 은 await 전에 잡아 둔다 — 실패 경로가 await 뒤에 있다.
    final AppLocalizations l = AppLocalizations.of(context);
    if (_edited.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.aiKeepOneExercise)));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final routine = _composeRoutine(l);

    // 이 전송 시도의 멱등키. 실패해서 트레이너가 다시 누르면 **같은 키**가 다시
    // 나가므로, 앞 시도가 서버에 이미 커밋됐더라도 중복 배정되지 않는다(#581).
    // 성공한 뒤에만 비워 다음 전송이 새 배정이 되게 한다.
    _sendRequestId ??= newClientRequestId();

    setState(() => _sending = true);
    try {
      // Assigning the routine IS the delivery — the member receives it via
      // /me/coach/routines. No chat note is sent here: routine delivery is
      // shown in the member's routine feed, not as a chat bubble (matches
      // the legacy single-shot editor's _send in ai_routine_page.dart).
      await ref
          .read(trainerRoutineRepositoryProvider)
          .assignRoutine(
            widget.client.id,
            routine,
            clientRequestId: _sendRequestId,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      // 네트워크 실패는 결과를 알 수 없다 — 서버가 이미 커밋한 뒤 응답만 유실됐을
      // 수 있다. 다만 멱등키를 함께 보내므로 **같은 키로 재시도해도 중복 배정이
      // 되지 않는다**(#581). 그래서 "먼저 확인하라" 대신 재시도를 안내한다.
      messenger.showSnackBar(SnackBar(content: Text(l.coachSendFailed)));
      return;
    }

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
      _sendRequestId = null; // 다음 전송은 새 배정이다.
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l.aiRoutineSent(widget.client.name))),
    );
  }

  /// 트레이너가 보낼 루틴을 조립한다.
  ///
  /// `name`·`reason` 은 트레이너가 만들어 회원에게 보내는 **본문**이라 트레이너의
  /// 로케일을 따른다(채팅·메모와 같은 층). 반면 `type` 은 서버가 Literal 로
  /// 검증하는 계약값이라 번역하지 않는다. (#501)
  AssignedRoutine _composeRoutine(AppLocalizations l) {
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
        .map(
          (exercise) =>
              l.aiExerciseWithMinutes(exercise.name, exercise.minutes),
        )
        .join(', ');
    final memo = _trainerMemo.text.trim();
    final rationale = memo.isEmpty ? _selectedChoiceOf(l).reason : memo;
    final optionName = _optionDisplayName(l, _selectedKey);

    return AssignedRoutine(
      id: '',
      name: l.aiCustomRoutineNamed(optionName),
      minutes: total,
      type: primaryType?.key ?? '근력',
      reason: '$exerciseSummary · $rationale',
      source: 'ai',
    );
  }

  void _openClientChat() {
    // Explicit: the button says 채팅, and the detail's default section is
    // a content tab now.
    context.go(
      AppRoutes.clientDetail(
        widget.client.id,
        section: AppRoutes.clientChatSection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
              style: const TextStyle(color: AppColors.foreground),
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
              style: const TextStyle(color: AppColors.foreground),
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
              style: const TextStyle(color: AppColors.foreground),
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
                  l.minutesShort(exercise.minutes),
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

  Widget _reviewActions() {
    final AppLocalizations l = AppLocalizations.of(context);
    if (_sent) {
      return SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          key: const ValueKey<String>('open-client-chat'),
          onPressed: _openClientChat,
          icon: const Icon(Icons.chat_bubble_outline, size: 17),
          label: Text(l.aiGoToChat(widget.client.name)),
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
        label: Text(_sending ? l.aiSending : l.aiSendToClient),
      ),
    );
  }

  Widget _sentConfirmation() {
    final AppLocalizations l = AppLocalizations.of(context);
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
            l.aiRoutineSent(widget.client.name),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.aiGoToChatHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.mutedForeground,
            ),
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
