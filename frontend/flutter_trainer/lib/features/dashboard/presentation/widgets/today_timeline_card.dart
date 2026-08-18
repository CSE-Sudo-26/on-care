import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/my/data/trainer_settings.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

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
    // 설정의 '수업 시작 전 알림' 이 이 강조를 켜고 끈다. 켜져 있으면 시작이
    // 알림 시점 안으로 들어온 세션을 눈에 띄게 그린다 — 설정 화면이 "대시보드에서
    // 강조해요" 라고 적어 두고 실제로는 아무 일도 하지 않았다(#817).
    final settings = ref.watch(trainerSettingsProvider);
    final clients =
        ref.watch(clientsProvider).valueOrNull ?? const <TrainerClient>[];

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
                  client: findClientIdentity(
                    clients,
                    clientId: session.clientId,
                    clientName: session.clientName,
                  ),
                  imminent:
                      settings.sessionReminders &&
                      startsWithin(session, settings.reminderLeadMinutes),
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
  const _Row({
    required this.session,
    required this.client,
    required this.imminent,
    required this.onTap,
  });

  final ScheduleSession session;
  final TrainerClient? client;

  /// 시작이 알림 시점 안으로 들어온 세션인가. (#817)
  final bool imminent;

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
      child: Container(
        decoration: imminent
            ? const BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: BorderRadius.all(AppRadius.sm),
              )
            : null,
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
                child: muted
                    ? Text(
                        l.dashEmptySlot,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.subtleForeground,
                        ),
                      )
                    : Text(
                        '${client == null ? session.clientName : clientIdentityLabel(context, client!)} · ${session.type}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
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
