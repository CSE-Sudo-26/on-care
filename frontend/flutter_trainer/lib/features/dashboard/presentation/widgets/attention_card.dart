import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// Clients who need the trainer today, with the reason spelled out.
///
/// A bare priority list ("these five, in this order") makes the trainer
/// re-derive why each name is there. The badge carries the reason, and
/// the row opens straight to the section that fixes it — 답장 대기 goes
/// to the chat, 나트륨 초과 goes to the diet.
class AttentionCard extends StatelessWidget {
  /// Creates the card for [entries].
  const AttentionCard({super.key, required this.entries, this.maxRows = 5});

  /// Attention entries, most urgent first.
  final List<AttentionClient> entries;

  /// How many rows to show before deferring to the 고객 tab.
  final int maxRows;

  /// The client sub-section that addresses [alert].
  static String sectionFor(ClientAlert alert) => switch (alert) {
    ClientAlert.unanswered => 'chat',
    ClientAlert.sodiumOver => 'diet',
    ClientAlert.lowCompletion => 'workout',
  };

  static Color _colorFor(ClientAlert alert) => switch (alert) {
    ClientAlert.unanswered => AppColors.destructive,
    ClientAlert.sodiumOver => AppColors.warning,
    ClientAlert.lowCompletion => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final shown = entries.take(maxRows).toList();
    return SectionCard(
      title: '주의가 필요한 고객',
      icon: Icons.priority_high,
      trailing: entries.length > maxRows
          ? CardLink(
              label: '+${entries.length - maxRows}명',
              onTap: () => context.go(AppRoutes.clientsFiltered('attention')),
            )
          : null,
      child: shown.isEmpty
          ? const EmptyHint(
              message: '지금 챙길 고객이 없어요',
              icon: Icons.check_circle_outline,
            )
          : Column(
              children: <Widget>[
                for (final entry in shown)
                  _Row(
                    entry: entry,
                    onTap: () => context.go(
                      AppRoutes.clientDetail(
                        entry.client.id,
                        section: sectionFor(entry.primary),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.onTap});

  final AttentionClient entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AttentionCard._colorFor(entry.primary);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: <Widget>[
            ClientAvatar(label: entry.client.avatar, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  Text(
                    entry.client.goal,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.subtleForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(AppRadius.pill),
              ),
              child: Text(
                entry.primary.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
