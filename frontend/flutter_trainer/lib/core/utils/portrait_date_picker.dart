import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';

/// 앱 전역에서 날짜 하나를 고르는 공용 달력 모달.
///
/// Material 기본 [showDatePicker] 는 하단에 취소/확인 텍스트 버튼을 나란히
/// 두고, 트레이너 웹처럼 늘 넓은 화면에서는 달력을 좌우로 나눈 landscape
/// 모양으로 바꾼다. 이 화면은 그 대신 [CalendarDatePicker](Material 이
/// 그리드에만 쓰는 하위 위젯)를 직접 감싸, 앱의 시간 선택기와 같은 우측
/// 상단 X 로 닫고 확인 버튼 하나만 그리드 바로 아래 둔다 — 취소는 X
/// 하나로 충분하고, CalendarDatePicker 자체는 orientation 에 따라 모양을
/// 바꾸지 않아 별도 세로 고정 트릭도 필요 없다.
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

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations l = MaterialLocalizations.of(context);
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
                    tooltip: l.closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              CalendarDatePicker(
                initialDate: widget.initialDate,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                onDateChanged: (DateTime date) =>
                    setState(() => _selected = date),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('portraitDatePickerConfirm'),
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text(l.okButtonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
