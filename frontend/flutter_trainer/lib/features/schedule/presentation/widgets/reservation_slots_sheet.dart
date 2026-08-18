import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/reservation_slot_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/reservation_slot.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

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
    // await 전에 한 번만 잡아 둔다 — 뒤에서 context 를 다시 만지면 async gap 을
    // 건너 쓰게 된다.
    final AppLocalizations l = AppLocalizations.of(context);
    final capacity = int.tryParse(_capacity.text);
    if (capacity == null || capacity < 1 || capacity > 100) {
      _showMessage(l.slotCapacityInvalid);
      return;
    }
    final startsAt = _startsAt(_time);
    if (!startsAt.isAfter(nowKst())) {
      _showMessage(l.slotPastTime);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(reservationSlotRepositoryProvider)
          .create(startsAt: startsAt, capacity: capacity);
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
    final controller = TextEditingController(text: '${slot.capacity}');
    final changed = await showDialog<(TimeOfDay, int)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l.slotEditTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.slotStartTime),
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
                  labelText: l.slotCapacity,
                  helperText: l.slotBookedNow(slot.booked),
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
              child: Text(l.actionSave),
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
        content: Text(l.slotCloseBody(slot.booked)),
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
        SlotErrorCodes.capacityRange => l.slotCapacityRange,
        SlotErrorCodes.futureOnly => l.slotFutureOnly,
        SlotErrorCodes.notFound => l.slotNotFound,
        SlotErrorCodes.capacityBelowBooked => l.slotCapacityBelowBooked,
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
                l.slotIntro(
                  l.dateMonthDay(
                    widget.selectedDay.month,
                    widget.selectedDay.day,
                  ),
                ),
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
                      key: const ValueKey<String>('slot-capacity-input'),
                      controller: _capacity,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.slotCapacity,
                        suffixText: l.dashUnitPeople,
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
                        .where(
                          (slot) => _sameDay(slot.startsAt, widget.selectedDay),
                        )
                        .toList();
                    if (daySlots.isEmpty) {
                      return Center(
                        child: Text(
                          l.slotEmpty,
                          style: const TextStyle(color: AppColors.mutedForeground),
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
                                      ? l.slotClosedSummary(slot.booked)
                                      : l.slotOpenSummary(
                                          slot.booked,
                                          slot.remaining,
                                        ),
                                  style: TextStyle(
                                    color: slot.isClosed
                                        ? AppColors.subtleForeground
                                        : AppColors.foreground,
                                  ),
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
