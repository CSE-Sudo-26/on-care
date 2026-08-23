import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/churn_risk.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';

/// Opens the 이탈 위험 dialog: who's flagged, and why.
Future<void> showChurnRiskDialog(
  BuildContext context, {
  required List<ChurnRiskClient> entries,
}) => showDialog<void>(
  context: context,
  builder: (_) => ChurnRiskDialog(entries: entries),
);

/// Lists every 이탈 위험 client with the reasons they were flagged — the
/// KPI card is a count, this is the "왜" behind it (#[dashboard]).
class ChurnRiskDialog extends StatelessWidget {
  /// Creates the dialog body.
  const ChurnRiskDialog({super.key, required this.entries});

  /// Flagged clients, worst (most reasons) first.
  final List<ChurnRiskClient> entries;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      key: const ValueKey<String>('churn-risk-dialog'),
      title: Text(l.dashChurnRiskTitle),
      content: SizedBox(
        width: 480,
        child: entries.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text(
                  l.dashChurnRiskEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedForeground),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final entry in entries) ...<Widget>[
                      _ChurnRiskTile(entry: entry),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('churn-risk-dialog-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
    );
  }
}

class _ChurnRiskTile extends StatelessWidget {
  const _ChurnRiskTile({required this.entry});

  final ChurnRiskClient entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = entry.client;
    return InkWell(
      key: ValueKey<String>('churn-risk-tile-${client.id}'),
      borderRadius: const BorderRadius.all(AppRadius.md),
      onTap: () {
        Navigator.of(context).pop();
        context.go(AppRoutes.clientDetail(client.id));
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: const BorderRadius.all(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.statusChurnRisk.withValues(
                    alpha: 0.12,
                  ),
                  child: Text(
                    client.avatar,
                    style: const TextStyle(
                      color: AppColors.statusChurnRisk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${client.name} · ${clientDemographicsLabel(context, client)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (client.goal.trim().isNotEmpty)
                        Text(
                          client.goal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.subtleForeground,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.disabledForeground,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final signal in entry.signals)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusChurnRisk.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                    ),
                    child: Text(
                      signal.label(l),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusChurnRisk,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
