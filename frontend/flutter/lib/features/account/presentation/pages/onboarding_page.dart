import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/auth/presentation/widgets/auth_fields.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

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

  /// 만성질환 선택지 — **전송 값**이다.
  ///
  /// 서버는 이 값을 자유 텍스트로 저장하고 AI 코치가 '내 건강 기록' 으로 읽는다. 화면
  /// 로케일에 따라 저장되는 문자열이 달라지면 같은 사용자의 기록이 언어별로 갈라지므로,
  /// 값은 한국어로 고정하고 표시 문구만 번역한다.
  static const List<String> _conditionOptions = <String>[
    '고혈압',
    '당뇨',
    '고지혈증',
    '비만',
  ];

  /// 전송 값 → 화면에 보일 문구.
  String _conditionLabel(AppLocalizations l, String value) => switch (value) {
    '고혈압' => l.onboardConditionHypertension,
    '당뇨' => l.onboardConditionDiabetes,
    '고지혈증' => l.onboardConditionDyslipidemia,
    '비만' => l.onboardConditionObesity,
    _ => value,
  };

  final PageController _pager = PageController();
  int _step = 0;
  bool _saving = false;

  final TextEditingController _birthDate = TextEditingController();
  String? _gender; // 'male' | 'female' | 'other'
  final TextEditingController _height = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _goals = TextEditingController();
  final Set<String> _conditions = <String>{};
  final TextEditingController _dailySodium = TextEditingController();

  @override
  void dispose() {
    _pager.dispose();
    _birthDate.dispose();
    _height.dispose();
    _weight.dispose();
    _goals.dispose();
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
    final AppLocalizations l = AppLocalizations.of(context);
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
            weightKg: _num(_weight),
            conditions: _conditions.isEmpty ? null : _conditions.join(', '),
            goals: _goals.text.trim().isEmpty ? null : _goals.text.trim(),
            dailySodiumMg: _int(_dailySodium),
          );
      if (!mounted) return;
      ref.invalidate(profileProvider);
      context.go(AppRoutes.dashboard);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.onboardSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
                    onPressed: _saving ? null : _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mutedForeground,
                    ),
                    child: Text(l.onboardSkip),
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
                      child: Text(l.onboardPrevious),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: AuthGradientButton(
                      loading: _saving,
                      label: isLast ? l.onboardDone : l.onboardNext,
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
    final AppLocalizations l = AppLocalizations.of(context);
    return _stepBody(
      title: l.onboardBasicTitle,
      subtitle: l.onboardBasicSubtitle,
      children: <Widget>[
        AuthField(
          controller: _birthDate,
          hint: l.onboardBirthHint,
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
          hint: l.onboardHeightHint,
          icon: Icons.straighten,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthField(
          controller: _weight,
          hint: l.onboardWeightHint,
          icon: Icons.monitor_weight_outlined,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _stepConditions() {
    final AppLocalizations l = AppLocalizations.of(context);
    return _stepBody(
      title: l.onboardHealthTitle,
      subtitle: l.onboardHealthSubtitle,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final String c in _conditionOptions)
              FilterChip(
                label: Text(_conditionLabel(l, c)),
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
    final AppLocalizations l = AppLocalizations.of(context);
    return _stepBody(
      title: l.onboardGoalTitle,
      subtitle: l.onboardGoalSubtitle,
      children: <Widget>[
        AuthField(
          controller: _goals,
          hint: l.onboardGoalHint,
          icon: Icons.flag_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthField(
          controller: _dailySodium,
          hint: l.onboardSodiumGoalHint,
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

  /// 전송 값은 이미 영문 코드라 그대로 두고 문구만 로케일을 따른다.
  static Map<String, String> _labelsOf(AppLocalizations l) => <String, String>{
    'male': l.onboardGenderMale,
    'female': l.onboardGenderFemale,
    'other': l.onboardGenderOther,
  };

  @override
  Widget build(BuildContext context) {
    final entries = _labelsOf(AppLocalizations.of(context)).entries.toList();
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
