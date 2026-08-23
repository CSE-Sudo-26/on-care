import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/activity_feedback.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
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
          _Header(title: l.dashAiSummaryTitle, today: l.dashToday),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < activityFeedback.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _ActivityFeedbackDetail(item: activityFeedback[i]),
          ],
          const SizedBox(height: AppSpacing.md),
          ActionButton(
            label: l.dashCreateAiRoutine,
            icon: Icons.auto_awesome,
            primary: true,
            onPressed: () => context.go(AppRoutes.coaching),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.today});

  final String title;
  final String today;

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
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.all(AppRadius.pill),
          ),
          child: Text(
            today,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One 트레이너 활동 피드백 bullet, written out in full — headline, the
/// explanation of what the signal means and what to do, and (when any
/// client triggered it) who.
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                item.kind.title(l),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: const BorderRadius.all(AppRadius.pill),
              ),
              child: Text(
                '${item.count}${l.dashUnitPeople}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          item.kind.description(l),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedForeground,
          ),
        ),
        if (item.clientNames.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            l.dashActivityFeedbackTarget(_names(item.clientNames)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }

  static String _names(List<String> names) {
    const maxShown = 3;
    if (names.length <= maxShown) return names.join(', ');
    final shown = names.take(maxShown).join(', ');
    return '$shown 외 ${names.length - maxShown}명';
  }
}
