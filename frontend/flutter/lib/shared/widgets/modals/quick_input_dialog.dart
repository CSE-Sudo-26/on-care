import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/atoms/app_button.dart';
import 'package:oncare/design_system/atoms/app_input.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/vitals/domain/entities/vital.dart';
import 'package:oncare/features/vitals/presentation/controllers/vitals_controller.dart';

enum QuickInputKind { weight, bloodPressure, bloodSugar }

/// Centered dialog that mirrors the React Dashboard's "체중/혈압/혈당
/// 입력" modal. Submitting now persists through [VitalsRepository] so
/// the value survives the drift round-trip; the `latestVitalProvider`
/// family is invalidated on success so MyHealth/Dashboard can refetch.
///
/// Resolves to `true` when a value was saved (the caller can then refresh
/// its own aggregates, e.g. `myHealthStateProvider`), and `false` when the
/// dialog was cancelled/dismissed.
Future<bool> showQuickInputDialog(
  BuildContext context, {
  required QuickInputKind kind,
}) async {
  final bool? saved = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (BuildContext ctx) => _QuickInputDialog(kind: kind),
  );
  return saved ?? false;
}

class _QuickInputDialog extends ConsumerStatefulWidget {
  const _QuickInputDialog({required this.kind});
  final QuickInputKind kind;

  @override
  ConsumerState<_QuickInputDialog> createState() => _QuickInputDialogState();
}

class _QuickInputDialogState extends ConsumerState<_QuickInputDialog> {
  final TextEditingController _primary = TextEditingController();
  final TextEditingController _secondary = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
    QuickInputKind.weight => '체중 입력',
    QuickInputKind.bloodPressure => '혈압 입력',
    QuickInputKind.bloodSugar => '혈당 입력',
  };

  VitalSubmission? _buildSubmission() {
    switch (widget.kind) {
      case QuickInputKind.weight:
        final kg = double.tryParse(_primary.text.trim());
        if (kg == null || kg <= 0) return null;
        return WeightSubmission(kg: kg);
      case QuickInputKind.bloodPressure:
        final s = int.tryParse(_primary.text.trim());
        final d = int.tryParse(_secondary.text.trim());
        if (s == null || d == null || s <= 0 || d <= 0) return null;
        return BloodPressureSubmission(systolic: s, diastolic: d);
      case QuickInputKind.bloodSugar:
        final mg = int.tryParse(_primary.text.trim());
        if (mg == null || mg <= 0) return null;
        return BloodSugarSubmission(mgPerDl: mg);
    }
  }

  Future<void> _save() async {
    final submission = _buildSubmission();
    if (submission == null) {
      setState(() => _error = '값을 확인해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(vitalsRepositoryProvider);
      await repo.submit(submission);
      // Refresh listeners (MyHealth IndicatorTile / Dashboard tiles).
      ref.invalidate(latestVitalProvider(submission.kind));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '저장 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _CloseButton(
                  onTap: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ..._fields(),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _saving ? '저장 중…' : '저장하기',
              fullWidth: true,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields() {
    switch (widget.kind) {
      case QuickInputKind.weight:
        return <Widget>[
          AppInput(
            controller: _primary,
            label: '체중 (kg)',
            hint: '72.0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ];
      case QuickInputKind.bloodPressure:
        return <Widget>[
          AppInput(
            controller: _primary,
            label: '수축기 (mmHg)',
            hint: '120',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppInput(
            controller: _secondary,
            label: '이완기 (mmHg)',
            hint: '80',
            keyboardType: TextInputType.number,
          ),
        ];
      case QuickInputKind.bloodSugar:
        return <Widget>[
          AppInput(
            controller: _primary,
            label: '혈당 (mg/dL)',
            hint: '95',
            keyboardType: TextInputType.number,
          ),
        ];
    }
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.close, size: 18),
        ),
      ),
    );
  }
}
