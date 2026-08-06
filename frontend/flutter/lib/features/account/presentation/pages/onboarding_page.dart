import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/auth/presentation/widgets/auth_fields.dart';

/// First-run onboarding — a 3-step wizard shown right after sign-up.
/// Collects basic info → chronic conditions → health goals, then
/// POST /users/me/onboarding and enters the app. Fully skippable.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const int _steps = 3;
  static const List<String> _conditionOptions = <String>[
    '고혈압',
    '당뇨',
    '고지혈증',
    '비만',
  ];

  final PageController _pager = PageController();
  int _step = 0;
  bool _saving = false;

  final TextEditingController _birthDate = TextEditingController();
  String? _gender; // 'male' | 'female' | 'other'
  final TextEditingController _height = TextEditingController();
  final Set<String> _conditions = <String>{};
  final TextEditingController _dailySodium = TextEditingController();

  @override
  void dispose() {
    _pager.dispose();
    _birthDate.dispose();
    _height.dispose();
    _dailySodium.dispose();
    super.dispose();
  }

  num? _num(TextEditingController c) => num.tryParse(c.text.trim());
  int? _int(TextEditingController c) => int.tryParse(c.text.trim());

  void _next() {
    if (_step < _steps - 1) {
      _pager.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _back() {
    if (_step > 0) {
      _pager.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _skip() => context.go(AppRoutes.dashboard);

  Future<void> _finish() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final birth = _birthDate.text.trim();
      await ref
          .read(accountRepositoryProvider)
          .submitOnboarding(
            birthDate: birth.isEmpty ? null : birth,
            gender: _gender,
            heightCm: _num(_height),
            conditions: _conditions.isEmpty ? null : _conditions.join(', '),
            dailySodiumMg: _int(_dailySodium),
          );
      ref.invalidate(profileProvider);
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('저장에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _steps - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    '${_step + 1} / $_steps',
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mutedForeground,
                    ),
                    child: const Text('나중에 하기'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _steps,
                  minHeight: 6,
                  backgroundColor: AppColors.inputBackground,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: <Widget>[
                  _stepBasic(),
                  _stepConditions(),
                  _stepGoals(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  if (_step > 0) ...<Widget>[
                    OutlinedButton(
                      onPressed: _saving ? null : _back,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('이전'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: AuthGradientButton(
                      loading: _saving,
                      label: isLast ? '완료' : '다음',
                      onTap: isLast ? _finish : _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
    );
  }

  Widget _stepBasic() {
    return _stepBody(
      title: '기본 정보',
      subtitle: '맞춤 건강 관리를 위해 기본 정보를 알려주세요.',
      children: <Widget>[
        AuthField(
          controller: _birthDate,
          hint: '생년월일 (YYYY-MM-DD)',
          icon: Icons.cake_outlined,
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: AppSpacing.md),
        _GenderSelector(
          value: _gender,
          onChanged: (g) => setState(() => _gender = g),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthField(
          controller: _height,
          hint: '키 (cm)',
          icon: Icons.straighten,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _stepConditions() {
    return _stepBody(
      title: '건강 상태',
      subtitle: '관리 중인 만성질환을 선택해 주세요. (복수 선택 가능)',
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final String c in _conditionOptions)
              FilterChip(
                label: Text(c),
                selected: _conditions.contains(c),
                onSelected: (sel) => setState(() {
                  if (sel) {
                    _conditions.add(c);
                  } else {
                    _conditions.remove(c);
                  }
                }),
                selectedColor: AppColors.accent,
                checkmarkColor: AppColors.secondary,
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepGoals() {
    return _stepBody(
      title: '건강 목표',
      subtitle: '달성하고 싶은 목표를 입력해 주세요. 나중에 바꿀 수 있어요.',
      children: <Widget>[
        AuthField(
          controller: _dailySodium,
          hint: '하루 나트륨 목표 (mg)',
          icon: Icons.spa_outlined,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  static const Map<String, String> _labels = <String, String>{
    'male': '남성',
    'female': '여성',
    'other': '기타',
  };

  @override
  Widget build(BuildContext context) {
    final entries = _labels.entries.toList();
    return Row(
      children: <Widget>[
        for (int i = 0; i < entries.length; i++) ...<Widget>[
          Expanded(
            child: ChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: Text(entries[i].value, textAlign: TextAlign.center),
              ),
              selected: value == entries[i].key,
              onSelected: (_) => onChanged(entries[i].key),
              selectedColor: AppColors.accent,
            ),
          ),
          if (i < entries.length - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}
