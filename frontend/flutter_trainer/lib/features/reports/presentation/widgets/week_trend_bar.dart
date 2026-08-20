import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// 한 주 한 줄 — 라벨 · 가로 막대 · 값.
///
/// 이행률(%)과 영양 지표(kcal·mg·g)가 같은 줄 모양을 쓴다. 값의 뜻은 부르는
/// 쪽이 정하고, 여기서는 **길이와 색만** 그린다.
class WeekTrendBar extends StatelessWidget {
  const WeekTrendBar({
    super.key,
    required this.label,
    required this.fraction,
    required this.text,
    required this.loading,
    required this.current,
    this.warn = false,
    this.goalFraction,
    this.valueWidth = 40,
  });

  final String label;

  /// 막대 길이(0~1). 기록이 없으면 null — 막대를 그리지 않는다.
  final double? fraction;

  /// 오른쪽에 찍을 값. 기록이 없으면 부르는 쪽이 '-' 를 준다.
  final String text;

  final bool loading;

  /// 보고 있는 주. 앞선 주와 눈에 띄게 구분한다.
  final bool current;

  /// 목표를 벗어난 주(이행률이 낮거나, 영양 지표가 목표를 넘었거나).
  final bool warn;

  /// 눈금 위 목표의 위치(0~1). 막대가 이 선을 넘었는지가 곧 목표 초과다.
  /// 목표가 눈금 끝과 같으면(이행률 100%) 선을 긋지 않는다 — 테두리와 겹친다.
  final double? goalFraction;

  /// 값 칸 너비. 'kcal' 처럼 단위가 붙으면 넓혀 준다.
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    // 목표를 벗어난 주는 빨강, 그 밖은 브랜드 색. 보고 있는 주만 제 색을
    // 쓰고 앞선 주는 흐리게 깔아, 색으로 초과 여부를 읽으면서도 어느 줄이
    // 이번 주인지 헷갈리지 않게 한다.
    final base = warn ? AppColors.overTarget : AppColors.primary;
    final tone = fraction == null
        ? AppColors.borderStrong
        : current
        ? base
        : base.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                color: current
                    ? AppColors.foreground
                    : AppColors.subtleForeground,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.all(AppRadius.pill),
              child: Stack(
                children: <Widget>[
                  Container(height: 9, color: AppColors.inputBackground),
                  // 눈금 위쪽 끝을 고정해 둔다 — 그 주의 최댓값에 맞춰 늘이면
                  // 2,288 과 2,166 이 전혀 다른 길이로 보인다.
                  FractionallySizedBox(
                    widthFactor: (fraction ?? 0).clamp(0.0, 1.0),
                    child: Container(height: 9, color: tone),
                  ),
                  // 목표선은 채움 위에 긋는다 — 아래 깔면 넘긴 주에서 가려져,
                  // 정작 넘겼는지 봐야 할 때 보이지 않는다.
                  if (goalFraction != null && goalFraction! < 1)
                    FractionallySizedBox(
                      widthFactor: goalFraction!,
                      alignment: Alignment.centerLeft,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 1.5,
                          height: 9,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: valueWidth,
            child: Text(
              loading ? '…' : text,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                color: current
                    ? AppColors.foreground
                    : AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
