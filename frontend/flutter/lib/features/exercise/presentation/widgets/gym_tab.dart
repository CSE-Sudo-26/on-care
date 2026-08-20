import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/my_reservation.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/domain/entities/trainer_slot.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

class GymTab extends ConsumerWidget {
  const GymTab({
    required this.selectedSlot,
    required this.onSlot,
    required this.onFind,
    super.key,
  });

  final String? selectedSlot;
  final ValueChanged<String> onSlot;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<Gym?> myGymAsync = ref.watch(myGymProvider);
    // 트레이너 소속 헬스장 이름은 제휴 + 카카오를 모두 아는 목록에서 찾아야 한다.
    // 제휴 목록만 보면 카카오 헬스장 소속 트레이너의 헬스장 이름이 빈칸이 된다(#329).
    final AsyncValue<List<Gym>> knownGymsAsync = ref.watch(
      gymFinderResultsProvider,
    );
    final MemberCoach? assignedCoach = ref
        .watch(memberCoachProvider)
        .valueOrNull;
    final List<ConsultationRequest> requests = ref.watch(
      consultationRequestControllerProvider,
    );
    final ConsultationRequest? recentRequest = requests.isEmpty
        ? null
        : requests.first;
    ConsultationRequest? pendingRequest;
    for (final ConsultationRequest request in requests) {
      if (request.status == ConsultationStatus.pending) {
        pendingRequest = request;
        break;
      }
    }
    final ConsultationRequest? displayedRequest =
        pendingRequest ?? recentRequest;
    final bool showTrainerChat =
        assignedCoach != null && pendingRequest == null;
    final int unreadCoachMessages = showTrainerChat
        ? ref.watch(coachUnreadProvider).valueOrNull ?? 0
        : 0;
    final GlobalKey recentConsultationKey = GlobalKey();

    void showRecentConsultation() {
      final BuildContext? targetContext = recentConsultationKey.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(title: l.exMyGymSection),
          const SizedBox(height: 10),
          _MyGymSection(
            gymAsync: myGymAsync,
            trainer: ref.watch(myTrainerProvider).valueOrNull,
            selectedSlot: selectedSlot,
            onSlot: onSlot,
            onFind: onFind,
            onRetry: () => ref.invalidate(myGymProvider),
            onPendingConsultationTap: pendingRequest == null
                ? null
                : showRecentConsultation,
            onTrainerChatTap: showTrainerChat
                ? () => openTrainerChatPage(
                    context,
                    trainerName: assignedCoach.name,
                  )
                : null,
            unreadCoachMessages: unreadCoachMessages,
          ),
          if (displayedRequest != null) ...<Widget>[
            const SizedBox(height: 28),
            _RecentConsultationSection(
              key: recentConsultationKey,
              request: displayedRequest,
            ),
          ],
          const SizedBox(height: 28),
          _RecommendedGymSection(
            // 이미 연결된 헬스장은 빠진 목록이다(#864) — 내 헬스장 카드는 위에
            // 그대로 있으므로 정보가 사라지지 않는다.
            gymsAsync: ref.watch(recommendedGymsProvider),
            onMore: () => context.push(AppRoutes.gyms),
            onRetry: () => ref.invalidate(nearbyGymsProvider),
          ),
          const SizedBox(height: 28),
          _RecommendedTrainerSection(
            trainersAsync: ref.watch(recommendedTrainersProvider),
            gymNames: <String, String>{
              for (final Gym gym in knownGymsAsync.valueOrNull ?? const <Gym>[])
                gym.id: gym.name,
            },
            onMore: () => context.push(AppRoutes.trainers),
            onRetry: () => ref.invalidate(recommendedTrainersProvider),
          ),
        ],
      ),
    );
  }
}

class _RecentConsultationSection extends StatelessWidget {
  const _RecentConsultationSection({required this.request, super.key});

  final ConsultationRequest request;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String targetName = request.trainerName ?? '';
    final String targetType = l.exTrainerConsultType;
    final String status = switch (request.status) {
      ConsultationStatus.pending => l.exConsultPendingStatus,
      ConsultationStatus.accepted => l.exConsultAcceptedStatus,
      ConsultationStatus.rejected => l.exConsultRejectedStatus,
    };
    final String date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(request.preferredDate);
    final Widget? outcome = _outcomeNote(context, l);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(title: l.exConsultStatusSection),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: FigmaColors.primaryA(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_outline,
                  size: 21,
                  color: FigmaColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            targetName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: FigmaColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: FigmaColors.primaryA(0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // 서버가 트레이너 대상 요청에 헬스장 이름을 주지 않아, 예전에는
                      // 앱을 다시 열면 "트레이너 상담 · " 로 뒤가 비어 보였다.
                      targetType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '$date · ${request.preferredTimeSlot}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    if (outcome != null) ...<Widget>[
                      const SizedBox(height: 10),
                      outcome,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 처리된 요청에 붙는 결과 안내. 대기 중이면 null. (#473)
  ///
  /// 거절은 사유가 본체다 — "거절됨" 배지만 보면 다시 신청해도 되는지, 다른
  /// 트레이너를 찾아야 하는지 판단할 근거가 없다. 트레이너가 사유를 적지 않았을
  /// 수도 있으므로 그때는 다음 행동을 안내한다.
  Widget? _outcomeNote(BuildContext context, AppLocalizations l) {
    switch (request.status) {
      case ConsultationStatus.pending:
        return null;
      case ConsultationStatus.accepted:
        return _OutcomeNote(
          key: const Key('consult-outcome-accepted'),
          tone: FigmaColors.primary,
          text: l.exConsultAcceptedGuide,
        );
      case ConsultationStatus.rejected:
        final String? note = request.decisionNote;
        return _OutcomeNote(
          key: const Key('consult-outcome-rejected'),
          tone: FigmaColors.textMuted,
          label: note == null ? null : l.exConsultRejectedReasonLabel,
          text: note ?? l.exConsultRejectedNoReason,
        );
    }
  }
}

/// 상태 카드 하단의 결과 안내 한 덩어리 — 승인 안내 또는 거절 사유.
class _OutcomeNote extends StatelessWidget {
  const _OutcomeNote({
    required this.tone,
    required this.text,
    this.label,
    super.key,
  });

  final Color tone;
  final String? label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (label != null) ...<Widget>[
            Text(
              label!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: FigmaColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyGymSection extends StatelessWidget {
  const _MyGymSection({
    required this.gymAsync,
    required this.trainer,
    required this.selectedSlot,
    required this.onSlot,
    required this.onFind,
    required this.onRetry,
    required this.onPendingConsultationTap,
    required this.onTrainerChatTap,
    required this.unreadCoachMessages,
  });

  final AsyncValue<Gym?> gymAsync;

  /// 담당 트레이너. 헬스장과 별개로 해제될 수 있어 null 이면 트레이너 행이 빠진다.
  final Trainer? trainer;
  final String? selectedSlot;
  final ValueChanged<String> onSlot;
  final VoidCallback onFind;
  final VoidCallback onRetry;
  final VoidCallback? onPendingConsultationTap;
  final VoidCallback? onTrainerChatTap;
  final int unreadCoachMessages;

  @override
  Widget build(BuildContext context) {
    return gymAsync.when(
      loading: () => const _SectionLoading(height: 180),
      error: (Object _, StackTrace _) => _SectionError(onRetry: onRetry),
      data: (Gym? gym) => gym == null
          ? Column(
              children: <Widget>[
                _EmptyMyGym(onFind: onFind),
                if (onPendingConsultationTap != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _PendingConsultationButton(onTap: onPendingConsultationTap!),
                ] else if (onTrainerChatTap != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _TrainerChatButton(
                    unread: unreadCoachMessages,
                    onTap: onTrainerChatTap!,
                  ),
                ],
              ],
            )
          : _MyGymCard(
              gym: gym,
              trainer: trainer,
              selectedSlot: selectedSlot,
              onSlot: onSlot,
              onGymTap: () => context.push(AppRoutes.gymDetailPath(gym.id)),
              onPendingConsultationTap: onPendingConsultationTap,
              onTrainerChatTap: onTrainerChatTap,
              unreadCoachMessages: unreadCoachMessages,
            ),
    );
  }
}

class _MyGymCard extends StatelessWidget {
  const _MyGymCard({
    required this.gym,
    required this.trainer,
    required this.selectedSlot,
    required this.onSlot,
    required this.onGymTap,
    required this.onPendingConsultationTap,
    required this.onTrainerChatTap,
    required this.unreadCoachMessages,
  });

  final Gym gym;
  final Trainer? trainer;
  final String? selectedSlot;
  final ValueChanged<String> onSlot;
  final VoidCallback onGymTap;
  final VoidCallback? onPendingConsultationTap;
  final VoidCallback? onTrainerChatTap;
  final int unreadCoachMessages;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: FigmaColors.primaryA(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle,
                    size: 13,
                    color: FigmaColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l.exConnected,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onGymTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            gym.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: FigmaColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${gym.address} · ${gym.distanceKm.toStringAsFixed(1)}km',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: FigmaColors.textFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 담당 트레이너가 없으면 예약 패널을 숨긴다. 없는 사람의 빈 시간을
          // 고르고 예약 완료 메시지까지 보게 되는 상태를 막는다.
          if (trainer != null) ...<Widget>[
            const SizedBox(height: 16),
            _ReservationPanel(
              gym: gym,
              trainer: trainer!,
              selectedSlot: selectedSlot,
              onSlot: onSlot,
            ),
          ],
          if (onPendingConsultationTap != null) ...<Widget>[
            const SizedBox(height: 14),
            _PendingConsultationButton(onTap: onPendingConsultationTap!),
          ] else if (onTrainerChatTap != null) ...<Widget>[
            const SizedBox(height: 14),
            _TrainerChatButton(
              unread: unreadCoachMessages,
              onTap: onTrainerChatTap!,
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingConsultationButton extends StatelessWidget {
  const _PendingConsultationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: FigmaColors.primary,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          l.exViewConsultationRequest,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TrainerChatButton extends StatelessWidget {
  const _TrainerChatButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String unreadLabel = unread > 99 ? '99+' : '$unread';

    final AppLocalizations l = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('gymTrainerChatButton'),
        onPressed: onTap,
        icon: const Icon(Icons.chat_bubble_outline, size: 16),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 배지가 붙으면 라벨과 함께 버튼 폭을 넘는다 — 글씨를 키운 뒤로는
            // 배지가 없어도 빠듯하다. 문구 쪽이 줄어든다. (#995)
            Flexible(
              // 줄임표가 되면 무슨 버튼인지 사라진다 — 좁으면 글씨를 줄인다.
              // (#1004)
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(l.coachChatWithTrainer, maxLines: 1),
              ),
            ),
            if (unread > 0) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: const BoxDecoration(
                  color: FigmaColors.redDot,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  unreadLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: FigmaColors.primary,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: FigmaColors.primaryA(0.25)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// 담당 트레이너의 실제 예약 가능 시간.
///
/// 슬롯은 트레이너에 귀속되므로 여기서 [trainerSlotsProvider] 를 직접 읽는다.
/// 마감된 자리도 숨기지 않고 비활성으로 남겨, 그 트레이너의 하루가 "비어 있음"
/// 이 아니라 "찼음" 으로 읽히게 한다.
class _ReservationPanel extends ConsumerStatefulWidget {
  const _ReservationPanel({
    required this.gym,
    required this.trainer,
    required this.selectedSlot,
    required this.onSlot,
  });

  final Gym gym;
  final Trainer trainer;

  /// 선택된 슬롯 id. 부모(운동 탭)가 들고 있다.
  final String? selectedSlot;
  final ValueChanged<String> onSlot;

  @override
  ConsumerState<_ReservationPanel> createState() => _ReservationPanelState();
}

class _ReservationPanelState extends ConsumerState<_ReservationPanel> {
  /// 요청이 오가는 동안 잡고 있는 슬롯 id. 예약은 멱등이 아니라서, 확정 버튼을
  /// 두 번 누르면 좌석이 두 번 빠진다 — 그래서 진행 중에는 버튼을 잠근다.
  String? _reserving;

  /// 취소 요청이 오가는 동안 잡고 있는 예약 id. 예약과 같은 이유로 잠근다.
  String? _cancelling;

  /// 로케일에 맞는 "8월 8일 오후 7:00" 형태. 고정 문자열이 아니라 실제 시각을
  /// 쓰므로 날이 바뀌어도 어긋나지 않는다.
  String _when(BuildContext context, AppLocalizations l, DateTime at) {
    final MaterialLocalizations m = MaterialLocalizations.of(context);
    return l.exSlotWhen(
      m.formatMediumDate(at),
      m.formatTimeOfDay(TimeOfDay.fromDateTime(at)),
    );
  }

  Future<void> _reserve(AppLocalizations l, TrainerSlot slot) async {
    if (_reserving != null) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String label = _when(context, l, slot.startsAt);
    setState(() => _reserving = slot.id);
    try {
      await ref.read(gymRepositoryProvider).reserve(slot.id);
    } catch (_) {
      if (mounted) setState(() => _reserving = null);
      messenger.showSnackBar(SnackBar(content: Text(l.exReserveFailed)));
      return;
    }
    if (!mounted) return;
    setState(() => _reserving = null);
    // 잔여 자리를 다시 읽어, 방금 잡은 자리가 목록에도 반영되게 한다.
    ref.invalidate(trainerSlotsProvider(widget.trainer.id));
    // 방금 잡은 예약이 '내 예약'에도 나타나야 취소가 걸린다. (#502)
    ref.invalidate(myReservationsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.exReserveConfirmedSlotGym(label, widget.gym.name)),
      ),
    );
  }

  /// 예약 취소. 확인을 받고, 성공하면 잔여 자리와 내 예약을 함께 다시 읽는다.
  ///
  /// 되돌릴 수 없는 동작이라 확인을 한 번 받는다 — 취소하면 그 자리는 곧바로
  /// 다른 회원이 잡을 수 있다. (#502)
  Future<void> _cancel(AppLocalizations l, MyReservation reservation) async {
    if (_reserving != null || _cancelling != null) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String label = _when(context, l, reservation.startsAt);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l.exCancelConfirmTitle),
        content: Text(l.exCancelConfirmBody(label)),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('cancel-dialog-keep'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.exCancelKeep),
          ),
          TextButton(
            key: const ValueKey<String>('cancel-dialog-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.exCancelReservation),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancelling = reservation.id);
    try {
      await ref.read(gymRepositoryProvider).cancelReservation(reservation.id);
    } catch (_) {
      if (mounted) setState(() => _cancelling = null);
      messenger.showSnackBar(SnackBar(content: Text(l.exCancelFailed)));
      return;
    }
    if (!mounted) return;
    setState(() => _cancelling = null);
    // 좌석이 돌아왔으므로 슬롯도 함께 다시 읽는다.
    ref.invalidate(trainerSlotsProvider(widget.trainer.id));
    ref.invalidate(myReservationsProvider);
    messenger.showSnackBar(SnackBar(content: Text(l.exCancelDone(label))));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<List<TrainerSlot>> slotsAsync = ref.watch(
      trainerSlotsProvider(widget.trainer.id),
    );
    // 이 트레이너에 대한 내 예약만 추린다 — 패널이 한 트레이너의 자리를 다룬다.
    final List<MyReservation> mine =
        (ref.watch(myReservationsProvider).valueOrNull ??
                const <MyReservation>[])
            .where((MyReservation r) => r.trainerId == widget.trainer.id)
            .toList()
          // 서버는 늦은 예약부터 준다(#980) — 쪽을 나누려면 그 순서여야 한다. 화면은
          // 다르다: **곧 다가오는 자리가 맨 위**여야 하고, 지난 예약은 최근 것부터
          // 아래에 남는다. 취소 가능 여부(`cancellable`)가 곧 예정/지난 판단이다.
          ..sort((MyReservation a, MyReservation b) {
            if (a.cancellable != b.cancellable) return a.cancellable ? -1 : 1;
            return a.cancellable
                ? a.startsAt.compareTo(b.startsAt)
                : b.startsAt.compareTo(a.startsAt);
          });
    final bool busy = _reserving != null || _cancelling != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[FigmaColors.bannerStart, FigmaColors.bannerEnd],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.primaryA(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.exAiSlotTitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.exTrainerAvailability(widget.trainer.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
          if (mine.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _MyReservations(
              reservations: mine,
              label: (DateTime at) => _when(context, l, at),
              cancelling: _cancelling,
              disabled: busy,
              onCancel: (MyReservation r) => _cancel(l, r),
            ),
          ],
          const SizedBox(height: 10),
          slotsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
            error: (Object _, StackTrace _) => _SlotNotice(
              message: l.exSlotsLoadError,
              onRetry: () =>
                  ref.invalidate(trainerSlotsProvider(widget.trainer.id)),
            ),
            data: (List<TrainerSlot> slots) {
              if (slots.isEmpty) {
                return _SlotNotice(message: l.exSlotsEmpty);
              }
              final bool allBooked = slots.every(
                (TrainerSlot slot) => slot.isFull,
              );
              final TrainerSlot? picked = slots
                  .where(
                    (TrainerSlot slot) =>
                        slot.id == widget.selectedSlot && !slot.isFull,
                  )
                  .firstOrNull;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (allBooked) ...<Widget>[
                    _SlotNotice(message: l.exSlotsAllBooked),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final TrainerSlot slot in slots)
                        _SlotChip(
                          key: ValueKey<String>('slot-chip-${slot.id}'),
                          label: _when(context, l, slot.startsAt),
                          sub: slot.isFull
                              ? l.exSlotFull
                              : l.exSlotRemaining(slot.remaining),
                          selected: picked?.id == slot.id,
                          // 마감된 자리는 고를 수 없고, 예약이 오가는 중에는
                          // 선택도 잠근다.
                          onTap: slot.isFull || busy
                              ? null
                              : () => widget.onSlot(slot.id),
                        ),
                    ],
                  ),
                  if (picked != null) ...<Widget>[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey<String>('reserve-confirm'),
                        onPressed: busy ? null : () => _reserve(l, picked),
                        style: FilledButton.styleFrom(
                          backgroundColor: FigmaColors.primary,
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l.exReserveConfirm(
                            _when(context, l, picked.startsAt),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 슬롯이 없거나 전부 찼거나 조회에 실패했을 때의 한 줄 안내.
class _SlotNotice extends StatelessWidget {
  const _SlotNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        const Icon(
          Icons.event_busy_outlined,
          size: 14,
          color: FigmaColors.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: FigmaColors.primary,
              minimumSize: const Size(48, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              l.actionRetry,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _RecommendedGymSection extends StatelessWidget {
  const _RecommendedGymSection({
    required this.gymsAsync,
    required this.onMore,
    required this.onRetry,
  });

  final AsyncValue<List<Gym>> gymsAsync;
  final VoidCallback onMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          title: l.exRecommendedGyms,
          actionLabel: l.exSeeMore,
          onAction: onMore,
        ),
        const SizedBox(height: 10),
        gymsAsync.when(
          loading: () => const _SectionLoading(height: 156),
          error: (Object _, StackTrace _) => _SectionError(onRetry: onRetry),
          data: (List<Gym> gyms) => gyms.isEmpty
              ? _EmptyRecommendation(message: l.exNoRecommendedGyms)
              : SizedBox(
                  height: 156,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: gyms.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (BuildContext context, int index) {
                      return _GymRecommendationCard(
                        gym: gyms[index],
                        onTap: () => context.push(
                          AppRoutes.gymDetailPath(gyms[index].id),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _GymRecommendationCard extends StatelessWidget {
  const _GymRecommendationCard({required this.gym, required this.onTap});

  final Gym gym;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _RecommendationSurface(
      width: 236,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            gym.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: FigmaColors.textMuted,
              ),
              const SizedBox(width: 3),
              Text(
                '${gym.distanceKm.toStringAsFixed(1)}km',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.star_rounded,
                size: 15,
                color: FigmaColors.orange,
              ),
              const SizedBox(width: 2),
              Text(
                gym.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String tag in gym.tags.take(2)) _TagChip(label: tag),
            ],
          ),
          const SizedBox(height: 12),
          if (gym.weekdayHours != null)
            Row(
              children: <Widget>[
                const Icon(
                  Icons.schedule_outlined,
                  size: 13,
                  color: FigmaColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l.exGymWeekdayHours(gym.weekdayHours!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecommendedTrainerSection extends StatelessWidget {
  const _RecommendedTrainerSection({
    required this.trainersAsync,
    required this.gymNames,
    required this.onMore,
    required this.onRetry,
  });

  final AsyncValue<List<Trainer>> trainersAsync;

  /// 소속 헬스장 이름만 붙이면 되므로, 헬스장 목록이 늦어도 카드는 그려진다.
  final Map<String, String> gymNames;
  final VoidCallback onMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          title: l.exRecommendedTrainers,
          actionLabel: l.exSeeMore,
          onAction: onMore,
        ),
        const SizedBox(height: 10),
        trainersAsync.when(
          loading: () => const _SectionLoading(height: 120),
          error: (Object _, StackTrace _) => _SectionError(onRetry: onRetry),
          data: (List<Trainer> trainers) {
            if (trainers.isEmpty) {
              return _EmptyRecommendation(message: l.exNoRecommendedTrainers);
            }
            return SizedBox(
              height: 120,
              child: ListView.separated(
                // 목록이 가로로 길고 지연 생성이라, 뒤쪽 카드는 화면에 들어오기
                // 전까지 **존재하지 않는다**. E2E 가 이 목록을 잡고 스크롤할 수
                // 있어야 뒤쪽 트레이너에게도 상담을 신청할 수 있다. (#640)
                key: const Key('trainer-recommendation-list'),
                scrollDirection: Axis.horizontal,
                itemCount: trainers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int index) {
                  final Trainer trainer = trainers[index];
                  return _TrainerRecommendationCard(
                    key: ValueKey<String>('trainer-card-${trainer.id}'),
                    trainer: trainer,
                    gymName: gymNames[trainer.gymId] ?? '',
                    onTap: () =>
                        context.push(AppRoutes.trainerDetailPath(trainer.id)),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrainerRecommendationCard extends StatelessWidget {
  const _TrainerRecommendationCard({
    required this.trainer,
    required this.gymName,
    required this.onTap,
    super.key,
  });

  final Trainer trainer;
  final String gymName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _RecommendationSurface(
      width: 252,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: FigmaColors.iconTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_outline,
              size: 21,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  trainer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                // '전담 트레이너'가 있던 자리·스타일에 소속 헬스장을 표기.
                Text(
                  gymName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  trainer.reason ?? l.exTrainerRecommendationReason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.primary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationSurface extends StatelessWidget {
  const _RecommendationSurface({
    required this.width,
    required this.onTap,
    required this.child,
  });

  final double width;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: FigmaColors.hairline),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: FigmaColors.primary,
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: FigmaColors.primaryA(0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: FigmaColors.primary,
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    super.key,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;

  /// null 이면 마감된 자리다 — 눌리지 않고 흐리게 그려진다.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return Material(
      color: selected
          ? FigmaColors.primary
          : (disabled ? FigmaColors.softBlue : Colors.white),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? null
                : Border.all(color: FigmaColors.primaryA(0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (disabled ? FigmaColors.textFaint : FigmaColors.ink),
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : (disabled
                            ? FigmaColors.textFaint
                            : AppColors.mutedForeground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMyGym extends StatelessWidget {
  const _EmptyMyGym({required this.onFind});

  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: _cardDecoration(),
      child: Column(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: FigmaColors.primaryA(0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.fitness_center,
              size: 23,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.exNoConnectedGym,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onFind,
            style: FilledButton.styleFrom(
              backgroundColor: FigmaColors.primary,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.search, size: 17),
            label: Text(
              l.exFindGym,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: _cardDecoration(),
      child: Column(
        children: <Widget>[
          Text(
            l.exGymsLoadError,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.primary,
              side: BorderSide(color: FigmaColors.primaryA(0.35)),
              minimumSize: const Size(48, 44),
            ),
            child: Text(l.actionRetry),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecommendation extends StatelessWidget {
  const _EmptyRecommendation({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: _cardDecoration(),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: FigmaColors.hairline),
    boxShadow: kCardShadow,
  );
}

/// 이 트레이너에 대한 **내 예약** 목록과 취소 버튼. (#502)
///
/// 예약 패널 안에 두는 이유: 자리를 잡은 곳과 무르는 곳이 같아야 회원이 찾는다.
/// 별도 '예약 내역' 화면을 만들면 한 번 보고 다시 안 여는 자리가 하나 더 생긴다.
class _MyReservations extends StatelessWidget {
  const _MyReservations({
    required this.reservations,
    required this.label,
    required this.cancelling,
    required this.disabled,
    required this.onCancel,
  });

  final List<MyReservation> reservations;
  final String Function(DateTime) label;

  /// 취소 요청이 오가는 예약 id(있다면).
  final String? cancelling;
  final bool disabled;
  final ValueChanged<MyReservation> onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FigmaColors.primaryA(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.exMyReservations,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: FigmaColors.primary,
            ),
          ),
          for (final MyReservation r in reservations) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label(r.startsAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                // 취소 가능 여부는 서버 판단(`cancellable`)을 따른다. 지난 예약은
                // 버튼 대신 그 사실을 적어 둔다 — 눌러도 실패할 버튼을 남기면
                // 회원은 앱이 고장 난 것으로 읽는다.
                if (!r.cancellable)
                  Text(
                    l.exReservationPast,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  )
                else if (cancelling == r.id)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    key: ValueKey<String>('cancel-reservation-${r.id}'),
                    onPressed: disabled ? null : () => onCancel(r),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      l.exCancelReservation,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
