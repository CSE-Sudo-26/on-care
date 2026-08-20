import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';

/// Seven day-columns of the week's sessions.
///
/// Answers the question the day timeline can't: where the free slots
/// are. Each column is a scroller of its own so a heavy Wednesday
/// doesn't stretch the whole grid.
class ScheduleWeekGrid extends StatelessWidget {
  const ScheduleWeekGrid({
    super.key,
    required this.start,
    required this.sessions,
    required this.selectedDay,
    required this.onPickDay,
    required this.onPickSession,
  });

  final DateTime start;
  final List<ScheduleSession> sessions;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onPickDay;
  final ValueChanged<ScheduleSession> onPickSession;

  @override
  Widget build(BuildContext context) {
    final today = ymd(nowKst());
    final byDate = <String, List<ScheduleSession>>{};
    for (final s in sessions) {
      if (s.isGap) continue;
      byDate.putIfAbsent(s.date, () => <ScheduleSession>[]).add(s);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        0,
        AppLayout.pagePadding,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < 7; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _DayColumn(
                day: start.add(Duration(days: i)),
                today: today,
                selected: ymd(start.add(Duration(days: i))) == ymd(selectedDay),
                sessions:
                    byDate[ymd(start.add(Duration(days: i)))] ??
                    const <ScheduleSession>[],
                onPickDay: onPickDay,
                onPickSession: onPickSession,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.today,
    required this.selected,
    required this.sessions,
    required this.onPickDay,
    required this.onPickSession,
  });

  final DateTime day;
  final String today;
  final bool selected;
  final List<ScheduleSession> sessions;
  final ValueChanged<DateTime> onPickDay;
  final ValueChanged<ScheduleSession> onPickSession;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final isToday = ymd(day) == today;
    final weekend = day.weekday >= DateTime.saturday;

    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.accentSurface : AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.borderStrong,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => onPickDay(day),
            borderRadius: const BorderRadius.vertical(top: AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: <Widget>[
                  Text(
                    weekdayNames(l)[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: weekend
                          ? AppColors.subtleForeground
                          : AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isToday ? AppColors.primary : AppColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderStrong),
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      l.schedEmptySlotShort,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtleForeground,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(5),
                    children: <Widget>[
                      for (final s in sessions)
                        _WeekChip(session: s, onTap: () => onPickSession(s)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeekChip extends ConsumerWidget {
  const _WeekChip({required this.session, required this.onTap});

  final ScheduleSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = session.isDone ? AppColors.success : AppColors.primary;
    final client = findClientIdentity(
      ref.watch(clientsProvider).valueOrNull ?? const <TrainerClient>[],
      clientId: session.clientId,
      clientName: session.clientName,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.all(AppRadius.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(AppRadius.xs),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(AppRadius.xs),
              border: Border(left: BorderSide(color: color, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (client == null)
                  Text(
                    session.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  )
                else
                  ClientIdentity(
                    client: client,
                    nameStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                    demographicsStyle: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.subtleForeground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
