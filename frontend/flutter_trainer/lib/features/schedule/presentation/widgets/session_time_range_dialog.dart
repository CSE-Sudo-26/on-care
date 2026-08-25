import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/design_system/tokens/toast.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/dialog_close_button.dart';
import 'package:oncare_trainer/shared/widgets/hour_clock_dial.dart';

/// 시작·종료 시간을 한 번에 고르는 가운데 모달(#1229, #1250).
///
/// 날짜 선택([showPortraitDatePicker])과 같은 세로 배치다 — 위에 키보드로
/// 바로 적는 한 줄(`10:00 - 11:00`), 그 아래 달력 대신 시작·종료 시계
/// 다이얼을 위아래로 둔다. 시계는 시(時)를 훑어 고르는 자리고, 분은 그
/// 위 텍스트 필드에 직접 적는다 — 두 값(시작·종료) 다이얼을 한 화면에
/// 같이 두면서 각각 시·분을 다 고르게 하면 자리도 손동작도 두 배가 된다.
Future<(TimeOfDay, TimeOfDay)?> showSessionTimeRangeDialog({
  required BuildContext context,
  required TimeOfDay initialStart,
  required TimeOfDay initialEnd,
}) {
  return showDialog<(TimeOfDay, TimeOfDay)>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      // 위쪽만 [AppToastStyle.dialogTopClearance] — 상단 토스트가 이
      // 대화상자 위로 겹쳐 뜰 수 있다.
      insetPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppToastStyle.dialogTopClearance,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
        ),
        child: _SessionTimeRangeDialog(
          initialStart: initialStart,
          initialEnd: initialEnd,
        ),
      ),
    ),
  );
}

class _SessionTimeRangeDialog extends StatefulWidget {
  const _SessionTimeRangeDialog({
    required this.initialStart,
    required this.initialEnd,
  });

  final TimeOfDay initialStart;
  final TimeOfDay initialEnd;

  @override
  State<_SessionTimeRangeDialog> createState() =>
      _SessionTimeRangeDialogState();
}

class _SessionTimeRangeDialogState extends State<_SessionTimeRangeDialog> {
  late TimeOfDay _start = widget.initialStart;
  late TimeOfDay _end = widget.initialEnd;
  late final TextEditingController _startText = TextEditingController(
    text: _format(_start),
  );
  late final TextEditingController _endText = TextEditingController(
    text: _format(_end),
  );
  String? _error;

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  /// `HH:mm` 을 24시간 기준으로 읽는다. 형식이 아니면 null.
  static TimeOfDay? _parse(String raw) {
    final match = RegExp(r'^([0-9]{1,2}):([0-9]{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _startText.dispose();
    _endText.dispose();
    super.dispose();
  }

  void _setStart(TimeOfDay t) {
    setState(() {
      _start = t;
      _startText.text = _format(t);
      _error = null;
    });
  }

  void _setEnd(TimeOfDay t) {
    setState(() {
      _end = t;
      _endText.text = _format(t);
      _error = null;
    });
  }

  void _onStartHourTap(int hour12) => _setStart(_withHour12(_start, hour12));

  void _onEndHourTap(int hour12) => _setEnd(_withHour12(_end, hour12));

  static TimeOfDay _withHour12(TimeOfDay current, int hour12) {
    final isPM = current.period == DayPeriod.pm;
    final hour24 = (hour12 % 12) + (isPM ? 12 : 0);
    return TimeOfDay(hour: hour24, minute: current.minute);
  }

  void _setStartPeriod(DayPeriod period) => _setStart(
    TimeOfDay(hour: _to24(_start.hourOfPeriod, period), minute: _start.minute),
  );

  void _setEndPeriod(DayPeriod period) => _setEnd(
    TimeOfDay(hour: _to24(_end.hourOfPeriod, period), minute: _end.minute),
  );

  static int _to24(int hourOfPeriod, DayPeriod period) {
    final h12 = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    return (h12 % 12) + (period == DayPeriod.pm ? 12 : 0);
  }

  void _confirm(AppLocalizations l) {
    final start = _parse(_startText.text);
    final end = _parse(_endText.text);
    if (start == null || end == null) {
      setState(() => _error = l.schedTimeRangeInvalid);
      return;
    }
    if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
      setState(() => _error = l.schedEndBeforeStart);
      return;
    }
    Navigator.of(context).pop((start, end));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l.schedTimeRangeTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // 키보드로 바로 적는 한 줄 — 시작 시간 - 종료 시간.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _TimeTextField(
                        key: const ValueKey<String>(
                          'session-time-range-start-input',
                        ),
                        label: l.schedFieldStart,
                        controller: _startText,
                        onSubmitted: (raw) {
                          final parsed = _parse(raw);
                          if (parsed != null) _setStart(parsed);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(
                        top: 30,
                        left: AppSpacing.xs,
                        right: AppSpacing.xs,
                      ),
                      child: Text(
                        '-',
                        style: TextStyle(color: AppColors.subtleForeground),
                      ),
                    ),
                    Expanded(
                      child: _TimeTextField(
                        key: const ValueKey<String>(
                          'session-time-range-end-input',
                        ),
                        label: l.schedFieldEnd,
                        controller: _endText,
                        onSubmitted: (raw) {
                          final parsed = _parse(raw);
                          if (parsed != null) _setEnd(parsed);
                        },
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.destructive,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _DialClock(
                  keyPrefix: 'session-time-range-start-dial',
                  label: l.schedFieldStart,
                  time: _start,
                  onHourTap: _onStartHourTap,
                  onPeriodChanged: _setStartPeriod,
                ),
                const SizedBox(height: AppSpacing.lg),
                _DialClock(
                  keyPrefix: 'session-time-range-end-dial',
                  label: l.schedFieldEnd,
                  time: _end,
                  onHourTap: _onEndHourTap,
                  onPeriodChanged: _setEndPeriod,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey<String>(
                          'session-time-range-cancel',
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l.actionCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey<String>(
                          'session-time-range-confirm',
                        ),
                        onPressed: () => _confirm(l),
                        child: Text(l.schedTimeRangeConfirm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: DialogCloseButton(
              tooltip: l.actionClose,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTextField extends StatelessWidget {
  const _TimeTextField({
    required this.label,
    required this.controller,
    required this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.datetime,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
        LengthLimitingTextInputFormatter(5),
      ],
      decoration: InputDecoration(labelText: label, isDense: true),
      onSubmitted: onSubmitted,
      onTapOutside: (_) => onSubmitted(controller.text),
    );
  }
}

class _DialClock extends StatelessWidget {
  const _DialClock({
    required this.keyPrefix,
    required this.label,
    required this.time,
    required this.onHourTap,
    required this.onPeriodChanged,
  });

  final String keyPrefix;
  final String label;
  final TimeOfDay time;
  final ValueChanged<int> onHourTap;
  final ValueChanged<DayPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PeriodToggle(
          keyPrefix: keyPrefix,
          period: time.period,
          amLabel: l.slotAm,
          pmLabel: l.slotPm,
          onChanged: onPeriodChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        HourClockDial(
          keyPrefix: keyPrefix,
          hour12: hour12,
          onChanged: onHourTap,
        ),
      ],
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.keyPrefix,
    required this.period,
    required this.amLabel,
    required this.pmLabel,
    required this.onChanged,
  });

  final String keyPrefix;
  final DayPeriod period;
  final String amLabel;
  final String pmLabel;
  final ValueChanged<DayPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PeriodButton(
          key: ValueKey<String>('$keyPrefix-period-am'),
          label: amLabel,
          selected: period == DayPeriod.am,
          onTap: () => onChanged(DayPeriod.am),
        ),
        const SizedBox(width: AppSpacing.xs),
        _PeriodButton(
          key: ValueKey<String>('$keyPrefix-period-pm'),
          label: pmLabel,
          selected: period == DayPeriod.pm,
          onTap: () => onChanged(DayPeriod.pm),
        ),
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSurface : AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.accent : AppColors.subtleForeground,
            ),
          ),
        ),
      ),
    );
  }
}
