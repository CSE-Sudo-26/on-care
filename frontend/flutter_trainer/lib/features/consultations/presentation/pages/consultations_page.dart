import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

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
  const ConsultationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final filter = ref.watch(consultationFilterProvider);
    final requests = ref.watch(consultationsProvider);
    final pending = ref.watch(consultationPendingCountProvider).valueOrNull;

    return PageScaffold(
      title: l.consultTitle,
      subtitle: pending == null
          ? null
          : (pending > 0 ? l.consultPendingCount(pending) : l.consultNoPending),
      actions: <Widget>[
        ActionButton(
          label: filter == 'pending' ? l.consultShowAll : l.consultShowPending,
          icon: Icons.filter_list,
          onPressed: () => ref
              .read(consultationFilterProvider.notifier)
              .state = filter == 'pending' ? 'all' : 'pending',
        ),
      ],
      child: requests.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _InboxMessage(
          icon: Icons.error_outline,
          title: l.consultLoadFailed,
          detail: (error is AppError ? error.message : null) ?? l.consultRetryLater,
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
                    _RequestCard(request: request),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
      ),
    );
  }
}

/// One request. Pending cards carry the 승인 / 거절 actions; decided ones
/// keep their place under the 전체 filter as a read-only record.
class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request});

  final ConsultationRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  /// Blocks both actions while one is in flight — a double-tapped 승인
  /// would otherwise race and the second call would 409.
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    // messenger 와 같이 await 전에 잡아 둔다.
    final String failureText = AppLocalizations.of(context).consultActionFailed;
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
        SnackBar(content: Text(e.message ?? failureText)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() => _run(
    () => acceptConsultation(ref, widget.request.id),
    AppLocalizations.of(context).consultApproved(widget.request.memberName),
  );

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
      title: request.memberName,
      trailing: request.viaGym
          ? _Tag(label: l.consultTargetGym, tone: AppColors.brandOrange)
          : _Tag(label: l.consultTargetTrainer, tone: AppColors.primary),
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
                    _Field(label: l.consultExerciseGoal, value: request.goalLabel),
                    _Field(
                      label: l.consultHealthPurpose,
                      value: request.purposeDetail == null
                          ? request.purposeLabel
                          : '${request.purposeLabel} · ${request.purposeDetail}',
                    ),
                    _Field(
                      label: l.consultPreferredTime,
                      value:
                          '${dateLabel(l, request.preferredDate)} '
                          '${request.preferredTimeLabel}',
                    ),
                    if (request.gymName != null)
                      _Field(label: l.consultGym, value: request.gymName!),
                  ],
                ),
              ),
            ],
          ),
          if (request.message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Quote(text: request.message!),
          ],
          if (!request.isPending) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _DecisionSummary(request: request),
          ],
          if (request.isPending) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                ActionButton(
                  label: l.consultReject,
                  tone: AppColors.destructive,
                  onPressed: _busy ? null : _reject,
                ),
                const SizedBox(width: AppSpacing.sm),
                ActionButton(
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
            style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
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
          // Returns '' rather than null when left blank: null is the
          // cancel signal, and an empty note is a valid "no reason given".
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l.consultRejectAction),
        ),
      ],
    );
  }
}

/// What happened to a request that is no longer pending.
class _DecisionSummary extends StatelessWidget {
  const _DecisionSummary({required this.request});

  final ConsultationRequest request;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final accepted = request.status == 'accepted';
    return Row(
      children: <Widget>[
        Icon(
          accepted ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: accepted ? AppColors.success : AppColors.destructive,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            accepted
                ? l.consultStatusApproved
                : (request.decisionNote == null
                      ? l.consultStatusRejected
                      : l.consultStatusRejectedWithNote(request.decisionNote!)),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
                fontSize: 12,
                color: AppColors.subtleForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
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
class _Quote extends StatelessWidget {
  const _Quote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppColors.foreground,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
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
