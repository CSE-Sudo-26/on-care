import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/activity_feedback.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/oni_avatar.dart';

/// "활동 피드백" — 트레이너 활동 피드백 3가지(이행률·이탈 위험 감지, 7일
/// 이상 활동 저조, 식단 피드백 미완료)를 풀어서 보여 주는 카드.
///
/// 이전에는 규칙 기반 코칭 요약(고객별 상태·근거·운동 중심)을 함께 그렸는데,
/// 활동 피드백 하나로 좁혔다 — 두 정보가 한 카드에 있으면 어느 쪽을 먼저
/// 읽어야 할지 애매했다.
///
/// 제목은 "AI 진단"이었지만 실제로는 AI(LLM) 를 부르지 않고 클라이언트에서
/// 규칙(`buildActivityFeedback`/`computeChurnSignals`)으로만 계산한다 —
/// 이름이 실제로 하는 일과 달라 "활동 피드백"으로 고쳤다.
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

  /// Where each kind's CTA leads — the client most worth checking first.
  String? _destination() {
    if (item.clientIds.isEmpty) return null;
    final id = item.clientIds.first;
    return switch (item.kind) {
      ActivityFeedbackKind.difficultyReview => AppRoutes.coachingFor(id),
      ActivityFeedbackKind.inactiveSevenDays => AppRoutes.messagesFor(id),
      ActivityFeedbackKind.dietFeedbackPending => AppRoutes.clientDetail(
        id,
        section: 'diet',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final destination = _destination();
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
        // 설명은 왼쪽에서 넓게 숨 쉬고, 버튼은 오른쪽에 고정 너비로 붙는다 —
        // 세 항목이 같은 두 칸 그리드로 줄을 맞춰야 나란히 훑어 읽힌다.
        Row(
          children: <Widget>[
            Expanded(
              // 추천 행동("프로그램에서 루틴을 조정해보세요")을 설명 문장에
              // 이어 붙인다 — 버튼은 그 탭으로 가는 짧은 링크일 뿐, 무엇을
              // 해야 하는지는 이 문장이 전부 말한다.
              child: Text(
                '${item.kind.description(l, _names(l, item.clientNames))} '
                '${item.kind.recommendation(l)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (destination != null)
              // 오늘의 일정 배너의 "수업 준비하기" 버튼과 같은 마감 —
              // 알약처럼 둥글고 여유 있게, 짧은 탭 이름이 초라해 보이지
              // 않도록.
              FilledButton.icon(
                key: ValueKey<String>('ai-summary-cta-${item.kind.name}'),
                onPressed: () => context.go(destination),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentDark,
                  foregroundColor: AppColors.accentForeground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 12,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(AppRadius.pill),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: Text(item.kind.tabLabel(l)),
                label: const Icon(Icons.chevron_right, size: 16),
                iconAlignment: IconAlignment.start,
              ),
          ],
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
