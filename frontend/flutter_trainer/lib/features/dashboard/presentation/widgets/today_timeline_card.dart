import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
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

/// 상담은 "메모 남기기"로, 그 외(1:1 PT 등)는 "PT 준비하기"로 갈린다 —
/// 상담엔 준비할 프로그램이 없고, PT엔 남길 상담 메모가 없다.
bool _isConsultation(String type) => type.contains('상담');

/// `HH:mm`.
String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Today's timeline, condensed for the dashboard: a "지금 · 다음 수업" 배너
/// 위에, 시간·상태 점·누구+무엇·상태 알약이 이어진다. 빈 시간(공백 슬롯)은
/// 오늘의 예약이 무엇인지와 무관해 아예 그리지 않는다 — 여기는 "오늘 할
/// 일"이 아니라 "오늘 누굴 보나" 목록이다.
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
          final next = booked.where((s) => s.isUpcoming).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (next.isNotEmpty) ...<Widget>[
                _NextUpBanner(
                  now: nowKst(),
                  next: next.first,
                  client: findClientIdentity(
                    clients,
                    clientId: next.first.clientId,
                    clientName: next.first.clientName,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              for (final session in booked)
                _Row(
                  key: ValueKey<String>('dashboard-schedule-${session.id}'),
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
                  onTap: () => context.go(
                    AppRoutes.scheduleAt(
                      date: session.date,
                      sessionId: session.id,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "지금 16:03  다음 수업 17:00 · 신규 고객  56분 뒤" — 오늘의 다음 일정이
/// 무엇이고 얼마나 남았는지, 그리고 그 일정에 맞는 행동(수업 준비/메모)을
/// 목록을 훑지 않고도 알 수 있게 한 줄로 요약한다.
class _NextUpBanner extends StatelessWidget {
  const _NextUpBanner({required this.now, required this.next, this.client});

  final DateTime now;
  final ScheduleSession next;
  final TrainerClient? client;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = client?.name ?? next.clientName;
    final nextMinutes = clockMinutes(next.time);
    final minutesLeft = nextMinutes == null
        ? 0
        : (nextMinutes - (now.hour * 60 + now.minute)).clamp(0, 24 * 60);
    final isConsultation = _isConsultation(next.type);
    final clientId = client?.id;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.schedule, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedForeground,
                ),
                children: <InlineSpan>[
                  TextSpan(text: l.dashScheduleNowLabel(_hm(now))),
                  const TextSpan(text: '   '),
                  TextSpan(
                    text: l.dashScheduleNextSession(next.time, name),
                    style: const TextStyle(color: AppColors.foreground),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: l.dashScheduleMinutesLeft(minutesLeft),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            key: const ValueKey<String>('dashboard-next-session-cta'),
            onPressed: () => context.go(
              isConsultation || clientId == null
                  ? AppRoutes.scheduleAt(date: next.date)
                  : AppRoutes.coachingFor(clientId),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 12,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(AppRadius.pill),
              ),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(
              isConsultation || clientId == null
                  ? l.dashLeaveMemo
                  : l.dashPreparePt,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
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
    final l = AppLocalizations.of(context);
    final isConsultation = _isConsultation(session.type);
    // 완료된 세션은 시간도 함께 물러난다 — 종류 알약이 완료 때 회색으로
    // 바래는 것과 같은 기준이다. 아직 끝나지 않은 시간은 "지금 처리해야
    // 할 일"이라 검은 글씨로 또렷하게 남는다.
    final timeColor = session.isDone
        ? AppColors.subtleForeground
        : AppColors.foreground;
    // "준비"는 아직 끝나지 않은 수업이 프로그램을 미리 짜 뒀는가이고,
    // "전송"(PT)/"작성"(상담)은 끝난 뒤 실제로 회원에게 나간 결과다 — 같은
    // 세션이 두 라벨을 동시에 달 일은 없다. 되지 않은 쪽도 회색으로나마
    // 항상 보여준다 — 라벨이 아예 없으면 "아직 안 했다"와 "이 세션엔 해당
    // 없다"를 구분할 수 없다. 상담이 끝나기 전만 예외(아직 남길 메모
    // 자체가 없다).
    String? statusTagLabel;
    Color statusTagColor = AppColors.primary;
    if (isConsultation) {
      if (session.isDone) {
        final written = session.note.trim().isNotEmpty;
        statusTagLabel = written
            ? l.dashSessionNoteWritten
            : l.dashSessionNoteNotWritten;
        statusTagColor = written
            ? AppColors.brandOrange
            : AppColors.disabledForeground;
      }
    } else if (session.isDone) {
      statusTagLabel = session.programSent
          ? l.dashSessionSent
          : l.dashSessionSentNo;
      statusTagColor = session.programSent
          ? AppColors.success
          : AppColors.disabledForeground;
    } else {
      final prepared = session.program.isNotEmpty;
      statusTagLabel = prepared
          ? l.dashSessionPrepared
          : l.dashSessionPreparedNo;
      statusTagColor = prepared
          ? AppColors.primary
          : AppColors.disabledForeground;
    }

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
        // 오른쪽 칸(완료/예정 + 상태 알약)이 둘로 쌓이면 왼쪽보다 키가 커진다
        // — Row 기본값인 가운데 정렬이라 시간·점도 그 가운데로 맞춰진다.
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 42,
              child: Text(
                session.time,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: timeColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
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
              child: Row(
                children: <Widget>[
                  Flexible(
                    flex: 3,
                    child: client == null
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
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // `Flexible`(고정폭이 아니라)로 감싸야 이 알약도 좁을 때
                  // 실제로 축소 대상이 된다 — 그래야 안의 `FittedBox` 가
                  // 줄어들 상한을 받는다.
                  Flexible(
                    child: _TypeBadge(
                      label: session.type,
                      muted: session.isDone,
                      outlined: isConsultation,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            // 완료/예정 알약과 나란히, 세로로는 이 줄 전체 기준 가운데 —
            // 아래에 쌓지 않아야 왼쪽 시간·점과 같은 높이로 읽힌다.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (statusTagLabel != null) ...<Widget>[
                  _StatusTag(label: statusTagLabel, color: statusTagColor),
                  const SizedBox(width: 6),
                ],
                SessionStatusChip(status: session.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "1:1 PT"/"상담" — 원으로 감싼 알약. 이름 줄의 나이 옆에 붙어, 상세
/// 카드의 알약(`SessionTypeChip`)보다 한 단계 더 크게 그린다.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.label,
    required this.muted,
    this.outlined = false,
  });

  final String label;
  final bool muted;

  /// 채우지 않고 윤곽선만 두른다(상담) — 스케줄 탭의 `SessionTypeChip` 과
  /// 같은 어휘다: 상담은 원래 파란 배경이 없다.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    // 이름이 길어 좁아지면 이 알약이 먼저 줄어든다 — `SessionTypeChip` 과
    // 같은 안전장치다. `Flexible` 하나로는 알약 자신의 최소 폭까지만
    // 줄어드는데, 좁은 화면에서는 그마저도 넘친다.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: muted
              ? AppColors.inputBackground
              : (outlined
                    ? AppColors.card
                    : AppColors.primary.withValues(alpha: 0.10)),
          borderRadius: const BorderRadius.all(AppRadius.pill),
          border: Border.all(
            color: muted
                ? AppColors.border
                : AppColors.primary.withValues(alpha: outlined ? 0.45 : 0.25),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: muted ? AppColors.disabledForeground : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// "전송됨"/"준비됨" — 완료 상태와 별개로, 회원에게 프로그램이 실제로
/// 나갔는지를 말한다. `session.programSent` 가 없으면 짠 프로그램만 있다는
/// 뜻이라 "준비됨"으로, 있으면 "전송됨"으로 갈린다.
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
