import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';

/// Today's timeline, condensed for the dashboard: time, status dot,
/// who + what, and the status word. Gaps are shown (a trainer's free
/// hour is information) but muted.
class TodayTimelineCard extends ConsumerWidget {
  /// Creates the card.
  const TodayTimelineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final schedule = ref.watch(todayScheduleProvider);

    return SectionCard(
      title: l.dashTodaySchedule,
      icon: Icons.today_outlined,
      trailing: CardLink(
        label: l.dashSeeAll,
        onTap: () => context.go(AppRoutes.scheduleView('day')),
      ),
      child: schedule.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => EmptyHint(message: l.dashScheduleLoadFailed),
        data: (sessions) {
          if (sessions.isEmpty) {
            return EmptyHint(
              message: l.dashNoScheduleToday,
              icon: Icons.event_busy_outlined,
            );
          }
          return Column(
            children: <Widget>[
              for (final session in sessions)
                _Row(
                  session: session,
                  onTap: () => context.go(AppRoutes.scheduleView('day')),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.session, required this.onTap});

  final ScheduleSession session;
  final VoidCallback onTap;

  Color get _statusColor {
    if (session.isDone) return AppColors.success;
    if (session.isUpcoming) return AppColors.primary;
    return AppColors.disabledForeground;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final muted = session.isGap;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Opacity(
          opacity: muted ? 0.55 : 1,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 42,
                child: Text(
                  session.time,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.subtleForeground,
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor,
                ),
              ),
              Expanded(
                child: Text(
                  muted
                      ? l.dashEmptySlot
                      : '${session.clientName} · ${session.type}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: muted ? FontWeight.w500 : FontWeight.w600,
                    color: muted
                        ? AppColors.subtleForeground
                        : AppColors.foreground,
                  ),
                ),
              ),
              if (!muted)
                Text(
                  // 저장된 계약값이 아니라 표시 문구를 그린다. (#501)
                  scheduleStatusLabel(l, session.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
