import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/design_system/tokens/toast.dart';

typedef TimeRangeValue = ({TimeOfDay start, TimeOfDay end});

Future<TimeRangeValue?> showScheduleTimeRangePicker({
  required BuildContext context,
  required TimeOfDay start,
  required TimeOfDay end,
}) => showDialog<TimeRangeValue>(
  context: context,
  builder: (_) => _TimeRangePickerDialog(start: start, end: end),
);

/// 시 → 분 → 종료 시 → 종료 분을 한 시계에서 고르는 범위 선택기.
/// 기본 Material 시간 선택기의 검은 윤곽선을 쓰지 않고 스케줄 화면의 옅은
/// 채움과 브랜드 남색만 사용한다.
class _TimeRangePickerDialog extends StatefulWidget {
  const _TimeRangePickerDialog({required this.start, required this.end});

  final TimeOfDay start;
  final TimeOfDay end;

  @override
  State<_TimeRangePickerDialog> createState() => _TimeRangePickerDialogState();
}

class _TimeRangePickerDialogState extends State<_TimeRangePickerDialog> {
  late TimeOfDay _start = widget.start;
  late TimeOfDay _end = widget.end;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  int _step = 0;

  bool get _isStart => _step < 2;
  bool get _isHour => _step.isEven;
  TimeOfDay get _active => _isStart ? _start : _end;

  String _clock(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: _clock(_start));
    _endController = TextEditingController(text: _clock(_end));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _syncFields() {
    _startController.text = _clock(_start);
    _endController.text = _clock(_end);
  }

  void _readField(String text, {required bool start}) {
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(text.trim());
    if (match == null) return;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return;
    setState(() {
      final value = TimeOfDay(hour: hour, minute: minute);
      if (start) {
        _start = value;
        _step = 0;
      } else {
        _end = value;
        _step = 2;
      }
    });
  }

  void _select(int value) {
    _setActiveValue(value, advance: true);
  }

  void _preview(int value) {
    _setActiveValue(value, advance: false);
  }

  void _setActiveValue(int value, {required bool advance}) {
    final current = _active;
    final next = _isHour
        ? TimeOfDay(hour: value, minute: current.minute)
        : TimeOfDay(hour: current.hour, minute: value);
    setState(() {
      if (_isStart) {
        _start = next;
      } else {
        _end = next;
      }
      if (advance && _step < 3) _step++;
      _syncFields();
    });
  }

  void _setPeriod(bool pm) {
    final current = _active;
    final hour = current.hour % 12 + (pm ? 12 : 0);
    setState(() {
      final next = TimeOfDay(hour: hour, minute: current.minute);
      if (_isStart) {
        _start = next;
      } else {
        _end = next;
      }
      _syncFields();
    });
  }

  @override
  Widget build(BuildContext context) {
    final endMinutes = _end.hour * 60 + _end.minute;
    final startMinutes = _start.hour * 60 + _start.minute;
    return Dialog(
      // 위쪽만 [AppToastStyle.dialogTopClearance] — 상단 토스트가 이
      // 대화상자 위로 겹쳐 뜰 수 있다.
      insetPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppToastStyle.dialogTopClearance,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '시간 선택',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _valueBox(
                      '시작 시간',
                      _startController,
                      _isStart,
                      key: const ValueKey<String>(
                        'session-time-range-start-input',
                      ),
                      onTap: () => setState(() => _step = 0),
                      onSubmitted: (value) => _readField(value, start: true),
                    ),
                  ),
                  const SizedBox(
                    width: 28,
                    child: Center(
                      child: Text('–', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  Expanded(
                    child: _valueBox(
                      '종료 시간',
                      _endController,
                      !_isStart,
                      key: const ValueKey<String>(
                        'session-time-range-end-input',
                      ),
                      onTap: () => setState(() => _step = 2),
                      onSubmitted: (value) => _readField(value, start: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 48,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_isStart ? '시작' : '종료'} ${_isHour ? '시' : '분'}',
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_step > 0) ...<Widget>[
                      IconButton(
                        key: const ValueKey<String>('time-range-back'),
                        tooltip: '이전 단계',
                        onPressed: () => setState(() => _step--),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        key: const ValueKey<String>('time-range-next'),
                        tooltip: '다음 단계',
                        onPressed: _step < 3
                            ? () => setState(() => _step++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Visibility(
                      visible: _isHour,
                      maintainAnimation: true,
                      maintainSize: true,
                      maintainState: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _periodButton('오전', false),
                          const SizedBox(width: AppSpacing.sm),
                          _periodButton('오후', true),
                        ],
                      ),
                    ),
                    if (_step == 3 && endMinutes < startMinutes)
                      const Text(
                        '종료 시간이 시작 시간보다 빠릅니다',
                        key: ValueKey<String>('time-range-invalid-end'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.destructive,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ClockFace(
                key: ValueKey<String>('time-range-step-$_step'),
                isHour: _isHour,
                selected: _isHour ? _active.hour : _active.minute,
                onChanged: _preview,
                onSelected: _select,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>(
                        'session-time-range-confirm',
                      ),
                      onPressed: endMinutes > startMinutes
                          ? () => Navigator.pop(
                              context,
                              (start: _start, end: _end),
                            )
                          : null,
                      child: const Text('확인'),
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

  Widget _valueBox(
    String label,
    TextEditingController controller,
    bool active, {
    required Key key,
    required VoidCallback onTap,
    required ValueChanged<String> onSubmitted,
  }) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: active ? AppColors.accentSurface : AppColors.inputBackground,
      borderRadius: const BorderRadius.all(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: AppColors.mutedForeground)),
        TextField(
          key: key,
          controller: controller,
          onTap: onTap,
          onChanged: onSubmitted,
          onSubmitted: onSubmitted,
          onEditingComplete: () => onSubmitted(controller.text),
          keyboardType: TextInputType.datetime,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.primary : AppColors.foreground,
          ),
        ),
      ],
    ),
  );

  Widget _periodButton(String label, bool pm) {
    final active = (_active.hour >= 12) == pm;
    return Material(
      color: active ? AppColors.accentSurface : AppColors.inputBackground,
      borderRadius: const BorderRadius.all(AppRadius.sm),
      child: InkWell(
        key: ValueKey<String>('time-period-${pm ? 'pm' : 'am'}'),
        onTap: () => _setPeriod(pm),
        borderRadius: const BorderRadius.all(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.primary : AppColors.mutedForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockFace extends StatelessWidget {
  const _ClockFace({
    super.key,
    required this.isHour,
    required this.selected,
    required this.onChanged,
    required this.onSelected,
  });

  final bool isHour;
  final int selected;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: 280,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.inputBackground,
          shape: BoxShape.circle,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => onChanged(_valueAt(details.localPosition)),
          onPanEnd: (_) => onSelected(selected),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _ClockHandPainter(
                    index: isHour ? selected % 12 : (selected / 5).round() % 12,
                  ),
                ),
              ),
              for (var index = 0; index < 12; index++) _number(index),
            ],
          ),
        ),
      ),
    ),
  );

  int _valueAt(Offset position) {
    const center = Offset(140, 140);
    final delta = position - center;
    final raw = (math.atan2(delta.dy, delta.dx) + math.pi / 2) /
        (2 * math.pi) *
        12;
    final index = raw.round() % 12;
    if (!isHour) return index * 5;
    final displayHour = index == 0 ? 12 : index;
    return (displayHour % 12) + (selected >= 12 ? 12 : 0);
  }

  Widget _number(int index) {
    final value = isHour ? (index == 0 ? 12 : index) : index * 5;
    final angle = index * math.pi / 6 - math.pi / 2;
    const size = 44.0;
    const center = 140.0;
    const radius = 108.0;
    final active = isHour ? (selected % 12 == value % 12) : selected == value;
    return Positioned(
      left: center + math.cos(angle) * radius - size / 2,
      top: center + math.sin(angle) * radius - size / 2,
      child: InkWell(
        key: ValueKey<String>('clock-value-$value'),
        customBorder: const CircleBorder(),
        onTap: () {
          if (isHour) {
            final isPm = selected >= 12;
            onSelected((value % 12) + (isPm ? 12 : 0));
          } else {
            onSelected(value);
          }
        },
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            isHour ? '$value' : value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active
                  ? AppColors.primaryForeground
                  : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockHandPainter extends CustomPainter {
  const _ClockHandPainter({required this.index});

  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final angle = index * math.pi / 6 - math.pi / 2;
    final end = center + Offset(math.cos(angle), math.sin(angle)) * 108;
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, end, paint);
    canvas.drawCircle(center, 5, paint);
  }

  @override
  bool shouldRepaint(_ClockHandPainter oldDelegate) =>
      oldDelegate.index != index;
}
