import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// The 운동기록 sub-tab: this week's completion bars + the workout
/// history list (completion donut, exercises, feedback, trainer note).
class WorkoutView extends ConsumerWidget {
  /// Creates the workout view for [client].
  const WorkoutView({super.key, required this.client});

  /// The client whose history is shown (carries weekCompletion).
  final TrainerClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(clientHistoryProvider(client.id));

    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
        child: Text(
          '운동 기록을 불러오지 못했어요',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
      ),
      data: (entries) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          _WeekCompletionCard(week: client.weekCompletion),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '운동 기록',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in entries) ...<Widget>[
            _HistoryCard(entry: entry),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Completion color scale shared by the bars and donuts: 100 = done
/// (green), partial = orange, 0 = untouched (grey).
Color _rateColor(int rate) {
  if (rate >= 100) return AppColors.success;
  if (rate > 0) return AppColors.warning;
  return AppColors.borderStrong;
}

/// "이번 주 완료율" — average % + 월~일 bars + legend.
class _WeekCompletionCard extends StatelessWidget {
  const _WeekCompletionCard({required this.week});

  final List<int> week;

  static const List<String> _days = <String>['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final avg = week.isEmpty
        ? 0
        : (week.reduce((a, b) => a + b) / week.length).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '이번 주 완료율',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Text(
                '$avg%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            // Tallest bar (40) + gap (4) + day label (~14) with headroom.
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (var i = 0; i < week.length && i < _days.length; i++) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Container(
                          height: (4 + week[i] * 0.36).clamp(4, 40).toDouble(),
                          decoration: BoxDecoration(
                            color: _rateColor(week[i]),
                            borderRadius: const BorderRadius.all(AppRadius.xs),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _days[i],
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subtleForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < week.length - 1) const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              const _LegendDot(color: AppColors.success, label: '완료'),
              const SizedBox(width: AppSpacing.md),
              const _LegendDot(color: AppColors.warning, label: '부분'),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.borderStrong, label: '미완료'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.subtleForeground,
          ),
        ),
      ],
    );
  }
}

/// A single workout record: date/kind, completion donut, exercise lines
/// (skipped ones struck through), client feedback, trainer note.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final RoutineHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.dateLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      entry.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtleForeground,
                      ),
                    ),
                  ],
                ),
              ),
              _CompletionDonut(rate: entry.completionRate),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in entry.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: line.contains('✗')
                      ? AppColors.disabledForeground
                      : AppColors.mutedForeground,
                  decoration: line.contains('✗')
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          if (entry.clientFeedback.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _NoteBox(
              title: '고객 피드백',
              body: entry.clientFeedback,
              color: AppColors.accent,
            ),
          ],
          if (entry.trainerNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _NoteBox(
              title: '트레이너 메모',
              body: entry.trainerNote,
              color: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

/// Completion ring with the % inside (green 100 / orange partial / grey 0).
class _CompletionDonut extends StatelessWidget {
  const _CompletionDonut({required this.rate});

  final int rate;

  @override
  Widget build(BuildContext context) {
    final color = _rateColor(rate);
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            value: rate / 100,
            strokeWidth: 3,
            color: color,
            backgroundColor: AppColors.inputBackground,
          ),
          Text(
            '$rate%',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: rate == 0 ? AppColors.disabledForeground : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Left-bordered note box ("고객 피드백" blue / "트레이너 메모" orange).
class _NoteBox extends StatelessWidget {
  const _NoteBox({
    required this.title,
    required this.body,
    required this.color,
  });

  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.4), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
