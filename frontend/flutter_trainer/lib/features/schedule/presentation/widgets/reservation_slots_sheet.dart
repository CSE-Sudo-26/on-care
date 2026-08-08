import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/reservation_slot_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/reservation_slot.dart';

class ReservationSlotsSheet extends ConsumerStatefulWidget {
  const ReservationSlotsSheet({super.key, required this.selectedDay});

  final DateTime selectedDay;

  @override
  ConsumerState<ReservationSlotsSheet> createState() =>
      _ReservationSlotsSheetState();
}

class _ReservationSlotsSheetState extends ConsumerState<ReservationSlotsSheet> {
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  final TextEditingController _capacity = TextEditingController(text: '1');
  bool _saving = false;

  @override
  void dispose() {
    _capacity.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  DateTime _startsAt(TimeOfDay time) => DateTime(
    widget.selectedDay.year,
    widget.selectedDay.month,
    widget.selectedDay.day,
    time.hour,
    time.minute,
  );

  Future<void> _create() async {
    final capacity = int.tryParse(_capacity.text);
    if (capacity == null || capacity < 1 || capacity > 100) {
      _showMessage('정원은 1명 이상 100명 이하로 입력해 주세요.');
      return;
    }
    final startsAt = _startsAt(_time);
    if (!startsAt.isAfter(DateTime.now())) {
      _showMessage('현재보다 이후 시간만 예약 슬롯으로 만들 수 있어요.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(reservationSlotRepositoryProvider)
          .create(startsAt: startsAt, capacity: capacity);
      ref.invalidate(reservationSlotsProvider);
      _showMessage('예약 슬롯을 열었습니다.');
    } catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(ReservationSlot slot) async {
    var time = TimeOfDay.fromDateTime(slot.startsAt);
    final controller = TextEditingController(text: '${slot.capacity}');
    final changed = await showDialog<(TimeOfDay, int)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('예약 슬롯 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('시작 시간'),
                trailing: Text(time.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (picked != null) setDialogState(() => time = picked);
                },
              ),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '정원',
                  helperText: '현재 예약 ${slot.booked}명',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final capacity = int.tryParse(controller.text);
                if (capacity == null ||
                    capacity < 1 ||
                    capacity < slot.booked ||
                    capacity > 100) {
                  return;
                }
                Navigator.pop(dialogContext, (time, capacity));
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (changed == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(reservationSlotRepositoryProvider)
          .update(
            slot.id,
            startsAt: _startsAt(changed.$1),
            capacity: changed.$2,
          );
      ref.invalidate(reservationSlotsProvider);
      _showMessage('예약 슬롯을 수정했습니다.');
    } catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close(ReservationSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('예약 슬롯 닫기'),
        content: Text('이미 예약된 ${slot.booked}건의 일정은 유지되고, 신규 예약만 중단됩니다.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '닫기',
              style: TextStyle(color: AppColors.destructive),
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
      _showMessage('신규 예약을 닫았습니다.');
    } catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] is String) {
        return data['detail'] as String;
      }
    }
    if (error is StateError) return error.message.toString();
    return '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
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
                  const Expanded(
                    child: Text(
                      '예약 슬롯 관리',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${widget.selectedDay.month}월 ${widget.selectedDay.day}일에 회원이 예약할 시간을 엽니다.',
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _time,
                              );
                              if (picked != null) {
                                setState(() => _time = picked);
                              }
                            },
                      icon: const Icon(Icons.schedule),
                      label: Text(_time.format(context)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _capacity,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '정원',
                        suffixText: '명',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _saving ? null : _create,
                    icon: const Icon(Icons.add),
                    label: const Text('열기'),
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
                      label: const Text('다시 불러오기'),
                    ),
                  ),
                  data: (allSlots) {
                    final daySlots = allSlots
                        .where(
                          (slot) => _sameDay(slot.startsAt, widget.selectedDay),
                        )
                        .toList();
                    if (daySlots.isEmpty) {
                      return const Center(
                        child: Text(
                          '이 날짜에 열린 예약 슬롯이 없습니다.',
                          style: TextStyle(color: AppColors.mutedForeground),
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
                                width: 64,
                                alignment: Alignment.center,
                                child: Text(
                                  TimeOfDay.fromDateTime(
                                    slot.startsAt,
                                  ).format(context),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  slot.isClosed
                                      ? '예약 닫힘 · 예약 ${slot.booked}명'
                                      : '예약 ${slot.booked}명 · 잔여 ${slot.remaining}명',
                                  style: TextStyle(
                                    color: slot.isClosed
                                        ? AppColors.subtleForeground
                                        : AppColors.foreground,
                                  ),
                                ),
                              ),
                              if (!slot.isClosed) ...<Widget>[
                                IconButton(
                                  tooltip: '수정',
                                  onPressed: _saving ? null : () => _edit(slot),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: '예약 닫기',
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
