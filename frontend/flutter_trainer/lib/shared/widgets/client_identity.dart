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

/// 고객 목록 행에 붙는 목표 한 줄. (#898)
///
/// 트레이너가 고객을 고르는 기준은 이름이 아니라 **무엇을 목표로 하는
/// 사람인가**다. 이름이 비슷한 고객이 섞여 있을 때 특히 그렇다. 전에는
/// `고객 관리` 탭 카드에만 있어서, 메시지·스케줄·프로그램·리포트에서
/// 목표를 보려면 탭을 나갔다 와야 했다.
///
/// 목표가 비면 아무것도 그리지 않는다 — 빈 [Text] 는 행 높이만 먹는다.
/// 이름보다 한 단계 작고 흐리게, 한 줄 말줄임으로 기존 정보 위계를
/// 흔들지 않는다.
class ClientGoalLabel extends StatelessWidget {
  /// Creates the goal line for [client].
  const ClientGoalLabel({
    super.key,
    required this.client,
    this.fontSize = 11.5,
    this.color = AppColors.subtleForeground,
  });

  final TrainerClient client;

  /// 부르는 쪽 행의 이름 글씨보다 한 단계 작게 준다.
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (client.goal.trim().isEmpty) return const SizedBox.shrink();
    return Text(
      client.goal,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// The shared client-name treatment used across trainer tabs.
class ClientIdentity extends StatelessWidget {
  const ClientIdentity({
    super.key,
    required this.client,
    this.nameStyle,
    this.demographicsStyle,
    this.maxLines = 1,
    this.stacked = false,
    this.textAlign,
  });

  final TrainerClient client;
  final TextStyle? nameStyle;
  final TextStyle? demographicsStyle;
  final int maxLines;
  final bool stacked;
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
    final name = Text(
      client.name,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: resolvedNameStyle,
    );
    final demographics = Text(
      clientDemographicsLabel(context, client),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: resolvedDemographicsStyle,
    );

    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: textAlign == TextAlign.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[name, const SizedBox(height: 2), demographics],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: textAlign == TextAlign.center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: <Widget>[
        Flexible(child: name),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: demographics),
      ],
    );
  }
}
