import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/account/domain/entities/goal_update.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/exercise/domain/entities/exercise_load.dart';
import 'package:oncare/features/my_health/domain/support_links.dart';
import 'package:oncare/features/notification/data/repositories/notification_settings_repository.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

/// 숫자 전용 입력 필터 — 붙여넣기/외부 키보드로 문자가 들어와 저장 시 int
/// 파싱이 null 로 날아가는 것을 막는다.
final List<TextInputFormatter> _digitsOnly = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

Widget _shell(
  BuildContext context,
  String title,
  List<Widget> children, {
  bool saving = false,
}) {
  final Widget page = Scaffold(
    key: const Key('mySettingsPage'),
    backgroundColor: Colors.white,
    appBar: AppBar(
      centerTitle: true,
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: FigmaColors.ink,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.contentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: children,
          ),
        ),
      ),
    ),
  );
  return PopScope(canPop: !saving, child: page);
}

Widget _card(List<Widget> children) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: FigmaColors.statBg,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  ),
);

/// Figma-styled label + editable text field used by the profile sheet.
/// White fill on the `statBg` card, brand-blue focus ring.
class _SheetField extends StatelessWidget {
  const _SheetField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.hintText,
    this.helperText,
    this.inputFormatters,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? hintText;

  /// 칸 아래 한 줄 안내. 값이 어디서 왔는지 말해야 할 때만 준다.
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;

  /// 사람이 친 글자만 올라온다 — 컨트롤러에 프로그램이 써 넣은 값은
  /// `onChanged` 를 부르지 않으므로, 서로 맞물린 칸끼리 되먹임이 생기지 않는다.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
            helperText: helperText,
            helperMaxLines: 2,
            helperStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: FigmaColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: FigmaColors.primary,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The gradient profile disc with the member's initial.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[FigmaColors.primary, FigmaColors.primaryDeep],
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Spinner shown inside a sheet while `profileProvider` is loading.
/// 프로필을 못 읽었을 때의 화면.
///
/// 예전에는 빈 [UserProfile] 로 폼을 그렸다. 화면만 보면 조회 성공과 구별되지
/// 않아, 기본값이 내 설정인 것처럼 보이고 그대로 저장하면 서버에 있던 실제 값이
/// 기본값으로 덮였다(#789). 읽지 못했으면 읽지 못했다고 말하고, 저장 자체를
/// 막는 것이 맞다.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.cloud_off_rounded,
            size: 32,
            color: FigmaColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            l.mySettingsLoadFailed,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.mySettingsLoadFailedBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('mySettingsRetry'),
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.primary,
              side: BorderSide(color: FigmaColors.primaryA(0.4)),
              minimumSize: const Size(48, 44),
            ),
            child: Text(l.actionRetry),
          ),
        ],
      ),
    );
  }
}

class _SheetLoader extends StatelessWidget {
  const _SheetLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(color: FigmaColors.primary),
      ),
    );
  }
}

/// The 취소 · 저장 footer shared by the profile and goal sheets. The primary
/// button shows a spinner and both buttons disable while [saving].
Widget _saveRow({
  required BuildContext context,
  required bool saving,
  required VoidCallback onSave,
}) {
  final AppLocalizations l = AppLocalizations.of(context);
  return Row(
    children: <Widget>[
      Expanded(
        child: OutlinedButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mutedForeground,
            side: const BorderSide(color: FigmaColors.hairline),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            l.myCancel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: saving ? null : onSave,
          style: FilledButton.styleFrom(
            backgroundColor: FigmaColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  l.mySave,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    ],
  );
}

// ───────────────────────────────────────────────────────── 내 프로필 ──

/// Profile editor — pre-fills from `profileProvider` and persists via
/// `AccountRepository.updateProfile`.
Future<void> openProfilePage(BuildContext context) {
  return context.push<void>(AppRoutes.mySettingsPath('profile'));
}

class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);
    return profile.when(
      data: (UserProfile p) => _ProfileForm(initial: p),
      loading: () =>
          _shell(context, l.myProfileTitle, const <Widget>[_SheetLoader()]),
      // 건강 목표와 같은 이유로 폼을 그리지 않는다 — 빈 프로필을 저장하면
      // 이름·연락처가 지워진다(#789).
      error: (_, _) => _shell(context, l.myProfileTitle, <Widget>[
        _LoadFailed(onRetry: () => ref.invalidate(profileProvider)),
      ]),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.initial});
  final UserProfile initial;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.initial.email,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initial.phone,
  );
  late final TextEditingController _birth = TextEditingController(
    text: widget.initial.birthDate,
  );
  // 성별은 비워 두지 않는다 (#1140) — 고르지 않은 채로 두면 이 회원이 무엇을
  // 골랐는지와 아직 안 골랐는지가 화면에서 같아 보인다.
  late String _gender = widget.initial.gender.isEmpty
      ? 'male'
      : widget.initial.gender;
  late final TextEditingController _height = TextEditingController(
    text: widget.initial.heightCm?.toString() ?? '',
  );
  late final TextEditingController _weight = TextEditingController(
    text: widget.initial.weightKg?.toString() ?? '',
  );
  late final TextEditingController _goals = TextEditingController(
    text: widget.initial.goals,
  );
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _birth.dispose();
    _height.dispose();
    _weight.dispose();
    _goals.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            birthDate: _birth.text.trim(),
            gender: _gender,
            heightCm: num.tryParse(_height.text.trim()),
            weightKg: num.tryParse(_weight.text.trim()),
            goals: _goals.text.trim(),
          );
      // Sheet dismissed mid-save → don't touch ref/pop the page below.
      if (!mounted) return;
      ref.invalidate(profileProvider);
      navigator.pop();
      showAppToastVia(messenger, l.myProfileSaved, kind: AppToastKind.success);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      showAppToastVia(messenger, l.mySaveFailed, kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String name = widget.initial.name.trim();
    final String initial = name.isNotEmpty ? name.substring(0, 1) : '·';
    return _shell(context, l.myProfileTitle, <Widget>[
      Center(child: _Avatar(initial: initial)),
      const SizedBox(height: 16),
      _card(<Widget>[
        _SheetField(label: l.myFieldName, controller: _name),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myFieldEmail,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myFieldPhone,
          controller: _phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myFieldBirth,
          controller: _birth,
          hintText: '1996-03-21',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _gender.isEmpty ? null : _gender,
          decoration: InputDecoration(labelText: l.myFieldGender),
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'male', child: Text(l.onboardGenderMale)),
            DropdownMenuItem(
              value: 'female',
              child: Text(l.onboardGenderFemale),
            ),
            DropdownMenuItem(value: 'other', child: Text(l.onboardGenderOther)),
          ],
          onChanged: (value) => setState(() => _gender = value ?? ''),
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myFieldHeight,
          controller: _height,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myFieldWeight,
          controller: _weight,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _SheetField(label: l.myFieldGoals, controller: _goals),
      ]),
      const SizedBox(height: 16),
      _saveRow(context: context, saving: _saving, onSave: _save),
    ], saving: _saving);
  }
}

// ───────────────────────────────────────────────────────── 건강 목표 ──

/// 건강 목표 시트 — 식단 일일 목표(6종) + 주간 운동 목표(3종)를 수정한다.
/// 체중/혈압/혈당(vitals) 목표는 다루지 않는다.
Future<void> openGoalsPage(BuildContext context) {
  return context.push<void>(AppRoutes.mySettingsPath('goals'));
}

class HealthGoalsPage extends ConsumerWidget {
  const HealthGoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);
    return profile.when(
      data: (UserProfile p) => _GoalsForm(initial: p),
      loading: () =>
          _shell(context, l.myHealthGoalsTitle, const <Widget>[_SheetLoader()]),
      error: (_, _) => _shell(context, l.myHealthGoalsTitle, <Widget>[
        _LoadFailed(onRetry: () => ref.invalidate(profileProvider)),
      ]),
    );
  }
}

class _GoalsForm extends ConsumerStatefulWidget {
  const _GoalsForm({required this.initial});
  final UserProfile initial;

  @override
  ConsumerState<_GoalsForm> createState() => _GoalsFormState();
}

class _GoalsFormState extends ConsumerState<_GoalsForm> {
  late final TextEditingController _kcal = _ctl(widget.initial.dailyCalories);
  late final TextEditingController _sodium = _ctl(widget.initial.dailySodiumMg);
  late final TextEditingController _sugar = _ctl(widget.initial.dailySugarG);
  late final TextEditingController _carbs = _ctl(widget.initial.dailyCarbsG);
  late final TextEditingController _protein = _ctl(
    widget.initial.dailyProteinG,
  );
  late final TextEditingController _fat = _ctl(widget.initial.dailyFatG);
  // 운동 목표는 운동 탭이 견주는 축과 같다 (#1139) — 소모는 하루, 유형별은
  // 한 주다. 주간 운동 횟수·시간은 어느 화면도 쓰지 않아 뺐다.
  late final TextEditingController _burn = _ctl(widget.initial.dailyBurnKcal);
  late final TextEditingController _cardio = _ctl(
    widget.initial.weeklyCardioMinutes,
  );
  late final TextEditingController _strength = _ctl(
    widget.initial.weeklyStrengthSets,
  );
  late final TextEditingController _flexibility = _ctl(
    widget.initial.weeklyFlexibilityMinutes,
  );
  bool _saving = false;

  /// 칼로리 칸이 탄단지에서 계산돼 채워졌는가. 그 칸 아래 안내를 켜는 값이라,
  /// 회원이 칼로리를 직접 고치면 다시 꺼진다.
  ///
  /// 화면을 열자마자는 `false` 다 — 저장된 목표를 그대로 보여 줘야 하고,
  /// 들어온 것만으로 값이 달라지면 안 된다.
  bool _kcalFromMacros = false;

  /// 저장된 값을 그대로 담는다. **없으면 빈 칸으로 둔다.**
  ///
  /// 예전에는 기본값을 채웠다. 그러면 목표를 세운 적 없는 회원이 화면을 열고
  /// 저장만 해도 기본값이 진짜 목표로 굳는다 — `null` 은 *미설정 또는 목표
  /// 해제*라는 계약이 화면 한 번 열었다는 이유로 깨진다(PR #900 리뷰).
  /// 기본값은 이제 [_SheetField.hintText] 로만 비친다.
  static TextEditingController _ctl(int? value) =>
      TextEditingController(text: value == null ? '' : '$value');

  /// 탄·단·지 1g 의 열량(kcal). 식품 영양표시가 쓰는 Atwater 계수다.
  static const int _kcalPerCarbG = 4;
  static const int _kcalPerProteinG = 4;
  static const int _kcalPerFatG = 9;

  /// 칼로리만 아는 회원에게 권하는 배분. 한국인 영양섭취기준의 에너지 적정
  /// 비율(탄 55~65 · 단 7~20 · 지 15~30) 안쪽에서 고른 값이다.
  static const double _carbShare = 0.5;
  static const double _proteinShare = 0.3;
  static const double _fatShare = 0.2;

  /// 지금 칼로리 칸의 값. 숫자가 아니거나 0 이하면 null.
  int? get _kcalValue {
    final kcal = int.tryParse(_kcal.text.trim());
    return kcal == null || kcal <= 0 ? null : kcal;
  }

  /// 칼로리 칸 기준 권장 배분(g). 칼로리가 비어 있으면 null 이다.
  ///
  /// 상태로 들고 있지 않고 그때그때 센다 — 칼로리 칸이 바뀌면 배분도 반드시
  /// 함께 바뀌어야 하는데, 따로 저장해 두면 둘이 어긋날 자리가 생긴다.
  ({int carbs, int protein, int fat})? get _suggestedSplit {
    final kcal = _kcalValue;
    if (kcal == null) return null;
    return (
      carbs: (kcal * _carbShare / _kcalPerCarbG).round(),
      protein: (kcal * _proteinShare / _kcalPerProteinG).round(),
      fat: (kcal * _fatShare / _kcalPerFatG).round(),
    );
  }

  /// 세 칸이 이미 권장 배분과 같은가. 같으면 `권장 비율로 채우기` 를 띄우지
  /// 않는다 — 눌러도 달라질 것이 없는 버튼이다.
  bool get _macrosMatchSuggestion {
    final split = _suggestedSplit;
    if (split == null) return true;
    return _val(_carbs) == split.carbs &&
        _val(_protein) == split.protein &&
        _val(_fat) == split.fat;
  }

  /// 탄단지 → 칼로리. 세 칸이 모두 채워졌을 때만 칼로리를 다시 쓴다.
  ///
  /// 한 칸이라도 비어 있으면 손대지 않는다 — 지우는 도중의 빈 칸을 0g 으로
  /// 읽으면 칼로리가 잠깐 엉뚱한 값으로 튄다.
  void _syncCaloriesFromMacros() {
    final carbs = _val(_carbs);
    final protein = _val(_protein);
    final fat = _val(_fat);
    if (carbs == null || protein == null || fat == null) {
      setState(() => _kcalFromMacros = false);
      return;
    }
    final kcal =
        carbs * _kcalPerCarbG + protein * _kcalPerProteinG + fat * _kcalPerFatG;
    setState(() {
      _kcal.text = '$kcal';
      _kcalFromMacros = true;
    });
  }

  /// 권장 배분을 세 칸에 채운다.
  ///
  /// 채운 뒤 칼로리를 다시 계산한다 — 반올림 때문에 배분의 합이 입력한
  /// 칼로리와 몇 kcal 어긋나는데, 화면에 남은 두 값이 서로 맞지 않으면
  /// 어느 쪽이 참인지 알 수 없다.
  void _applySuggestedSplit() {
    final split = _suggestedSplit;
    if (split == null) return;
    _carbs.text = '${split.carbs}';
    _protein.text = '${split.protein}';
    _fat.text = '${split.fat}';
    _syncCaloriesFromMacros();
  }

  /// 네 칸이 이미 권장값과 같은가. 같으면 `권장 비율로 채우기` 를 띄우지
  /// 않는다 — 눌러도 달라질 것이 없는 버튼이다.
  bool get _exerciseGoalsMatchSuggestion =>
      _val(_burn) == kDefaultExerciseLoadGoals.dailyBurnKcal.round() &&
      _val(_cardio) == kDefaultExerciseLoadGoals.weeklyCardioMinutes.round() &&
      _val(_strength) == kDefaultExerciseLoadGoals.weeklyStrengthSets.round() &&
      _val(_flexibility) ==
          kDefaultExerciseLoadGoals.weeklyFlexibilityMinutes.round();

  /// 권장 운동 목표를 네 칸에 채운다.
  void _applySuggestedExerciseGoals() {
    setState(() {
      _burn.text = '${kDefaultExerciseLoadGoals.dailyBurnKcal.round()}';
      _cardio.text = '${kDefaultExerciseLoadGoals.weeklyCardioMinutes.round()}';
      _strength.text =
          '${kDefaultExerciseLoadGoals.weeklyStrengthSets.round()}';
      _flexibility.text =
          '${kDefaultExerciseLoadGoals.weeklyFlexibilityMinutes.round()}';
    });
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _kcal,
      _sodium,
      _sugar,
      _carbs,
      _protein,
      _fat,
      _burn,
      _cardio,
      _strength,
      _flexibility,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _val(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final UserProfile updatedProfile = await ref
          .read(accountRepositoryProvider)
          // 이 화면이 들고 있는 열 칸을 다 보낸다. 빈 칸은
          // `GoalUpdate(null)` 로 나가 서버에서 목표 해제가 된다 — 회원이 지운
          // 목표는 지워져야 한다.
          .updateHealthGoals(
            dailyCalories: GoalUpdate(_val(_kcal)),
            dailySodiumMg: GoalUpdate(_val(_sodium)),
            dailySugarG: GoalUpdate(_val(_sugar)),
            dailyCarbsG: GoalUpdate(_val(_carbs)),
            dailyProteinG: GoalUpdate(_val(_protein)),
            dailyFatG: GoalUpdate(_val(_fat)),
            dailyBurnKcal: GoalUpdate(_val(_burn)),
            weeklyCardioMinutes: GoalUpdate(_val(_cardio)),
            weeklyStrengthSets: GoalUpdate(_val(_strength)),
            weeklyFlexibilityMinutes: GoalUpdate(_val(_flexibility)),
          );
      if (!mounted) return;
      ref.read(profileProvider.notifier).applyUpdatedProfile(updatedProfile);
      ref.invalidate(dashboardSummaryProvider);
      navigator.pop();
      // 시트를 닫은 **뒤에** 뜨는 알림이라 messenger 를 미리 잡아 두고 쓴다.
      // 예전에는 이 자리만 위쪽 배너로 따로 떠 있었다 — 하단 토스트가 `+`
      // 버튼과 겹치는 것을 이 화면에서만 피하려던 우회였다(#1259). 토스트가
      // 바를 비키게 된 지금은 다른 화면과 같은 방식으로 알린다.
      showAppToastVia(messenger, l.myGoalsSaved, kind: AppToastKind.success);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      showAppToastVia(messenger, l.mySaveFailed, kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // 칼로리와 탄단지는 서로 다른 값이 아니다 — 탄·단은 4kcal/g, 지방은
    // 9kcal/g 이라 셋이 정해지면 칼로리도 정해진다. 두 방향을 세기를 달리해
    // 잇는다: 탄단지를 고치면 칼로리를 **바꾸고**, 칼로리를 고치면 탄단지에는
    // **권해만 준다**. 뒤쪽까지 자동으로 덮으면 회원이 적어 둔 배분이 칼로리를
    // 만질 때마다 사라진다.
    final split = _suggestedSplit;
    return _shell(context, l.myHealthGoalsTitle, <Widget>[
      _GoalsSectionLabel(l.myGoalsDietSection),
      const SizedBox(height: 8),
      _card(<Widget>[
        _SheetField(
          label: l.myGoalCalories,
          controller: _kcal,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText: '${UserProfile.defaultDailyCalories}',
          helperText: _kcalFromMacros ? l.myGoalCaloriesFromMacros : null,
          // 회원이 직접 고친 순간부터는 계산된 값이 아니다.
          onChanged: (_) => setState(() => _kcalFromMacros = false),
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myGoalSodium,
          controller: _sodium,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText: '${UserProfile.defaultDailySodiumMg}',
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myGoalSugar,
          controller: _sugar,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText: '${UserProfile.defaultDailySugarG}',
        ),
        const SizedBox(height: 12),
        _SheetField(
          key: const Key('goalCarbsField'),
          label: l.myGoalCarbs,
          controller: _carbs,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText: split == null
              ? '${UserProfile.defaultDailyCarbsG}'
              : '${split.carbs}',
          onChanged: (_) => _syncCaloriesFromMacros(),
        ),
        const SizedBox(height: 12),
        _SheetField(
          key: const Key('goalProteinField'),
          label: l.myGoalProtein,
          controller: _protein,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText: split == null
              ? '${UserProfile.defaultDailyProteinG}'
              : '${split.protein}',
          onChanged: (_) => _syncCaloriesFromMacros(),
        ),
        const SizedBox(height: 12),
        _SheetField(
          key: const Key('goalFatField'),
          label: l.myGoalFat,
          controller: _fat,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText: split == null
              ? '${UserProfile.defaultDailyFatG}'
              : '${split.fat}',
          onChanged: (_) => _syncCaloriesFromMacros(),
        ),
        if (split != null && !_macrosMatchSuggestion) ...<Widget>[
          const SizedBox(height: 10),
          _MacroSuggestionRow(
            buttonKey: const Key('goalApplyMacroSplit'),
            note: l.myGoalMacroSuggestionNote(_kcalValue!),
            actionLabel: l.myGoalMacroApplySuggestion,
            onApply: _applySuggestedSplit,
          ),
        ],
      ]),
      const SizedBox(height: 20),
      _GoalsSectionLabel(l.myGoalsExerciseSection),
      const SizedBox(height: 8),
      _card(<Widget>[
        _SheetField(
          key: const Key('goalDailyBurnField'),
          label: l.myGoalBurnDaily,
          controller: _burn,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText: '${kDefaultExerciseLoadGoals.dailyBurnKcal.round()}',
        ),
        const SizedBox(height: 12),
        _SheetField(
          key: const Key('goalCardioField'),
          label: l.myGoalCardioWeekly,
          controller: _cardio,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText: '${kDefaultExerciseLoadGoals.weeklyCardioMinutes.round()}',
        ),
        const SizedBox(height: 12),
        _SheetField(
          key: const Key('goalStrengthField'),
          label: l.myGoalStrengthWeekly,
          controller: _strength,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText: '${kDefaultExerciseLoadGoals.weeklyStrengthSets.round()}',
        ),
        const SizedBox(height: 12),
        _SheetField(
          key: const Key('goalFlexibilityField'),
          label: l.myGoalFlexibilityWeekly,
          controller: _flexibility,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          hintText:
              '${kDefaultExerciseLoadGoals.weeklyFlexibilityMinutes.round()}',
        ),
        // 식단 목표의 `권장 비율로 채우기` 와 같은 자리·같은 모양이다 (#1139).
        // 권장값은 WHO 권고(주 150분 중강도 유산소)를 따르는
        // [kDefaultExerciseLoadGoals] 그대로다.
        if (!_exerciseGoalsMatchSuggestion) ...<Widget>[
          const SizedBox(height: 10),
          _MacroSuggestionRow(
            buttonKey: const Key('goalApplyExerciseGoals'),
            note: l.myGoalExerciseSuggestionNote,
            actionLabel: l.myGoalExerciseApplySuggestion,
            onApply: _applySuggestedExerciseGoals,
          ),
        ],
      ]),
      const SizedBox(height: 16),
      _saveRow(context: context, saving: _saving, onSave: _save),
    ], saving: _saving);
  }
}

/// 칼로리에서 뽑은 탄단지 권장 배분 안내와, 그대로 채우는 버튼.
///
/// 세 칸의 placeholder 만으로는 그 숫자가 어디서 왔는지 알 수 없어 한 줄
/// 적어 준다. 버튼은 배분이 이미 세 칸과 같으면 부르는 쪽이 감춘다.
class _MacroSuggestionRow extends StatelessWidget {
  const _MacroSuggestionRow({
    required this.note,
    required this.actionLabel,
    required this.onApply,
    required this.buttonKey,
  });

  final String note;
  final String actionLabel;
  final VoidCallback onApply;

  /// 버튼의 키. 식단·운동 두 곳이 같은 줄을 쓰므로 각자 다른 키를 준다.
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            note,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: buttonKey,
          onPressed: onApply,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: FigmaColors.primary,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Small section heading between the two goal groups.
class _GoalsSectionLabel extends StatelessWidget {
  const _GoalsSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: FigmaColors.ink,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── 알림 설정 ──

/// 토글 목록은 저장소 계약(`kNotificationSettingItems`)이 갖는다 — 키를 서버와
/// 공유하므로 화면이 따로 들고 있으면 어긋난다(#489). 표시 라벨은 [_notifLabel]
/// 이 ARB 에서 찾는다.

/// Localized label for a notification toggle, keyed off its stable prefKey.
String _notifLabel(AppLocalizations l, String prefKey) {
  switch (prefKey) {
    case 'notif_diet_log':
      return l.myNotifDietLog;
    case 'notif_exercise_reminder':
      return l.myNotifExercise;
    case 'notif_trainer_message':
      return l.myNotifTrainer;
    case 'notif_ai_coaching':
      return l.myNotifAiCoaching;
    case 'notif_weekly_report':
      return l.myNotifWeeklyReport;
    default:
      return prefKey;
  }
}

/// 알림 수신 설정.
///
/// 실모드는 계정 단위로 서버에 저장한다 — 기기를 바꿔도 유지되고, 무엇보다
/// 서버가 설정을 알아야 알림을 만들 때 끌 수 있다(#489). 데모/목은 기존대로
/// SharedPreferences 라 화면과 동작이 지금과 같다.
Future<void> openNotificationSettingsPage(BuildContext context) {
  return context.push<void>(AppRoutes.mySettingsPath('notifications'));
}

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  /// 이 화면에서 바꾼 값. 서버 응답을 기다리는 동안에도 스위치가 즉시 움직여야
  /// 한다 — 왕복을 기다리면 눌리지 않는 것처럼 보인다.
  ///
  /// 저장에 **성공한 값도 여기 남는다.** 지우면 최초 조회값으로 돌아가는데,
  /// 서버에는 저장된 값이 남아 있어 화면과 어긋난다.
  final Map<String, bool> _local = <String, bool>{};

  /// 키별 최신 요청 번호. 늦게 도착한 옛 응답이 최신 상태를 덮어쓰는 것을 막는다.
  final Map<String, int> _requestSeq = <String, int>{};

  /// 화면에 그릴 값 — 내가 바꾼 값이 우선, 없으면 서버 값.
  bool _valueOf(String key, Map<String, bool> saved, bool fallback) =>
      _local[key] ?? saved[key] ?? fallback;

  Future<void> _persist(String key, bool value, bool previous) async {
    final int seq = (_requestSeq[key] ?? 0) + 1;
    _requestSeq[key] = seq;
    setState(() => _local[key] = value);
    final messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    try {
      await ref
          .read(notificationSettingsRepositoryProvider)
          .setValue(key, value);
    } on Object {
      if (!mounted) return;
      // 이 요청을 기다리는 사이 더 눌렀다면, 옛 실패로 최신 상태를 되돌리지
      // 않는다(리뷰).
      if (_requestSeq[key] != seq) return;
      // 되돌릴 곳은 **직전 값**이지 최초 조회값이 아니다. 한 번 저장에 성공한 뒤
      // 다음 저장이 실패하면 최초값으로 돌아가 서버와 어긋난다(리뷰).
      setState(() => _local[key] = previous);
      showAppToastVia(
        messenger,
        l.myNotificationSaveFailed,
        kind: AppToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Map<String, bool> saved =
        ref.watch(notificationSettingsProvider).valueOrNull ??
        <String, bool>{
          for (final NotificationSettingItem item in kNotificationSettingItems)
            item.key: item.fallback,
        };
    return _shell(context, l.myNotifTitle, <Widget>[
      _card(<Widget>[
        for (int i = 0; i < kNotificationSettingItems.length; i++) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _notifLabel(l, kNotificationSettingItems[i].key),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.ink,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _valueOf(
                  kNotificationSettingItems[i].key,
                  saved,
                  kNotificationSettingItems[i].fallback,
                ),
                activeThumbColor: FigmaColors.primary,
                onChanged: (bool v) => _persist(
                  kNotificationSettingItems[i].key,
                  v,
                  // 실패했을 때 돌아갈 곳 — 지금 화면에 보이는 값.
                  _valueOf(
                    kNotificationSettingItems[i].key,
                    saved,
                    kNotificationSettingItems[i].fallback,
                  ),
                ),
              ),
            ],
          ),
          if (i < kNotificationSettingItems.length - 1)
            const Divider(height: 1, color: FigmaColors.hairline),
        ],
      ]),
    ]);
  }
}

// ───────────────────────────────────────────────────────── 고객 지원 ──

/// Customer support entries.
Future<void> openSupportPage(BuildContext context) {
  return context.push<void>(AppRoutes.mySettingsPath('support'));
}

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _shell(context, l.mySupportTitle, <Widget>[
      // FAQ·1:1 문의는 앱 안에 화면을 만들지 않고 운영 중인 카카오톡 채널로
      // 보낸다. 문의는 사람이 답해야 하는 일이고 그 창구는 이미 있다. (#507)
      _supportRow(
        Icons.help_outline,
        l.mySupportFaq,
        () => _openExternal(context, kSupportChannelUrl),
        external: true,
        hint: l.mySupportExternalHint,
      ),
      _supportRow(
        Icons.chat_bubble_outline,
        l.mySupportInquiry,
        () => _openExternal(context, kSupportChatUrl),
        external: true,
        hint: l.mySupportExternalHint,
      ),
      _supportRow(
        Icons.description_outlined,
        l.myLegalTermsTitle,
        () => _openLegal(context, _LegalDoc.terms),
      ),
      _supportRow(
        Icons.privacy_tip_outlined,
        l.myLegalPrivacyTitle,
        () => _openLegal(context, _LegalDoc.privacy),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          l.myAppVersion,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    ]);
  }
}

/// 외부 링크를 연다. 실패하면 사유를 알린다.
///
/// 조용히 아무 일도 일어나지 않는 것이 가장 나쁘다 — 카카오톡이 없거나 열 수 있는
/// 앱이 없을 때, 사용자는 앱이 고장 난 것으로 읽는다. (#507)
Future<void> _openExternal(BuildContext context, String url) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  bool opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      // 앱 안 웹뷰가 아니라 브라우저·카카오톡으로 넘긴다 — 로그인된 채널
      // 세션을 그대로 쓸 수 있어야 문의가 이어진다.
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    showAppToastVia(messenger, l.mySupportOpenFailed, kind: AppToastKind.error);
  }
}

void _openLegal(BuildContext context, _LegalDoc doc) {
  context.push<void>(AppRoutes.mySettingsPath(doc.name));
}

Widget _supportRow(
  IconData icon,
  String label,
  VoidCallback onTap, {
  bool external = false,
  String? hint,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: FigmaColors.statBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: FigmaColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: FigmaColors.ink,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: FigmaColors.textFaint,
                        ),
                      ),
                  ],
                ),
              ),
              // 앱 밖으로 나가는 행은 화살표 대신 외부 링크 아이콘을 쓴다 —
              // 눌렀을 때 무엇이 일어나는지 미리 보이게.
              Icon(
                external ? Icons.open_in_new : Icons.chevron_right,
                size: 18,
                color: FigmaColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The in-app legal documents surfaced from customer support. Titles and
/// bodies are resolved from localizations via [_LegalDocSheet].
enum _LegalDoc { terms, privacy }

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.document});

  final String document;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool isTerms = document == _LegalDoc.terms.name;
    final String title = isTerms ? l.myLegalTermsTitle : l.myLegalPrivacyTitle;
    final String body = isTerms ? l.myLegalTermsBody : l.myLegalPrivacyBody;
    return _shell(context, title, <Widget>[
      _card(<Widget>[
        Text(
          body,
          style: const TextStyle(
            fontSize: 14,
            height: 1.7,
            fontWeight: FontWeight.w500,
            color: AppColors.foreground,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Center(
        child: Text(
          l.myLegalEffectiveDate,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    ]);
  }
}
