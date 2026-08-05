import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// Category order and labels mirror the member app's exercise-add sheet.
const List<String> kRoutineCategoryLabels = <String>[
  '걷기',
  '유산소',
  '근력',
  '요가',
  '스트레칭',
  '기타',
];

/// Button-style category picker matching the member exercise-add sheet.
class RoutineCategoryChips extends StatelessWidget {
  const RoutineCategoryChips({
    required this.value,
    required this.onChanged,
    this.keyPrefix = 'routine-category',
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final selected = kRoutineCategoryLabels.contains(value) ? value : '기타';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '운동 유형',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final category in kRoutineCategoryLabels)
              _ChoiceButton(
                key: ValueKey<String>('$keyPrefix-$category'),
                label: category,
                selected: selected == category,
                onTap: () => onChanged(category),
              ),
          ],
        ),
      ],
    );
  }
}

/// 5–120 minute, five-minute-step slider matching the member add sheet.
class RoutineMinutesSlider extends StatelessWidget {
  const RoutineMinutesSlider({
    required this.minutes,
    required this.onChanged,
    super.key,
  });

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = minutes.clamp(5, 120).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              '운동 시간',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.subtleForeground,
              ),
            ),
            const Spacer(),
            Text(
              '$minutes분',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 5,
          max: 120,
          divisions: 23,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.borderStrong,
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }
}

/// Three-button intensity picker matching the member add sheet.
class RoutineIntensityChips extends StatelessWidget {
  const RoutineIntensityChips({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const List<(String, String)> _choices = <(String, String)>[
    ('가벼움', 'low'),
    ('보통', 'moderate'),
    ('높음', 'high'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '운동 강도',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (var index = 0; index < _choices.length; index++) ...<Widget>[
              Expanded(
                child: _ChoiceButton(
                  key: ValueKey<String>(
                    'routine-intensity-${_choices[index].$2}',
                  ),
                  label: _choices[index].$1,
                  selected: value == _choices[index].$2,
                  centered: true,
                  onTap: () => onChanged(_choices[index].$2),
                ),
              ),
              if (index < _choices.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.centered = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSurface : AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: Container(
          alignment: centered ? Alignment.center : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.accent : AppColors.subtleForeground,
            ),
          ),
        ),
      ),
    );
  }
}
