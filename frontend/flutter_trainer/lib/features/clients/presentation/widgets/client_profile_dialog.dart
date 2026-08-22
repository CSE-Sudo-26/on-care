import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/member_health_profile.dart';
import 'package:oncare_trainer/features/clients/domain/entities/trainer_memo.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/services/trainer_memo_repository.dart';

/// Opens the merged 신체·목표·메모 dialog for [clientId].
///
/// The header's 메모 quick action is the only way in — one button, one
/// popup, the way 신체·목표 and 메모 each had their own before (#1024).
Future<void> showClientProfileDialog(
  BuildContext context, {
  required String clientId,
  required String clientName,
  String fallbackGender = '',
}) => showDialog<void>(
  context: context,
  builder: (_) => ClientProfileDialog(
    clientId: clientId,
    clientName: clientName,
    fallbackGender: fallbackGender,
  ),
);

/// Merge of the old 신체·목표 and 메모 modal dialogs (#1024).
///
/// A trainer used to close one popup to open the other — body info, a
/// goal, and a memo about the same visit lived in places that could never
/// be on screen together. Both now share one popup: 상단 신체정보·목표,
/// 하단 메모.
///
/// The merged content first landed as an inline `ExpansionTile` on the
/// detail page. Trainers asked for the popup back — editing a memo is a
/// short errand you leave again, and folding the page open pushed 식단·운동
/// off screen to do it. The merge stays; the toggle is gone.
class ClientProfileDialog extends StatelessWidget {
  /// Creates the dialog body for [clientId].
  const ClientProfileDialog({
    super.key,
    required this.clientId,
    required this.clientName,
    this.fallbackGender = '',
  });

  /// The client whose profile and memos are shown.
  final String clientId;

  /// Named in the memo section heading.
  final String clientName;

  /// 저장된 성별이 없을 때 열어 둘 값 — 로스터가 이미 말하고 있는 성별이다(#960).
  final String fallbackGender;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      key: const ValueKey<String>('client-profile-dialog'),
      title: Text(l.clientProfileSectionTitle),
      content: SizedBox(
        // Same width as the two dialogs this replaces, so the form fields
        // keep the proportions trainers already know.
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 상단: 신체정보와 목표.
              _HealthProfileSection(
                clientId: clientId,
                fallbackGender: fallbackGender,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(color: AppColors.borderStrong, height: 1),
              const SizedBox(height: AppSpacing.lg),
              // 하단: 메모. 이 열 전체가 하나의 스크롤 안에 있어, 메모가 아무리
              // 쌓여도 대화상자가 화면을 넘치지 않는다.
              _MemoSection(clientId: clientId, clientName: clientName),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('client-profile-dialog-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
    );
  }
}

/// 신체정보 · 목표 폼 — 예전 `MemberHealthProfileDialog` 의 내용을 다이얼로그
/// 밖으로 꺼낸 것이다. 저장 버튼은 이 섹션 안에 있어 메모 저장과 서로
/// 간섭하지 않는다.
class _HealthProfileSection extends ConsumerStatefulWidget {
  const _HealthProfileSection({
    required this.clientId,
    this.fallbackGender = '',
  });

  final String clientId;
  final String fallbackGender;

  @override
  ConsumerState<_HealthProfileSection> createState() =>
      _HealthProfileSectionState();
}

class _HealthProfileSectionState extends ConsumerState<_HealthProfileSection> {
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
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _profile = ref
        .read(clientRepositoryProvider)
        .fetchHealthProfile(widget.clientId)
        .then((profile) {
          if (mounted) setState(() => _profileLoaded = true);
          return profile;
        });
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
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
    setState(() {
      _saving = true;
      _saved = false;
    });
    try {
      await ref
          .read(clientRepositoryProvider)
          .updateHealthProfile(widget.clientId, <String, Object?>{
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
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
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
      InputDecoration(labelText: label, isDense: true);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<MemberHealthProfile>(
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = snapshot.data!;
        _initialize(profile);
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l.clientHealthGoals,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('client-profile-gender'),
                initialValue:
                    <String>['', 'male', 'female', 'other'].contains(_gender)
                    ? _gender
                    : '',
                decoration: _decoration(l.memberHealthGender),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text(l.memberHealthGenderUnset),
                  ),
                  DropdownMenuItem<String>(
                    value: 'male',
                    child: Text(l.memberHealthGenderMale),
                  ),
                  DropdownMenuItem<String>(
                    value: 'female',
                    child: Text(l.memberHealthGenderFemale),
                  ),
                  DropdownMenuItem<String>(
                    value: 'other',
                    child: Text(l.memberHealthGenderOther),
                  ),
                ],
                onChanged: (value) => _gender = value ?? '',
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _height,
                      decoration: _decoration(l.memberHealthHeight),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          _validate(l, value, min: 50, max: 300),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _conditions,
                decoration: _decoration(l.memberHealthConditions),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _goals,
                decoration: _decoration(l.memberHealthGoals),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l.memberHealthWeeklyGoal,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
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
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextFormField(
                      controller: _weeklyMinutes,
                      decoration: _decoration(l.memberHealthWeeklyMinutes),
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
                  const SizedBox(width: AppSpacing.xs),
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
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_saved)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Text(
                          l.actionSave,
                          style: const TextStyle(
                            color: AppColors.statusNormal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    FilledButton(
                      key: const ValueKey<String>('client-profile-save'),
                      onPressed: _saving || !_profileLoaded ? null : _save,
                      child: Text(
                        _saving ? l.memberHealthSaving : l.actionSave,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 메모 목록 — 예전 `ClientMemoDialog` 의 내용을 다이얼로그 밖으로 꺼낸 것이다.
class _MemoSection extends ConsumerStatefulWidget {
  const _MemoSection({required this.clientId, required this.clientName});

  final String clientId;
  final String clientName;

  @override
  ConsumerState<_MemoSection> createState() => _MemoSectionState();
}

class _MemoSectionState extends ConsumerState<_MemoSection> {
  /// Mirrors the backend's `TrainerMemoCreateRequest.body` cap.
  static const int _maxLength = 2000;

  final TextEditingController _draft = TextEditingController();
  bool _busy = false;
  String? _editingId;
  final TextEditingController _edit = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    _edit.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() write, String fallback) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await write();
      ref.invalidate(trainerMemosProvider(widget.clientId));
      if (!mounted) return;
      setState(() => _busy = false);
    } on AppError catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(
        serverDetailOr(AppLocalizations.of(context), error.message, fallback),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(fallback);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final body = _draft.text.trim();
    if (body.isEmpty) return;
    final l = AppLocalizations.of(context);
    await _run(() async {
      await ref
          .read(trainerMemoRepositoryProvider)
          .create(widget.clientId, body: body);
      _draft.clear();
    }, l.clientTrainerMemoSaveFailed);
  }

  Future<void> _saveEdit(TrainerMemo memo) async {
    final body = _edit.text.trim();
    if (body.isEmpty) return;
    if (body == memo.body) {
      setState(() => _editingId = null);
      return;
    }
    final l = AppLocalizations.of(context);
    await _run(() async {
      await ref
          .read(trainerMemoRepositoryProvider)
          .update(widget.clientId, memo.id, body);
      _editingId = null;
    }, l.clientTrainerMemoSaveFailed);
  }

  Future<void> _delete(TrainerMemo memo) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.clientTrainerMemoDeleteTitle),
        content: Text(l.clientTrainerMemoDeleteBody),
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
    await _run(() async {
      await ref
          .read(trainerMemoRepositoryProvider)
          .delete(widget.clientId, memo.id);
      if (_editingId == memo.id) _editingId = null;
    }, l.clientTrainerMemoDeleteFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final memos = ref.watch(trainerMemosProvider(widget.clientId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l.clientTrainerMemo,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey<String>('client-memo-input'),
          controller: _draft,
          maxLines: 3,
          maxLength: _maxLength,
          enabled: !_busy,
          decoration: InputDecoration(
            hintText: l.clientTrainerMemoHint,
            border: const OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey<String>('client-memo-add'),
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l.clientTrainerMemoAdd),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        memos.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _LoadFailed(
            message: error is AppError
                ? serverDetailOr(l, error.message, l.clientTrainerMemoLoadFailed)
                : l.clientTrainerMemoLoadFailed,
            onRetry: () =>
                ref.invalidate(trainerMemosProvider(widget.clientId)),
          ),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xl,
                  ),
                  child: Text(
                    l.clientTrainerMemoEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.mutedForeground),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (final memo in list) ...<Widget>[
                      _memoTile(l, memo),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _memoTile(AppLocalizations l, TrainerMemo memo) {
    final editing = _editingId == memo.id;
    return Container(
      key: ValueKey<String>('client-memo-${memo.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: const BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (memo.source == TrainerMemoSource.chatInsight)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 14,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l.clientTrainerMemoFromChat,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          if (editing)
            TextField(
              key: ValueKey<String>('client-memo-edit-${memo.id}'),
              controller: _edit,
              maxLines: 3,
              maxLength: _maxLength,
              enabled: !_busy,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            )
          else
            Text(memo.body),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _dayLabel(memo.updatedAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              if (editing) ...<Widget>[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _editingId = null),
                  child: Text(l.actionCancel),
                ),
                TextButton(
                  key: ValueKey<String>('client-memo-save-${memo.id}'),
                  onPressed: _busy ? null : () => _saveEdit(memo),
                  child: Text(l.actionSave),
                ),
              ] else ...<Widget>[
                TextButton(
                  key: ValueKey<String>('client-memo-edit-open-${memo.id}'),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _editingId = memo.id;
                          _edit.text = memo.body;
                        }),
                  child: Text(l.actionEdit),
                ),
                TextButton(
                  key: ValueKey<String>('client-memo-delete-${memo.id}'),
                  onPressed: _busy ? null : () => _delete(memo),
                  child: Text(l.actionDelete),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime at) {
    final local = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const ValueKey<String>('client-memo-retry'),
            onPressed: onRetry,
            child: Text(l.actionRetry),
          ),
        ],
      ),
    );
  }
}
