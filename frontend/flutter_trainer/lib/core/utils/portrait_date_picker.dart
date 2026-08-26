import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// 앱 전역에서 날짜 하나를 고르는 공용 달력 모달.
///
/// Material 기본 [showDatePicker] 는 트레이너 웹처럼 늘 넓은 화면에서는
/// 달력을 좌우로 나눈 landscape 모양으로 바꾼다. 이 화면은 그 대신
/// [CalendarDatePicker](Material 이 그리드에만 쓰는 하위 위젯)를 직접 감싸
/// 늘 세로 배치로 그린다 — CalendarDatePicker 자체는 orientation 에 따라
/// 모양을 바꾸지 않아 별도 세로 고정 트릭이 필요 없다. 앱의 시간
/// 선택기와 같은 우측 상단 X 와, 하단 취소·확인 버튼을 모두 둔다.
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
      backgroundColor: AppColors.card,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isCalendar
                        ? l.inputDateModeButtonLabel
                        : l.calendarModeButtonLabel,
                    onPressed: _toggleEntryMode,
                    icon: Icon(isCalendar ? Icons.edit : Icons.calendar_today),
                  ),
                  IconButton(
                    tooltip: l.closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
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

/// 반복 일정의 시작·종료 날짜를 한 번의 달력에서 고른다 — 위
/// [showPortraitDatePicker] 와 같은 자리에서 쓰이지만, Flutter 에는 그
/// 자체 커스텀 다이얼로그에 대응하는 공용 범위 선택 위젯이 없어 여기서는
/// Material 기본 [showDateRangePicker] 를 세로 배치로 강제해 쓴다.
Future<DateTimeRange?> showPortraitDateRangePicker({
  required BuildContext context,
  required DateTimeRange initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDateRangePicker(
    context: context,
    initialDateRange: initialDateRange,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) {
      final Widget themed = child!;
      final MediaQueryData query = MediaQuery.of(context);
      if (query.size.width <= query.size.height) return themed;
      return MediaQuery(
        data: query.copyWith(size: Size(query.size.height, query.size.width)),
        child: themed,
      );
    },
  );
}
