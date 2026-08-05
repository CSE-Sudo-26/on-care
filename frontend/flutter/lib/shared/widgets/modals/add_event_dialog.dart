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

String _todayString() {
  final now = DateTime.now();
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  return '${now.year}-$mm-$dd';
}

class _AddEventDialog extends ConsumerStatefulWidget {
  const _AddEventDialog();
  @override
  ConsumerState<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends ConsumerState<_AddEventDialog> {
  final TextEditingController _title = TextEditingController();
  late final TextEditingController _date = TextEditingController(
    text: _todayString(),
  );
  final TextEditingController _time = TextEditingController();
  String _category = _categoryMap.keys.first;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final title = _title.text.trim();
    final date = _date.text.trim();
    if (title.isEmpty || date.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('제목과 날짜를 입력해 주세요')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .createEvent(
            date: date,
            time: _time.text.trim(),
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
              AppInput(controller: _date, label: '날짜', hint: '2026-05-14'),
              const SizedBox(height: AppSpacing.sm),
              AppInput(controller: _time, label: '시간', hint: '10:00'),
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
