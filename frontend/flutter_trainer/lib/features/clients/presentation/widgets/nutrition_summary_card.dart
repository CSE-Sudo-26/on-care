/// 고객의 오늘 영양 요약 — **회원 앱 식단 탭 `오늘` 카드와 같은 한 장**이다.
/// (#698, #1166)
///
/// 예전에는 카드가 세 장이었다(칼로리+탄단지 / 나트륨 / 당류). 회원 앱은 한
/// 장이라 같은 하루를 회원과 트레이너가 다른 그림으로 봤다 — 회원이 "나트륨
/// 카드가 빨개요" 라고 말할 때 트레이너 화면에는 같은 자리가 없었다.
///
/// 두 앱은 서로 다른 Dart 패키지라 위젯을 그대로 가져올 수 없어 여기에 옮겼다.
/// 색은 트레이너 토큰으로 바꾸되 **구성과 규칙은 회원 앱을 따른다.**
///
///  * 위: `오늘 섭취 칼로리` → 큰 숫자 `값 / 목표 kcal` → **탄·단·지 글자 세
///    줄**(막대 없음). 오른쪽에 달성률 도넛. 칼로리가 무엇으로 채워졌는지가
///    그 숫자 바로 아래에서 읽혀야 한다.
///  * 아래: 나트륨·당류 두 칸의 가로 진행 바. 초과분은 라벨 오른쪽에
///    `+1,429mg` 로 작게 빨간 글씨.
///  * 색은 **목표 안쪽 = 트레이너 메인 색([AppColors.statusWithinGoal]),
///    초과 = 빨강** 하나의 규칙이다. 초록은 쓰지 않는다 — "정상" 으로 읽혀서
///    목표에 한참 못 미친 날까지 괜찮다고 말한다(회원 앱 #1070).
///
/// 목표값은 회원 앱 기본값과 같다(`UserProfile.defaultDaily*`). 회원이 자기
/// 목표를 바꿔도 트레이너 API 가 그 값을 주지 않아, 지금은 기본값으로 그린다.
library;

import 'package:flutter/material.dart';

import 'package:oncare_trainer/core/utils/number_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// 회원 앱 `UserProfile` 의 기본 목표와 같은 값. 칼로리·나트륨·당류는
/// `trainer_client.dart` 가 이미 들고 있다(로스터 카드도 같은 값을 본다).
const int carbsTargetG = 275;
const int proteinTargetG = 100;
const int fatTargetG = 55;

/// 영양 요약 카드의 기준 높이. `오늘`·`이번 주`·`전체` 세 화면이 함께 쓴다 —
/// 기간 토글을 눌렀을 때 카드가 커졌다 작아지면 그 아래 내용이 그때마다 뛴다.
/// 최소 높이라 글자 배율이 커지면 셋이 함께 커진다. (회원 앱 #1124)
const double kClientNutritionCardHeight = 240;

/// 진행 바·링의 바닥색.
const Color _track = AppColors.inputBackground;

/// 카드가 쓰는 모서리. 회원 앱 카드와 같은 20이다.
const double _cardRadius = 20;

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

  /// 목표 대비 실제 비율. **자르지 않는다** — 목표를 넘기면 1.0 을 넘는다.
  /// 달성률 라벨이 이 값을 적는다. 여기서 잘라 두면 목표를 260kcal 넘긴 날에도
  /// '100%' 라고 말해 바로 아래 문구와 어긋난다(#820).
  double get ratio => target <= 0 ? 0 : current / target;

  /// 게이지에 넣을 값. 링과 막대는 1.0 을 넘으면 눈금이 깨지므로 그릴 때만
  /// 자른다.
  double get gaugeValue => ratio.clamp(0.0, 1.0).toDouble();

  bool get isOverGoal => current > target;

  /// 목표까지 남은/넘은 양.
  String get difference => formatNumber((current - target).abs());
}

/// 오늘 섭취 칼로리 + 탄단지 + 나트륨·당류. 카드는 **한 장**이다.
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
    final List<_Item> minerals = <_Item>[
      _Item(
        label: l.metricSodium,
        value: formatNumber(client.sodiumMg),
        goal: formatNumber(sodiumTargetMg),
        unit: 'mg',
        current: client.sodiumMg,
        target: sodiumTargetMg,
      ),
      _Item(
        label: l.metricSugar,
        value: formatNumber(client.sugarG),
        goal: formatNumber(sugarTargetG),
        unit: 'g',
        current: client.sugarG,
        target: sugarTargetG,
      ),
    ];

    final Color calorieColor = _statusColor(calories);
    return Container(
      key: const Key('client-nutrition-summary-card'),
      // 오늘·이번 주·전체가 같은 크기여야 토글을 눌러도 화면이 튀지 않는다.
      // 글자 배율이 커지면 셋 다 함께 커진다 — 최소 높이라 넘치지 않는다.
      constraints: const BoxConstraints(minHeight: kClientNutritionCardHeight),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.dietCalorieIntake,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
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
                                color: calorieColor,
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
                    // 탄단지는 칼로리 숫자와 도넛 사이에 놓는다 — 칼로리가
                    // 무엇으로 채워졌는지가 그 숫자 바로 아래에서 읽혀야 한다.
                    // 바는 두지 않는다: 옆의 도넛이 이미 달성률을 그리고 있어,
                    // 좁은 왼쪽 칸에 바까지 넣으면 읽을 것만 는다. (회원 앱 #1120)
                    const SizedBox(height: 10),
                    for (final _Item m in macros) ...<Widget>[
                      _MacroTextLine(item: m),
                      if (m != macros.last) const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _CalorieDonut(calories: calories, color: calorieColor),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, thickness: 1, color: AppColors.borderStrong),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              if (c.maxWidth < 280) {
                return Column(
                  children: <Widget>[
                    for (final _Item m in minerals) ...<Widget>[
                      _MineralItem(item: m),
                      if (m != minerals.last)
                        const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < minerals.length; i++) ...<Widget>[
                    Expanded(child: _MineralItem(item: minerals[i])),
                    if (i < minerals.length - 1)
                      const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 목표 안쪽이면 메인 색, 넘겼으면 빨강. 카드 전체가 이 한 규칙을 쓴다.
Color _statusColor(_Item item) =>
    item.isOverGoal ? AppColors.statusOver : AppColors.statusWithinGoal;

/// 칼로리 달성률 도넛. 링은 한 바퀴에서 멈추지만 숫자는 자르지 않는다.
class _CalorieDonut extends StatelessWidget {
  const _CalorieDonut({required this.calories, required this.color});

  final _Item calories;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SizedBox.square(
      dimension: 92,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox.square(
            dimension: 92,
            child: CircularProgressIndicator(
              key: const Key('client-nutrition-calorie-progress'),
              value: calories.gaugeValue,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: _track,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          // 링은 지름이 고정이라 글자 배율이 커지면 안쪽 두 줄이 원을 넘어선다.
          // 원 안에 들어가도록 함께 줄인다.
          Padding(
            padding: const EdgeInsets.all(18),
            child: FittedBox(
              child: Column(
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
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 머리의 탄단지 한 줄 — `탄수화물 204 /275g`. 바 없이 글자만 쓴다.
class _MacroTextLine extends StatelessWidget {
  const _MacroTextLine({required this.item});

  final _Item item;

  /// 라벨이 차지하는 폭. `탄수화물`(네 글자)이 들어갈 만큼만 잡는다 — 값이
  /// 라벨 바로 옆에서 시작하면서도 세 줄의 숫자가 세로로 가지런하다. 글자
  /// 배율을 따라가야 큰 글씨에서 라벨이 잘리지 않는다. (회원 앱 #1149)
  static const double _labelWidth = 56;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('client-nutrition-macro-${item.label}'),
      children: <Widget>[
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(_labelWidth),
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // 값은 라벨 바로 옆에서 시작한다. 글자 배율이 커지면 값부터 줄인다 —
        // 이 줄이 넘치면 카드 오른쪽의 도넛을 밀어낸다.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: item.value,
                    // 초과면 빨강 — 바가 없으니 색이 그 말을 대신한다.
                    // 세 항목이 각자 판단하므로 지방만 넘긴 날은 지방 줄만
                    // 빨개진다. (회원 앱 #890)
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: item.isOverGoal
                          ? AppColors.statusOver
                          : AppColors.statusWithinGoal.withValues(alpha: 0.65),
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
        ),
      ],
    );
  }
}

/// 아래 줄의 나트륨·당류 한 칸 — 라벨(+초과분) · 값/목표 · 진행 바.
///
/// 나트륨·당류는 탄단지와 달리 그 자체가 경고 지표라, 목표 안쪽일 때도 색이
/// 또렷하다(옅게 두지 않는다).
class _MineralItem extends StatelessWidget {
  const _MineralItem({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final Color color = _statusColor(item);
    return Column(
      key: Key('client-nutrition-mineral-${item.label}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: item.label),
              // 초과분은 라벨 오른쪽에 한 단계 작은 빨간 글씨로. 초과가
              // 아닐 때는 아무것도 붙이지 않는다 — 체크 표시를 두면 목표에
              // 한참 못 미친 날도 "정상" 이라고 말한다. (회원 앱 #1070)
              if (item.isOverGoal)
                TextSpan(
                  text: ' +${item.difference}${item.unit}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusOver,
                  ),
                ),
            ],
          ),
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
          key: Key('client-nutrition-mineral-progress-${item.label}'),
          progress: item.gaugeValue,
          color: color,
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.progress, required this.color});

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
