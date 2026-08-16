import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/atoms/app_button.dart';
import 'package:oncare/design_system/atoms/app_input.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';
import 'package:oncare/features/schedule/presentation/controllers/schedule_controller.dart';

const Map<String, ScheduleCategory> _categoryMap = <String, ScheduleCategory>{
  '병원': ScheduleCategory.hospital,
  '운동': ScheduleCategory.exercise,
  '식사': ScheduleCategory.meal,
  '약 복용': ScheduleCategory.medication,
  '기타': ScheduleCategory.other,
};

Future<void> showAddEventDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (BuildContext ctx) => const _AddEventDialog(),
  );
}

/// 서버 계약 형식(`YYYY-MM-DD`). 화면에는 로케일 형식으로 보여 주고, 나갈 때만
/// 이 형식으로 바꾼다 — 사용자가 형식을 맞출 일이 없어야 한다.
String wireDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 서버 계약 형식(`HH:mm`, 24시간). 시드 일정도 같은 형식이다.
String wireTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

class _AddEventDialog extends ConsumerStatefulWidget {
  const _AddEventDialog();
  @override
  ConsumerState<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends ConsumerState<_AddEventDialog> {
  final TextEditingController _title = TextEditingController();

  /// 날짜는 늘 값이 있다(기본 오늘). 피커로만 고르므로 형식이 어긋날 수 없다.
  DateTime _date = DateTime.now();

  /// 시간은 선택 항목이다 — 서버 계약에서도 빈 문자열을 허용한다.
  TimeOfDay? _time;

  String _category = _categoryMap.keys.first;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // 지난 일정도 기록할 수 있어야 하고, 앞으로도 넉넉히 잡을 수 있어야 한다.
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final title = _title.text.trim();
    // 날짜는 피커가 늘 채우므로 제목만 확인하면 된다.
    if (title.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('일정 제목을 입력해 주세요')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .createEvent(
            date: wireDate(_date),
            time: _time == null ? '' : wireTime(_time!),
            title: title,
            category: _categoryMap[_category] ?? ScheduleCategory.other,
          );
      // 오늘 일정이면 대시보드 "오늘의 일정"에 반영된다.
      ref.invalidate(dashboardSummaryProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('일정 추가에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '일정 추가',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Material(
                    color: AppColors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Icons.close, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppInput(controller: _title, label: '일정 제목', hint: '예: 병원 정기검진'),
              const SizedBox(height: AppSpacing.sm),
              // 날짜·시간은 직접 칠 수 없다. 예전에는 자유 입력이라 `2026/05/14`
              // 처럼 계약을 벗어난 값이 저장되고, 조회는 `YYYY-MM-DD` 를 전제해
              // 걸러 내서 넣은 일정이 어디에도 보이지 않았다(#785).
              _PickerField(
                key: const Key('addEventDate'),
                label: '날짜',
                value: MaterialLocalizations.of(context).formatMediumDate(_date),
                icon: Icons.calendar_today_outlined,
                onTap: _saving ? null : _pickDate,
              ),
              const SizedBox(height: AppSpacing.sm),
              _PickerField(
                key: const Key('addEventTime'),
                label: '시간',
                // 시간은 선택이라 비워 둘 수 있다. 비었다는 것을 값 자리에서
                // 그대로 말해 준다.
                value: _time == null
                    ? '시간 없음'
                    : MaterialLocalizations.of(
                        context,
                      ).formatTimeOfDay(_time!),
                muted: _time == null,
                icon: Icons.schedule_outlined,
                onTap: _saving ? null : _pickTime,
                onClear: _time == null || _saving
                    ? null
                    : () => setState(() => _time = null),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    onChanged: (String? value) {
                      if (value != null) setState(() => _category = value);
                    },
                    items: <DropdownMenuItem<String>>[
                      for (final String c in _categoryMap.keys)
                        DropdownMenuItem<String>(value: c, child: Text(c)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _saving ? '추가 중...' : '추가하기',
                fullWidth: true,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 눌러서 고르는 값 한 칸. [AppInput] 과 같은 테두리·라벨을 쓰되 글자를 직접
/// 칠 수는 없다 — 형식이 어긋난 값이 애초에 만들어지지 않게 하는 것이 목적이다.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
    this.muted = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  /// null 이면 저장 중이라 잠긴 상태다.
  final VoidCallback? onTap;

  /// 지울 수 있는 값(시간)일 때만 준다.
  final VoidCallback? onClear;

  /// 값이 비어 있음을 알리는 자리표시일 때 흐리게 그린다.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(AppRadius.md),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.mutedForeground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted
                      ? AppColors.mutedForeground
                      : AppColors.foreground,
                ),
              ),
            ),
            if (onClear != null)
              // 시각적 아이콘은 16 이지만 탭 영역은 접근성 최소치를 지킨다.
              Semantics(
                button: true,
                label: '$label 지우기',
                child: InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
