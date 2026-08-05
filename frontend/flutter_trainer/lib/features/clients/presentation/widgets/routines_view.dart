import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 루틴 — what this client has actually been given, and when.
///
/// Two sources, deliberately kept apart because they mean different
/// things: **배정된 루틴** is what the member sees in their own app
/// (server-side, real API only), while **PT 프로그램** is what the
/// trainer scheduled for a session. In demo mode the first is empty and
/// the second carries the story.
class RoutinesView extends ConsumerWidget {
  /// Creates the routines tab for [client].
  const RoutinesView({super.key, required this.client});

  /// The client being viewed.
  final TrainerClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(assignedRoutinesProvider(client.id));
    final sessions = ref.watch(clientSessionsProvider(client.name));
    final today = ymd(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        SectionCard(
          title: '배정된 루틴',
          icon: Icons.assignment_turned_in_outlined,
          dense: true,
          trailing: CardLink(
            label: '새 루틴',
            onTap: () => context.go(AppRoutes.coachingFor(client.id)),
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
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
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
        ),
      ],
    );
  }
}

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
