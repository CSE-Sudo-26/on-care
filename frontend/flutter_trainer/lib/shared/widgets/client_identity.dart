import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Returns the localized demographic label used to distinguish clients who
/// share a name.
String clientDemographicsLabel(BuildContext context, TrainerClient client) {
  final korean = Localizations.localeOf(context).languageCode == 'ko';
  final gender = switch (client.rosterGender) {
    'female' => korean ? '여성' : 'Female',
    'male' => korean ? '남성' : 'Male',
    _ => korean ? '기타' : 'Other',
  };
  final age = korean ? '${client.rosterAge}세' : 'Age ${client.rosterAge}';
  return '$gender · $age';
}

/// Returns a plain-text identity for places that cannot compose text styles.
String clientIdentityLabel(BuildContext context, TrainerClient client) =>
    '${client.name} ${clientDemographicsLabel(context, client)}';

/// Resolves display-only records that carry a client id and a legacy name.
/// A name fallback is safe only when it identifies exactly one roster entry.
TrainerClient? findClientIdentity(
  List<TrainerClient> clients, {
  required String? clientId,
  required String clientName,
}) {
  for (final client in clients) {
    if (clientId != null && client.id == clientId) return client;
  }
  final sameName = clients.where((client) => client.name == clientName);
  return sameName.length == 1 ? sameName.single : null;
}

/// The shared client-name treatment used across trainer tabs.
class ClientIdentity extends StatelessWidget {
  const ClientIdentity({
    super.key,
    required this.client,
    this.nameStyle,
    this.demographicsStyle,
    this.maxLines = 1,
    this.textAlign,
  });

  final TrainerClient client;
  final TextStyle? nameStyle;
  final TextStyle? demographicsStyle;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final resolvedNameStyle =
        nameStyle ??
        const TextStyle(
          color: AppColors.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        );
    final resolvedDemographicsStyle =
        demographicsStyle ??
        resolvedNameStyle.copyWith(
          color: AppColors.subtleForeground,
          fontSize: (resolvedNameStyle.fontSize ?? 14) - 3,
          fontWeight: FontWeight.w600,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: textAlign == TextAlign.center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: <Widget>[
        Flexible(
          child: Text(
            client.name,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: resolvedNameStyle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            clientDemographicsLabel(context, client),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: resolvedDemographicsStyle,
          ),
        ),
      ],
    );
  }
}
