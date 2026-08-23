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
import 'package:oncare_trainer/features/schedule/presentation/widgets/session_chips.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// Today's timeline, condensed for the dashboard: time, status dot, who +
/// what, and the status pill. 빈 시간(공백 슬롯)은 오늘의 예약이 무엇인지와
/// 무관해 아예 그리지 않는다 — 여기는 "오늘 할 일"이 아니라 "오늘 누굴
/// 보나" 목록이다.
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
        onTap: () => context.go(AppRoutes.scheduleAt()),
      ),
      child: schedule.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => EmptyHint(message: l.dashScheduleLoadFailed),
        data: (sessions) {
          final booked = sessions.where((s) => !s.isGap).toList();
          if (booked.isEmpty) {
            return EmptyHint(
              message: l.dashNoScheduleToday,
              icon: Icons.event_busy_outlined,
            );
          }
          return Column(
            children: <Widget>[
              for (final session in booked)
                _Row(
                  session: session,
                  client: findClientIdentity(
                    clients,
                    clientId: session.clientId,
                    clientName: session.clientName,
                  ),
                  // 로스터에 없는 고객(상담으로 잡힌 가망 고객)도 이름만
                  // 부른다 — 스케줄 탭과 같은 표기다(#1012).
                  fallbackName: session.clientName,
                  imminent:
                      settings.sessionReminders &&
                      startsWithin(session, settings.reminderLeadMinutes),
                  onTap: () => context.go(AppRoutes.scheduleAt()),
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
    required this.fallbackName,
    required this.imminent,
    required this.onTap,
  });

  final ScheduleSession session;
  final TrainerClient? client;

  /// 로스터에서 못 찾은 고객을 부를 이름.
  final String fallbackName;

  /// 시작이 알림 시점 안으로 들어온 세션인가. (#817)
  final bool imminent;

  final VoidCallback onTap;

  Color get _dotColor {
    if (session.isDone) return AppColors.success;
    if (session.isUpcoming) return AppColors.primary;
    return AppColors.disabledForeground;
  }

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Padding(
              padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dotColor,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  client == null
                      ? Text(
                          fallbackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        )
                      : ClientIdentity(
                          client: client!,
                          nameStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                  Text(
                    // 소요 시간은 안 보여준다 — 여기서 정할 것은 "누구인가"고
                    // "얼마나 걸리나"는 스케줄 탭에서 보면 된다.
                    session.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.subtleForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            SessionStatusChip(status: session.status),
          ],
        ),
      ),
    );
  }
}
