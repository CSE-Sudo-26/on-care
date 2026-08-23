import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/activity_feedback.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/oni_avatar.dart';

/// "AI 진단" — 트레이너 활동 피드백 3가지(이행률·이탈 위험 감지, 7일 이상
/// 활동 저조, 식단 피드백 미완료)를 풀어서 보여 주는 카드.
///
/// 이전에는 규칙 기반 코칭 요약(고객별 상태·근거·운동 중심)을 함께 그렸는데,
/// "AI 진단" 이라는 이름에 맞춰 활동 피드백 하나로 좁혔다 — 두 정보가 한
/// 카드에 있으면 어느 쪽을 먼저 읽어야 할지 애매했다.
class AiSummaryCard extends StatelessWidget {
  /// Creates the card.
  const AiSummaryCard({super.key, required this.activityFeedback});

  /// 이행률·이탈 위험·식단 피드백 미완료 등 트레이너 활동 피드백 bullets.
  final List<ActivityFeedbackItem> activityFeedback;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // 대상이 없는 신호는 아예 그리지 않는다 — "0명" 문장은 안내가 아니다.
    final active = activityFeedback.where((i) => i.count > 0).toList();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.aiCardGradientEnd),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.aiCardGradientStart, AppColors.bannerEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(title: l.dashAiSummaryTitle),
          const SizedBox(height: AppSpacing.md),
          if (active.isEmpty)
            Text(
              l.dashAiNoClients,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.mutedForeground,
              ),
            )
          else
            for (var i = 0; i < active.length; i++) ...<Widget>[
              if (i > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const Divider(color: AppColors.aiCardGradientEnd, height: 1),
                const SizedBox(height: AppSpacing.sm),
              ],
              _ActivityFeedbackDetail(item: active[i]),
            ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const OniAvatar(size: 28),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }
}

/// One 트레이너 활동 피드백 bullet, written out in full — headline, a
/// sentence that names the clients naturally, and a right-aligned link to
/// go act on it.
///
/// 흰 박스로 감싸지 않는다 — 카드 자체가 이미 그라디언트로 구분돼 있어,
/// 안에 또 흰 상자를 두면 레이어가 하나 더 생길 뿐이었다(#[dashboard]).
class _ActivityFeedbackDetail extends StatelessWidget {
  const _ActivityFeedbackDetail({required this.item});

  final ActivityFeedbackItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.kind.title(l),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.kind.description(l, _names(l, item.clientNames)),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: ValueKey<String>('ai-summary-cta-${item.kind.name}'),
            onPressed: () => context.go(AppRoutes.coaching),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Text(
              l.dashActivityCreateRoutine,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            label: const Icon(Icons.chevron_right, size: 14),
            iconAlignment: IconAlignment.start,
          ),
        ),
      ],
    );
  }

  static String _names(AppLocalizations l, List<String> names) {
    const maxShown = 3;
    if (names.length <= maxShown) return names.join(', ');
    final shown = names.take(maxShown).join(', ');
    return l.dashActivityMoreClients(shown, names.length - maxShown);
  }
}
