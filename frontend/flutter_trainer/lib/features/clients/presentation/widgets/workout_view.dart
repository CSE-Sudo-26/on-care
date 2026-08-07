import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays;
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 운동 — the whole prescription→execution loop for one client, in the
/// order the trainer reasons about it.
///
/// 배정된 루틴 (what this client was given) used to be its own 루틴 tab.
/// Splitting it from the history meant the one question the tab exists to
/// answer — "I assigned this; did they do it?" — needed two tabs and a
/// memory of the first. They are one story, so they are one screen:
/// what's active now, then this week at a glance, then what actually
/// happened session by session.
class WorkoutView extends ConsumerWidget {
  /// Creates the workout view for [client].
  const WorkoutView({super.key, required this.client});

  /// The client whose history is shown (carries weekCompletion).
  final TrainerClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(clientHistoryProvider(client.id));
    final assigned = ref.watch(assignedRoutinesProvider(client.id));
    final sessions = ref.watch(
      clientSessionsProvider((id: client.id, name: client.name)),
    );

    // Each section owns its own async state. Gating the whole list on
    // the history provider would mean a failing /history takes the
    // routines and the PT sessions down with it — and those two used to
    // be their own tab, reachable whether or not the history loaded.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        _AssignedRoutinesCard(clientId: client.id, assigned: assigned),
        const SizedBox(height: AppSpacing.md),
        _SessionsCard(sessions: sessions),
        const SizedBox(height: AppSpacing.md),
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
        ...history.when(
          loading: () => const <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ],
          error: (e, _) => const <Widget>[
            EmptyHint(message: '운동 기록을 불러오지 못했어요'),
          ],
          data: (entries) => <Widget>[
            if (entries.isEmpty)
              const EmptyHint(
                message: '아직 운동 기록이 없어요',
                icon: Icons.fitness_center_outlined,
              ),
            for (final entry in entries) ...<Widget>[
              _HistoryCard(entry: entry),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ],
    );
  }
}

/// 배정된 루틴 — what the member sees in their own app (server-side, real
/// API only). Empty in demo mode, where the mock repository has no member
/// backend to deliver to; the history below carries the story there.
class _AssignedRoutinesCard extends StatelessWidget {
  const _AssignedRoutinesCard({required this.clientId, required this.assigned});

  final String clientId;
  final AsyncValue<List<AssignedRoutine>> assigned;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '배정된 루틴',
      icon: Icons.assignment_turned_in_outlined,
      dense: true,
      trailing: CardLink(
        label: '새 루틴',
        onTap: () => context.go(AppRoutes.coachingFor(clientId)),
      ),
      child: assigned.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => const EmptyHint(message: '루틴을 불러오지 못했어요'),
        data: (routines) => routines.isEmpty
            ? const EmptyHint(
                message: '아직 이 고객에게 배정된 루틴이 없어요',
                icon: Icons.assignment_outlined,
              )
            : Column(
                children: <Widget>[
                  for (final routine in routines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: <Widget>[
                          _TypeChip(
                            label: routine.type,
                            ai: routine.source == 'ai',
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  routine.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.foreground,
                                  ),
                                ),
                                if (routine.reason.isNotEmpty)
                                  Text(
                                    routine.reason,
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
                          Text(
                            '${routine.minutes}분',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// PT 프로그램 이력 — the sessions actually on the calendar for this
/// client and whether a program is attached.
///
/// Deliberately kept apart from 운동 기록 below: this is the *schedule*
/// (including sessions still 예정), that is the *record* of what was
/// completed. The 스케줄 tab answers the same question by date; this is
/// the only place it's answered per client.
class _SessionsCard extends StatelessWidget {
  const _SessionsCard({required this.sessions});

  final AsyncValue<List<ScheduleSession>> sessions;

  @override
  Widget build(BuildContext context) {
    final today = ymd(DateTime.now());
    return SectionCard(
      title: 'PT 프로그램 이력',
      icon: Icons.event_note_outlined,
      dense: true,
      child: sessions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => const EmptyHint(message: '일정을 불러오지 못했어요'),
        data: (list) => list.isEmpty
            ? const EmptyHint(
                message: '등록된 PT 세션이 없어요',
                icon: Icons.event_busy_outlined,
              )
            : Column(
                children: <Widget>[
                  for (final session in list.take(8))
                    _SessionRow(session: session, today: today),
                ],
              ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.today});

  final ScheduleSession session;
  final String today;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(session.date);
    final label = date == null ? session.date : '${date.month}/${date.day}';
    final exercises = session.program.map((p) => p.name).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 46,
            child: Text(
              session.date == today ? '오늘' : label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: session.date == today
                    ? AppColors.primary
                    : AppColors.subtleForeground,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${session.type} · ${session.durationMinutes}분',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  exercises.isEmpty ? '등록된 프로그램 없음' : exercises,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: exercises.isEmpty
                        ? AppColors.disabledForeground
                        : AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            session.status,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: session.isDone ? AppColors.success : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// AI-generated routines carry the navy sparkle; trainer-authored ones
/// carry the orange the rest of the app uses for trainer edits.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.ai});

  final String label;
  final bool ai;

  @override
  Widget build(BuildContext context) {
    final color = ai ? AppColors.primary : AppColors.brandOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: ai
          ? IconLabel(
              icon: Icons.auto_awesome,
              label: label,
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            )
          : Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
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
    // 아직 오지 않은 요일은 평균에서도 막대에서도 뺀다 — 0으로 세면
    // 주 초반일수록 실제보다 낮은 완료율이 나온다.
    final elapsed = elapsedWeekdays(DateTime.now());
    final counted = week.take(elapsed).toList();
    final avg = counted.isEmpty
        ? 0
        : (counted.reduce((a, b) => a + b) / counted.length).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
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
                          height: i >= elapsed
                              ? 4
                              : (4 + week[i] * 0.36).clamp(4, 40).toDouble(),
                          decoration: BoxDecoration(
                            color: i >= elapsed
                                ? AppColors.border
                                : _rateColor(week[i]),
                            borderRadius: const BorderRadius.all(AppRadius.xs),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _days[i],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: i >= elapsed
                                ? AppColors.disabledForeground
                                : AppColors.subtleForeground,
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
        boxShadow: kCardShadow,
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
          for (final line in entry.exercises) _ExerciseLine(line: line),
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
/// One line of a logged routine.
///
/// The stored string marks its own outcome with a trailing '✓' / '✗'
/// (see [RoutineHistoryEntry.exercises]). Those characters are a storage
/// convention, not something to print: Flutter web has no glyph for them
/// in the app's font stack and draws 두부 boxes. Read the marker, then
/// render it as an icon and strike-through.
class _ExerciseLine extends StatelessWidget {
  const _ExerciseLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final skipped = line.contains('✗');
    final text = line.replaceAll(RegExp(r'\s*[✓✗]\s*'), ' ').trim();
    final color = skipped
        ? AppColors.disabledForeground
        : AppColors.mutedForeground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              skipped ? Icons.close : Icons.check,
              size: 12,
              color: skipped ? AppColors.disabledForeground : AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: color,
                decoration: skipped ? TextDecoration.lineThrough : null,
                decorationColor: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

/// Left-bordered note box ("고객 피드백" navy / "트레이너 메모" orange).
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
