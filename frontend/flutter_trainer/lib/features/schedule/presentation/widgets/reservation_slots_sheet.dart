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
import 'package:oncare_trainer/shared/widgets/app_toast.dart';

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

  /// 24시간 표기로 고정한다 — `TimeOfDay.format(context)` 는 로케일 기본값
  /// (오전/오후 12시간제)을 따라가 이 시트만 다른 곳(스케줄 시간표 등)과
  /// 다른 표기로 보였다.
  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

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
      _showMessage(l.slotOpened, kind: AppToastKind.success);
    } catch (error) {
      _showMessage(_errorMessage(l, error), kind: AppToastKind.error);
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
      _showMessage(l.slotClosed, kind: AppToastKind.success);
    } catch (error) {
      _showMessage(_errorMessage(l, error), kind: AppToastKind.error);
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

  void _showMessage(String message, {AppToastKind kind = AppToastKind.info}) {
    if (!mounted) return;
    showAppToast(context, message, kind: kind);
  }

  /// 종류·날짜·시간 세 필드가 같은 모양으로 보이도록 쓰는 라벨 + 테두리 상자
  /// — 스케줄 프로그램 수정(운동 날짜 필드 등)과 같은 언어다: 위에 옅은
  /// 라벨, 아래에 `borderStrong` 테두리 상자, 아이콘은 강조색으로 둔다.
  /// 예전 채움 칩(`inputBackground` 배경, 라벨 없음)은 이 시트만 다른 필드
  /// 모양이라 다른 곳과 이어 보이지 않았다.
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.subtleForeground,
      ),
    );
  }

  Widget _fieldBox({required IconData icon, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppColors.subtleForeground,
          ),
        ],
      ),
    );
  }

  /// 라벨 + [_fieldBox] 한 벌. 날짜·시간처럼 눌러서 다이얼로그를 여는
  /// 자리에 쓴다. 종류는 [PopupMenuButton] 이 자기 탭 처리를 이미 하므로
  /// 이 래퍼 대신 그 `child` 자리에 [_fieldBox] 만 준다.
  Widget _tappableFieldColumn({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback? onTap,
    Key? key,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _fieldLabel(label),
        const SizedBox(height: AppSpacing.sm),
        Material(
          key: key,
          color: Colors.transparent,
          borderRadius: const BorderRadius.all(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(AppRadius.md),
            child: _fieldBox(icon: icon, value: value),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final slots = ref.watch(reservationSlotsProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    // 가운데 모달로 뜬다(#1250 과 같은 자리) — 닫기(X)는 카드 바깥
    // `_openCenteredDialog` 가 이미 그려 주므로 여기서 또 두지 않는다.
    // `Dialog` 자체는 투명이라(#1250) 배경은 이 위젯이 직접 그린다 — 예전
    // 바텀시트는 `showModalBottomSheet` 의 `backgroundColor` 로 받았는데,
    // 가운데 모달로 옮기며 그 배경이 통째로 빠졌었다.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.all(AppRadius.lg),
        border: Border.all(color: AppColors.borderStrong),
      ),
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
              Text(
                l.slotManageTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.slotIntro(l.dateMonthDay(_date.month, _date.day)),
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: AppSpacing.lg),
              // 종류·날짜·시간·추가 버튼을 한 줄에 둔다 — 넷 다 "언제·누구
              // 자리를 열까"를 정하고 실행하는 같은 흐름이라, 하나만 다른
              // 줄에 서면 무엇이 먼저인지 자리로 오해된다. 라벨 + 흰
              // 테두리 상자 모양은 스케줄 프로그램 수정 화면과 같은
              // 언어다(#1090).
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _fieldLabel(l.schedFieldType),
                        const SizedBox(height: AppSpacing.sm),
                        PopupMenuButton<String>(
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
                          child: _fieldBox(
                            icon: Icons.badge_outlined,
                            value: sessionTypeLabel(l, _type),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _tappableFieldColumn(
                      key: const ValueKey<String>('slot-date'),
                      label: l.schedFieldDate,
                      icon: Icons.calendar_today_outlined,
                      value: l.dateMonthDay(_date.month, _date.day),
                      onTap: _saving ? null : _pickDate,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _tappableFieldColumn(
                      key: const ValueKey<String>('slot-time-range'),
                      label: l.schedFieldTime,
                      icon: Icons.schedule_outlined,
                      value: '${_hhmm(_time)} – ${_hhmm(_endTime)}',
                      onTap: _saving ? null : _pickRange,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    key: const ValueKey<String>('slot-create'),
                    onPressed: _saving ? null : _create,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l.slotOpenAction),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
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
                        // 닫혔거나 이미 예약된 자리는 "골라 쓸 수 없는 자리"라
                        // 같은 회색으로 눌러 둔다 — 비어 있는 자리(흰 카드)와
                        // 구분된다.
                        final taken = slot.isClosed || slot.booked;
                        return Container(
                          key: ValueKey<String>('slot-row-${slot.id}'),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: taken
                                ? AppColors.inputBackground
                                : AppColors.card,
                            border: Border.all(color: AppColors.borderStrong),
                            borderRadius: const BorderRadius.all(AppRadius.md),
                          ),
                          child: Row(
                            children: <Widget>[
                              // 종류 → 시간 순서다 — 새 일정 모달과 위 열기
                              // 폼(종류 → 날짜 → 시간)이 같은 순서로 읽힌다.
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 3,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.accentSurface,
                                  borderRadius: BorderRadius.all(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  sessionTypeLabel(l, slot.sessionType),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  '${_hhmm(TimeOfDay.fromDateTime(slot.startsAt))} – '
                                  '${_hhmm(TimeOfDay.fromDateTime(slot.startsAt.add(Duration(minutes: slot.durationMinutes))))}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (slot.isClosed)
                                Text(
                                  l.slotClosedSummary,
                                  style: const TextStyle(
                                    color: AppColors.subtleForeground,
                                  ),
                                )
                              else if (slot.booked)
                                // 예약자 이름을 보여 준다(#1394) — 예전
                                // 수정·닫기 아이콘 자리다. 이름이 아직 없으면
                                // (오래된 데이터 등) 상태 문구로 대신한다.
                                Text(
                                  slot.bookedByName ?? l.slotBookedSummary,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.foreground,
                                  ),
                                )
                              else
                                // 아직 아무도 잡지 않은 자리만 지울 수 있다 —
                                // 수정 대신 삭제다(#1394).
                                IconButton(
                                  tooltip: l.slotCloseAction,
                                  onPressed: _saving
                                      ? null
                                      : () => _close(slot),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.destructive,
                                  ),
                                ),
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
