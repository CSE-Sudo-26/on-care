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
    this.fill = false,
  });

  final WeeklyReport report;

  /// 요약을 피드백 입력창으로 옮긴다.
  final void Function(String draft) onUseAsDraft;

  /// 남은 세로 자리를 채울 것인가.
  ///
  /// 넓은 화면에서 이 카드는 왼쪽 열의 마지막 칸이다. 내용만큼만 차지하면 그
  /// 아래가 통째로 빈 회색 바닥이 되어, 화면의 3분의 1이 아무 말도 하지
  /// 않았다. 채우되 **넘치지는 않는다** — 본문이 길면 카드 안에서 스크롤하고,
  /// 동작 줄은 바닥에 붙어 늘 보인다(#1177).
  final bool fill;

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
              mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
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
                // 한 번만 조립하고, 자리를 채울 때만 [Expanded] 로 감싼다.
                () {
                  final Widget content = summary.when(
                    loading: () => _Muted(text: l.reportsAiLoading),
                    // 생성이 실패해도 카드가 비지 않는다 — 예전 안내문으로
                    // 되돌아가 그 자리에 무엇이 올지는 말해 준다.
                    error: (_, _) => _Muted(text: l.reportsAiUnavailable),
                    data: (value) => _SummaryBody(
                      summary: value,
                      actions: summaryCoachingActions(l, report),
                      fill: fill,
                      onRegenerate: () =>
                          ref.invalidate(reportSummaryProvider(key)),
                      onUseAsDraft: () => onUseAsDraft(value.asDraft),
                    ),
                  );
                  return fill ? Expanded(child: content) : content;
                }(),
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
    required this.actions,
    required this.onRegenerate,
    required this.onUseAsDraft,
    this.fill = false,
  });

  final ReportSummary summary;

  /// 다음 주에 할 일. 요약이 지난 주를 말하면, 이쪽은 그래서 무엇을 하면
  /// 되는지를 말한다 — 카드 아래가 비어 있던 자리다(#1177).
  final List<String> actions;
  final VoidCallback onRegenerate;
  final VoidCallback onUseAsDraft;

  /// 남은 자리를 채운다. 글이 길면 본문만 스크롤하고 동작 줄은 바닥에 붙는다.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        if (actions.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.reportsAiNextWeek,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          for (final action in actions) ...<Widget>[
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 13,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    action,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
    final buttons = Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      // 카드가 292px 왼쪽 열로 내려오면서(#897) 두 동작이 한 줄에 들어가지
      // 않는 조합이 생겼다 — 영어 · 배율 1.3 이 그렇다. 줄을 접어 받는다.
      child: Wrap(
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
    );
    if (!fill) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[body, buttons],
      );
    }
    // 넘칠 것 같으면 본문만 스크롤한다. 카드가 열 밖으로 자라면 왼쪽 열이
    // 화면을 넘어가고, 그건 이 카드를 늘린 이유와 정반대다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey<String>('reports-summary-body-scroll'),
            child: body,
          ),
        ),
        buttons,
      ],
    );
  }
}

/// 아직 문장이 없을 때의 한 줄.
class _Muted extends StatelessWidget {
  const _Muted({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.mutedForeground,
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
    ),
  );
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
