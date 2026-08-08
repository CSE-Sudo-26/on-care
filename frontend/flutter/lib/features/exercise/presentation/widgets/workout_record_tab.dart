import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/errors/app_error.dart';
import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/charts/app_stacked_bar_chart.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_week.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/exercise/presentation/widgets/add_session_sheet.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/ai_coach_card.dart';
import 'package:oncare/shared/widgets/error_view.dart';
import 'package:oncare/shared/widgets/swipe_to_delete.dart';

/// 운동 기록 tab body. Stat row → stacked weekly chart → AI feedback
/// (unchanged AiCoachCard) → grouped session history. The FAB lives
/// on the parent page so it can sit above the bottom nav.
class WorkoutRecordTab extends ConsumerWidget {
  const WorkoutRecordTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exerciseWeekProvider);
    return async.when(
      // 운동 추가 후 invalidate 시 전체 화면이 스피너로 깜빡이지 않도록 이전 데이터 유지.
      skipLoadingOnRefresh: true,
      data: (week) => _Body(week: week),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => ErrorView(
        error: e is AppError ? e : UnknownError(message: e.toString()),
        onRetry: () => ref.invalidate(exerciseWeekProvider),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.week});
  final ExerciseWeek week;

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    try {
      await ref.read(exerciseRepositoryProvider).deleteSession(id);
      ref.invalidate(exerciseWeekProvider); // 삭제가 이번 주 집계에 반영
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.dietDeleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasStackedSeries =
        week.cardioMinutes.isNotEmpty ||
        week.strengthMinutes.isNotEmpty ||
        week.stretchingMinutes.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl + 56, // leave room for the FAB
      ),
      children: <Widget>[
        // Stat row — four cards side-by-side, last one is the orange
        // streak card to match the prototype.
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: l.exThisWeek,
                value: week.workoutCount.toString(),
                unit: '회',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                label: l.exStatTime,
                value: week.totalMinutes.toString(),
                unit: '분',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                label: l.dashboardMetricCalories,
                value: week.totalCalories.toString(),
                unit: 'kcal',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _StreakTile(days: week.streakDays)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Weekly chart.
        AppCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '이번 주 운동 현황',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 200,
                child: AppStackedBarChart(
                  labels: week.dayLabels,
                  series: hasStackedSeries
                      ? <({String name, Color color, List<double> values})>[
                          (
                            name: '유산소',
                            color: const Color(0xFF60A5FA),
                            values: week.cardioMinutes,
                          ),
                          (
                            name: '근력',
                            color: const Color(0xFF1E40AF),
                            values: week.strengthMinutes,
                          ),
                          (
                            name: '스트레칭',
                            color: const Color(0xFFBAE6FD),
                            values: week.stretchingMinutes,
                          ),
                        ]
                      : <({String name, Color color, List<double> values})>[
                          (
                            name: '운동',
                            color: AppColors.primary,
                            values: week.dailyMinutes,
                          ),
                        ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (hasStackedSeries)
                _LegendRow(
                  entries: <_LegendEntry>[
                    _LegendEntry(
                      label: l.exTypeCardio,
                      color: const Color(0xFF60A5FA),
                    ),
                    _LegendEntry(
                      label: l.exTypeStrength,
                      color: const Color(0xFF1E40AF),
                    ),
                    _LegendEntry(
                      label: l.exTypeStretching,
                      color: const Color(0xFFBAE6FD),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 온이의 피드백 — kept verbatim per the task requirements.
        AiCoachCard(message: week.aiCoachMessage),
        const SizedBox(height: AppSpacing.lg),

        for (final s in week.sessions) ...<Widget>[
          if (s.id == null)
            _SessionCard(session: s)
          else
            SwipeToDelete(
              dismissKey: ValueKey<String>('ex-${s.id}'),
              message: '이 운동 기록을 삭제할까요?',
              onDelete: () => _delete(context, ref, s.id!),
              child: _SessionCard(
                session: s,
                onTap: () => showAddSessionSheet(context, session: s),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFB923C), Color(0xFFEF4444)],
        ),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(height: 2),
          Text(
            days.toString(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            '일 연속',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _LegendEntry {
  const _LegendEntry({required this.label, required this.color});
  final String label;
  final Color color;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.entries});
  final List<_LegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < entries.length; i++) ...<Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: entries[i].color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(entries[i].label, style: theme.textTheme.bodySmall),
          if (i < entries.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

String _typeLabel(ExerciseType t) => switch (t) {
  ExerciseType.cardio => '유산소',
  ExerciseType.strength => '근력',
  ExerciseType.yoga => '요가',
  ExerciseType.walking => '걷기',
  ExerciseType.stretching => '스트레칭',
  ExerciseType.other => '기타',
};

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, this.onTap});
  final ExerciseSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = session.dateLabel ?? '${session.dayLabel}요일';
    final timeLabel = session.timeLabel;
    return AppCard(
      outlined: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            dateLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    if (timeLabel != null) ...<Widget>[
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(timeLabel, style: theme.textTheme.bodySmall),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.all(AppRadius.pill),
                      ),
                      child: Text(
                        _typeLabel(session.type),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '소모 칼로리',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.foreground,
                    ),
                  ),
                  Text(
                    '${session.calories} kcal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (session.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            for (final item in session.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text('• $item', style: theme.textTheme.bodySmall),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${session.minutes}분 운동',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
