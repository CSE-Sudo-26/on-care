import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

enum _ExerciseGoal { weightLoss, strength, fitness, posture, health, other }

enum _HealthPurpose { weight, chronic, rehab, general, none, other }

enum _PreferredTime { morning, afternoon, evening, flexible }

// 화면 선택지 → 서버 계약 enum. 순서가 같으므로 index 로 잇되, 길이가 어긋나면
// 조용히 틀린 값이 나가므로 아래 assert 로 막는다.
extension on _ExerciseGoal {
  ExerciseGoal get wire => ExerciseGoal.values[index];
}

extension on _HealthPurpose {
  HealthPurposeType get wire => HealthPurposeType.values[index];
}

extension on _PreferredTime {
  PreferredTimeSlot get wire => PreferredTimeSlot.values[index];
}

class ConsultationRequestPage extends ConsumerStatefulWidget {
  const ConsultationRequestPage({
    required this.gymId,
    required this.trainerId,
    super.key,
  });

  final String gymId;

  /// 상담을 받을 트레이너. 폐지된 헬스장 대상 링크로 들어오면 비어 있고, 그때는
  /// 폼 대신 "대상을 찾을 수 없음"을 띄운다.
  final String? trainerId;

  @override
  ConsumerState<ConsultationRequestPage> createState() =>
      _ConsultationRequestPageState();
}

class _ConsultationRequestPageState
    extends ConsumerState<ConsultationRequestPage> {
  final TextEditingController _healthPurposeController =
      TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  _ExerciseGoal? _exerciseGoal;
  _HealthPurpose? _healthPurpose;
  DateTime? _preferredDate;
  _PreferredTime? _preferredTime;
  bool _attempted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _healthPurposeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Gym? _findGym(List<Gym> gyms) {
    for (final Gym gym in gyms) {
      if (gym.id == widget.gymId) return gym;
    }
    return null;
  }

  Future<void> _selectDate() async {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _preferredDate = selected);
    }
  }

  bool get _healthPurposeInputMissing =>
      _healthPurpose == _HealthPurpose.other &&
      _healthPurposeController.text.trim().isEmpty;

  bool get _isValid =>
      _exerciseGoal != null &&
      _healthPurpose != null &&
      !_healthPurposeInputMissing &&
      _preferredDate != null &&
      _preferredTime != null;

  Future<void> _submit({
    required Gym gym,
    required Trainer trainer,
    required Map<_ExerciseGoal, String> goalLabels,
    required Map<_HealthPurpose, String> purposeLabels,
    required Map<_PreferredTime, String> timeLabels,
  }) async {
    if (_submitting) return;
    setState(() => _attempted = true);
    if (!_isValid) return;

    final controller = ref.read(consultationRequestControllerProvider.notifier);
    if (controller.hasPending(trainerId: trainer.id)) {
      return;
    }

    setState(() => _submitting = true);
    final DateTime now = DateTime.now();
    final String message = _messageController.text.trim();
    final ConsultationRequest request = ConsultationRequest(
      id: 'consult-${now.microsecondsSinceEpoch}',
      targetType: ConsultationTargetType.trainer,
      gymId: gym.id,
      gymName: gym.name,
      trainerId: trainer.id,
      trainerName: trainer.name,
      trainerRole: trainer.role,
      // 라벨이 아니라 계약 enum 을 담는다 — 라벨을 저장하면 서버에서 복원할 때
      // 문구를 만들 수 없다(#327).
      exerciseGoal: _exerciseGoal!.wire,
      healthPurposeType: _healthPurpose!.wire,
      healthPurposeDetail: _healthPurpose == _HealthPurpose.other
          ? _healthPurposeController.text.trim()
          : null,
      preferredDate: _preferredDate!,
      preferredTimeSlot: _preferredTime!.wire,
      message: message.isEmpty ? null : message,
      status: ConsultationStatus.pending,
      createdAt: now,
    );
    final ConsultationDraft draft = ConsultationDraft(
      trainerId: trainer.id,
      exerciseGoal: _exerciseGoal!.wire,
      healthPurposeType: _healthPurpose!.wire,
      healthPurposeDetail: _healthPurpose == _HealthPurpose.other
          ? _healthPurposeController.text.trim()
          : null,
      preferredDate: _preferredDate!,
      preferredTimeSlot: _preferredTime!.wire,
      message: message.isEmpty ? null : message,
    );

    final ConsultationRequest? saved;
    try {
      saved = await controller.submit(draft: draft, display: request);
    } on Object {
      // 409 외의 실패(네트워크 등)를 잡지 않으면 _submitting 이 true 로 남아
      // 제출 버튼이 영영 눌리지 않는다(리뷰 지적).
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorUnknown)),
      );
      return;
    }
    if (!mounted) return;
    if (saved == null) {
      setState(() => _submitting = false);
      return;
    }
    context.replace(AppRoutes.consultationComplete, extra: saved);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<List<Gym>> nearbyAsync = ref.watch(nearbyGymsProvider);
    final AsyncValue<Gym?> myGymAsync = ref.watch(myGymProvider);
    final List<ConsultationRequest> requests = ref.watch(
      consultationRequestControllerProvider,
    );

    final Gym? nearbyGym = switch (nearbyAsync) {
      AsyncData<List<Gym>>(:final value) => _findGym(value),
      _ => null,
    };
    final Gym? myGym = switch (myGymAsync) {
      AsyncData<Gym?>(:final value) when value?.id == widget.gymId => value,
      _ => null,
    };
    final Gym? gym = nearbyGym ?? myGym;
    final bool hasTrainerId = (widget.trainerId ?? '').isNotEmpty;
    // 대상 트레이너를 id 로 직접 읽는다.
    final AsyncValue<Trainer?> trainerAsync = hasTrainerId
        ? ref.watch(trainerProvider(widget.trainerId!))
        : const AsyncValue<Trainer?>.data(null);
    final Trainer? trainer = trainerAsync.valueOrNull;
    final bool targetIsValid = gym != null && trainer != null;

    final Widget body;
    if (targetIsValid) {
      final bool hasPending = requests.any(
        (ConsultationRequest request) =>
            request.trainerId == trainer.id &&
            request.status == ConsultationStatus.pending,
      );
      body = _buildForm(gym: gym, trainer: trainer, hasPending: hasPending);
    } else if (hasTrainerId && trainerAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 3));
    } else if (!hasTrainerId || widget.gymId.isEmpty || gym != null) {
      body = _StateMessage(message: l.exConsultTargetNotFound);
    } else if (nearbyAsync.isLoading || myGymAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 3));
    } else if (nearbyAsync.hasError || myGymAsync.hasError) {
      body = _StateMessage(
        message: l.exGymsLoadError,
        onRetry: () {
          ref.invalidate(nearbyGymsProvider);
          ref.invalidate(myGymProvider);
        },
      );
    } else {
      body = _StateMessage(message: l.exConsultTargetNotFound);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          l.exConsultRequestTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: FigmaColors.ink,
          ),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _buildForm({
    required Gym gym,
    required Trainer trainer,
    required bool hasPending,
  }) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Map<_ExerciseGoal, String> goalLabels = <_ExerciseGoal, String>{
      _ExerciseGoal.weightLoss: l.exGoalWeightLoss,
      _ExerciseGoal.strength: l.exGoalStrength,
      _ExerciseGoal.fitness: l.exGoalFitness,
      _ExerciseGoal.posture: l.exGoalPosture,
      _ExerciseGoal.health: l.exGoalHealth,
      _ExerciseGoal.other: l.exOptionOther,
    };
    final Map<_HealthPurpose, String> purposeLabels = <_HealthPurpose, String>{
      _HealthPurpose.weight: l.exPurposeWeight,
      _HealthPurpose.chronic: l.exPurposeChronic,
      _HealthPurpose.rehab: l.exPurposeRehab,
      _HealthPurpose.general: l.exPurposeGeneral,
      _HealthPurpose.none: l.exPurposeNone,
      _HealthPurpose.other: l.exOptionOther,
    };
    final Map<_PreferredTime, String> timeLabels = <_PreferredTime, String>{
      _PreferredTime.morning: l.exTimeMorning,
      _PreferredTime.afternoon: l.exTimeAfternoon,
      _PreferredTime.evening: l.exTimeEvening,
      _PreferredTime.flexible: l.exTimeFlexible,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          // 폼이 한 화면보다 길다. 아래쪽 항목은 화면에 들어오기 전까지 만들어지지
          // 않으므로, E2E 가 이 목록을 잡고 스크롤할 수 있어야 한다. (#640)
          key: const Key('consult-form'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: <Widget>[
            _TargetCard(gym: gym, trainer: trainer),
            const SizedBox(height: 20),
            _ChoiceField<_ExerciseGoal>(
              chipKeyPrefix: 'consult-goal',
              title: l.exExerciseGoal,
              values: _ExerciseGoal.values,
              labels: goalLabels,
              selected: _exerciseGoal,
              onSelected: (_ExerciseGoal value) =>
                  setState(() => _exerciseGoal = value),
              errorText: _attempted && _exerciseGoal == null
                  ? l.exGoalRequired
                  : null,
            ),
            if (_exerciseGoal == _ExerciseGoal.other) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l.exOtherGoalHint,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _ChoiceField<_HealthPurpose>(
              key: const Key('health-purpose-options'),
              chipKeyPrefix: 'consult-purpose',
              title: l.exHealthPurpose,
              values: _HealthPurpose.values,
              labels: purposeLabels,
              selected: _healthPurpose,
              onSelected: (_HealthPurpose value) {
                setState(() => _healthPurpose = value);
              },
              errorText: _attempted && _healthPurpose == null
                  ? l.exHealthPurposeRequired
                  : null,
            ),
            if (_healthPurpose == _HealthPurpose.other) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                key: const Key('consult-purpose-other'),
                controller: _healthPurposeController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l.exHealthPurposeOtherHint,
                  errorText: _attempted && _healthPurposeInputMissing
                      ? l.exHealthPurposeInputRequired
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _FieldTitle(title: l.exPreferredDate),
            const SizedBox(height: 8),
            _DateField(
              key: const Key('consult-date'),
              date: _preferredDate,
              onTap: _selectDate,
            ),
            if (_attempted && _preferredDate == null)
              _ErrorText(l.exDateRequired),
            const SizedBox(height: 20),
            _ChoiceField<_PreferredTime>(
              chipKeyPrefix: 'consult-time',
              title: l.exPreferredTime,
              values: _PreferredTime.values,
              labels: timeLabels,
              selected: _preferredTime,
              onSelected: (_PreferredTime value) =>
                  setState(() => _preferredTime = value),
              errorText: _attempted && _preferredTime == null
                  ? l.exTimeRequired
                  : null,
            ),
            const SizedBox(height: 20),
            _FieldTitle(title: l.exConsultMessage),
            const SizedBox(height: 8),
            TextField(
              key: const Key('consult-message'),
              controller: _messageController,
              minLines: 4,
              maxLines: 7,
              decoration: InputDecoration(hintText: l.exConsultMessageHint),
            ),
            if (hasPending) ...<Widget>[
              const SizedBox(height: 14),
              _PendingNotice(message: l.exConsultPendingExists),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('consult-submit'),
              onPressed: hasPending || _submitting
                  ? null
                  : () => unawaited(
                      _submit(
                        gym: gym,
                        trainer: trainer,
                        goalLabels: goalLabels,
                        purposeLabels: purposeLabels,
                        timeLabels: timeLabels,
                      ),
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: FigmaColors.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      hasPending
                          ? l.exConsultPendingCta
                          : l.exSendConsultRequest,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.gym, required this.trainer});

  final Gym gym;
  final Trainer trainer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String typeLabel = l.exTrainerConsultType;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.softBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FigmaColors.primaryA(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.exConsultTarget,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: FigmaColors.primaryA(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            trainer.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trainer.role ?? l.exTrainerDedicated,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${l.exTrainerAffiliation} · ${gym.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceField<T> extends StatelessWidget {
  const _ChoiceField({
    required this.title,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.errorText,
    this.chipKeyPrefix,
    super.key,
  });

  final String title;
  final List<T> values;
  final Map<T, String> labels;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String? errorText;

  /// 칩마다 붙일 키의 앞자리. E2E 가 화면에 보이는 **문구 대신 자리**로 칩을 고를
  /// 수 있게 한다 — 문구는 번역이 바뀌면 흔들리고, 이 화면은 선택지가 많다. (#640)
  final String? chipKeyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldTitle(title: title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final (int i, T value) in values.indexed)
              ChoiceChip(
                key: chipKeyPrefix == null
                    ? null
                    : ValueKey<String>('$chipKeyPrefix-$i'),
                label: Text(labels[value]!),
                selected: selected == value,
                selectedColor: FigmaColors.primaryA(0.14),
                side: BorderSide(
                  color: selected == value
                      ? FigmaColors.primary
                      : FigmaColors.hairline,
                ),
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
        if (errorText != null) _ErrorText(errorText!),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap, super.key});

  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String text = date == null
        ? l.exSelectDate
        : MaterialLocalizations.of(context).formatMediumDate(date!);
    return Material(
      color: FigmaColors.softBlue,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FigmaColors.hairline),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: FigmaColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: date == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: date == null
                        ? AppColors.mutedForeground
                        : FigmaColors.ink,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: FigmaColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldTitle extends StatelessWidget {
  const _FieldTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: FigmaColors.ink,
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

class _PendingNotice extends StatelessWidget {
  const _PendingNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FigmaColors.primaryA(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: FigmaColors.primary,
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.info_outline,
              size: 34,
              color: FigmaColors.textFaint,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.foreground),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(l.actionRetry)),
            ],
          ],
        ),
      ),
    );
  }
}
