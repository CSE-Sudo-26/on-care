import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/atoms/app_card.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';

enum DietEntryDetailResult { updated, deleted }

const Map<MealType, String> _mealLabels = <MealType, String>{
  MealType.breakfast: '아침',
  MealType.lunch: '점심',
  MealType.dinner: '저녁',
  MealType.snack: '간식',
};

class DietEntryDetailPage extends ConsumerStatefulWidget {
  const DietEntryDetailPage({required this.entry, super.key});

  final DietEntry entry;

  @override
  ConsumerState<DietEntryDetailPage> createState() =>
      _DietEntryDetailPageState();
}

class _DietEntryDetailPageState extends ConsumerState<DietEntryDetailPage> {
  final _formKey = GlobalKey<FormState>();
  late MealType _mealType = widget.entry.mealType;
  late final TextEditingController _timeController = TextEditingController(
    text: widget.entry.timeLabel,
  );
  late final TextEditingController _sodiumController = TextEditingController(
    text: widget.entry.sodiumMg.toString(),
  );
  late final TextEditingController _sugarController = TextEditingController(
    text: widget.entry.sugarG.toString(),
  );
  late final List<_FoodControllers> _foods = widget.entry.foods
      .map(_FoodControllers.fromFood)
      .toList();
  bool _saving = false;
  bool _deleting = false;

  bool get _busy => _saving || _deleting;
  bool get _canPersist => widget.entry.id != null;

  @override
  void dispose() {
    _timeController.dispose();
    _sodiumController.dispose();
    _sugarController.dispose();
    for (final _FoodControllers food in _foods) {
      food.dispose();
    }
    super.dispose();
  }

  int? get _currentCalories {
    if (_foods.isEmpty) return widget.entry.totalCalories;
    var total = 0;
    for (final _FoodControllers food in _foods) {
      final calories = int.tryParse(food.calories.text.trim());
      if (calories == null) return null;
      total += calories;
    }
    return total;
  }

  Future<void> _save() async {
    if (_busy) return;
    final id = widget.entry.id;
    if (id == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final foods = _foods
        .map(
          (_FoodControllers food) => FoodItem(
            name: food.name.text.trim(),
            calories: int.parse(food.calories.text.trim()),
          ),
        )
        .toList();
    final totalCalories = foods.fold<int>(
      0,
      (int sum, FoodItem food) => sum + food.calories,
    );

    setState(() => _saving = true);
    try {
      await ref
          .read(dietRepositoryProvider)
          .updateEntry(
            id: id,
            mealType: _mealType.name,
            timeLabel: _timeController.text.trim(),
            foods: foods,
            totalCalories: totalCalories,
            sodiumMg: int.parse(_sodiumController.text.trim()),
            // validate() 게이트를 통과했으므로 파싱은 안전(잘못된 값은 저장 전 차단).
            sugarG: double.parse(_sugarController.text.trim()),
          );
      ref.invalidate(dietTodayProvider);
      navigator.pop(DietEntryDetailResult.updated);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('수정에 실패했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    if (_busy) return;
    final id = widget.entry.id;
    if (id == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('식단 기록 삭제'),
        content: const Text('이 식단 기록을 삭제할까요?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    await _delete(id);
  }

  Future<void> _delete(String id) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      await ref.read(dietRepositoryProvider).deleteEntry(id);
      ref.invalidate(dietTodayProvider);
      navigator.pop(DietEntryDetailResult.deleted);
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('삭제에 실패했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calories = _currentCalories;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('식단 상세'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            140,
          ),
          children: <Widget>[
            _TopInfo(
              mealLabel: _mealLabels[_mealType]!,
              timeLabel: _timeController.text.trim(),
            ),
            const SizedBox(height: AppSpacing.md),
            _SummarySection(
              caloriesLabel: calories == null ? '-' : '$calories kcal',
              sodiumLabel: _nutrientLabel(_sodiumController.text, 'mg'),
              sugarLabel: _nutrientLabel(
                _sugarController.text,
                'g',
                decimal: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: '음식 정보',
              child: _foods.isEmpty
                  ? Text(
                      '인식된 음식 정보가 없어요.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    )
                  : Column(
                      children: <Widget>[
                        for (var i = 0; i < _foods.length; i++) ...<Widget>[
                          _FoodFields(
                            index: i,
                            controllers: _foods[i],
                            onChanged: () => setState(() {}),
                          ),
                          if (i != _foods.length - 1)
                            const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: '영양 정보',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _NumberField(
                          controller: _sodiumController,
                          label: '총 나트륨',
                          suffixText: 'mg',
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _NumberField(
                          controller: _sugarController,
                          label: '총 당류',
                          suffixText: 'g',
                          decimal: true,
                          fieldKey: const Key('sugarField'),
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'AI 분석 결과를 바탕으로 한 식사 전체 영양 정보예요.\n'
                    '필요한 경우 직접 수정할 수 있어요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: '식사 정보',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final MealType mealType in MealType.values)
                        ChoiceChip(
                          label: Text(_mealLabels[mealType]!),
                          selected: _mealType == mealType,
                          selectedColor: AppColors.accent,
                          onSelected: _busy
                              ? null
                              : (_) => setState(() => _mealType = mealType),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _FieldLabel('식사 시간'),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _timeController,
                        validator: _mealTimeValidator,
                        keyboardType: TextInputType.datetime,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '예: 12:40',
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || !_canPersist ? null : _confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(AppRadius.lg),
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _deleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('삭제하기'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _busy || !_canPersist ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(AppRadius.lg),
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('수정 완료'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _nutrientLabel(String raw, String unit, {bool decimal = false}) {
  final String trimmed = raw.trim();
  if (decimal) {
    final double? value = double.tryParse(trimmed);
    if (value == null) return '-';
    // 정수면 정수로, 소수면 그대로(예: 14 / 8.5).
    final String text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return '$text$unit';
  }
  final int? value = int.tryParse(trimmed);
  if (value == null) return '-';
  return '$value$unit';
}

String? _requiredText(String? value) {
  if (value == null || value.trim().isEmpty) return '값을 입력해 주세요.';
  return null;
}

String? _nonNegativeNumber(String? value) {
  if (value == null || value.trim().isEmpty) return '숫자를 입력해 주세요.';
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < 0) return '0 이상의 숫자만 입력해 주세요.';
  return null;
}

/// 당류 등 소수 필드용. 파싱 실패(예: "8.5.3", 빈 값)나 음수면 안내 메시지를
/// 돌려줘 저장을 막는다(이전엔 double.tryParse(...) ?? 0 으로 조용히 0 저장됨).
String? _nonNegativeDecimal(String? value) {
  if (value == null || value.trim().isEmpty) return '숫자를 입력해 주세요.';
  final parsed = double.tryParse(value.trim());
  if (parsed == null || parsed < 0) return '0 이상의 숫자만 입력해 주세요.';
  return null;
}

String? _mealTimeValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '식사 시간을 입력해 주세요.';
  final isValid = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text);
  if (!isValid) return '식사 시간은 HH:mm 형식으로 입력해 주세요.';
  return null;
}

class _FoodControllers {
  _FoodControllers({required String name, required int calories})
    : name = TextEditingController(text: name),
      calories = TextEditingController(text: calories.toString());

  factory _FoodControllers.fromFood(FoodItem food) {
    return _FoodControllers(name: food.name, calories: food.calories);
  }

  final TextEditingController name;
  final TextEditingController calories;

  void dispose() {
    name.dispose();
    calories.dispose();
  }
}

class _TopInfo extends StatelessWidget {
  const _TopInfo({required this.mealLabel, required this.timeLabel});

  final String mealLabel;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTime = timeLabel.isEmpty ? '-' : timeLabel;
    return Text(
      '$mealLabel · $displayTime',
      style: theme.textTheme.titleMedium?.copyWith(
        color: AppColors.mutedForeground,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.caloriesLabel,
    required this.sodiumLabel,
    required this.sugarLabel,
  });

  final String caloriesLabel;
  final String sodiumLabel;
  final String sugarLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      outlined: true,
      color: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            caloriesLabel,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '나트륨 $sodiumLabel · 당류 $sugarLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      outlined: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _FoodFields extends StatelessWidget {
  const _FoodFields({
    required this.index,
    required this.controllers,
    required this.onChanged,
  });

  final int index;
  final _FoodControllers controllers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '음식 ${index + 1}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _FieldLabel('음식명'),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: controllers.name,
                    validator: _requiredText,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: '음식명',
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(AppRadius.lg),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: _NumberField(
                controller: controllers.calories,
                label: '칼로리',
                suffixText: 'kcal',
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffixText,
    required this.onChanged,
    this.decimal = false,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final String suffixText;
  final VoidCallback onChanged;

  /// 테스트에서 이 입력 필드를 특정하기 위한 키(선택).
  final Key? fieldKey;

  /// 당류처럼 소수(예: 8.5g)를 받는 필드면 true. 소수점 입력을 허용하고
  /// 소수 검증기를 쓴다(정수 전용 필드는 digitsOnly + 정수 검증기).
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(label),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          key: fieldKey,
          controller: controller,
          validator: decimal ? _nonNegativeDecimal : _nonNegativeNumber,
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            decimal
                ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                : FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: suffixText,
            filled: true,
            fillColor: AppColors.inputBackground,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.mutedForeground,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
