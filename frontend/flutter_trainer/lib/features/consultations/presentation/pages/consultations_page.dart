import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/consultations/data/dtos/consultation_dtos.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';

/// 승인이 만드는 세션의 소요 시간(분). 백엔드 기본값과 같다.
const int _defaultConsultationDurationMinutes = 30;

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
      actions: <Widget>[
        if (modal)
          IconButton(
            key: const ValueKey<String>('consultations-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 메시지 탭 고객 리스트 상단의 `전체 / 읽지 않음 N` 칩과 같은 언어다
          // — 글자 토글(`전체 보기`/`대기 중만`) 대신 두 상태를 한눈에 본다.
          // 예전에는 헤더 우측 `actions` 자리에 있었는데, 그 자리는 액션마다
          // 자동으로 여백을 더해 칩 사이가 메시지 탭보다 넓어 보였고, 바로
          // 위 `대기 중 N건` 부제와 같은 정보를 두 번 말하고 있었다 — 부제를
          // 없애고 그 자리로 옮긴다.
          Row(
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
                onTap: () =>
                    ref.read(consultationFilterProvider.notifier).state =
                        'pending',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
              padding: EdgeInsets.only(top: AppSpacing.xxl),
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
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
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
    final messenger = ScaffoldMessenger.of(context);
    // messenger 와 같이 await 전에 잡아 둔다.
    final AppLocalizations l = AppLocalizations.of(context);
    final String failureText = l.consultActionFailed;
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on AppError catch (e) {
      // A failed decision usually means the request moved on without us —
      // another trainer at the same gym accepted it first. Refresh before
      // showing the reason, or the card stays actionable and the trainer
      // can keep pressing 승인 on something already decided (review).
      ref.invalidate(consultationsProvider);
      ref.invalidate(consultationPendingCountProvider);
      // 409 carries the server's reason (이미 처리됨 / 다른 트레이너가 담당 중)
      // — that sentence is the whole point, so it is shown verbatim.
      messenger.showSnackBar(
        SnackBar(content: Text(serverDetailOr(l, e.message, failureText))),
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
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(
        SnackBar(content: Text(l.consultApproved(request.memberName))),
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(serverDetailOr(l, e.message, l.consultActionFailed)),
        ),
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
    return SectionCard(
      // 이름이 비어 오는 경우의 대체 문구는 화면이 붙인다 — DTO 는
      // 로케일을 모른다. (#501)
      title: request.memberName.isEmpty ? l.unknownMember : request.memberName,
      // 승인·거절 결과를 카드 우측 상단 배지로 바로 보여준다. 대기 중은
      // 배지를 달지 않는다 — 위 `대기 N` 필터가 이미 그 상태를 말하고
      // 있어, 카드마다 또 붙이면 같은 말을 반복하는 셈이다.
      trailing: request.isPending ? null : _StatusBadge(status: request.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClientAvatar(
                label: request.memberName.isEmpty
                    ? '?'
                    : request.memberName.characters.first,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Field(
                      label: l.consultExerciseGoal,
                      value: label(exerciseGoalLabels(l), request.goalCode),
                    ),
                    _Field(
                      label: l.consultHealthPurpose,
                      value: <String>[
                        label(healthPurposeLabels(l), request.purposeCode),
                        if (request.purposeDetail != null)
                          request.purposeDetail!,
                      ].join(' · '),
                    ),
                    _Field(
                      label: l.consultPreferredTime,
                      value:
                          '${dateLabel(l, request.preferredDate)} '
                          '${preferredTimeLabel(l, request.preferredTimeCode)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Quote(label: l.consultMessage, text: request.message!),
          ],
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
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

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
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The member's own note, set apart from the structured fields.
///
/// [label] 은 위의 다른 항목(운동 목표·관리 목적·희망 일시)과 같은 자리다 —
/// 라벨 없이 인용구만 있으면 이 글이 회원이 직접 쓴 문의 내용이라는 것이
/// 위 항목들과의 시각적 구분(색상 배경)에만 기대게 된다(#1092).
class _Quote extends StatelessWidget {
  const _Quote({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.subtleForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.accentSurface,
            borderRadius: BorderRadius.all(AppRadius.card),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
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
