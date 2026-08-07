import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

enum _ExerciseGoal { weightLoss, strength, fitness, posture, health, other }

enum _HealthPurpose { weight, chronic, rehab, general, none, other }

enum _PreferredTime { morning, afternoon, evening, flexible }

class ConsultationRequestPage extends ConsumerStatefulWidget {
  const ConsultationRequestPage({
    required this.targetType,
    required this.gymId,
    super.key,
  });

  final ConsultationTargetType? targetType;
  final String gymId;

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

  void _submit({
    required Gym gym,
    required Map<_ExerciseGoal, String> goalLabels,
    required Map<_HealthPurpose, String> purposeLabels,
    required Map<_PreferredTime, String> timeLabels,
  }) {
    if (_submitting) return;
    setState(() => _attempted = true);
    if (!_isValid) return;

    final ConsultationTargetType targetType = widget.targetType!;
    final controller = ref.read(consultationRequestControllerProvider.notifier);
    if (controller.hasPending(targetType: targetType, gymId: gym.id)) {
      return;
    }

    setState(() => _submitting = true);
    final DateTime now = DateTime.now();
    final String message = _messageController.text.trim();
    final ConsultationRequest request = ConsultationRequest(
      id: 'consult-${now.microsecondsSinceEpoch}',
      targetType: targetType,
      gymId: gym.id,
      gymName: gym.name,
      trainerName: targetType == ConsultationTargetType.trainer
          ? gym.trainerName
          : null,
      trainerRole: targetType == ConsultationTargetType.trainer
          ? gym.trainerRole
          : null,
      exerciseGoal: goalLabels[_exerciseGoal]!,
      healthPurpose: _healthPurpose == _HealthPurpose.other
          ? _healthPurposeController.text.trim()
          : purposeLabels[_healthPurpose]!,
      preferredDate: _preferredDate!,
      preferredTimeSlot: timeLabels[_preferredTime]!,
      message: message.isEmpty ? null : message,
      status: ConsultationStatus.pending,
      createdAt: now,
    );
    if (!controller.add(request)) {
      setState(() => _submitting = false);
      return;
    }
    context.replace(AppRoutes.consultationComplete, extra: request);
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
    final bool targetIsValid =
        widget.targetType != null &&
        gym != null &&
        (widget.targetType != ConsultationTargetType.trainer ||
            (gym.trainerName?.isNotEmpty ?? false));

    final Widget body;
    if (targetIsValid) {
      final ConsultationTargetType targetType = widget.targetType!;
      final bool hasPending = requests.any(
        (ConsultationRequest request) =>
            request.targetType == targetType &&
            request.gymId == gym.id &&
            request.status == ConsultationStatus.pending,
      );
      body = _buildForm(gym: gym, hasPending: hasPending);
    } else if (widget.targetType == null ||
        widget.gymId.isEmpty ||
        gym != null) {
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

  Widget _buildForm({required Gym gym, required bool hasPending}) {
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: <Widget>[
            _TargetCard(targetType: widget.targetType!, gym: gym),
            const SizedBox(height: 20),
            _ChoiceField<_ExerciseGoal>(
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
            _DateField(date: _preferredDate, onTap: _selectDate),
            if (_attempted && _preferredDate == null)
              _ErrorText(l.exDateRequired),
            const SizedBox(height: 20),
            _ChoiceField<_PreferredTime>(
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
              onPressed: hasPending || _submitting
                  ? null
                  : () => _submit(
                      gym: gym,
                      goalLabels: goalLabels,
                      purposeLabels: purposeLabels,
                      timeLabels: timeLabels,
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
  const _TargetCard({required this.targetType, required this.gym});

  final ConsultationTargetType targetType;
  final Gym gym;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool trainerTarget = targetType == ConsultationTargetType.trainer;
    final String typeLabel = trainerTarget
        ? l.exTrainerConsultType
        : l.exGymConsultType;
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
            trainerTarget ? gym.trainerName! : gym.name,
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
            trainerTarget
                ? (gym.trainerRole ?? l.exTrainerDedicated)
                : gym.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            trainerTarget
                ? '${l.exTrainerAffiliation} · ${gym.name}'
                : '${l.exAssignedTrainer} · ${l.exTrainerAssignedLater}',
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
    super.key,
  });

  final String title;
  final List<T> values;
  final Map<T, String> labels;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String? errorText;

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
            for (final T value in values)
              ChoiceChip(
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
  const _DateField({required this.date, required this.onTap});

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
