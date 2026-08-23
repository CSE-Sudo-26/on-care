import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/core/utils/portrait_date_picker.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/consultations/data/dtos/consultation_dtos.dart';
import 'package:oncare_trainer/features/consultations/data/repositories/consultation_repository.dart';
import 'package:oncare_trainer/features/consultations/domain/entities/consultation_request.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

/// Schedule-tab inbox for member consultation requests.
///
/// Returning a date tells the schedule page to jump to the newly created
/// calendar entry after the sheet closes.
class ConsultationInboxSheet extends ConsumerWidget {
  const ConsultationInboxSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final requests = ref.watch(consultationsProvider).requests;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l.consultTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                l.consultEmptyHint,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: requests.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(child: Text(l.consultLoadFailed)),
                  data: (rows) => rows.isEmpty
                      ? Center(child: Text(l.consultEmptyPending))
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) => _RequestCard(
                            // E2E 가 "내가 낸 요청" 을 집어야 한다 — 목록의 자리는
                            // 다른 회원의 요청이 끼면 밀린다. (#640)
                            key: ValueKey<String>(
                              'consult-request-${rows[index].id}',
                            ),
                            request: rows[index],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request, super.key});

  final ConsultationRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _schedule() async {
    final booking = await showDialog<_Booking>(
      context: context,
      builder: (_) => _ScheduleDialog(request: widget.request),
    );
    if (booking == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final schedule = ConsultationSchedule(
        date: ymd(booking.date),
        time: booking.time,
        type: '상담',
        durationMinutes: booking.durationMinutes,
      );
      // Demo mode has no backend transaction, so mirror the accepted request
      // into the local Drift calendar before finalizing the decision. A failed
      // calendar write therefore leaves the request pending and retryable.
      final useMockApi = ref.read(appConfigProvider).useMockApi;
      if (useMockApi) {
        await ref
            .read(scheduleRepositoryProvider)
            .addSession(
              date: schedule.date,
              clientName: widget.request.memberName,
              clientId: widget.request.memberId,
              time: schedule.time,
              type: schedule.type,
              durationMinutes: schedule.durationMinutes,
              note: widget.request.message ?? '',
            );
      }
      await acceptConsultation(ref, widget.request.id, schedule: schedule);
      ref.invalidate(scheduleForDateProvider(schedule.date));
      ref.invalidate(bookedDatesProvider);
      if (!mounted) return;
      Navigator.of(context).pop(schedule.date);
      messenger.showSnackBar(
        SnackBar(content: Text(l.consultApproved(widget.request.memberName))),
      );
    } on AppError catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            serverDetailOr(l, error.message, l.consultActionFailed),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.consultActionFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final l = AppLocalizations.of(context);
    final note = await showDialog<String?>(
      context: context,
      builder: (context) => const _RejectDialog(),
    );
    if (note == null || note.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await rejectConsultation(ref, widget.request.id, note: note);
    } on AppError catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            serverDetailOr(l, error.message, l.consultActionFailed),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.consultActionFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final request = widget.request;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            request.memberName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 운동 목표 하나만 보인다 — 관리 목적은 회원이 고른 운동 목표에서
          // 자동으로 채워지는 값이라 따로 보여줄 이유가 없다(#1112).
          // "기타"의 상세는 문의 내용에 있다.
          _line(
            l.consultExerciseGoal,
            label(exerciseGoalLabels(l), request.goalCode),
          ),
          _line(
            l.consultPreferredTime,
            '${dateLabel(l, request.preferredDate)} · '
            '${label(preferredTimeLabels(l), request.preferredTimeCode)}',
          ),
          if (request.message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _line(l.consultMessage, request.message!),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              ActionButton(
                key: const Key('consult-reject'),
                label: l.consultReject,
                tone: AppColors.destructive,
                onPressed: _busy ? null : _reject,
              ),
              const SizedBox(width: AppSpacing.sm),
              ActionButton(
                key: const Key('consult-accept'),
                label: l.schedNewSession,
                icon: Icons.event_available_outlined,
                primary: true,
                onPressed: _busy ? null : _schedule,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String name, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Text(
            name,
            style: const TextStyle(color: AppColors.subtleForeground),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

/// 거절 사유를 받는 다이얼로그.
///
/// 컨트롤러를 **이 위젯이 소유한다.** 호출부에서 `showDialog` 가 반환되자마자 버리면,
/// 다이얼로그가 사라지는 애니메이션 동안 남아 있는 프레임이 이미 버린 컨트롤러를 읽어
/// "A TextEditingController was used after being disposed" 로 터진다. State 가 소유하면
/// 화면이 완전히 사라진 뒤에 정리된다.
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
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.consultRejectTitle),
      content: TextField(
        key: const Key('consult-reject-reason'),
        controller: _controller,
        maxLength: 500,
        maxLines: 3,
        decoration: InputDecoration(hintText: l.consultRejectHint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => TextButton(
            key: const Key('consult-reject-confirm'),
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(value.text.trim()),
            child: Text(l.consultRejectAction),
          ),
        ),
      ],
    );
  }
}

class _Booking {
  const _Booking(this.date, this.time, this.durationMinutes);

  final DateTime date;
  final String time;
  final int durationMinutes;
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({required this.request});

  final ConsultationRequest request;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late DateTime _date;
  late int _hour = switch (widget.request.preferredTimeCode) {
    'morning' => 10,
    'afternoon' => 14,
    'evening' => 19,
    _ => 10,
  };
  int _minute = 0;
  int _duration = 30;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(nowKst());
    final lastDate = today.add(const Duration(days: 365));
    _date = _clampDate(
      DateUtils.dateOnly(widget.request.preferredDate),
      today,
      lastDate,
    );
  }

  DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
    if (value.isBefore(first)) return first;
    if (value.isAfter(last)) return last;
    return value;
  }

  String get _time =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.schedAddTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.request.memberName),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('consult-book-date'),
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(dateLabel(l, _date)),
            onPressed: () async {
              final today = DateUtils.dateOnly(nowKst());
              final lastDate = today.add(const Duration(days: 365));
              final picked = await showPortraitDatePicker(
                context: context,
                initialDate: _clampDate(_date, today, lastDate),
                firstDate: today,
                lastDate: lastDate,
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const Key('consult-book-hour'),
                  initialValue: _hour,
                  decoration: InputDecoration(labelText: l.schedFieldTime),
                  items: <DropdownMenuItem<int>>[
                    for (var hour = 6; hour <= 22; hour++)
                      DropdownMenuItem(
                        value: hour,
                        child: Text(l.schedHourLabel('$hour')),
                      ),
                  ],
                  onChanged: (value) => setState(() => _hour = value ?? _hour),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const Key('consult-book-minute'),
                  initialValue: _minute,
                  decoration: InputDecoration(labelText: l.schedMinuteSuffix),
                  items: <DropdownMenuItem<int>>[
                    for (final minute in const <int>[0, 15, 30, 45])
                      DropdownMenuItem(
                        value: minute,
                        child: Text(l.schedMinuteLabel('$minute')),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _minute = value ?? _minute),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int>(
            key: const Key('consult-book-duration'),
            initialValue: _duration,
            decoration: InputDecoration(labelText: l.schedFieldDuration),
            items: <DropdownMenuItem<int>>[
              for (final duration in const <int>[30, 45, 60, 90])
                DropdownMenuItem(value: duration, child: Text('$duration분')),
            ],
            onChanged: (value) =>
                setState(() => _duration = value ?? _duration),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
        TextButton(
          key: const Key('consult-book-confirm'),
          onPressed: () =>
              Navigator.of(context).pop(_Booking(_date, _time, _duration)),
          child: Text(l.schedAddAction),
        ),
      ],
    );
  }
}
