import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';

/// Category order mirrors the member app's exercise-add sheet.
///
/// 여기 담긴 것은 **계약값**이다(서버 `RoutineType` Literal). 화면 문구는
/// `routineTypeLabel(l, value)` 로 따로 가져온다 — 번역하면 서버가 422 를
/// 돌려준다. (#501)
const List<String> kRoutineCategoryLabels = kRoutineTypes;

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
    final AppLocalizations l = AppLocalizations.of(context);
    final selected = kRoutineCategoryLabels.contains(value) ? value : '기타';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l.routineFieldType,
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
                // key 는 계약값으로 — 로케일이 바뀌어도 위젯 identity 는 같아야
                // 하고, 기존 테스트도 이 키를 쓴다.
                key: ValueKey<String>('$keyPrefix-$category'),
                label: routineTypeLabel(l, category),
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
    this.label,
    super.key,
  });

  final int minutes;
  final ValueChanged<int> onChanged;

  /// Optional context-specific label. Individual exercises use the default
  /// `routineFieldMinutes`; generation constraints pass the total-time label.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final value = minutes.clamp(5, 120).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label ?? l.routineFieldMinutes,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.subtleForeground,
              ),
            ),
            const Spacer(),
            Text(
              l.minutesShort(minutes),
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

  /// (라벨 키, 계약값). 저장되는 것은 뒤쪽 값이다 — 라벨만 로케일을 따른다.
  static List<(String, String)> _choices(AppLocalizations l) =>
      <(String, String)>[
        (l.intensityLight, 'low'),
        (l.intensityModerate, 'moderate'),
        (l.intensityHigh, 'high'),
      ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l.routineFieldIntensity,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (var index = 0; index < _choices(l).length; index++) ...<Widget>[
              Builder(
                builder: (BuildContext context) {
                  final (String label, String wire) = _choices(l)[index];
                  return Expanded(
                    child: _ChoiceButton(
                      // key 는 계약값으로 — 로케일이 바뀌어도 identity 는 같다.
                      key: ValueKey<String>('routine-intensity-$wire'),
                      label: label,
                      selected: value == wire,
                      centered: true,
                      onTap: () => onChanged(wire),
                    ),
                  );
                },
              ),
              if (index < _choices(l).length - 1)
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
