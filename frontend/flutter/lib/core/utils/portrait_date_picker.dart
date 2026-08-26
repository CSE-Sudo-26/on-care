import 'package:flutter/material.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';

/// 앱 전역에서 날짜 하나를 고르는 공용 달력 모달.
///
/// Material 기본 [showDatePicker] 는 넓은 화면에서 달력을 좌우로 나눈
/// landscape 모양으로 바꾼다. 이 화면은 그 대신 [CalendarDatePicker]
/// (Material 이 그리드에만 쓰는 하위 위젯)를 직접 감싸 늘 세로 배치로
/// 그린다 — CalendarDatePicker 자체는 orientation 에 따라 모양을 바꾸지
/// 않아 별도 세로 고정 트릭이 필요 없다. 우측 상단 X 와 하단 취소·확인
/// 버튼을 모두 둔다 — 앱의 다른 모달과 같은 X 로도 닫히고, 하단
/// 취소·확인은 다른 다이얼로그 액션과 같은 자리를 유지한다.
///
/// Material 기본 다이얼로그처럼 연필 아이콘으로 그리드([CalendarDatePicker])
/// ↔ 키보드 직접 입력([InputDatePickerFormField]) 을 전환할 수 있다.
Future<DateTime?> showPortraitDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black54,
    builder: (BuildContext ctx) => _PortraitDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _PortraitDatePickerDialog extends StatefulWidget {
  const _PortraitDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_PortraitDatePickerDialog> createState() =>
      _PortraitDatePickerDialogState();
}

class _PortraitDatePickerDialogState extends State<_PortraitDatePickerDialog> {
  late DateTime _selected = widget.initialDate;
  final GlobalKey<FormState> _inputFormKey = GlobalKey<FormState>();
  DatePickerEntryMode _entryMode = DatePickerEntryMode.calendar;

  void _toggleEntryMode() {
    setState(() {
      _entryMode = _entryMode == DatePickerEntryMode.calendar
          ? DatePickerEntryMode.input
          : DatePickerEntryMode.calendar;
    });
  }

  void _confirm() {
    if (_entryMode == DatePickerEntryMode.input) {
      final FormState? form = _inputFormKey.currentState;
      if (form == null || !form.validate()) return;
      form.save();
    }
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations l = MaterialLocalizations.of(context);
    final bool isCalendar = _entryMode == DatePickerEntryMode.calendar;
    return Dialog(
      key: const Key('portraitDatePicker'),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l.datePickerHelpText,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: isCalendar
                        ? l.inputDateModeButtonLabel
                        : l.calendarModeButtonLabel,
                    icon: Icon(isCalendar ? Icons.edit : Icons.calendar_today),
                    onPressed: _toggleEntryMode,
                  ),
                  Material(
                    color: AppColors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Tooltip(
                        message: l.closeButtonTooltip,
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(Icons.close, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isCalendar)
                CalendarDatePicker(
                  initialDate: widget.initialDate,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  onDateChanged: (DateTime date) =>
                      setState(() => _selected = date),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Form(
                    key: _inputFormKey,
                    child: InputDatePickerFormField(
                      initialDate: _selected,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      onDateSubmitted: (DateTime date) =>
                          setState(() => _selected = date),
                      onDateSaved: (DateTime date) =>
                          setState(() => _selected = date),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      key: const Key('portraitDatePickerCancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l.cancelButtonLabel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const Key('portraitDatePickerConfirm'),
                      onPressed: _confirm,
                      child: Text(l.okButtonLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
