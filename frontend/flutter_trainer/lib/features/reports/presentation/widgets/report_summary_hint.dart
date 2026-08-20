import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/reports/presentation/widgets/report_ai_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 요약 자리에 아직 내용이 없을 때 — 그 자리에 **무엇이 뜨는지**만 적는다.
///
/// 빈 칸으로 두면 왼쪽 열이 목록 아래로 그냥 잘린 것처럼 보이고, 고객을 고르면
/// 무엇을 얻는지도 알 수 없다. 카드 껍데기는 [ReportAiCard] 와 같게 두어,
/// 내용이 채워질 때 자리가 흔들리지 않는다.
class ReportSummaryHint extends StatelessWidget {
  const ReportSummaryHint({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('reports-summary-hint'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.aiCardGradientStart,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.aiCardGradientEnd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.reportsAiTitle,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
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
