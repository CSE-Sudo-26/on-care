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
///  * 탄단지는 진행 바. 항목별로 목표를 넘기면 빨강 — 세 항목이 각자 판단한다.
///  * 나트륨·당류는 별도 카드 두 장. 정상 초록 / 초과 빨강 — 둘은 같은 성격의
///    지표라 "정상" 을 서로 다른 색으로 말하지 않는다.
///
/// 목표값은 회원 앱 기본값과 같다(`UserProfile.defaultDaily*`). 회원이 자기
/// 목표를 바꿔도 트레이너 API 가 그 값을 주지 않아, 지금은 기본값으로 그린다.
library;

import 'package:flutter/material.dart';

import 'package:oncare_trainer/core/utils/number_format.dart';
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

  /// 링이 그리는 비율. 한 바퀴에서 멈춘다 — 넘긴 양은 링이 아니라 옆의
  /// 문구가 말한다.
  double get ratio =>
      target <= 0 ? 0 : (current / target).clamp(0.0, 1.0).toDouble();

  /// 화면에 적는 비율. 링과 달리 자르지 않는다. 예전에는 링의 비율을 그대로
  /// 적어, 목표를 260kcal 넘긴 날에도 '100% 달성률' 이라고 말했다 — 바로
  /// 아래의 '목표보다 260 kcal 넘었어요' 와 정면으로 어긋났다(#820).
  double get labelRatio => target <= 0 ? 0 : current / target;

  bool get isOverGoal => current > target;

  /// 목표까지 남은/넘은 양.
  String get difference => formatNumber((current - target).abs());
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
      value: formatNumber(client.calories),
      goal: formatNumber(calorieTargetKcal),
      unit: 'kcal',
      current: client.calories,
      target: calorieTargetKcal,
    );
    final List<_Item> macros = <_Item>[
      _Item(
        label: l.metricCarbs,
        value: formatNumber(client.carbsG),
        goal: formatNumber(carbsTargetG),
        unit: 'g',
        current: client.carbsG,
        target: carbsTargetG,
      ),
      _Item(
        label: l.metricProtein,
        value: formatNumber(client.proteinG),
        goal: formatNumber(proteinTargetG),
        unit: 'g',
        current: client.proteinG,
        target: proteinTargetG,
      ),
      _Item(
        label: l.metricFat,
        value: formatNumber(client.fatG),
        goal: formatNumber(fatTargetG),
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
            value: formatNumber(client.sodiumMg),
            goal: formatNumber(sodiumTargetMg),
            unit: 'mg',
            current: client.sodiumMg,
            target: sodiumTargetMg,
          ),
          sugar: _Item(
            label: l.metricSugar,
            value: formatNumber(client.sugarG),
            goal: formatNumber(sugarTargetG),
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
    // 정상은 초록이다 (#1019). 바로 옆 나트륨·당류 카드가 이미 초록으로
    // 말하는데 여기만 파랑이면, 파랑이 "정상" 인지 "다른 종류의 지표" 인지 알 수
    // 없다. 회원 앱 식단 탭도 같은 규칙으로 맞췄다.
    final Color color = calories.isOverGoal
        ? AppColors.statusOver
        : AppColors.statusNormal;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                    '${(calories.labelRatio * 100).round()}%',
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
        // 넘긴 항목은 빨강. 바는 목표 지점에서 멈추므로(ratio 가 1.0 으로
        // 잘린다) 색까지 그대로면 꽉 찬 것과 넘긴 것이 같은 그림이 된다.
        // 같은 카드의 칼로리 링과 나트륨·당류는 이미 이렇게 갈린다 — 탄단지
        // 바만 예외였다(#891).
        _Bar(
          progress: item.ratio,
          color: item.isOverGoal
              ? AppColors.statusOver
              : AppColors.statusNormal.withValues(alpha: 0.65),
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
        ? AppColors.statusOver
        : AppColors.statusNormal;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(
          color: item.isOverGoal
              ? AppColors.statusOver.withValues(alpha: 0.32)
              : AppColors.statusNormal.withValues(alpha: 0.18),
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
                    // 초과일 때만 경고 아이콘. 그 외에 체크 아이콘을 두면
                    // 목표에 한참 못 미친 날도 "정상" 이라고 말한다(#1070).
                    if (item.isOverGoal) ...<Widget>[
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: status,
                      ),
                      const SizedBox(width: 5),
                    ],
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
