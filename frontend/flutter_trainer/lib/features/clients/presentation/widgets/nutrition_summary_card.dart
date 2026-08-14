/// 고객의 오늘 영양 요약 — **회원 앱 식단 탭과 같은 카드**다. (#698)
///
/// 트레이너가 보던 것은 6칸짜리 타일 묶음이라, 같은 하루를 회원과 트레이너가 다른
/// 그림으로 봤다. 회원이 "칼로리 링이 80%" 라고 말할 때 트레이너 화면에는 링이
/// 없었다.
///
/// 두 앱은 서로 다른 Dart 패키지라 위젯을 그대로 가져올 수 없어 여기에 옮겼다.
/// 색·문구는 트레이너 앱 토큰으로 바꾸되 **구성과 규칙은 회원 앱을 따른다.**
///
///  * 칼로리는 큰 숫자 + 달성률 링. 목표를 넘기면 빨강.
///  * 탄단지는 진행 바.
///  * 나트륨·당류는 별도 카드 두 장. 정상 초록 / 초과 빨강 — 둘은 같은 성격의
///    지표라 "정상" 을 서로 다른 색으로 말하지 않는다.
///
/// 목표값은 회원 앱 기본값과 같다(`UserProfile.defaultDaily*`). 회원이 자기
/// 목표를 바꿔도 트레이너 API 가 그 값을 주지 않아, 지금은 기본값으로 그린다.
library;

import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// 회원 앱 `UserProfile` 의 기본 목표와 같은 값.
const int calorieTargetKcal = 2000;
const int carbsTargetG = 275;
const int proteinTargetG = 100;
const int fatTargetG = 55;

/// 진행 바·링의 바닥색.
const Color _track = Color(0xFFE8EEF4);

/// 한 지표의 표시값 한 벌.
class _Item {
  const _Item({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.current,
    required this.target,
  });

  final String label;
  final String value;
  final String goal;
  final String unit;
  final num current;
  final num target;

  double get ratio =>
      target <= 0 ? 0 : (current / target).clamp(0.0, 1.0).toDouble();

  bool get isOverGoal => current > target;

  /// 목표까지 남은/넘은 양.
  String get difference => _number((current - target).abs());
}

String _number(num v) {
  if (v != v.roundToDouble()) return v.toStringAsFixed(1);
  return v.toInt().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (Match _) => ',',
  );
}

/// 오늘 섭취 칼로리 + 탄단지 + 나트륨·당류.
class NutritionSummaryCard extends StatelessWidget {
  /// Creates the summary for [client].
  const NutritionSummaryCard({super.key, required this.client});

  /// 오늘 합계를 들고 있는 고객.
  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);

    final _Item calories = _Item(
      label: l.metricCalories,
      value: _number(client.calories),
      goal: _number(calorieTargetKcal),
      unit: 'kcal',
      current: client.calories,
      target: calorieTargetKcal,
    );
    final List<_Item> macros = <_Item>[
      _Item(
        label: l.metricCarbs,
        value: _number(client.carbsG),
        goal: _number(carbsTargetG),
        unit: 'g',
        current: client.carbsG,
        target: carbsTargetG,
      ),
      _Item(
        label: l.metricProtein,
        value: _number(client.proteinG),
        goal: _number(proteinTargetG),
        unit: 'g',
        current: client.proteinG,
        target: proteinTargetG,
      ),
      _Item(
        label: l.metricFat,
        value: _number(client.fatG),
        goal: _number(fatTargetG),
        unit: 'g',
        current: client.fatG,
        target: fatTargetG,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          key: const Key('client-nutrition-summary-card'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.all(AppRadius.card),
            boxShadow: kCardShadow,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CalorieRow(calories: calories, label: l.dietTodaySummary),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  if (c.maxWidth < 280) {
                    return Column(
                      children: <Widget>[
                        for (final _Item m in macros) ...<Widget>[
                          _MacroItem(item: m),
                          if (m != macros.last)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (int i = 0; i < macros.length; i++) ...<Widget>[
                        Expanded(child: _MacroItem(item: macros[i])),
                        if (i < macros.length - 1)
                          const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _StatusCards(
          sodium: _Item(
            label: l.metricSodium,
            value: _number(client.sodiumMg),
            goal: _number(sodiumTargetMg),
            unit: 'mg',
            current: client.sodiumMg,
            target: sodiumTargetMg,
          ),
          sugar: _Item(
            label: l.metricSugar,
            value: _number(client.sugarG),
            goal: _number(sugarTargetG),
            unit: 'g',
            current: client.sugarG,
            target: sugarTargetG,
          ),
        ),
      ],
    );
  }
}

class _CalorieRow extends StatelessWidget {
  const _CalorieRow({required this.calories, required this.label});

  final _Item calories;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Color color = calories.isOverGoal
        ? AppColors.overTarget
        : AppColors.primary;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: calories.value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextSpan(
                        text: ' / ${calories.goal} ${calories.unit}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                calories.isOverGoal
                    ? l.dietAmountOver(
                        '${calories.difference} ${calories.unit}',
                      )
                    : l.dietAmountRemaining(
                        '${calories.difference} ${calories.unit}',
                      ),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: calories.isOverGoal
                      ? AppColors.overTarget
                      : AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox.square(
          dimension: 92,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox.square(
                dimension: 92,
                child: CircularProgressIndicator(
                  key: const Key('client-nutrition-calorie-progress'),
                  value: calories.ratio,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: _track,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${(calories.ratio * 100).round()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.dietAchieveRate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroItem extends StatelessWidget {
  const _MacroItem({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('client-nutrition-macro-${item.label}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: item.value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                TextSpan(
                  text: ' / ${item.goal}${item.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 7),
        _Bar(
          progress: item.ratio,
          color: AppColors.primary.withValues(alpha: 0.65),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const double h = 6;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: h,
          child: Stack(
            children: <Widget>[
              const Positioned.fill(child: ColoredBox(color: _track)),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: c.maxWidth * progress.clamp(0.0, 1.0),
                  height: h,
                  child: ColoredBox(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCards extends StatelessWidget {
  const _StatusCards({required this.sodium, required this.sugar});

  final _Item sodium;
  final _Item sugar;

  @override
  Widget build(BuildContext context) {
    final Widget a = _StatusCard(
      key: const Key('client-nutrition-sodium-status'),
      item: sodium,
    );
    final Widget b = _StatusCard(
      key: const Key('client-nutrition-sugar-status'),
      item: sugar,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth < 310) {
          return Column(
            children: <Widget>[
              a,
              const SizedBox(height: AppSpacing.sm),
              b,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: a),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: b),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({super.key, required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 나트륨·당류는 같은 성격의 지표다. "정상" 을 서로 다른 색으로 말하지 않는다.
    final Color status = item.isOverGoal
        ? AppColors.overTarget
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(
          color: item.isOverGoal
              ? AppColors.overTarget.withValues(alpha: 0.32)
              : AppColors.primary.withValues(alpha: 0.18),
        ),
        boxShadow: kCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _VerticalBar(progress: item.ratio, color: status),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      item.isOverGoal
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: status,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: item.value,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: status,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${item.goal}${item.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.isOverGoal
                      ? l.dietAmountOver('${item.difference}${item.unit}')
                      : l.dietAmountRemaining('${item.difference}${item.unit}'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalBar extends StatelessWidget {
  const _VerticalBar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const double h = 56;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 6,
        height: h,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: ColoredBox(color: _track)),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 6,
                height: h * progress.clamp(0.0, 1.0),
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
