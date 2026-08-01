import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// Categories shared with the member app's latest exercise record flow.
const List<String> kRoutineCategoryLabels = <String>[
  '걷기',
  '유산소',
  '근력',
  '요가',
  '스트레칭',
  '기타',
];

class RoutineCategoryDropdown extends StatelessWidget {
  const RoutineCategoryDropdown({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = kRoutineCategoryLabels.contains(value) ? value : '기타';
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isDense: true,
      decoration: const InputDecoration(
        labelText: '운동 카테고리',
        labelStyle: TextStyle(color: AppColors.mutedForeground),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
      items: <DropdownMenuItem<String>>[
        for (final category in kRoutineCategoryLabels)
          DropdownMenuItem<String>(value: category, child: Text(category)),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

/// Numeric minute input. The recommendation stays a placeholder until the
/// trainer types a value and confirms it with Enter/Done; confirmed input is
/// highlighted in navy.
class RoutineMinutesField extends StatefulWidget {
  const RoutineMinutesField({
    required this.recommendedMinutes,
    required this.onSaved,
    this.requiredConfirmation = false,
    super.key,
  });

  final int recommendedMinutes;
  final ValueChanged<int> onSaved;
  final bool requiredConfirmation;

  @override
  State<RoutineMinutesField> createState() => _RoutineMinutesFieldState();
}

class _RoutineMinutesFieldState extends State<RoutineMinutesField> {
  final TextEditingController _controller = TextEditingController();
  bool _saved = false;
  String? _errorText;

  @override
  void didUpdateWidget(covariant RoutineMinutesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recommendedMinutes != widget.recommendedMinutes) {
      final confirmedMinutes = int.tryParse(_controller.text.trim());
      if (_saved && confirmedMinutes == widget.recommendedMinutes) return;
      _controller.clear();
      _saved = false;
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final minutes = int.tryParse(raw.trim());
    if (minutes == null || minutes < 1 || minutes > 600) {
      setState(() {
        _saved = false;
        _errorText = '1~600분 사이로 입력해 주세요';
      });
      return;
    }
    setState(() {
      _saved = true;
      _errorText = null;
    });
    widget.onSaved(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (_) {
        if (_saved || _errorText != null) {
          setState(() {
            _saved = false;
            _errorText = null;
          });
        }
      },
      onSubmitted: _submit,
      decoration: InputDecoration(
        labelText: '운동 시간',
        hintText: '${widget.recommendedMinutes}분 추천',
        helperText: widget.requiredConfirmation && !_saved
            ? '시간을 입력하고 Enter로 저장해 주세요'
            : _saved
            ? '저장됨'
            : 'Enter로 변경 시간을 저장할 수 있어요',
        errorText: _errorText,
        suffixText: '분',
        prefixIcon: Icon(
          _saved ? Icons.check_circle : Icons.schedule_outlined,
          size: 18,
          color: _saved ? AppColors.accent : AppColors.mutedForeground,
        ),
        filled: true,
        fillColor: _saved ? AppColors.accentSurface : AppColors.inputBackground,
        labelStyle: TextStyle(
          color: _saved ? AppColors.accent : AppColors.mutedForeground,
        ),
        hintStyle: const TextStyle(color: AppColors.mutedForeground),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(AppRadius.md),
          borderSide: BorderSide(
            color: _saved ? AppColors.accent : AppColors.borderStrong,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadius.md),
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(AppRadius.md),
          borderSide: BorderSide(color: AppColors.destructive),
        ),
      ),
    );
  }
}
