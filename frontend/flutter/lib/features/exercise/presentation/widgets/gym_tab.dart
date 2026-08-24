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
import 'package:oncare/features/exercise/presentation/pages/gym_list_page.dart';
import 'package:oncare/features/exercise/presentation/widgets/connected_gym_card.dart';
import 'package:oncare/features/exercise/presentation/widgets/gym_trainer_line.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/app_toast.dart';

class GymTab extends ConsumerWidget {
  const GymTab({required this.selectedSlot, required this.onSlot, super.key});

  final String? selectedSlot;
  final ValueChanged<String> onSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<Gym?> myGymAsync = ref.watch(myGymProvider);
    final MemberCoach? assignedCoach = ref
        .watch(memberCoachProvider)
        .valueOrNull;
    final List<ConsultationRequest> requests = ref.watch(
      consultationRequestControllerProvider,
    );
    ConsultationRequest? pendingRequest;
    for (final ConsultationRequest request in requests) {
      if (request.status == ConsultationStatus.pending) {
        pendingRequest = request;
        break;
      }
    }
    final bool showTrainerChat =
        assignedCoach != null && pendingRequest == null;
    final int unreadCoachMessages = showTrainerChat
        ? ref.watch(coachUnreadProvider).valueOrNull ?? 0
        : 0;

    // 연결된 헬스장이 없으면 이 탭에서 할 일은 헬스장을 찾는 것뿐이다 —
    // 지도만 든 빈 카드와 `헬스장 찾기` 버튼 대신 찾기 화면을 그대로 보여
    // 준다 (#1133). 추천 헬스장·추천 트레이너 섹션도 그 화면의 목록과 같은
    // 말을 하므로 함께 내린다. 트레이너와 채팅 버튼도 여기서는 없다 (#1132) —
    // 담당이 있으면 헤더의 채팅 버튼이 그 자리를 맡는다.
    //
    // 조회 중에는 찾기 화면을 미리 보여 주지 않는다. 잠깐 떴다 사라지면 연결이
    // 풀린 것처럼 읽힌다.
    if (myGymAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Align(
          alignment: Alignment.topCenter,
          child: _SectionLoading(height: 180),
        ),
      );
    }
    if (!myGymAsync.hasError && myGymAsync.valueOrNull == null) {
      // 상담 요청 내역은 검색창 옆 아이콘이 맡는다. 요청 직후 요약 카드를 여기
      // 끼우면 검색창이 아래로 밀려 화면 구조가 바뀐다(#1287).
      return const GymFinderView();
    }

    // 이 탭은 높이를 받아 놓인다 (#1274) — 연결된 헬스장 화면은 섹션이 여럿인
    // 긴 화면이라 제 스크롤을 갖는다. 찾기 화면은 스스로 시트를 굴리므로 이
    // 스크롤을 타지 않는다.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 이미 연결된 헬스장이 있어도 다른 헬스장을 둘러볼 수 있어야 한다 —
          // 마이페이지의 `헬스장 찾기`와 같은 목적지다(#1257).
          _SectionHeader(
            title: l.exMyGymSection,
            actionLabel: l.exFindGym,
            onAction: () => context.push(AppRoutes.gyms),
          ),
          const SizedBox(height: 10),
          _MyGymSection(
            gymAsync: myGymAsync,
            trainer: ref.watch(myTrainerProvider).valueOrNull,
            selectedSlot: selectedSlot,
            onSlot: onSlot,
            onRetry: () => ref.invalidate(myGymProvider),
            onTrainerChatTap: showTrainerChat
                ? () => openTrainerChatPage(
                    context,
                    trainerName: assignedCoach.name,
                  )
                : null,
            unreadCoachMessages: unreadCoachMessages,
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
    required this.onRetry,
    required this.onTrainerChatTap,
    required this.unreadCoachMessages,
  });

  final AsyncValue<Gym?> gymAsync;

  /// 담당 트레이너. 헬스장과 별개로 해제될 수 있어 null 이면 트레이너 행이 빠진다.
  final Trainer? trainer;
  final String? selectedSlot;
  final ValueChanged<String> onSlot;
  final VoidCallback onRetry;
  final VoidCallback? onTrainerChatTap;
  final int unreadCoachMessages;

  @override
  Widget build(BuildContext context) {
    return gymAsync.when(
      loading: () => const _SectionLoading(height: 180),
      error: (Object _, StackTrace _) => _SectionError(onRetry: onRetry),
      // 연결된 헬스장이 없는 경우는 이 위젯에 오지 않는다 — 탭이 찾기 화면을
      // 대신 그린다 (#1133). 그래도 방어적으로 빈 상태를 오류처럼 다루지 않고
      // 재시도 자리를 남긴다.
      data: (Gym? gym) => gym == null
          ? _SectionError(onRetry: onRetry)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ConnectedGymCard(
                  gym: gym,
                  trainer: trainer,
                  onGymTap: () => context.push(AppRoutes.gymDetailPath(gym.id)),
                  onTrainerDetail: trainer == null
                      ? null
                      : () => context.push(
                          AppRoutes.trainerDetailPath(trainer!.id),
                        ),
                  footer: onTrainerChatTap == null
                      ? null
                      : _TrainerChatButton(
                          unread: unreadCoachMessages,
                          onTap: onTrainerChatTap!,
                        ),
                ),
                if (trainer != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _ReservationPanel(
                    key: const Key('my-gym-reservation-panel'),
                    gym: gym,
                    trainer: trainer!,
                    selectedSlot: selectedSlot,
                    onSlot: onSlot,
                  ),
                ],
              ],
            ),
    );
  }
}

// TODO(#1313): remove after the shared card rollout is verified.
// ignore: unused_element
class _MyGymCard extends StatelessWidget {
  const _MyGymCard({
    required this.gym,
    required this.trainer,
    required this.onGymTap,
    required this.onTrainerChatTap,
    required this.unreadCoachMessages,
  });

  final Gym gym;
  final Trainer? trainer;
  final VoidCallback onGymTap;
  final VoidCallback? onTrainerChatTap;
  final int unreadCoachMessages;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);

    return Container(
      key: const Key('my-gym-info-card'),
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
          // 담당 트레이너가 누구인지 카드에서 한 줄로 읽힌다 (#1187). 예전에는
          // 예약 패널 문구에서 이름이 스쳐 지나갈 뿐이었다.
          if (trainer != null) ...<Widget>[
            const SizedBox(height: 12),
            GymTrainerLine(
              key: const Key('gym-trainer-line-mine'),
              trainer: trainer!,
              // 고를 이유가 아니라 이미 함께 하는 사람이다 — 추천 이유는 뺀다.
              showReason: false,
              onDetail: () =>
                  context.push(AppRoutes.trainerDetailPath(trainer!.id)),
            ),
          ],
          if (onTrainerChatTap != null) ...<Widget>[
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

/// 읽지 않음 배지의 지름. 원을 유지하려면 가로·세로가 같아야 한다 (#1138).
const double _kUnreadBadgeSize = 18;

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
        // 이 버튼만 카드 안 다른 문구보다 커서 혼자 떠 보였다 — 글자와
        // 아이콘을 한 단계씩 줄인다. (#1184)
        icon: const Icon(Icons.chat_bubble_outline, size: 14),
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
              // 한 자리 수는 **정원**이어야 한다 (#1138). 좌우 여백만 주면
              // 글자 높이만큼 세로로 길어져 알약처럼 보였다. 최소 지름을
              // 정해 두고 숫자는 그 안에서 줄인다 — `99+` 도 같은 원 안에
              // 들어간다.
              Container(
                width: _kUnreadBadgeSize,
                height: _kUnreadBadgeSize,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: FigmaColors.redDot,
                  shape: BoxShape.circle,
                ),
                // 원 안에 들어갈 만큼 글자를 줄인다. `99+` 처럼 긴 값도 원을
                // 늘리지 않는다 — 늘어난 원은 알약이 된다.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      unreadLabel,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: FigmaColors.primary,
          // 앱 서체를 **버리지 않는다** — 여기에 맨 `TextStyle` 을 주면
          // fontFamily 까지 덮어써 한글이 기본 서체로 떨어진다.
          textStyle: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontSize: 13),
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
    super.key,
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

  /// 24시간(HH:mm) 표기로 고정한다 — 로케일 기본(오전/오후 12시간제)을 쓰던
  /// `MaterialLocalizations.formatTimeOfDay` 대신이다. 빈 예약 시간을
  /// 트레이너 쪽 스케줄·모달과 같은 표기로 보여준다.
  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  /// "8월 8일 19:00" 형태. 고정 문자열이 아니라 실제 시각을 쓰므로 날이
  /// 바뀌어도 어긋나지 않는다.
  String _when(BuildContext context, AppLocalizations l, DateTime at) {
    final MaterialLocalizations m = MaterialLocalizations.of(context);
    return l.exSlotWhen(
      m.formatMediumDate(at),
      _hhmm(TimeOfDay.fromDateTime(at)),
    );
  }

  String _slotWhen(BuildContext context, TrainerSlot slot) {
    final MaterialLocalizations m = MaterialLocalizations.of(context);
    final DateTime end = slot.startsAt.add(
      Duration(minutes: slot.durationMinutes),
    );
    final String start = _hhmm(TimeOfDay.fromDateTime(slot.startsAt));
    final String finish = _hhmm(TimeOfDay.fromDateTime(end));
    return '${m.formatMediumDate(slot.startsAt)}\n$start–$finish';
  }

  Future<void> _reserve(AppLocalizations l, TrainerSlot slot) async {
    if (_reserving != null) return;
    final AppToastHost toast = AppToastHost.of(context);
    final String label = _when(context, l, slot.startsAt);
    setState(() => _reserving = slot.id);
    try {
      await ref.read(gymRepositoryProvider).reserve(slot.id);
    } catch (_) {
      if (mounted) setState(() => _reserving = null);
      toast.show(l.exReserveFailed, kind: AppToastKind.error);
      return;
    }
    if (!mounted) return;
    setState(() => _reserving = null);
    // 잔여 자리를 다시 읽어, 방금 잡은 자리가 목록에도 반영되게 한다.
    ref.invalidate(trainerSlotsProvider(widget.trainer.id));
    // 방금 잡은 예약이 '내 예약'에도 나타나야 취소가 걸린다. (#502)
    ref.invalidate(myReservationsProvider);
    toast.show(
      l.exReserveConfirmedSlotGym(label, widget.gym.name),
      kind: AppToastKind.success,
    );
  }

  /// 예약 취소. 확인을 받고, 성공하면 잔여 자리와 내 예약을 함께 다시 읽는다.
  ///
  /// 되돌릴 수 없는 동작이라 확인을 한 번 받는다 — 취소하면 그 자리는 곧바로
  /// 다른 회원이 잡을 수 있다. (#502)
  Future<void> _cancel(AppLocalizations l, MyReservation reservation) async {
    if (_reserving != null || _cancelling != null) return;
    final AppToastHost toast = AppToastHost.of(context);
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
      toast.show(l.exCancelFailed, kind: AppToastKind.error);
      return;
    }
    if (!mounted) return;
    setState(() => _cancelling = null);
    // 좌석이 돌아왔으므로 슬롯도 함께 다시 읽는다.
    ref.invalidate(trainerSlotsProvider(widget.trainer.id));
    ref.invalidate(myReservationsProvider);
    toast.show(l.exCancelDone(label), kind: AppToastKind.success);
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
    // 다가오는 예약이 이미 있으면 빈 자리를 더 고르게 하지 않는다 — 1:1 PT 라
    // 다음 일정은 하나면 충분하고, 자리를 옮기려면 먼저 취소하는 흐름이다(#1072).
    // 취소 가능 여부(`cancellable`)가 곧 '다음 일정' 판단이다.
    final bool hasUpcoming = mine.any((MyReservation r) => r.cancellable);
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
          if (mine.isNotEmpty) ...<Widget>[
            _MyReservations(
              reservations: mine,
              label: (DateTime at) => _when(context, l, at),
              cancelling: _cancelling,
              disabled: busy,
              onCancel: (MyReservation r) => _cancel(l, r),
            ),
            const SizedBox(height: 10),
          ],
          if (!hasUpcoming) ...<Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.event_available_outlined,
                  size: 14,
                  color: FigmaColors.primary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    l.exTrainerAvailability(widget.trainer.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
                    ),
                  ),
                ),
              ],
            ),
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
              data: (List<TrainerSlot> all) {
                // 이미 연결된 헬스장이라 상담은 지난 걸음이다 — 상담으로 열린
                // 자리는 여기서 보여 주지 않는다 (#1136). 남는 것은 1:1 PT 뿐.
                final List<TrainerSlot> slots = all
                    .where((TrainerSlot slot) => slot.sessionType != '상담')
                    .toList(growable: false);
                if (slots.isEmpty) {
                  return _SlotNotice(message: l.exSlotsEmpty);
                }
                final bool allBooked = slots.every(
                  (TrainerSlot slot) => slot.booked,
                );
                final TrainerSlot? picked = slots
                    .where(
                      (TrainerSlot slot) =>
                          slot.id == widget.selectedSlot && !slot.booked,
                    )
                    .firstOrNull;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (allBooked) ...<Widget>[
                      _SlotNotice(message: l.exSlotsAllBooked),
                      const SizedBox(height: 10),
                    ],
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            const double gap = 8;
                            final double itemWidth =
                                (constraints.maxWidth - gap) / 2;
                            return Wrap(
                              spacing: gap,
                              runSpacing: 8,
                              children: <Widget>[
                                for (final TrainerSlot slot in slots)
                                  SizedBox(
                                    width: itemWidth,
                                    child: _SlotChip(
                                      key: ValueKey<String>(
                                        'slot-chip-${slot.id}',
                                      ),
                                      // 종류를 시각 앞에 둔다. 내 헬스장에는 1:1 PT 자리만
                                      // 남으므로(#1136) 실제로는 늘 같은 값이다.
                                      type: l.exSlotTypePersonalTraining,
                                      label: _slotWhen(context, slot),
                                      selected: picked?.id == slot.id,
                                      // 마감된 자리는 고를 수 없고, 예약이 오가는 중에는
                                      // 선택도 잠근다.
                                      onTap: slot.booked || busy
                                          ? null
                                          : () => widget.onSlot(slot.id),
                                    ),
                                  ),
                              ],
                            );
                          },
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

// 추천 목록은 미연결 상태의 GymFinderView가 전담한다. 연결 화면에서 다시
// 노출하지 않되, 카드 구현은 별도 목록 화면 재사용을 위해 남겨 둔다.
// ignore: unused_element
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

// ignore: unused_element
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
    required this.type,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// `1:1 PT` 또는 `상담` — 이 자리가 무엇인지. 트레이너 스케줄 탭의 종류
  /// 알약과 같은 값이라, 상담으로 연 자리도 그대로 알아볼 수 있다(#1083).
  final String type;

  final String label;

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
                type,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : (disabled
                            ? FigmaColors.textFaint
                            : FigmaColors.primary),
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (disabled ? FigmaColors.textFaint : FigmaColors.ink),
                ),
              ),
            ],
          ),
        ),
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
