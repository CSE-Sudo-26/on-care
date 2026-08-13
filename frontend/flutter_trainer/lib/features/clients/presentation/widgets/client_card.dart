import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/widgets/alert_badge.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// A client row on the 고객 관리 list: avatar + active dot, name, goal,
/// last message, and a quick-metric footer (칼로리 / 나트륨 / 마지막 루틴).
class ClientCard extends StatelessWidget {
  /// Creates a card for [client]; [onTap] opens the detail screen.
  const ClientCard({
    super.key,
    required this.client,
    required this.onTap,
    this.selected = false,
    this.unread = 0,
    this.compact = false,
  });

  /// The client to render.
  final TrainerClient client;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  /// Highlighted in the wide-viewport split layout when this client's
  /// detail panel is open.
  final bool selected;

  /// Unread chat messages — shows a count badge next to the preview.
  final int unread;

  /// Dense master-list presentation used by the Figma 회원 관리 split view.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return DecoratedBox(
      // 사용자 앱과 동일한 kCardShadow(소프트 블루)로 통일.
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
      ),
      child: Material(
        color: selected ? AppColors.accentSurface : AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(AppRadius.card),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.5)
                    : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: compact
                ? _CompactClientContent(client: client, unread: unread)
                : Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          ClientAvatar(
                            label: client.avatar,
                            showStatus: true,
                            active: client.active,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        client.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.foreground,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      client.lastTime,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.subtleForeground,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  client.goal,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.subtleForeground,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        client.lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: unread > 0
                                              ? AppColors.foreground
                                              : AppColors.mutedForeground,
                                          fontWeight: unread > 0
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (unread > 0)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          left: AppSpacing.xs,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: AppColors.accent,
                                          borderRadius: BorderRadius.all(
                                            AppRadius.pill,
                                          ),
                                        ),
                                        child: Text(
                                          '$unread',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.accentForeground,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppColors.disabledForeground,
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Divider(
                          height: 1,
                          color: AppColors.borderStrong,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          _Metric(
                            label: l.metricCalories,
                            value: '${client.calories}kcal',
                          ),
                          _Metric(
                            label: l.metricSodium,
                            value: '${client.sodiumMg}mg',
                            warn: client.sodiumOverBudget,
                          ),
                          _Metric(
                            label: l.clientLastRoutine,
                            value: client.lastRoutine,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CompactClientContent extends StatelessWidget {
  const _CompactClientContent({required this.client, required this.unread});

  final TrainerClient client;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final completion = recordedCompletionMean(client)?.round();
    final alerts = alertsFor(client, unread: unread);
    return Row(
      children: <Widget>[
        ClientAvatar(
          label: client.avatar,
          size: 36,
          showStatus: true,
          active: client.active,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      client.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (alerts.isNotEmpty)
                    AlertBadge(alert: alerts.first, showIcon: false),
                  if (unread > 0) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.all(AppRadius.pill),
                      ),
                      child: Text(
                        '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                client.goal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.subtleForeground,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                client.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  const Text(
                    '주간 이행률',
                    style: TextStyle(
                      color: AppColors.subtleForeground,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: completion == null ? 0 : completion / 100,
                        backgroundColor: AppColors.inputBackground,
                        color:
                            completion != null &&
                                completion < lowCompletionThreshold
                            ? AppColors.overTarget
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    completion == null ? '-' : '$completion%',
                    style: TextStyle(
                      color:
                          completion != null &&
                              completion < lowCompletionThreshold
                          ? AppColors.overTarget
                          : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.subtleForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: warn ? AppColors.overTarget : AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
