import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/oni_avatar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

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
  /// testable without a widget pump — 로케일도 인자로 받아 테스트가 어느
  /// 언어를 검사하는지 명시한다. (#501)
  static String messageFor(AppLocalizations l, DashboardSummary summary) {
    if (summary.totalClients == 0) {
      return l.dashAiNoClients;
    }
    final sodium = summary.attention
        .where((a) => a.alerts.contains(ClientAlert.sodiumOver))
        .length;
    final low = summary.attention
        .where((a) => a.alerts.contains(ClientAlert.lowCompletion))
        .length;

    if (summary.unreadTotal > 0) {
      return l.dashAiUnread(summary.unreadClients);
    }
    if (sodium > 0) {
      return l.dashAiSodium(summary.totalClients, sodium);
    }
    if (low > 0) {
      return l.dashAiLowCompletion(low, lowCompletionThreshold);
    }
    return l.dashAiAllOnTrack(summary.totalClients);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
              Text(
                l.dashAiSummaryTitle,
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
                  l.dashToday,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            messageFor(l, summary),
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionButton(
              label: l.dashCreateAiRoutine,
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
