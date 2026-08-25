import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/account/domain/entities/recommended_goals.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/auth/presentation/widgets/auth_fields.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/app_toast.dart';

/// 가입 직후 한 번 보는 첫 설정 마법사 — 네 단계다.
///
///   1. 기본 정보 (생년월일·성별·키·체중)
///   2. 건강 상태 (만성질환 + 이루고 싶은 목표 한 줄)
///   3. 식단 목표 (하루 6칸)
///   4. 운동 목표 (소모 1칸 + 유형별 주간 3칸)
///
/// 3·4 단계는 **빈 칸으로 내밀지 않는다**. 1단계에서 받은 나이·성별·키·
/// 체중으로 [recommendedGoalsFor] 가 낸 권장값을 미리 채워 두고, 그 값이
/// 어디서 왔는지 각주로 밝힌다. 회원이 칸을 고치면 그 칸은 그대로 두고,
/// `권장값으로 되돌리기` 로 언제든 되돌릴 수 있다.
///
/// 여기서 저장하는 목표 열 칸은 MY `건강 목표` 가 고치는 열과 **같은 열**이다
/// — 온보딩에서 정한 값이 홈·식단·운동 탭의 목표선으로 그대로 이어진다.
/// 전에는 온보딩이 나트륨 한 칸만 받아, 첫 화면들이 전부 앱 기본값을 견줬다.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

/// 목표 칸 하나를 가리키는 이름. 회원이 **직접 고친 칸**을 기억하는 열쇠다.
enum _GoalField {
  calories(_GoalGroup.diet),
  sodium(_GoalGroup.diet),
  sugar(_GoalGroup.diet),
  carbs(_GoalGroup.diet),
  protein(_GoalGroup.diet),
  fat(_GoalGroup.diet),
  burn(_GoalGroup.exercise),
  cardio(_GoalGroup.exercise),
  strength(_GoalGroup.exercise),
  flexibility(_GoalGroup.exercise);

  const _GoalField(this.group);

  /// 어느 단계의 칸인가. `권장값으로 되돌리기` 가 이 묶음 단위로 움직인다.
  final _GoalGroup group;
}

enum _GoalGroup { diet, exercise }

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const int _steps = 4;

  /// 만성질환 선택지 — **전송 값**이다.
  ///
  /// 서버는 이 값을 자유 텍스트로 저장하고 AI 코치가 '내 건강 기록' 으로 읽는다. 화면
  /// 로케일에 따라 저장되는 문자열이 달라지면 같은 사용자의 기록이 언어별로 갈라지므로,
  /// 값은 한국어로 고정하고 표시 문구만 번역한다.
  /// 이 앱이 관리 대상으로 삼는 두 질환만 묻는다. 고지혈증·비만은 뺐다 —
  /// 가입 첫 화면에서 고를 것이 늘수록 대충 넘기고, 그렇게 들어온 값은 AI
  /// 코치가 읽는 건강 기록을 흐린다.
  static const List<String> _conditionOptions = <String>['고혈압', '당뇨'];

  /// 전송 값 → 화면에 보일 문구.
  ///
  /// 선택지에서 뺀 값도 계속 옮긴다 — 예전에 고른 값이 프로필에 남아 있을 수
  /// 있고, 그때 원문 그대로 노출되면 영어 로케일에서만 한국어가 튄다.
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

  // ── 1단계 ──
  //
  // 생년월일은 **세 칸을 따로** 들고 있다. 달력 다이얼로그를 띄우면 1단계가
  // 시작되자마자 새 창이 덮어 나머지 칸이 보이지 않고, 40년 전을 찾아가는
  // 길도 길다. 년·월·일 드롭다운은 그 자리에서 세 번 고르면 끝난다.
  int? _birthYear;
  int? _birthMonth;
  int? _birthDay;
  String? _gender; // 'male' | 'female' | 'other'
  final TextEditingController _height = TextEditingController();
  final TextEditingController _weight = TextEditingController();

  // ── 2단계 ──
  final Set<String> _conditions = <String>{};
  final TextEditingController _goals = TextEditingController();

  // ── 3·4단계 ── 칸 하나에 컨트롤러 하나.
  late final Map<_GoalField, TextEditingController> _goalControllers = <
    _GoalField,
    TextEditingController
  >{
    for (final _GoalField f in _GoalField.values) f: TextEditingController(),
  };

  /// 회원이 **직접 고친** 칸. 여기 든 칸은 1단계 값이 바뀌어도 다시 쓰지 않고,
  /// `권장값으로 되돌리기` 를 눌러야 비워진다.
  final Set<_GoalField> _edited = <_GoalField>{};

  @override
  void initState() {
    super.initState();
    // 3·4단계에 닿기 전에 이미 채워 둔다 — 뒤로 돌아왔을 때도 칸이 비어 있는
    // 순간이 없어야 한다.
    _fillRecommended();
  }

  @override
  void dispose() {
    _pager.dispose();
    _height.dispose();
    _weight.dispose();
    _goals.dispose();
    for (final TextEditingController c in _goalControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(_GoalField f) => _goalControllers[f]!;

  num? _num(TextEditingController c) => num.tryParse(c.text.trim());
  int? _goalValue(_GoalField f) => int.tryParse(_ctl(f).text.trim());

  // ───────────────────────────────────────────────── 권장값 ──

  /// 오늘 기준 만 나이. 생년월일을 아직 안 골랐으면 null.
  ///
  /// 서버로 나가는 문자열([_birthDateText])을 그대로 읽는다 — 화면이 세는
  /// 나이와 서버에 저장되는 생년월일이 같은 값에서 나와야 한다.
  int? get _age {
    final String? text = _birthDateText;
    return text == null ? null : ageFromBirthDate(text, today: todayKst());
  }

  double? get _heightCm => _num(_height)?.toDouble();
  double? get _weightKg => _num(_weight)?.toDouble();

  /// 지금 1단계 값으로 낸 권장 목표.
  ///
  /// 회원이 **칼로리 칸을 직접 고쳤으면** 그 값을 기준으로 다시 나눈다 —
  /// 각주가 말하는 비율과 탄단지 칸의 숫자가 어긋나지 않아야 한다.
  RecommendedGoals get _recommended {
    final RecommendedGoals base = recommendedGoalsFor(
      ageYears: _age,
      gender: _gender,
      heightCm: _heightCm,
      weightKg: _weightKg,
    );
    if (!_edited.contains(_GoalField.calories)) return base;
    final int? kcal = _goalValue(_GoalField.calories);
    if (kcal == null || kcal <= 0) return base;
    return recommendedGoalsFromCalories(kcal, basis: base.basis);
  }

  int _recommendedValue(_GoalField f, RecommendedGoals r) => switch (f) {
    _GoalField.calories => r.dailyCalories,
    _GoalField.sodium => r.dailySodiumMg,
    _GoalField.sugar => r.dailySugarG,
    _GoalField.carbs => r.dailyCarbsG,
    _GoalField.protein => r.dailyProteinG,
    _GoalField.fat => r.dailyFatG,
    _GoalField.burn => r.dailyBurnKcal,
    _GoalField.cardio => r.weeklyCardioMinutes,
    _GoalField.strength => r.weeklyStrengthSets,
    _GoalField.flexibility => r.weeklyFlexibilityMinutes,
  };

  /// 아직 손대지 않은 칸에 권장값을 써 넣는다.
  ///
  /// [only] 를 주면 그 묶음만 다시 쓴다. 손댄 칸을 건너뛰는 것이 핵심이다 —
  /// 1단계로 되돌아가 체중을 고쳤다고 회원이 적어 둔 목표까지 덮으면, 고친
  /// 값이 소리 없이 사라진다.
  void _fillRecommended({_GoalGroup? only}) {
    final RecommendedGoals r = _recommended;
    for (final _GoalField f in _GoalField.values) {
      if (only != null && f.group != only) continue;
      if (_edited.contains(f)) continue;
      _ctl(f).text = '${_recommendedValue(f, r)}';
    }
  }

  /// 묶음 하나를 권장값으로 되돌린다 — 손댔다는 기억부터 지운다.
  void _resetGroup(_GoalGroup group) {
    setState(() {
      _edited.removeWhere((_GoalField f) => f.group == group);
      _fillRecommended(only: group);
    });
  }

  /// 그 묶음에 회원이 고친 칸이 있는가. `권장값으로 되돌리기` 를 띄우는 조건이다.
  bool _isEdited(_GoalGroup group) =>
      _edited.any((_GoalField f) => f.group == group);

  /// 사람이 친 글자만 올라온다 — 프로그램이 컨트롤러에 써 넣은 값은
  /// `onChanged` 를 부르지 않으므로 되먹임이 생기지 않는다.
  void _onGoalEdited(_GoalField f) {
    setState(() {
      _edited.add(f);
      // 칼로리를 고치면 아직 손대지 않은 탄단지·당류가 그 칼로리를 따라간다.
      if (f == _GoalField.calories) _fillRecommended(only: _GoalGroup.diet);
    });
  }

  /// 1단계 값이 바뀌면 손대지 않은 목표 칸을 다시 계산한다.
  void _onBasicChanged() => setState(_fillRecommended);

  // ───────────────────────────────────────────────── 이동·저장 ──

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

  /// 건강 상태 단계를 건너뛴다 — 이 단계에서 적은 것을 **비우고** 넘어간다.
  ///
  /// 그냥 `다음` 을 누르는 것과 다르다: 골라 뒀다가 마음이 바뀌어 건너뛰었는데
  /// 고른 질환이 그대로 저장되면, 건너뛴 것이 건너뛴 것이 아니게 된다.
  void _skipConditions() {
    setState(() {
      _conditions.clear();
      _goals.clear();
    });
    _next();
  }

  Future<void> _finish() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final AppToastHost toast = AppToastHost.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .submitOnboarding(
            birthDate: _birthDateText,
            gender: _gender,
            heightCm: _num(_height),
            weightKg: _num(_weight),
            conditions: _conditions.isEmpty ? null : _conditions.join(', '),
            goals: _goals.text.trim().isEmpty ? null : _goals.text.trim(),
            dailyCalories: _goalValue(_GoalField.calories),
            dailySodiumMg: _goalValue(_GoalField.sodium),
            dailySugarG: _goalValue(_GoalField.sugar),
            dailyCarbsG: _goalValue(_GoalField.carbs),
            dailyProteinG: _goalValue(_GoalField.protein),
            dailyFatG: _goalValue(_GoalField.fat),
            dailyBurnKcal: _goalValue(_GoalField.burn),
            weeklyCardioMinutes: _goalValue(_GoalField.cardio),
            weeklyStrengthSets: _goalValue(_GoalField.strength),
            weeklyFlexibilityMinutes: _goalValue(_GoalField.flexibility),
          );
      if (!mounted) return;
      ref.invalidate(profileProvider);
      context.go(AppRoutes.dashboard);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      toast.show(l.onboardSaveFailed, kind: AppToastKind.error);
    }
  }

  /// 서버가 받는 `YYYY-MM-DD`. **세 칸이 다 차야** 값이 된다.
  ///
  /// 년만 고른 상태를 `1986-01-01` 같은 날짜로 메우지 않는다 — 회원이 고르지
  /// 않은 달·일을 지어내면, 만 나이가 한 살 어긋난 채로 권장 목표까지 따라
  /// 어긋난다.
  String? get _birthDateText {
    final int? y = _birthYear;
    final int? m = _birthMonth;
    final int? d = _birthDay;
    if (y == null || m == null || d == null) return null;
    return '${y.toString().padLeft(4, '0')}-'
        '${m.toString().padLeft(2, '0')}-'
        '${d.toString().padLeft(2, '0')}';
  }

  /// 태어난 해로 고를 수 있는 값 — 올해부터 120년 전까지, 최근 연도가 위다.
  List<int> get _birthYearOptions {
    final int thisYear = todayKst().year;
    return <int>[for (int y = thisYear; y >= thisYear - 120; y--) y];
  }

  /// 고를 수 있는 달. 올해를 골랐으면 이번 달까지만 — 앞으로 올 달에 태어난
  /// 사람은 없다.
  List<int> get _birthMonthOptions {
    final DateTime today = todayKst();
    final int last = _birthYear == today.year ? today.month : 12;
    return <int>[for (int m = 1; m <= last; m++) m];
  }

  /// 고를 수 있는 날. 그 달의 마지막 날까지이고, 이번 달이면 오늘까지다.
  List<int> get _birthDayOptions =>
      <int>[for (int d = 1; d <= _lastSelectableBirthDay; d++) d];

  int get _lastSelectableBirthDay {
    final DateTime today = todayKst();
    final int year = _birthYear ?? today.year;
    final int month = _birthMonth ?? 1;
    if (year == today.year && month == today.month) return today.day;
    // 다음 달 0일 = 이번 달 마지막 날. 윤년 2월도 이 셈이 알아서 맞춘다.
    return DateTime(year, month + 1, 0).day;
  }

  /// 세 칸 중 하나가 바뀌었다. 있을 수 없는 날이 남지 않게 다듬고, 손대지 않은
  /// 목표 칸을 새 나이로 다시 계산한다.
  ///
  /// 예: 1월 31일을 골라 둔 채 2월로 바꾸면 `2월 31일` 이 된다. 드롭다운이
  /// 들고 있지 않은 값이라 그대로 두면 화면이 그려지지도 않는다.
  void _onBirthPartChanged() {
    final DateTime today = todayKst();
    if (_birthYear == today.year && (_birthMonth ?? 0) > today.month) {
      _birthMonth = today.month;
    }
    final int lastDay = _lastSelectableBirthDay;
    if ((_birthDay ?? 0) > lastDay) _birthDay = lastDay;
    _onBasicChanged();
  }

  // ───────────────────────────────────────────────── 화면 ──

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool isLast = _step == _steps - 1;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.contentMaxWidth,
              ),
              child: Column(
                children: <Widget>[
                  _header(l),
                  _progress(),
                  Expanded(
                    child: PageView(
                      controller: _pager,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (int i) => setState(() => _step = i),
                      children: <Widget>[
                        _stepBasic(l),
                        _stepConditions(l),
                        _stepDietGoals(l),
                        _stepExerciseGoals(l),
                      ],
                    ),
                  ),
                  _footer(l, isLast: isLast),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l) => Padding(
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
            fontWeight: FontWeight.w700,
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
  );

  Widget _progress() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: (_step + 1) / _steps,
        minHeight: 6,
        backgroundColor: FigmaColors.track,
        valueColor: const AlwaysStoppedAnimation<Color>(FigmaColors.primary),
      ),
    ),
  );

  Widget _footer(AppLocalizations l, {required bool isLast}) => Padding(
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
  );

  /// 네 단계가 **모두** 이 뼈대를 쓴다 — 제목 · 한 줄 설명 · [_StepSection] 들.
  ///
  /// 예전에는 단계마다 생김새가 조금씩 달랐다. 1·2단계는 흰 바닥에 칩이 그냥
  /// 놓여 있고 3·4단계만 회색 카드였다 — 같은 마법사를 네 번 넘기는 동안 화면이
  /// 세 번 바뀌는 셈이었다. 이제 모든 내용은 [_OnboardCard] 안에 들어가고,
  /// 카드 아래 각주 자리도 [_StepNote] 하나로 같다.
  Widget _stepBody({
    required String title,
    required String subtitle,
    required List<_StepSection> sections,
    bool optional = false,
    VoidCallback? onSkipStep,
  }) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: FigmaColors.ink,
                  ),
                ),
              ),
              // 안 채워도 되는 단계라는 말은 제목 옆에 붙어야 읽힌다 — 아래
              // 설명 줄에 섞으면 다음 버튼을 먼저 누른 뒤에나 눈에 들어온다.
              if (optional) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  l.onboardOptionalTag,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.textSub,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: FigmaColors.textSub,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (int i = 0; i < sections.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.xl),
            sections[i],
          ],
          if (onSkipStep != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: TextButton(
                key: const Key('onboardSkipStep'),
                onPressed: _saving ? null : onSkipStep,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mutedForeground,
                ),
                child: Text(
                  l.onboardSkipStep,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 1단계: 기본 정보 ──

  Widget _stepBasic(AppLocalizations l) {
    return _stepBody(
      title: l.onboardBasicTitle,
      subtitle: l.onboardBasicSubtitle,
      sections: <_StepSection>[
        _StepSection(
          card: _OnboardCard(
            children: <Widget>[
              _FieldLabel(l.onboardBirthLabel),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 4,
                    child: _BirthPartDropdown(
                      dropdownKey: const Key('onboardBirthYear'),
                      hint: l.onboardBirthYearHint,
                      value: _birthYear,
                      options: _birthYearOptions,
                      labelOf: l.onboardBirthYearValue,
                      onChanged: _saving
                          ? null
                          : (int? v) => setState(() {
                              _birthYear = v;
                              _onBirthPartChanged();
                            }),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: _BirthPartDropdown(
                      dropdownKey: const Key('onboardBirthMonth'),
                      hint: l.onboardBirthMonthHint,
                      value: _birthMonth,
                      options: _birthMonthOptions,
                      labelOf: l.onboardBirthMonthValue,
                      onChanged: _saving
                          ? null
                          : (int? v) => setState(() {
                              _birthMonth = v;
                              _onBirthPartChanged();
                            }),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: _BirthPartDropdown(
                      dropdownKey: const Key('onboardBirthDay'),
                      hint: l.onboardBirthDayHint,
                      value: _birthDay,
                      options: _birthDayOptions,
                      labelOf: l.onboardBirthDayValue,
                      onChanged: _saving
                          ? null
                          : (int? v) => setState(() {
                              _birthDay = v;
                              _onBirthPartChanged();
                            }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _kFieldGap),
              _FieldLabel(l.onboardGenderLabel),
              const SizedBox(height: 6),
              _GenderSelector(
                value: _gender,
                onChanged: (String? g) {
                  setState(() => _gender = g);
                  _onBasicChanged();
                },
              ),
              const SizedBox(height: _kFieldGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _OnboardField(
                      key: const Key('onboardHeightField'),
                      label: l.onboardHeightHint,
                      controller: _height,
                      onChanged: (_) => _onBasicChanged(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _OnboardField(
                      key: const Key('onboardWeightField'),
                      label: l.onboardWeightHint,
                      controller: _weight,
                      onChanged: (_) => _onBasicChanged(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 카드 아래 각주 자리는 3·4단계의 `출처 · 되돌리기` 와 같은 자리다.
          // 여기서는 방금 적은 값을 되읽어 준다 — 권장 목표가 이 둘에서 나오니
          // 오타를 다음 단계로 넘어가기 전에 알아채야 한다.
          note: _BodySummary(age: _age, heightCm: _heightCm, weightKg: _weightKg),
        ),
      ],
    );
  }

  // ── 2단계: 건강 상태 ──

  Widget _stepConditions(AppLocalizations l) {
    return _stepBody(
      title: l.onboardHealthTitle,
      subtitle: l.onboardHealthSubtitle,
      optional: true,
      onSkipStep: _skipConditions,
      sections: <_StepSection>[
        _StepSection(
          card: _OnboardCard(
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final String c in _conditionOptions)
                    _OnboardChip(
                      label: _conditionLabel(l, c),
                      selected: _conditions.contains(c),
                      onTap: () => setState(() {
                        if (!_conditions.remove(c)) _conditions.add(c);
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        _StepSection(
          label: l.onboardGoalTitle,
          description: l.onboardGoalSubtitle,
          card: _OnboardCard(
            children: <Widget>[
              _OnboardField(
                key: const Key('onboardGoalTextField'),
                label: l.onboardGoalHint,
                controller: _goals,
                keyboardType: TextInputType.text,
                digitsOnly: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 3단계: 식단 목표 ──

  Widget _stepDietGoals(AppLocalizations l) {
    return _stepBody(
      title: l.onboardDietTitle,
      subtitle: l.onboardDietSubtitle,
      sections: <_StepSection>[
        _StepSection(
          card: _OnboardCard(
            children: <Widget>[
              _goalField(_GoalField.calories, l.myGoalCalories, 'onboardKcal'),
              const SizedBox(height: _kFieldGap),
              _goalField(_GoalField.carbs, l.myGoalCarbs, 'onboardCarbs'),
              const SizedBox(height: _kFieldGap),
              _goalField(_GoalField.protein, l.myGoalProtein, 'onboardProtein'),
              const SizedBox(height: _kFieldGap),
              _goalField(_GoalField.fat, l.myGoalFat, 'onboardFat'),
              const SizedBox(height: _kFieldGap),
              _goalField(_GoalField.sodium, l.myGoalSodium, 'onboardSodium'),
              const SizedBox(height: _kFieldGap),
              _goalField(_GoalField.sugar, l.myGoalSugar, 'onboardSugar'),
            ],
          ),
          note: _StepNote(
            infoLine: _recommended.isPersonalized
                ? l.onboardRecommendedPersonal
                : l.onboardRecommendedFallback,
            sourceNote: l.onboardDietSourceNote,
            actionKey: const Key('onboardResetDietGoals'),
            actionLabel: l.onboardResetToRecommended,
            onAction: _isEdited(_GoalGroup.diet)
                ? () => _resetGroup(_GoalGroup.diet)
                : null,
          ),
        ),
      ],
    );
  }

  // ── 4단계: 운동 목표 ──

  Widget _stepExerciseGoals(AppLocalizations l) {
    return _stepBody(
      title: l.onboardExerciseTitle,
      subtitle: l.onboardExerciseSubtitle,
      sections: <_StepSection>[
        _StepSection(
          card: _OnboardCard(
            children: <Widget>[
              _goalField(_GoalField.burn, l.myGoalBurnDaily, 'onboardBurn'),
              const SizedBox(height: _kFieldGap),
              _goalField(
                _GoalField.cardio,
                l.myGoalCardioWeekly,
                'onboardCardio',
              ),
              const SizedBox(height: _kFieldGap),
              _goalField(
                _GoalField.strength,
                l.myGoalStrengthWeekly,
                'onboardStrength',
              ),
              const SizedBox(height: _kFieldGap),
              _goalField(
                _GoalField.flexibility,
                l.myGoalFlexibilityWeekly,
                'onboardFlexibility',
              ),
            ],
          ),
          note: _StepNote(
            // 운동 권장값은 WHO 권고 그대로라 1단계 정보와 무관하다 — 나이·체중을
            // 안 적었다고 "덜 정확한 값" 이라고 말하면 사실이 아니다.
            sourceNote: l.onboardExerciseSourceNote,
            actionKey: const Key('onboardResetExerciseGoals'),
            actionLabel: l.onboardResetToRecommended,
            onAction: _isEdited(_GoalGroup.exercise)
                ? () => _resetGroup(_GoalGroup.exercise)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _goalField(_GoalField field, String label, String keyName) =>
      _OnboardField(
        key: Key('${keyName}Field'),
        label: label,
        controller: _ctl(field),
        onChanged: (_) => _onGoalEdited(field),
      );
}

/// 카드 안 칸과 칸 사이. 네 단계가 같은 간격을 쓴다.
const double _kFieldGap = 14;

/// 한 단계 안의 묶음 하나 — 제목(선택) · 한 줄 설명(선택) · 카드 · 각주(선택).
///
/// 단계마다 담기는 내용은 달라도 **쌓는 순서와 간격은 하나**다. 마법사를 네 번
/// 넘기는 동안 눈이 같은 자리에서 같은 것을 찾게 하려는 것이다.
class _StepSection extends StatelessWidget {
  const _StepSection({
    required this.card,
    this.label,
    this.description,
    this.note,
  });

  final Widget card;

  /// 한 단계에 묶음이 둘 이상일 때만 준다. 하나뿐이면 단계 제목이 곧 이름이라
  /// 같은 말을 두 번 적게 된다.
  final String? label;
  final String? description;

  /// 카드 아래 작은 글씨 자리 — 출처·되돌리기·요약이 모두 여기 온다.
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (description != null) ...<Widget>[
          Text(
            description!,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textSub,
            ),
          ),
          const SizedBox(height: 10),
        ],
        card,
        if (note != null) ...<Widget>[
          const SizedBox(height: 10),
          note!,
        ],
      ],
    );
  }
}

/// 카드 한 장 — MY `건강 목표` 시트와 같은 회색 판이다.
class _OnboardCard extends StatelessWidget {
  const _OnboardCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
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
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: AppColors.foreground,
    ),
  );
}

/// 온보딩의 **모든** 칩. 성별(하나만)과 만성질환(여럿)이 같은 모양을 쓴다.
///
/// 예전에는 두 자리가 `ChoiceChip` 과 `FilterChip` 이었다. 머티리얼 기본
/// 생김새라 카드 안의 입력칸과도, 서로와도 달라 보였다 — 한쪽에는 체크 표시가
/// 붙고 다른 쪽에는 안 붙었다.
class _OnboardChip extends StatelessWidget {
  const _OnboardChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 성별처럼 한 줄을 고르게 나눠 채울 때 true.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget chip = Material(
      color: selected ? FigmaColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? FigmaColors.primary : FigmaColors.hairline,
            ),
          ),
          // 글자만큼만 넓어야 한다 — `Container.alignment` 를 주면 칸이 남는
          // 너비를 통째로 먹어, 만성질환 칩 넷이 한 줄에 나란히 서지 못하고
          // 화면 폭짜리 막대 넷으로 쌓인다.
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : FigmaColors.textBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return expand ? Expanded(child: chip) : chip;
  }
}

/// 라벨 + 입력칸. MY `건강 목표` 시트의 칸과 같은 모양이라, 온보딩에서 채운
/// 값을 나중에 MY 에서 볼 때 같은 화면으로 읽힌다.
class _OnboardField extends StatelessWidget {
  const _OnboardField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.number,
    this.digitsOnly = true,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;

  /// 숫자 칸은 붙여넣기로도 문자가 들어오지 못하게 막는다 — 저장 때 int 파싱이
  /// null 로 날아가면 목표가 조용히 비어 버린다.
  final bool digitsOnly;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: digitsOnly
              ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
              : null,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
          decoration: _fieldDecoration(),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration({String? hintText}) => InputDecoration(
  isDense: true,
  filled: true,
  fillColor: Colors.white,
  hintText: hintText,
  hintStyle: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedForeground,
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: FigmaColors.hairline),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: FigmaColors.primary, width: 1.4),
  ),
);

/// 생년월일의 한 칸 — 년·월·일 중 하나를 고르는 드롭다운.
///
/// 예전에는 칸을 누르면 달력 다이얼로그가 떴다. 가입하고 처음 보는 화면에서
/// 곧바로 새 창이 덮었고, 40년 전을 찾아가려면 연도 격자까지 두 번 더 들어가야
/// 했다. 세 칸을 그 자리에서 고르는 편이 짧다.
///
/// 생김새는 같은 카드 안의 입력칸과 하나다 — 흰 바탕, 같은 테두리, 같은 반경.
/// 펼쳐지는 목록도 흰 바탕이라 달력 창과 색이 갈리지 않는다.
class _BirthPartDropdown extends StatelessWidget {
  const _BirthPartDropdown({
    required this.dropdownKey,
    required this.hint,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final Key dropdownKey;

  /// 아직 고르지 않았을 때 보일 말 — `년` · `월` · `일`.
  final String hint;
  final int? value;
  final List<int> options;

  /// 숫자 → 화면에 보일 문구. 로케일이 단위를 붙일지 정한다.
  final String Function(int) labelOf;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: _fieldDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          key: dropdownKey,
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.expand_more,
            size: 18,
            color: AppColors.mutedForeground,
          ),
          hint: Text(
            hint,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
          // 펼친 목록은 오버레이라 화면의 기본 글꼴이 그대로 따라오지 않는다 —
          // 테마의 타입 스케일에서 시작해야 목록 안 숫자도 같은 서체로 찍힌다.
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
          items: <DropdownMenuItem<int>>[
            for (final int option in options)
              DropdownMenuItem<int>(
                value: option,
                child: Text(labelOf(option), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// 1단계에서 적은 값을 그 자리에서 되읽어 주는 줄 — 만 나이와 체질량지수.
///
/// 권장 목표가 이 둘에서 나오므로, 회원이 오타를 냈는지 다음 단계로 가기 전에
/// 스스로 알아챌 수 있어야 한다.
class _BodySummary extends StatelessWidget {
  const _BodySummary({
    required this.age,
    required this.heightCm,
    required this.weightKg,
  });

  final int? age;
  final double? heightCm;
  final double? weightKg;

  /// 대한비만학회 비만 진료지침(아시아·태평양 기준)의 구간.
  static String _category(AppLocalizations l, double bmi) {
    if (bmi < 18.5) return l.onboardBmiUnderweight;
    if (bmi < 23) return l.onboardBmiNormal;
    if (bmi < 25) return l.onboardBmiPreObese;
    if (bmi < 30) return l.onboardBmiObese1;
    if (bmi < 35) return l.onboardBmiObese2;
    return l.onboardBmiObese3;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final double? h = heightCm;
    final double? w = weightKg;
    final bool canBmi =
        h != null && w != null && h >= 50 && h <= 300 && w >= 20 && w <= 500;
    final double? bmi = canBmi ? w / ((h / 100) * (h / 100)) : null;
    if (age == null && bmi == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (age != null) _Pill(l.onboardAgeSummary(age!)),
            if (bmi != null)
              _Pill(
                l.onboardBmiSummary(
                  bmi.toStringAsFixed(1),
                  _category(l, bmi),
                ),
              ),
          ],
        ),
        if (bmi != null) ...<Widget>[
          const SizedBox(height: 8),
          _SourceLine(l.onboardBmiSourceNote),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: FigmaColors.softBlue,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: FigmaColors.primary,
      ),
    ),
  );
}

/// 카드 아래 각주 자리 — 네 단계가 **같은 위젯**을 쓴다.
///
/// 위에서부터 안내 한 줄(선택) · 출처 한 줄 · 오른쪽 끝의 작은 버튼(선택)이다.
/// 버튼은 **회원이 칸을 고쳤을 때만** 나온다 — 눌러도 달라질 것이 없는 버튼을
/// 계속 띄우면 무슨 뜻인지 읽히지 않는다. (MY `권장 비율로 채우기` 와 같은
/// 규칙이다.)
class _StepNote extends StatelessWidget {
  const _StepNote({
    required this.sourceNote,
    this.infoLine,
    this.actionKey,
    this.actionLabel,
    this.onAction,
  });

  /// 값이 어디서 왔는지. 운동 목표처럼 1단계 정보와 무관한 자리는 비운다.
  final String? infoLine;
  final String sourceNote;
  final Key? actionKey;
  final String? actionLabel;

  /// null 이면 아직 고친 칸이 없다는 뜻이라 버튼을 감춘다.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (infoLine != null) ...<Widget>[
          Text(
            infoLine!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FigmaColors.textSub,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _SourceLine(sourceNote)),
            if (onAction != null && actionLabel != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                key: actionKey,
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: FigmaColors.primary,
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 출처 한 줄 — 화면에서 가장 작고 옅은 글씨다.
class _SourceLine extends StatelessWidget {
  const _SourceLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
  );
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
    final List<MapEntry<String, String>> entries = _labelsOf(
      AppLocalizations.of(context),
    ).entries.toList();
    return Row(
      children: <Widget>[
        for (int i = 0; i < entries.length; i++) ...<Widget>[
          _OnboardChip(
            label: entries[i].value,
            selected: value == entries[i].key,
            onTap: () => onChanged(entries[i].key),
            expand: true,
          ),
          if (i < entries.length - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}
