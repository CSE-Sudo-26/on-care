import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays, weekdayCount, weekdayLabels;
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
import 'package:oncare_trainer/features/clients/presentation/widgets/weekly_exercise_trend_card.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';

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
    final AppLocalizations l = AppLocalizations.of(context);
    final history = ref.watch(clientHistoryProvider(client.id));
    final assigned = ref.watch(assignedRoutinesProvider(client.id));
    final sessionKey = (id: client.id, name: client.name);
    final sessions = ref.watch(clientSessionsProvider(sessionKey));
    final exerciseWeek = ref.watch(clientExerciseWeekProvider(client.id));

    // Each section owns its own async state. Gating the whole list on
    // the history provider would mean a failing /history takes the
    // routines and the PT sessions down with it — and those two used to
    // be their own tab, reachable whether or not the history loaded.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        _AssignedRoutinesCard(clientId: client.id, assigned: assigned),
        const SizedBox(height: AppSpacing.md),
        _SessionsCard(
          sessions: sessions,
          onRetry: () => ref.invalidate(clientSessionsProvider(sessionKey)),
        ),
        const SizedBox(height: AppSpacing.md),
        WeeklyExerciseTrendCard(
          week: exerciseWeek,
          onRetry: () => ref.invalidate(clientExerciseWeekProvider(client.id)),
        ),
        const SizedBox(height: AppSpacing.md),
        _WeekCompletionCard(week: client.weekCompletion),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l.workoutRecords,
          style: TextStyle(
            fontSize: 12.5,
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
          error: (e, _) => <Widget>[
            EmptyHint(
              message: l.workoutLoadFailed,
              icon: Icons.error_outline,
              action: ActionButton(
                key: ValueKey<String>('workout-history-retry-${client.id}'),
                label: l.actionRetry,
                onPressed: history.isLoading
                    ? null
                    : () => ref.invalidate(clientHistoryProvider(client.id)),
              ),
            ),
          ],
          data: (entries) => <Widget>[
            if (entries.isEmpty)
              EmptyHint(
                message: l.workoutEmpty,
                icon: Icons.fitness_center_outlined,
              ),
            for (final entry in entries) ...<Widget>[
              _HistoryCard(clientId: client.id, entry: entry),
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
class _AssignedRoutinesCard extends ConsumerWidget {
  const _AssignedRoutinesCard({required this.clientId, required this.assigned});

  final String clientId;
  final AsyncValue<List<AssignedRoutine>> assigned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SectionCard(
      title: l.routinesAssigned,
      icon: Icons.assignment_turned_in_outlined,
      dense: true,
      trailing: CardLink(
        label: l.routineNew,
        onTap: () => context.go(AppRoutes.coachingFor(clientId)),
      ),
      child: assigned.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => EmptyHint(
          message: l.routinesLoadFailed,
          icon: Icons.error_outline,
          action: ActionButton(
            key: ValueKey<String>('assigned-routines-retry-$clientId'),
            label: l.actionRetry,
            onPressed: assigned.isLoading
                ? null
                : () => ref.invalidate(assignedRoutinesProvider(clientId)),
          ),
        ),
        data: (routines) => routines.isEmpty
            ? EmptyHint(
                message: l.routinesEmpty,
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
                                    fontSize: 13.5,
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
                                      fontSize: 11.5,
                                      color: AppColors.subtleForeground,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            l.minutesShort(routine.minutes),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          // 배정 뒤 정정·철회. 전에는 잘못 넣어도 고칠 수 없어
                          // 새 루틴을 하나 더 배정했고, 회원 앱에는 둘 다
                          // 그대로 보였다. (#504)
                          _RoutineActions(clientId: clientId, routine: routine),
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
  const _SessionsCard({required this.sessions, required this.onRetry});

  final AsyncValue<List<ScheduleSession>> sessions;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final today = ymd(DateTime.now());
    return SectionCard(
      title: l.ptProgramHistory,
      icon: Icons.event_note_outlined,
      dense: true,
      child: sessions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => EmptyHint(
          message: l.scheduleLoadFailed,
          icon: Icons.error_outline,
          action: ActionButton(
            key: const ValueKey<String>('client-sessions-retry'),
            label: l.actionRetry,
            onPressed: sessions.isLoading ? null : onRetry,
          ),
        ),
        data: (list) => list.isEmpty
            ? EmptyHint(
                message: l.ptSessionsEmpty,
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
    final AppLocalizations l = AppLocalizations.of(context);
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
              session.date == today ? l.labelToday : label,
              style: TextStyle(
                fontSize: 12,
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
                  l.sessionTypeAndDuration(
                    sessionTypeLabel(l, session.type),
                    session.durationMinutes,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  exercises.isEmpty ? l.programNone : exercises,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
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
            scheduleStatusLabel(l, session.status),
            style: TextStyle(
              fontSize: 11.5,
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
              fontSize: 11,
              fontWeight: FontWeight.w800,
            )
          : Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

  /// 요일 라벨은 로케일을 따르므로 const 로 둘 수 없다. (#501)
  static List<String> _days(AppLocalizations l) => weekdayLabels(l);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
              Expanded(
                child: Text(
                  l.weekCompletionRate,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Text(
                '$avg%',
                style: const TextStyle(
                  fontSize: 19,
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
                for (var i = 0; i < week.length && i < weekdayCount; i++) ...[
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
                          _days(l)[i],
                          style: TextStyle(
                            fontSize: 10,
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
              _LegendDot(color: AppColors.success, label: l.legendDone),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.warning, label: l.legendPartial),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.borderStrong, label: l.legendMissed),
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
            fontSize: 10,
            color: AppColors.subtleForeground,
          ),
        ),
      ],
    );
  }
}

/// A single workout record: date/kind, completion donut, exercise lines
/// (skipped ones struck through), client feedback, trainer note.
class _HistoryCard extends ConsumerStatefulWidget {
  const _HistoryCard({required this.clientId, required this.entry});

  final String clientId;
  final RoutineHistoryEntry entry;

  @override
  ConsumerState<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends ConsumerState<_HistoryCard> {
  bool _saving = false;

  Future<void> _editFeedback() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final String? feedback = await showDialog<String>(
      context: context,
      builder: (_) => _FeedbackDialog(initialValue: widget.entry.trainerNote),
    );
    if (feedback == null || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(clientRepositoryProvider)
          .updateHistoryFeedback(widget.clientId, widget.entry.id, feedback);
      ref.invalidate(clientHistoryProvider(widget.clientId));
      messenger.showSnackBar(SnackBar(content: Text(l.routineFeedbackSaved)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            serverDetailOr(
              l,
              error is AppError ? error.message : null,
              l.routineFeedbackFailed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final RoutineHistoryEntry entry = widget.entry;
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      entry.label,
                      style: const TextStyle(
                        fontSize: 11,
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
              title: l.clientFeedback,
              body: entry.clientFeedback,
              color: AppColors.accent,
            ),
          ],
          if (entry.trainerNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _NoteBox(
              title: l.trainerNote,
              body: entry.trainerNote,
              color: AppColors.warning,
            ),
          ],
          if (entry.assignedRoutineId != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: ActionButton(
                key: ValueKey<String>('routine-feedback-${entry.id}'),
                label: entry.trainerNote.isEmpty
                    ? l.routineFeedbackWrite
                    : l.routineFeedbackEdit,
                onPressed: _saving ? null : _editFeedback,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.routineFeedbackTitle),
      content: TextField(
        key: const ValueKey<String>('routine-feedback-input'),
        controller: _controller,
        autofocus: true,
        maxLength: 2000,
        maxLines: 5,
        decoration: InputDecoration(hintText: l.routineFeedbackHint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('routine-feedback-save'),
          onPressed: () {
            final String text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.of(context).pop(text);
          },
          child: Text(l.actionSave),
        ),
      ],
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
                fontSize: 12.5,
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
              fontSize: 9.5,
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
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// 배정된 루틴 한 줄의 수정·삭제. (#504)
///
/// 목록 안에 두는 이유: 잘못 배정한 것을 발견하는 자리가 곧 고치는 자리여야
/// 한다. 별도 편집 화면으로 보내면 어느 루틴을 고치는 중인지 다시 확인해야 한다.
class _RoutineActions extends ConsumerStatefulWidget {
  const _RoutineActions({required this.clientId, required this.routine});

  final String clientId;
  final AssignedRoutine routine;

  @override
  ConsumerState<_RoutineActions> createState() => _RoutineActionsState();
}

class _RoutineActionsState extends ConsumerState<_RoutineActions> {
  /// 요청이 오가는 동안 잠근다 — 삭제를 두 번 누르면 두 번째는 404 다.
  bool _busy = false;

  Future<void> _edit() async {
    // messenger 와 함께 await 전에 잡아 둔다 — 실패 경로가 await 뒤에 있다.
    final messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    final result =
        await showDialog<({String name, int minutes, String reason})>(
          context: context,
          builder: (_) => _RoutineEditDialog(routine: widget.routine),
        );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(trainerRoutineRepositoryProvider)
          .updateRoutine(
            widget.clientId,
            widget.routine.id,
            name: result.name,
            minutes: result.minutes,
            reason: result.reason,
          );
    } on StateError {
      // 404 — 그 루틴이 서버에 이미 없다(다른 기기에서 먼저 지웠거나 담당이
      // 풀렸다). 뒤처진 쪽은 화면이므로 목록을 다시 읽어 서버를 따라간다.
      // 그대로 두면 없는 루틴이 남아 다시 눌러도 계속 실패한다.
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(assignedRoutinesProvider(widget.clientId));
      }
      messenger.showSnackBar(SnackBar(content: Text(l.routineAlreadyGone)));
      return;
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l.routineUpdateFailed)));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(assignedRoutinesProvider(widget.clientId));
    messenger.showSnackBar(SnackBar(content: Text(l.routineUpdated)));
  }

  Future<void> _delete() async {
    final AppLocalizations l = AppLocalizations.of(context);
    // 되돌릴 수 없는 동작이라 확인을 받는다 — 회원 앱에서도 곧바로 사라진다.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.routineDeleteTitle),
        content: Text(l.routineDeleteBody(widget.routine.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.actionDelete,
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(trainerRoutineRepositoryProvider)
          .deleteRoutine(widget.clientId, widget.routine.id);
    } on StateError {
      // 404 — 이미 없는 것을 지우려 했다. 목적은 이뤄진 셈이라 실패로만 알리고
      // 끝내지 않고, 목록을 다시 읽어 그 줄을 화면에서 걷어낸다.
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(assignedRoutinesProvider(widget.clientId));
      }
      messenger.showSnackBar(SnackBar(content: Text(l.routineAlreadyGone)));
      return;
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l.routineDeleteFailed)));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(assignedRoutinesProvider(widget.clientId));
    messenger.showSnackBar(SnackBar(content: Text(l.routineDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.only(left: AppSpacing.sm),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          key: ValueKey<String>('routine-edit-${widget.routine.id}'),
          onPressed: _edit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          color: AppColors.mutedForeground,
          tooltip: l.routineEdit,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          key: ValueKey<String>('routine-delete-${widget.routine.id}'),
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline, size: 16),
          color: AppColors.destructive,
          tooltip: l.routineDelete,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// 루틴 수정 다이얼로그. 이름·시간·사유만 다룬다.
///
/// 종류(type)를 빼 둔 이유: 그 값은 서버가 Literal 로 검증하는 계약값이고,
/// 종류를 바꾸는 것은 사실상 다른 루틴을 주는 일이라 새로 배정하는 편이 맞다.
class _RoutineEditDialog extends StatefulWidget {
  const _RoutineEditDialog({required this.routine});

  final AssignedRoutine routine;

  @override
  State<_RoutineEditDialog> createState() => _RoutineEditDialogState();
}

class _RoutineEditDialogState extends State<_RoutineEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.routine.name,
  );
  late final TextEditingController _minutes = TextEditingController(
    text: widget.routine.minutes.toString(),
  );
  late final TextEditingController _reason = TextEditingController(
    text: widget.routine.reason,
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _minutes.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final minutes = int.tryParse(_minutes.text.trim());
    final reason = _reason.text.trim();
    if (name.isEmpty) {
      final AppLocalizations l = AppLocalizations.of(context);
      setState(() => _error = l.routineNameRequired);
      return;
    }
    // 서버 제약(name 100자·minutes 0~600·reason 200자)과 같은 값으로 미리
    // 거른다 — 422 를 받아 오면 "수정하지 못했어요"라는 애매한 문구만 남아,
    // 무엇이 문제인지 트레이너가 알 수 없다.
    //
    // 세는 단위도 서버와 맞춘다. Pydantic 의 max_length 는 파이썬 문자(코드
    // 포인트) 수인데 Dart 의 String.length 는 UTF-16 코드 유닛 수라, 이모지가
    // 들어가면 서버가 받아 줄 값을 화면이 먼저 막는다. runes 로 센다.
    if (name.runes.length > 100) {
      final AppLocalizations l = AppLocalizations.of(context);
      setState(() => _error = l.routineNameTooLong);
      return;
    }
    if (minutes == null || minutes < 0 || minutes > 600) {
      final AppLocalizations l = AppLocalizations.of(context);
      setState(() => _error = l.routineMinutesRange);
      return;
    }
    if (reason.runes.length > 200) {
      final AppLocalizations l = AppLocalizations.of(context);
      setState(() => _error = l.routineReasonTooLong);
      return;
    }
    Navigator.of(context).pop((name: name, minutes: minutes, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.routineEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('routine-edit-name'),
            controller: _name,
            decoration: InputDecoration(labelText: l.routineFieldName),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey<String>('routine-edit-minutes'),
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.routineFieldMinutesLabel),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey<String>('routine-edit-reason'),
            controller: _reason,
            decoration: InputDecoration(labelText: l.routineFieldReason),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.destructive,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        TextButton(
          key: const ValueKey<String>('routine-edit-save'),
          onPressed: _submit,
          child: Text(l.actionSave),
        ),
      ],
    );
  }
}
