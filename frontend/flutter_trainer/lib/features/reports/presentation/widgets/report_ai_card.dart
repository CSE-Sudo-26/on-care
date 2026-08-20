import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/report_summary.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 리포트 요약 카드 — 트레이너가 매주 같은 문장을 처음부터 쓰지 않게 한다.
///
/// 결과는 그대로 읽는 글이 아니라 **피드백 초안으로 가져다 고칠 재료**다.
/// 그래서 `피드백으로 가져오기` 가 이 카드의 본래 동선이고, 문장이 마음에 안
/// 들면 다시 생성한다(#755).
///
/// 데모에는 모델이 없어 수치에서 조립한 문장이 온다. 실서버도 공급자 장애면
/// 같은 문장으로 되돌아온다 — 그 경우 `생성` 배지를 달지 않아, 트레이너가 이
/// 문장을 어디까지 믿을지 알 수 있다.
class ReportAiCard extends ConsumerWidget {
  const ReportAiCard({
    super.key,
    required this.report,
    required this.onUseAsDraft,
  });

  final WeeklyReport report;

  /// 요약을 피드백 입력창으로 옮긴다.
  final void Function(String draft) onUseAsDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final key = (client: report.client, weekStart: report.weekStart);
    final summary = ref.watch(reportSummaryProvider(key));
    return Container(
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l.reportsAiTitle,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (summary.valueOrNull?.isGenerated ?? false)
                      Text(
                        l.reportsAiGenerated,
                        style: const TextStyle(
                          color: AppColors.subtleForeground,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                summary.when(
                  loading: () => Text(
                    l.reportsAiLoading,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // 생성이 실패해도 카드가 비지 않는다 — 예전 안내문으로
                  // 되돌아가 그 자리에 무엇이 올지는 말해 준다.
                  error: (_, _) => Text(
                    l.reportsAiUnavailable,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  data: (value) => _SummaryBody(
                    summary: value,
                    onRegenerate: () =>
                        ref.invalidate(reportSummaryProvider(key)),
                    onUseAsDraft: () => onUseAsDraft(value.asDraft),
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

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.summary,
    required this.onRegenerate,
    required this.onUseAsDraft,
  });

  final ReportSummary summary;
  final VoidCallback onRegenerate;
  final VoidCallback onUseAsDraft;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          summary.headline,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        for (final point in summary.points) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            '· $point',
            style: const TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        // 카드가 292px 왼쪽 열로 내려오면서(#897) 두 동작이 한 줄에 들어가지
        // 않는 조합이 생겼다 — 영어 · 배율 1.3 이 그렇다. 줄을 접어 받는다.
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            _SummaryAction(
              label: l.reportsAiUseAsDraft,
              icon: Icons.edit_note,
              onTap: onUseAsDraft,
            ),
            _SummaryAction(
              label: l.reportsAiRegenerate,
              icon: Icons.refresh,
              onTap: onRegenerate,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryAction extends StatelessWidget {
  const _SummaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: const BorderRadius.all(AppRadius.sm),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 3),
          // 한 동작만으로도 열 폭을 넘는 조합이 있다 — 잘라내지 않고 접는다.
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
