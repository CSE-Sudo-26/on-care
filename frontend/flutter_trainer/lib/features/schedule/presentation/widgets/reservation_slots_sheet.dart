import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/portrait_date_picker.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/reservation_slot_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/reservation_slot.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/time_range_picker_dialog.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

class ReservationSlotsSheet extends ConsumerStatefulWidget {
  const ReservationSlotsSheet({super.key, required this.selectedDay});

  final DateTime selectedDay;

  @override
  ConsumerState<ReservationSlotsSheet> createState() =>
      _ReservationSlotsSheetState();
}

class _ReservationSlotsSheetState extends ConsumerState<ReservationSlotsSheet> {
  late DateTime _date = widget.selectedDay;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  bool _saving = false;

  /// 정원 대신 종류를 고른다 — 슬롯은 늘 한 사람 몫이다(#1012). 회원 예약이
  /// 만드는 일정이 이 종류를 그대로 물려받는다(#1083).
  String _type = SessionType.personalTraining;

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  DateTime _startsAt(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  int _duration(TimeOfDay start, TimeOfDay end) =>
      end.hour * 60 + end.minute - start.hour * 60 - start.minute;

  Future<void> _pickRange() async {
    final picked = await showScheduleTimeRangePicker(
      context: context,
      start: _time,
      end: _endTime,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _time = picked.start;
      _endTime = picked.end;
    });
  }

  /// 시트를 연 날짜만 볼 수 있던 것을 고친다 — 다른 날짜에 슬롯을 열려면
  /// 시트를 닫고 캘린더에서 날짜를 옮긴 뒤 다시 열어야 했다(#1090).
  Future<void> _pickDate() async {
    final today = nowKst();
    final picked = await showPortraitDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _create() async {
    // await 전에 한 번만 잡아 둔다 — 뒤에서 context 를 다시 만지면 async gap 을
    // 건너 쓰게 된다.
    final AppLocalizations l = AppLocalizations.of(context);
    final startsAt = _startsAt(_time);
    if (!startsAt.isAfter(nowKst())) {
      _showMessage(l.slotPastTime);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(reservationSlotRepositoryProvider)
          .create(
            startsAt: startsAt,
            durationMinutes: _duration(_time, _endTime),
            sessionType: _type,
          );
      ref.invalidate(reservationSlotsProvider);
      _showMessage(l.slotOpened);
    } catch (error) {
      _showMessage(_errorMessage(l, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(ReservationSlot slot) async {
    final AppLocalizations l = AppLocalizations.of(context);
    var time = TimeOfDay.fromDateTime(slot.startsAt);
    var endTime = TimeOfDay.fromDateTime(
      slot.startsAt.add(Duration(minutes: slot.durationMinutes)),
    );
    var type = slot.sessionType;
    // 이미 예약이 걸린 자리는 종류를 고칠 수 없다 — 서버가 409 로 막는
    // 동작을 아예 내놓지 않는다(#871 과 같은 규약).
    final typeLocked = slot.booked;
    final changed = await showDialog<(TimeOfDay, TimeOfDay, String)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l.slotEditTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${l.schedFieldStart} – ${l.schedFieldEnd}'),
                trailing: Text(
                  '${time.format(context)} – ${endTime.format(context)}',
                ),
                onTap: () async {
                  final picked = await showScheduleTimeRangePicker(
                    context: context,
                    start: time,
                    end: endTime,
                  );
                  if (picked != null) {
                    setDialogState(() {
                      time = picked.start;
                      endTime = picked.end;
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.slotSessionType),
                trailing: typeLocked
                    ? Text(sessionTypeLabel(l, type))
                    : DropdownButton<String>(
                        value: type,
                        underline: const SizedBox.shrink(),
                        items: <DropdownMenuItem<String>>[
                          for (final t in SessionType.all)
                            DropdownMenuItem<String>(
                              value: t,
                              child: Text(sessionTypeLabel(l, t)),
                            ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => type = v ?? type),
                      ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                (time, endTime, type),
              ),
              child: Text(l.actionSave),
            ),
          ],
        ),
      ),
    );
    if (changed == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(reservationSlotRepositoryProvider)
          .update(
            slot.id,
            startsAt: _startsAt(changed.$1),
            durationMinutes: _duration(changed.$1, changed.$2),
            sessionType: changed.$3 == slot.sessionType ? null : changed.$3,
          );
      ref.invalidate(reservationSlotsProvider);
      _showMessage(l.slotUpdated);
    } catch (error) {
      _showMessage(_errorMessage(l, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close(ReservationSlot slot) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.slotCloseTitle),
        content: Text(l.slotCloseBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l.actionClose,
              style: const TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(reservationSlotRepositoryProvider).close(slot.id);
      ref.invalidate(reservationSlotsProvider);
      _showMessage(l.slotClosed);
    } catch (error) {
      _showMessage(_errorMessage(l, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorMessage(AppLocalizations l, Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] is String) {
        // 서버가 보낸 사유는 한국어 화면에서만 그대로 쓴다. (#501)
        return serverDetailOr(l, data['detail'] as String, l.slotActionFailed);
      }
    }
    if (error is StateError) {
      // 목 리포지토리는 코드를 던진다 — 문구는 여기서 붙인다. (#501)
      return switch (error.message.toString()) {
        SlotErrorCodes.futureOnly => l.slotFutureOnly,
        SlotErrorCodes.notFound => l.slotNotFound,
        SlotErrorCodes.typeLockedByBooking => l.slotTypeLockedByBooking,
        _ => l.slotActionFailed,
      };
    }
    return l.slotActionFailed;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 종류·날짜·시간 세 필드가 한 줄에서 같은 무게로 보이도록 쓰는 옅은
  /// 채움 칩. `OutlinedButton` 의 짙은 윤곽선 대신 트레이너 웹 다른 곳
  /// (필터 칩 등)과 같은 `inputBackground` 채움을 쓴다(#1090).
  Widget _compactField({required IconData icon, required String label}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.all(AppRadius.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 17, color: AppColors.mutedForeground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [_compactField] 를 누를 수 있게 감싼다 — 날짜·시간처럼 다이얼로그를
  /// 여는 자리에 쓴다. 종류는 [PopupMenuButton] 이 자기 탭 처리를 이미
  /// 하므로 이 래퍼를 쓰지 않는다.
  Widget _tappableField({
    required Widget child,
    required VoidCallback? onTap,
    Key? key,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.sm),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final slots = ref.watch(reservationSlotsProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl + bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l.slotManageTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.actionClose,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.slotIntro(l.dateMonthDay(_date.month, _date.day)),
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: AppSpacing.lg),
              // 종류·날짜·시간을 한 줄에 둔다 — 셋 다 "언제·누구 자리를
              // 열까"를 정하는 같은 층위의 선택이라, 종류만 위에 따로 서고
              // 나머지가 아래에 서면 무엇이 먼저인지 자리로 오해된다.
              // 옅은 채움만 쓰고 테두리를 넣지 않는다 — 기본
              // `OutlinedButton` 의 짙은 윤곽선은 이 시트에서 유일하게
              // 선을 두른 요소라 눈에 튀었다(#1090).
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: PopupMenuButton<String>(
                      key: const ValueKey<String>('slot-session-type'),
                      enabled: !_saving,
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        for (final t in SessionType.all)
                          PopupMenuItem<String>(
                            value: t,
                            child: Text(sessionTypeLabel(l, t)),
                          ),
                      ],
                      onSelected: (v) => setState(() => _type = v),
                      child: _compactField(
                        icon: Icons.badge_outlined,
                        label: sessionTypeLabel(l, _type),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: _tappableField(
                      key: const ValueKey<String>('slot-date'),
                      onTap: _saving ? null : _pickDate,
                      child: _compactField(
                        icon: Icons.calendar_today_outlined,
                        label: l.dateMonthDay(_date.month, _date.day),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 5,
                    child: _tappableField(
                      key: const ValueKey<String>('slot-time-range'),
                      onTap: _saving
                          ? null
                          : _pickRange,
                      child: _compactField(
                        icon: Icons.schedule_outlined,
                        label:
                            '${_time.format(context)} – '
                            '${_endTime.format(context)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    key: const ValueKey<String>('slot-create'),
                    onPressed: _saving ? null : _create,
                    icon: const Icon(Icons.add),
                    label: Text(l.slotOpenAction),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: slots.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: FilledButton.tonalIcon(
                      onPressed: () => ref.invalidate(reservationSlotsProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(l.slotReload),
                    ),
                  ),
                  data: (allSlots) {
                    final daySlots = allSlots
                        .where((slot) => _sameDay(slot.startsAt, _date))
                        .toList();
                    if (daySlots.isEmpty) {
                      return Center(
                        child: Text(
                          l.slotEmpty,
                          style: const TextStyle(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: daySlots.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final slot = daySlots[index];
                        return Container(
                          key: ValueKey<String>('slot-row-${slot.id}'),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: slot.isClosed
                                ? AppColors.inputBackground
                                : AppColors.card,
                            border: Border.all(color: AppColors.borderStrong),
                            borderRadius: const BorderRadius.all(AppRadius.md),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 132,
                                alignment: Alignment.center,
                                child: Text(
                                  '${TimeOfDay.fromDateTime(slot.startsAt).format(context)} – '
                                  '${TimeOfDay.fromDateTime(slot.startsAt.add(Duration(minutes: slot.durationMinutes))).format(context)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      sessionTypeLabel(l, slot.sessionType),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      // 한 사람 몫뿐인 자리라 인원수를 셀
                                      // 것이 없다 — 상태만 적는다(#1072).
                                      slot.isClosed
                                          ? l.slotClosedSummary
                                          : (slot.booked
                                                ? l.slotBookedSummary
                                                : l.slotOpenSummary),
                                      style: TextStyle(
                                        color: slot.isClosed
                                            ? AppColors.subtleForeground
                                            : AppColors.foreground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!slot.isClosed) ...<Widget>[
                                IconButton(
                                  tooltip: l.actionEdit,
                                  onPressed: _saving ? null : () => _edit(slot),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: l.slotCloseAction,
                                  onPressed: _saving
                                      ? null
                                      : () => _close(slot),
                                  icon: const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.destructive,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
