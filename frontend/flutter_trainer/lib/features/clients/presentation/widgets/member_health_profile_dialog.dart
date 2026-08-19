import 'package:flutter/material.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/features/clients/domain/entities/member_health_profile.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

Future<void> showMemberHealthProfileDialog(
  BuildContext context, {
  required String memberId,
  required ClientRepository repository,
  String fallbackGender = '',
}) => showDialog<void>(
  context: context,
  builder: (_) => _MemberHealthProfileDialog(
    memberId: memberId,
    repository: repository,
    fallbackGender: fallbackGender,
  ),
);

class _MemberHealthProfileDialog extends StatefulWidget {
  const _MemberHealthProfileDialog({
    required this.memberId,
    required this.repository,
    this.fallbackGender = '',
  });

  final String memberId;
  final ClientRepository repository;

  /// 저장된 성별이 없을 때 열어 둘 값 — 로스터가 이미 말하고 있는 성별이다.
  ///
  /// 헤더가 '여성'이라고 적어 둔 회원의 대화상자가 빈 칸으로 열리면 화면 두
  /// 곳이 서로 다른 말을 한다. 데모 저장소는 이미 같은 값을 채워 주는데, 실
  /// API 는 서버에 성별이 없으면 빈 문자열을 내려 이 자리만 비어 있었다(#960).
  final String fallbackGender;

  @override
  State<_MemberHealthProfileDialog> createState() =>
      _MemberHealthProfileDialogState();
}

class _MemberHealthProfileDialogState
    extends State<_MemberHealthProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Future<MemberHealthProfile> _profile;
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _conditions = TextEditingController();
  final _goals = TextEditingController();
  final _weeklyCount = TextEditingController();
  final _weeklyMinutes = TextEditingController();
  final _weeklyBurn = TextEditingController();
  String _gender = '';
  bool _initialized = false;
  bool _profileLoaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.fetchHealthProfile(widget.memberId).then((
      profile,
    ) {
      if (mounted) setState(() => _profileLoaded = true);
      return profile;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _height,
      _weight,
      _conditions,
      _goals,
      _weeklyCount,
      _weeklyMinutes,
      _weeklyBurn,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initialize(MemberHealthProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _gender = profile.gender.isEmpty ? widget.fallbackGender : profile.gender;
    _height.text = _displayNumber(profile.heightCm);
    _weight.text = _displayNumber(profile.weightKg);
    _conditions.text = profile.conditions;
    _goals.text = profile.goals;
    _weeklyCount.text = profile.weeklyWorkoutGoal?.toString() ?? '';
    _weeklyMinutes.text = profile.weeklyExerciseMinutesGoal?.toString() ?? '';
    _weeklyBurn.text = profile.weeklyBurnGoal?.toString() ?? '';
  }

  String _displayNumber(double? value) => value == null
      ? ''
      : value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  Object? _number(String value, {required bool integer}) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return integer ? int.parse(text) : double.parse(text);
  }

  String? _validate(
    AppLocalizations l,
    String? value, {
    required double min,
    required double max,
    bool integer = false,
  }) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = integer
        ? int.tryParse(value.trim())
        : double.tryParse(value.trim());
    if (parsed == null || parsed < min || parsed > max) {
      return l.memberHealthRange('$min', '$max');
    }
    return null;
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateHealthProfile(widget.memberId, {
        'gender': _gender,
        'height_cm': _number(_height.text, integer: false),
        'weight_kg': _number(_weight.text, integer: false),
        'conditions': _conditions.text.trim(),
        'goals': _goals.text.trim(),
        'weekly_workout_goal': _number(_weeklyCount.text, integer: true),
        'weekly_exercise_minutes_goal': _number(
          _weeklyMinutes.text,
          integer: true,
        ),
        'weekly_burn_goal': _number(_weeklyBurn.text, integer: true),
      });
      if (mounted) Navigator.of(context).pop();
    } on AppError catch (error) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serverDetailOr(l, error.message, l.memberHealthSaveFailed),
          ),
        ),
      );
      setState(() => _saving = false);
    } catch (_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.memberHealthSaveFailed)));
      setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) =>
      InputDecoration(labelText: label);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.memberHealthTitle),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<MemberHealthProfile>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Text(
                error is AppError
                    ? serverDetailOr(l, error.message, l.memberHealthLoadFailed)
                    : l.memberHealthLoadFailed,
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final profile = snapshot.data!;
            _initialize(profile);
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.memberName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue:
                          ['', 'male', 'female', 'other'].contains(_gender)
                          ? _gender
                          : '',
                      decoration: _decoration(l.memberHealthGender),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(l.memberHealthGenderUnset),
                        ),
                        DropdownMenuItem(
                          value: 'male',
                          child: Text(l.memberHealthGenderMale),
                        ),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text(l.memberHealthGenderFemale),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text(l.memberHealthGenderOther),
                        ),
                      ],
                      onChanged: (value) => _gender = value ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _height,
                            decoration: _decoration(l.memberHealthHeight),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                _validate(l, value, min: 50, max: 300),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weight,
                            decoration: _decoration(l.memberHealthWeight),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                _validate(l, value, min: 20, max: 500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _conditions,
                      decoration: _decoration(l.memberHealthConditions),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _goals,
                      decoration: _decoration(l.memberHealthGoals),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.memberHealthWeeklyGoal,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weeklyCount,
                            decoration: _decoration(l.memberHealthWeeklyCount),
                            keyboardType: TextInputType.number,
                            validator: (value) => _validate(
                              l,
                              value,
                              min: 0,
                              max: 14,
                              integer: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _weeklyMinutes,
                            decoration: _decoration(
                              l.memberHealthWeeklyMinutes,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) => _validate(
                              l,
                              value,
                              min: 0,
                              max: 10080,
                              integer: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _weeklyBurn,
                            decoration: _decoration(l.memberHealthWeeklyBurn),
                            keyboardType: TextInputType.number,
                            validator: (value) => _validate(
                              l,
                              value,
                              min: 0,
                              max: 100000,
                              integer: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: _saving || !_profileLoaded ? null : _save,
          child: Text(_saving ? l.memberHealthSaving : l.actionSave),
        ),
      ],
    );
  }
}
