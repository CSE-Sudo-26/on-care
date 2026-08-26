import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';

/// A client row on the 고객 관리 list: avatar + active dot, identity,
/// goal, and a quick-metric footer (칼로리 / 나트륨 / 마지막 루틴).
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

  /// Unread chat messages retained for call-site compatibility. The customer
  /// roster intentionally does not expose chat previews or notification badges.
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
                ? _CompactClientContent(client: client)
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
                                ClientIdentity(
                                  client: client,
                                  nameStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.foreground,
                                  ),
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
                      const SizedBox(height: AppSpacing.md),
                      _WeeklyRoutineAdherence(client: client),
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
  const _CompactClientContent({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
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
                  Expanded(child: ClientIdentity(client: client)),
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
              const SizedBox(height: AppSpacing.sm),
              _WeeklyRoutineAdherence(client: client, compact: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// 이번 주에 기록된 날만 평균낸 루틴 수행률.
///
/// 0은 미수행이 아니라 미집계이므로 빈 주를 0% 실패처럼 그리지 않는다. 주의
/// 배지와 고객 검색이 쓰는 [recordedCompletionMean]을 그대로 사용해 고객
/// 목록 안에서 같은 회원을 서로 다른 숫자로 말하지 않게 한다. (#1284)
class _WeeklyRoutineAdherence extends StatelessWidget {
  const _WeeklyRoutineAdherence({required this.client, this.compact = false});

  final TrainerClient client;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final double? mean = recordedCompletionMean(client);
    final int? percent = mean?.round();
    final String valueLabel = percent == null
        ? l.clientRoutineAdherenceUnmeasured
        : '$percent%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 카드마다 `주간 이행률` 을 되풀이하지 않는다(#1464) — 목록의 모든
        // 그래프가 같은 지표라, 그 말은 목록 위 툴바가 한 번만 한다. 카드에는
        // 견줄 값(%)과 그래프만 남는다.
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            valueLabel,
            key: ValueKey<String>('client-adherence-value-${client.id}'),
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: percent == null
                  ? AppColors.mutedForeground
                  : AppColors.foreground,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: l.clientWeeklyRoutineAdherence,
          value: valueLabel,
          child: ExcludeSemantics(
            child: LinearProgressIndicator(
              key: ValueKey<String>('client-weekly-adherence-${client.id}'),
              value: (mean ?? 0).clamp(0, 100) / 100,
              minHeight: compact ? 4 : 6,
              borderRadius: const BorderRadius.all(AppRadius.pill),
              backgroundColor: AppColors.borderStrong,
              color: AppColors.accent,
            ),
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
