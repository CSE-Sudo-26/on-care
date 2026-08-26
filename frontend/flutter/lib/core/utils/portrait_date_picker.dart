import 'package:flutter/material.dart';
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
/// 날짜 값 자체가 입력창이라 따로 전환할 필요 없이 타이핑도, 바로 아래
/// 달력([CalendarDatePicker])에서 탭으로 고르는 것도 둘 다 항상 된다.
/// 입력창에 타이핑하면 [MaterialLocalizations.parseCompactDate] 로 즉시
/// 해석해 달력도 같이 움직이고, 달력에서 고르면 입력창 글자도 같이 바뀐다.
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
  final TextEditingController _dateController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  /// 입력창 글자가 바뀔 때마다(키 입력마다) 유효한 날짜인지 확인해 곧장
  /// 반영한다 — 아래 달력이 입력과 같이 움직여야 한다.
  void _handleTextChanged(MaterialLocalizations l, String text) {
    if (text.isEmpty) {
      setState(() => _errorText = null);
      return;
    }
    final DateTime? parsed = l.parseCompactDate(text);
    if (parsed == null) {
      setState(() => _errorText = l.invalidDateFormatLabel);
      return;
    }
    if (parsed.isBefore(widget.firstDate) || parsed.isAfter(widget.lastDate)) {
      setState(() => _errorText = l.dateOutOfRangeLabel);
      return;
    }
    setState(() {
      _selected = parsed;
      _errorText = null;
    });
  }

  /// 달력 탭은 입력창의 글자도 같이 바꾼다 — 타이핑 쪽(`_handleTextChanged`)과
  /// 달리 이쪽은 사용자가 지금 커서를 두고 타이핑 중이 아니므로 컨트롤러
  /// 텍스트를 직접 덮어써도 된다.
  void _handleCalendarChanged(MaterialLocalizations l, DateTime date) {
    setState(() {
      _selected = date;
      _errorText = null;
      _dateController.text = l.formatCompactDate(date);
    });
  }

  void _confirm() {
    if (_errorText != null) return;
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations l = MaterialLocalizations.of(context);
    if (_dateController.text.isEmpty) {
      _dateController.text = l.formatCompactDate(_selected);
    }
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
        // 오류 문구가 뜨거나 화면이 낮으면 입력창+달력+버튼 전체 높이가
        // 다이얼로그보다 커질 수 있다 — 넘치는 대신 스크롤하게 한다.
        child: SingleChildScrollView(
          child: Padding(
            // 시간 선택 다이얼로그(`consult_time_range_picker.dart`)와 같은
            // 여백을 써서 두 다이얼로그의 크기 차이가 두드러지지 않게 한다.
            padding: const EdgeInsets.all(AppSpacing.xl),
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
                      tooltip: l.closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                // 날짜 값 자체가 입력창이다 — 따로 전환할 필요 없이 타이핑도,
                // 아래 달력 탭도 둘 다 바로 된다. 한쪽이 바뀌면 다른 쪽도
                // 같이 움직인다.
                TextField(
                  key: const Key('portraitDatePickerInput'),
                  controller: _dateController,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: l.dateInputLabel,
                    errorText: _errorText,
                  ),
                  onChanged: (String text) => _handleTextChanged(l, text),
                ),
                const SizedBox(height: AppSpacing.sm),
                CalendarDatePicker(
                  key: ValueKey<DateTime>(_selected),
                  initialDate: _selected,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  onDateChanged: (DateTime date) =>
                      _handleCalendarChanged(l, date),
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
      ),
    );
  }
}
