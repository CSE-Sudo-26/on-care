import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/design_system/tokens/toast.dart';
import 'package:oncare_trainer/features/consultations/data/dtos/consultation_dtos.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/app_toast.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 승인이 만드는 세션의 소요 시간(분). 백엔드 기본값과 같다.
const int _defaultConsultationDurationMinutes = 30;

/// `HH:mm` 에 [minutes] 를 더한다. 자정을 넘기면 다음 날로 넘어가지 않고
/// 24시간 안에서만 돈다 — 희망 시각 표시용이라 날짜가 바뀌는 값까지 다룰
/// 필요는 없다.
String _addMinutes(String hhmm, int minutes) {
  final parts = hhmm.split(':');
  final total = int.parse(parts[0]) * 60 + int.parse(parts[1]) + minutes;
  final hour = (total ~/ 60) % 24;
  final minute = total % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

/// 희망 시각 문구 — 정확한 시각(`HH:mm`)이면 기본 상담 소요 시간을 더해
/// 시작–종료로 보여준다. 회원이 이미 범위를 준 코드(`HH:mm-HH:mm`)나
/// `flexible`/레거시 값은 [preferredTimeLabel] 그대로 둔다.
String _preferredTimeRangeLabel(AppLocalizations l, String code) {
  final String label = preferredTimeLabel(l, code);
  final String? start = preferredStartTime(code);
  if (start == null || label.contains('–')) return label;
  return '$start–${_addMinutes(start, _defaultConsultationDurationMinutes)}';
}

/// 상담 요청 — the inbox where a member becomes a client.
///
/// Accepting is the only path from "someone asked" to a real trainer↔member
/// link, so the card carries everything a trainer needs to decide without
/// opening anything else: who, what they want, and when they can come.
///
/// Two request sources land here — a member who picked this trainer by
/// name, and a member who asked the gym. The second kind is badged, since
/// any trainer at that gym can pick it up and the first to accept wins.
///
/// The demo build never reaches this page: its repository reports no inbox
/// and the sidebar row is not rendered (see [consultationInboxEnabledProvider]).
class ConsultationsPage extends ConsumerWidget {
  /// Creates the inbox page.
  const ConsultationsPage({super.key, this.returnTo, this.modal = false});

  /// Entry surface (`dashboard` or null/default schedule).
  final String? returnTo;

  /// Whether the inbox is being shown over its entry surface.
  final bool modal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final filter = ref.watch(consultationFilterProvider);
    final inbox = ref.watch(consultationsProvider);
    final pending = ref.watch(consultationPendingCountProvider).valueOrNull;
    final fromDashboard = returnTo == 'dashboard';

    final page = PageScaffold(
      title: l.consultTitle,
      // 메시지 탭 고객 리스트 상단의 `전체 / 읽지 않음 N` 칩과 같은 언어다 —
      // 글자 토글(`전체 보기`/`대기 중만`) 대신 두 상태를 한눈에 본다. 부제
      // 자리에 그대로 얹는다: 본문 쪽에 별도 줄로 끼워 넣으면 헤더가 이미
      // 부제 한 줄만큼 예약해 둔 높이(`AppLayout.pageHeaderHeight`)가 빈
      // 채로 남아 그 아래에 또 여백을 넣는 꼴이 된다.
      subtitleWidget: Padding(
        // 제목과 칩 사이를 살짝 띄운다 — 헤더 전체는 고정 높이 안에서
        // 세로 가운데 정렬되므로, 둘이 붙어 있으면 그 블록이 위로
        // 치우쳐 보이고 우측 닫기 버튼과도 중심이 안 맞아 보였다.
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ConsultFilterChip(
              key: const ValueKey<String>('consultation-filter-all'),
              label: l.consultFilterAll,
              selected: filter == 'all',
              onTap: () =>
                  ref.read(consultationFilterProvider.notifier).state = 'all',
            ),
            const SizedBox(width: AppSpacing.xs),
            _ConsultFilterChip(
              key: const ValueKey<String>('consultation-filter-pending'),
              label: l.consultFilterPendingCount(pending ?? 0),
              selected: filter == 'pending',
              onTap: () => ref.read(consultationFilterProvider.notifier).state =
                  'pending',
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (modal)
          IconButton(
            key: const ValueKey<String>('consultations-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
      ],
      // 위쪽만 줄인다 — 기본값(`AppLayout.pagePadding`)은 헤더가 부제
      // 없이 끝날 때를 기준으로 맞춘 여백이라, 칩이 그 부제 자리를 채운
      // 지금은 칩과 본문 사이가 필요 이상으로 벌어져 보였다.
      contentPadding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        AppSpacing.sm,
        AppLayout.pagePadding,
        AppLayout.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!modal) ...<Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ActionButton(
                key: const ValueKey<String>('consultations-back-to-schedule'),
                label: fromDashboard
                    ? l.consultBackToDashboard
                    : l.consultBackToSchedule,
                icon: Icons.arrow_back,
                onPressed: () => context.go(
                  fromDashboard ? AppRoutes.dashboard : AppRoutes.schedule,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          inbox.requests.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _InboxMessage(
              icon: Icons.error_outline,
              title: l.consultLoadFailed,
              detail: serverDetailOr(
                l,
                error is AppError ? error.message : null,
                l.consultRetryLater,
              ),
              action: ActionButton(
                label: l.actionRetry,
                onPressed: () => ref.invalidate(consultationsProvider),
              ),
            ),
            data: (list) => list.isEmpty
                ? _InboxMessage(
                    icon: Icons.inbox_outlined,
                    title: filter == 'pending'
                        ? l.consultEmptyPending
                        : l.consultEmptyHistory,
                    detail: l.consultEmptyHint,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final request in list) ...<Widget>[
                        _RequestCard(
                          key: ValueKey<String>('consultation-${request.id}'),
                          request: request,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      // 서버는 한 쪽만 준다(#980). 상한에 닿았을 때만 버튼을 띄운다 —
                      // 늘 보이면 더 없는데도 누를 것이 있는 것처럼 읽힌다.
                      if (inbox.hasMore)
                        Align(
                          child: ActionButton(
                            key: const ValueKey<String>(
                              'consultation-load-more',
                            ),
                            label: l.consultLoadMore,
                            icon: Icons.history,
                            onPressed: inbox.loadingMore
                                ? null
                                : () => ref
                                      .read(consultationsProvider.notifier)
                                      .loadMore(),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );

    if (!modal) return page;
    return Dialog(
      key: const ValueKey<String>('consultations-dialog'),
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      // 위쪽만 [AppToastStyle.dialogTopClearance] — 상단 토스트가 이
      // 대화상자 위로 겹쳐 뜰 수 있다.
      insetPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppToastStyle.dialogTopClearance,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 960,
        height: MediaQuery.sizeOf(context).height * .82,
        child: page,
      ),
    );
  }
}

/// Opens the shared consultation inbox without leaving the current workspace.
Future<void> showConsultationsDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const ConsultationsPage(modal: true),
);

/// One request. Pending cards carry the 승인 / 거절 actions; decided ones
/// keep their place under the 전체 filter as a read-only record.
class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request, super.key});

  final ConsultationRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  /// Blocks both actions while one is in flight — a double-tapped 승인
  /// would otherwise race and the second call would 409.
  bool _busy = false;

  /// 승인하려던 시간이 겹쳐 막혔을 때의 안내 — 스낵바 대신 승인 버튼 왼쪽
  /// 여백에 인라인으로 보인다. 다른 409(이미 처리됨 등)는 여기 담기지
  /// 않고 예전처럼 스낵바로 뜬다.
  String? _conflict;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _conflict = null;
    });
    final AppLocalizations l = AppLocalizations.of(context);
    final String failureText = l.consultActionFailed;
    try {
      await action();
      if (!mounted) return;
      showAppToast(context, success, kind: AppToastKind.success);
    } on AppError catch (e) {
      // A failed decision usually means the request moved on without us —
      // another trainer at the same gym accepted it first. Refresh before
      // showing the reason, or the card stays actionable and the trainer
      // can keep pressing 승인 on something already decided (review).
      ref.invalidate(consultationsProvider);
      ref.invalidate(consultationPendingCountProvider);
      if (!mounted) return;
      // 409 carries the server's reason (이미 처리됨 / 다른 트레이너가 담당 중)
      // — that sentence is the whole point, so it is shown verbatim.
      showAppToast(
        context,
        serverDetailOr(l, e.message, failureText),
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 승인은 회원이 정확한 시각을 준 경우에만(`HH:mm`, `flexible`·과거
  /// morning/afternoon/evening 값 제외) 그 희망 일시로 실제 스케줄을 만든다.
  /// 정확한 시각이 없는데 아무 시간이나 임의로 잡으면, 그 시간이 이미 다른
  /// 일정으로 차 있을 때 승인 자체가 막혀 버린다 — 트레이너가 직접 시간을
  /// 정하지 않은 요청을 시스템이 추측해 예약하는 셈이라 위험만 크고 얻는
  /// 것이 없다. 이런 요청은 예전처럼 담당 편입·알림만 하고 스케줄은
  /// 비워 둔다.
  ///
  /// 겹치면 서버가 아무것도 만들지 않고 [ConsultationScheduleConflictError]
  /// 로 막는데, 그건 스낵바가 아니라 버튼 옆 인라인 문구로 보여준다.
  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _conflict = null;
    });
    final AppLocalizations l = AppLocalizations.of(context);
    final request = widget.request;
    final String? startTime = preferredStartTime(request.preferredTimeCode);
    try {
      await acceptConsultation(
        ref,
        request.id,
        schedule: startTime == null
            ? null
            : ConsultationSchedule(
                date: ymd(request.preferredDate),
                time: startTime,
                type: SessionType.consultation,
                durationMinutes: _defaultConsultationDurationMinutes,
              ),
      );
      if (!mounted) return;
      showAppToast(
        context,
        l.consultApproved(request.memberName),
        kind: AppToastKind.success,
      );
    } on ConsultationScheduleConflictError catch (e) {
      if (mounted) {
        setState(
          () => _conflict = l.consultScheduleConflict(e.clientName, e.time),
        );
      }
    } on AppError catch (e) {
      ref.invalidate(consultationsProvider);
      ref.invalidate(consultationPendingCountProvider);
      if (!mounted) return;
      showAppToast(
        context,
        serverDetailOr(l, e.message, l.consultActionFailed),
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final note = await showDialog<String?>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (note == null) return;
    await _run(
      () => rejectConsultation(ref, widget.request.id, note: note),
      l.consultRejected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final request = widget.request;
    // 이름이 비어 오는 경우의 대체 문구는 화면이 붙인다 — DTO 는
    // 로케일을 모른다. (#501)
    final String name = request.memberName.isEmpty
        ? l.unknownMember
        : request.memberName;
    return SectionCard(
      title: name,
      // 아바타를 이름 옆(제목 자리)에 둔다 — 예전에는 아바타가 운동
      // 목표·희망 일시 줄과 한 Row에 있어 이름은 카드 제목으로, 아바타는
      // 그 아래 필드 줄 옆으로 떨어져 보였다(#1395).
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClientAvatar(
            label: request.memberName.isEmpty
                ? '?'
                : request.memberName.characters.first,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                name,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
      // 승인·거절 결과를 카드 우측 상단 배지로 바로 보여준다. 대기 중은
      // 배지를 달지 않는다 — 위 `대기 N` 필터가 이미 그 상태를 말하고
      // 있어, 카드마다 또 붙이면 같은 말을 반복하는 셈이다.
      trailing: request.isPending ? null : _StatusBadge(status: request.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 건강관리 목적은 회원이 따로 고르지 않는다 — 운동 목표 하나에서
          // 서버 호환용으로 파생된 값이라, 여기서 또 보여주면 같은 정보를
          // 두 번 말하는 셈이다. `기타` 목표에서는 그 상세가 문의 내용과
          // 완전히 같은 문구라 아래 인용구와 겹치기까지 한다.
          _Field(
            label: l.consultExerciseGoal,
            value: label(exerciseGoalLabels(l), request.goalCode),
          ),
          _Field(
            label: l.consultPreferredTime,
            // 대기 중일 때만 정확한 시간까지 본다 — 승인·거절이 끝나면
            // 그 요청이 원래 몇 시를 원했는지는 더 이상 결정에 쓸 정보가
            // 아니다. 승인된 세션의 실제 시간은 스케줄 화면이 말한다.
            value: request.isPending
                ? '${dateLabel(l, request.preferredDate)} '
                      '${_preferredTimeRangeLabel(l, request.preferredTimeCode)}'
                : dateLabel(l, request.preferredDate),
          ),
          if (request.message != null)
            _Field(
              label: l.consultMessage,
              value: request.message!,
              bold: false,
            ),
          // 상태는 이제 위 배지가 말한다 — 거절 사유만 있으면 별도로
          // 덧붙인다(회원에게 보낸 알림 본문과 같은 문구).
          if (request.status == 'rejected' &&
              (request.decisionNote?.isNotEmpty ?? false)) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Field(label: l.consultDecisionNote, value: request.decisionNote!),
          ],
          if (request.isPending) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                // 겹침 안내는 버튼 왼쪽 여백을 그대로 쓴다 — 스낵바 대신
                // 여기서 바로 무엇과 겹치는지 읽을 수 있다.
                Expanded(
                  child: _conflict == null
                      ? const SizedBox.shrink()
                      : Text(
                          _conflict!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.destructive,
                          ),
                        ),
                ),
                ActionButton(
                  key: ValueKey<String>('consultation-reject-${request.id}'),
                  label: l.consultReject,
                  tone: AppColors.destructive,
                  onPressed: _busy ? null : _reject,
                ),
                const SizedBox(width: AppSpacing.sm),
                ActionButton(
                  key: ValueKey<String>('consultation-accept-${request.id}'),
                  label: l.consultApprove,
                  primary: true,
                  onPressed: _busy ? null : _accept,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Rejection reason. Optional — a trainer who is simply full should not
/// have to compose a sentence, but the field is offered because the member
/// receives whatever is written here as their notification body.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(l.consultRejectTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.consultRejectNotice,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey<String>('consultation-reject-reason'),
            controller: _controller,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l.consultRejectHint,
              filled: true,
              fillColor: AppColors.inputBackground,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        TextButton(
          key: const ValueKey<String>('consultation-reject-confirm'),
          style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
          // Returns '' rather than null when left blank: null is the
          // cancel signal, and an empty note is a valid "no reason given".
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l.consultRejectAction),
        ),
      ],
    );
  }
}

/// 대기·승인·거절 — 카드 우측 상단에 색으로 구분해 붙인다.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  /// `pending` | `accepted` | `rejected`.
  final String status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final (String label, Color color) = switch (status) {
      'accepted' => (l.consultStatusAccepted, AppColors.success),
      'rejected' => (l.consultStatusRejected, AppColors.destructive),
      _ => (l.consultStatusPending, AppColors.statusCaution),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.bold = true});

  final String label;
  final String value;

  /// 문의 내용처럼 회원이 직접 쓴 글은 다른 항목과 굵기를 맞추지 않는다 —
  /// 원문 그대로라는 느낌을 남긴다.
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.subtleForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.foreground,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared empty / error presentation so both read as the same surface.
class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // 필터 칩 바로 아래 오는 자리라 예전(부제+헤더 뒤)만큼 넓은 위쪽
    // 여백은 필요 없다 — `AppSpacing.xxl` 은 그 자리를 기준으로 잡은
    // 값이라 지금은 칩과 겹쳐 과하게 벌어져 보였다.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 40, color: AppColors.disabledForeground),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.mutedForeground,
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// 전체 / 대기 N — 메시지 탭 고객 리스트 상단의 `전체 / 읽지 않음 N` 필과
/// 같은 언어다. 글자 토글(`전체 보기`/`대기 중만`) 대신 두 상태를 한눈에
/// 본다.
class _ConsultFilterChip extends StatelessWidget {
  const _ConsultFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSurface : AppColors.inputBackground,
      borderRadius: const BorderRadius.all(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
