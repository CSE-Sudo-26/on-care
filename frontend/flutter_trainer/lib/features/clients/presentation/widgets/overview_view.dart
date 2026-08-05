import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays, weekdayLabels;
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/metric_tile.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 개요 — "how is this person doing right now?", answered before the
/// trainer has to open anything else.
///
/// The other sub-tabs are each one lens (오늘 먹은 것, 지난 운동, 대화).
/// Opening a client used to land on the chat, which meant reconstructing
/// their state from the last few messages. This section leads with the
/// alerts, then today's numbers, then the two trends that explain them.
class OverviewView extends ConsumerWidget {
  /// Creates the overview for [client].
  const OverviewView({
    super.key,
    required this.client,
    required this.onOpenSection,
  });

  /// The client being viewed.
  final TrainerClient client;

  /// Jumps to another sub-tab (used by the "자세히" links).
  final ValueChanged<String> onOpenSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(clientHistoryProvider(client.id));
    // The unread count has to come along: without it `alertsFor` always
    // sees 0 and 답장 대기 could never appear here — so a client the
    // dashboard flagged in red lost its reason on arrival.
    final unread =
        ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};
    final alerts = alertsFor(client, unread: unread[client.id] ?? 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        if (alerts.isNotEmpty) ...<Widget>[
          _AlertStrip(alerts: alerts),
          const SizedBox(height: AppSpacing.md),
        ],
        SectionCard(
          title: '오늘 요약',
          icon: Icons.today_outlined,
          dense: true,
          trailing: CardLink(
            label: '식단 보기',
            onTap: () => onOpenSection('diet'),
          ),
          child: Row(
            children: <Widget>[
              MetricTile(
                label: '칼로리',
                value: client.calories,
                unit: 'kcal',
                color: AppColors.foreground,
              ),
              const SizedBox(width: AppSpacing.xs),
              MetricTile(
                label: '나트륨',
                value: client.sodiumMg,
                unit: 'mg',
                color: AppColors.foreground,
                warn: client.sodiumOverBudget,
              ),
              const SizedBox(width: AppSpacing.xs),
              MetricTile(
                label: '당류',
                value: client.sugarG,
                unit: 'g',
                color: AppColors.foreground,
                warn: client.sugarG > sugarTargetG,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: '주간 운동 이행률',
          icon: Icons.fitness_center_outlined,
          dense: true,
          trailing: CardLink(
            label: '운동기록',
            onTap: () => onOpenSection('workout'),
          ),
          child: client.weekCompletion.length == weekdayLabels.length
              ? BarSeriesChart(
                  values: client.weekCompletion,
                  labels: weekdayLabels,
                  maxValue: 100,
                  height: 76,
                  showValues: true,
                  valueSuffix: '%',
                  highlightIndex: elapsedWeekdays(DateTime.now()) - 1,
                  pendingFromIndex: elapsedWeekdays(DateTime.now()),
                )
              : const EmptyHint(message: '이번 주 기록이 아직 없어요'),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: '최근 7일 나트륨',
          icon: Icons.show_chart,
          dense: true,
          trailing: client.sodiumWeekAvg == null
              ? null
              : Text(
                  '평균 ${client.sodiumWeekAvg}mg',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: (client.sodiumWeekAvg ?? 0) > sodiumTargetMg
                        ? AppColors.overTarget
                        : AppColors.primary,
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Sparkline(
                values: client.sodiumWeek,
                threshold: sodiumTargetMg,
                height: 52,
              ),
              if (client.sodiumWeek.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  client.sodiumOverDays > 0
                      ? '목표(${sodiumTargetMg}mg) 초과 ${client.sodiumOverDays}일'
                      : '이번 주 모두 목표 이내예요',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: client.sodiumOverDays > 0
                        ? AppColors.overTarget
                        : AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: '최근 활동',
          icon: Icons.history,
          dense: true,
          child: history.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => const EmptyHint(message: '기록을 불러오지 못했어요'),
            data: (entries) => entries.isEmpty
                ? const EmptyHint(message: '아직 운동 기록이 없어요')
                : Column(
                    children: <Widget>[
                      for (final entry in entries.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 62,
                                child: Text(
                                  entry.dateLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.subtleForeground,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.foreground,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.completionRate}%',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: entry.completionRate >= 80
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: ActionButton(
                label: 'AI 루틴 만들기',
                icon: Icons.auto_awesome,
                primary: true,
                onPressed: () => context.go(AppRoutes.coachingFor(client.id)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ActionButton(
                label: '주간 리포트',
                icon: Icons.insights_outlined,
                onPressed: () => context.go(AppRoutes.reportFor(client.id)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The reasons this client is flagged, as a row of badges. Repeating
/// them here (they also drive the dashboard) means the trainer who
/// arrived from a link and the one who clicked through the list see the
/// same explanation.
class _AlertStrip extends StatelessWidget {
  const _AlertStrip({required this.alerts});

  final List<ClientAlert> alerts;

  static Color _colorFor(ClientAlert alert) => switch (alert) {
    // 하나의 색은 하나의 뜻만: 남색 = 처리 필요, 빨강 = 목표 초과
    // (사용자 앱과 동일), 주황 = 완만한 주의. 답장 대기의 시급함은 색이
    // 아니라 목록 맨 위에 오는 순서가 말한다.
    ClientAlert.unanswered => AppColors.primary,
    ClientAlert.sodiumOver => AppColors.overTarget,
    ClientAlert.lowCompletion => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final alert in alerts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _colorFor(alert).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.error_outline, size: 12, color: _colorFor(alert)),
                const SizedBox(width: 4),
                Text(
                  alert.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _colorFor(alert),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
