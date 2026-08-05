import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/oni_avatar.dart';

/// The AI's read on the roster, in one sentence, plus the action it
/// implies. Shares the Oni mascot with the member app so "AI가 말한다"
/// looks the same on both sides of the service.
///
/// The sentence is composed locally from the same aggregates the KPI row
/// uses — it is a summary of the trainer's own data, not a model call.
/// The generative surface is the AI 코칭 tab, which this links into.
class AiSummaryCard extends StatelessWidget {
  /// Creates the card.
  const AiSummaryCard({super.key, required this.summary});

  /// The dashboard aggregates the message is written from.
  final DashboardSummary summary;

  /// The headline sentence for [summary]. Pure, so the wording rules are
  /// testable without a widget pump.
  static String messageFor(DashboardSummary summary) {
    if (summary.totalClients == 0) {
      return '아직 담당 고객이 없어요. 고객을 등록하면 식단·운동 데이터를 모아 코칭 포인트를 짚어 드릴게요.';
    }
    final sodium = summary.attention
        .where((a) => a.alerts.contains(ClientAlert.sodiumOver))
        .length;
    final low = summary.attention
        .where((a) => a.alerts.contains(ClientAlert.lowCompletion))
        .length;

    if (summary.unreadTotal > 0) {
      return '고객 ${summary.unreadClients}명이 답장을 기다리고 있어요. '
          '먼저 대화를 확인하고 오늘 루틴을 조정해 보세요.';
    }
    if (sodium > 0) {
      return '이번 주 담당 고객 ${summary.totalClients}명 중 $sodium명이 '
          '나트륨 목표를 넘겼어요. 저염 식단과 유산소 중심 루틴을 제안해 보세요.';
    }
    if (low > 0) {
      return '$low명의 주간 이행률이 $lowCompletionThreshold% 아래예요. '
          '강도를 낮춘 루틴으로 다시 습관을 잡아 주세요.';
    }
    return '담당 고객 ${summary.totalClients}명 모두 목표 범위 안이에요. '
        '지금 강도를 유지하면서 다음 주 목표를 올려 보세요.';
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: <Widget>[
              const OniAvatar(size: 28),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'AI 코칭 요약',
                style: TextStyle(
                  fontSize: 13,
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
                child: const Text(
                  '오늘',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            messageFor(summary),
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionButton(
              label: 'AI 루틴 만들기',
              icon: Icons.auto_awesome,
              primary: true,
              onPressed: () => context.go(AppRoutes.coaching),
            ),
          ),
        ],
      ),
    );
  }
}
