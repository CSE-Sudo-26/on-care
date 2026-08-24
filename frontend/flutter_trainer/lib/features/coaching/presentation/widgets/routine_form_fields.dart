import 'package:flutter/material.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/portrait_date_picker.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/dtos/routine_dtos.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/number_stepper.dart';

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
          style: const TextStyle(
            fontSize: 12,
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

/// 운동 시간 한 칸 — 직접 입력하고 −/+ 로 한 칸씩 고친다. (#1276)
///
/// 예전에는 슬라이더였다. "대충 이쯤" 을 고르기엔 좋지만 트레이너가 아는
/// 값(45분)을 그대로 넣기에는 나쁘다 — 회원 앱의 운동 추가 시트와 같은 모양으로
/// 맞췄다.
class RoutineMinutesField extends StatelessWidget {
  const RoutineMinutesField({
    required this.minutes,
    required this.onChanged,
    this.label,
    this.keyPrefix,
    super.key,
  });

  final int minutes;
  final ValueChanged<int> onChanged;

  /// Optional context-specific label. Individual exercises use the default
  /// `routineFieldMinutes`; generation constraints pass the total-time label.
  final String? label;

  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _LabeledStepper(
      label: label ?? l.routineFieldMinutes,
      value: minutes.toDouble(),
      min: 1,
      max: 600,
      suffix: l.routineUnitMinutes,
      keyPrefix: keyPrefix ?? 'routine-minutes',
      onChanged: (double v) => onChanged(v.round()),
    );
  }
}

/// 근력의 세트 수 한 칸.
class RoutineSetsField extends StatelessWidget {
  const RoutineSetsField({
    required this.sets,
    required this.onChanged,
    this.keyPrefix,
    super.key,
  });

  final int sets;
  final ValueChanged<int> onChanged;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _LabeledStepper(
      label: l.routineFieldSets,
      value: sets.toDouble(),
      min: 1,
      max: 99,
      suffix: l.routineUnitSets,
      keyPrefix: keyPrefix ?? 'routine-sets',
      onChanged: (double v) => onChanged(v.round()),
    );
  }
}

/// 근력의 중량 한 칸. 소수점 한 자리까지 받는다 — 원판은 0.5kg 단위다.
class RoutineWeightField extends StatelessWidget {
  const RoutineWeightField({
    required this.weight,
    required this.onChanged,
    this.keyPrefix,
    super.key,
  });

  final double weight;
  final ValueChanged<double> onChanged;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _LabeledStepper(
      label: l.routineFieldWeight,
      value: weight,
      min: 0,
      max: 1000,
      decimals: 1,
      suffix: l.routineUnitKg,
      keyPrefix: keyPrefix ?? 'routine-weight',
      onChanged: onChanged,
    );
  }
}

/// 운동 이름 한 칸 — 자유 입력. 유형은 집계 축이라 넷뿐이라, 무슨 운동인지는
/// 이 칸에만 남는다. (#1276)
class RoutineNameField extends StatelessWidget {
  const RoutineNameField({
    required this.controller,
    this.label,
    this.keyPrefix = 'routine-exercise-name',
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(label ?? l.routineFieldExerciseName),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: ValueKey<String>(keyPrefix),
          controller: controller,
          maxLength: 100,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            hintText: l.routineFieldExerciseNameHint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(AppRadius.md),
              borderSide: BorderSide(color: AppColors.borderStrong),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(AppRadius.md),
              borderSide: BorderSide(color: AppColors.borderStrong),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(AppRadius.md),
              borderSide: BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

/// 날짜 한 칸 — 눌러서 달력을 연다. 기본값은 오늘이다. (#1276)
class RoutineDateField extends StatelessWidget {
  const RoutineDateField({
    required this.date,
    required this.onChanged,
    this.keyPrefix = 'routine-date',
    super.key,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(l.routineFieldDate),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          key: ValueKey<String>(keyPrefix),
          borderRadius: const BorderRadius.all(AppRadius.md),
          onTap: () async {
            final DateTime now = nowKst();
            final DateTime? picked = await showPortraitDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(now.year - 2),
              // 프로그램은 앞으로 할 운동도 잡는다 — 회원 기록과 달리 미래를
              // 막지 않는다.
              lastDate: DateTime(now.year + 2),
            );
            if (picked != null) {
              onChanged(DateTime(picked.year, picked.month, picked.day));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(AppRadius.md),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    // 로케일이 정하는 날짜 문구 — 하드코딩하면 영어 화면에도
                    // 한국식 표기가 남는다.
                    MaterialLocalizations.of(context).formatFullDate(date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.subtleForeground,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 예상 소모 칼로리 — 읽기 전용. 유형·시간(또는 세트)·강도에서 나온다.
class RoutineCaloriesLine extends StatelessWidget {
  const RoutineCaloriesLine({required this.calories, super.key});

  final int calories;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('routine-calories'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.local_fire_department,
            size: 16,
            color: AppColors.brandOrange,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.routineFieldCalories,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
          Text(
            l.routineKcalValue(calories),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledStepper extends StatelessWidget {
  const _LabeledStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.keyPrefix,
    required this.onChanged,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final String keyPrefix;
  final int decimals;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(alignment: Alignment.centerLeft, child: _FieldLabel(label)),
        const SizedBox(height: AppSpacing.sm),
        NumberStepper(
          value: value,
          min: min,
          max: max,
          decimals: decimals,
          suffix: suffix,
          keyPrefix: keyPrefix,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.subtleForeground,
    ),
  );
}

/// Three-button intensity picker matching the member add sheet.
class RoutineIntensityChips extends StatelessWidget {
  const RoutineIntensityChips({
    required this.value,
    required this.onChanged,
    this.keyPrefix = 'routine-intensity',
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String keyPrefix;

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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (
              var index = 0;
              index < _choices(l).length;
              index++
            ) ...<Widget>[
              Builder(
                builder: (BuildContext context) {
                  final (String label, String wire) = _choices(l)[index];
                  return Expanded(
                    child: _ChoiceButton(
                      // key 는 계약값으로 — 로케일이 바뀌어도 identity 는 같다.
                      key: ValueKey<String>('$keyPrefix-$wire'),
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
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.accent : AppColors.subtleForeground,
            ),
          ),
        ),
      ),
    );
  }
}
