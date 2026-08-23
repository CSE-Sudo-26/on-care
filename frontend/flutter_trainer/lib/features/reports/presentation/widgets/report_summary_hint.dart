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
  const ReportSummaryHint({
    super.key,
    required this.message,
    this.fill = false,
  });

  final String message;

  /// 남은 세로 자리를 채우는가. [ReportAiCard] 와 같은 자리에 놓이므로 같은
  /// 규칙을 쓴다 — 칸이 안내문보다 짧으면 카드 안에서 스크롤한다.
  ///
  /// 이 값이 없던 때에는 리포트를 읽는 동안 칸이 잠깐 얇아지는 순간마다
  /// 렌더 오버플로가 났다. 채우는 자리에서만 스크롤을 붙이는 이유는, 좁은
  /// 화면에서는 이 카드가 **스스로 스크롤하는 열 안에** 놓여 높이가 무한하기
  /// 때문이다(#1177).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
    );
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
            child: fill
                ? SingleChildScrollView(
                    key: const ValueKey<String>('reports-summary-hint-scroll'),
                    child: body,
                  )
                : body,
          ),
        ],
      ),
    );
  }
}
