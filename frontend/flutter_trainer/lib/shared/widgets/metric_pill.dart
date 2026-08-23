import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';

/// 그래프 하나가 여러 지표를 돌려 쓸 때 쓰는 알약 버튼.
///
/// 리포트의 비교 그래프와 식단 추이가 같은 동작(지표 갈아 끼우기)을 하므로
/// 같은 모양을 쓴다 — 두 카드가 조금씩 다른 알약을 그리면 같은 화면에서
/// 다른 종류의 버튼처럼 보인다(#1177).
class MetricPill extends StatelessWidget {
  /// Creates a metric pill.
  const MetricPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary : AppColors.card,
    borderRadius: const BorderRadius.all(AppRadius.pill),
    child: InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderStrong,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.primaryForeground
                : AppColors.mutedForeground,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
