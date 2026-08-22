import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/domain/entities/goal_update.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/my_health/presentation/widgets/my_flows.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 세우지 않은 목표는 화면을 열고 저장해도 세워지지 않는다. (PR #900 리뷰)
///
/// `null` 은 *미설정 또는 목표 해제*라는 계약이고, 서버는 키가 없으면 그대로
/// 두고 키가 `null` 로 오면 해제한다. 화면이 빈 칸을 기본값으로 채워 두면
/// 열어 보기만 해도 기본값이 진짜 목표로 굳는다.

/// 마지막으로 받은 인자를 잡아 두는 저장소 — 화면이 무엇을 보냈는지 본다.
class _RecordingAccountRepository extends MockAccountRepository {
  _RecordingAccountRepository({required super.profile});

  GoalUpdate? lastCarbs;
  GoalUpdate? lastProtein;
  bool called = false;

  @override
  Future<UserProfile> updateHealthGoals({
    GoalUpdate? dailyCalories,
    GoalUpdate? dailySodiumMg,
    GoalUpdate? dailySugarG,
    GoalUpdate? dailyCarbsG,
    GoalUpdate? dailyProteinG,
    GoalUpdate? dailyFatG,
    GoalUpdate? weeklyWorkoutGoal,
    GoalUpdate? weeklyExerciseMinutesGoal,
    GoalUpdate? weeklyBurnGoal,
    GoalUpdate? dailyBurnKcal,
    GoalUpdate? weeklyCardioMinutes,
    GoalUpdate? weeklyStrengthSets,
    GoalUpdate? weeklyFlexibilityMinutes,
  }) {
    called = true;
    lastCarbs = dailyCarbsG;
    lastProtein = dailyProteinG;
    return super.updateHealthGoals(
      dailyCalories: dailyCalories,
      dailySodiumMg: dailySodiumMg,
      dailySugarG: dailySugarG,
      dailyCarbsG: dailyCarbsG,
      dailyProteinG: dailyProteinG,
      dailyFatG: dailyFatG,
      weeklyWorkoutGoal: weeklyWorkoutGoal,
      weeklyExerciseMinutesGoal: weeklyExerciseMinutesGoal,
      weeklyBurnGoal: weeklyBurnGoal,
      dailyBurnKcal: dailyBurnKcal,
      weeklyCardioMinutes: weeklyCardioMinutes,
      weeklyStrengthSets: weeklyStrengthSets,
      weeklyFlexibilityMinutes: weeklyFlexibilityMinutes,
    );
  }
}

/// 탄수화물만 세우지 않은 프로필.
const UserProfile _carbsUnset = UserProfile(
  id: 'user-null-carbs',
  name: '목표없음',
  email: 'none@oncare.com',
  dailyCalories: 1800,
  dailySodiumMg: 1500,
  dailySugarG: 40,
  dailyProteinG: 120,
  dailyFatG: 50,
  weeklyWorkoutGoal: 3,
  weeklyExerciseMinutesGoal: 150,
  weeklyBurnGoal: 500,
);

Future<_RecordingAccountRepository> _openHealthGoals(
  WidgetTester tester,
) async {
  final repository = _RecordingAccountRepository(profile: _carbsUnset);
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        accountRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HealthGoalsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

TextField _field(WidgetTester tester, String key) => tester.widget<TextField>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
);

Future<void> _save(WidgetTester tester) async {
  final Finder saveButton = find.text('저장');
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  // 저장 알림 배너는 3초 뒤 스스로 닫힌다. 그 타이머를 흘려보내지 않으면
  // 위젯 트리가 사라진 뒤에도 타이머가 남아 테스트가 깨진다.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('세우지 않은 목표는 빈 칸으로 열리고 기본값은 placeholder 로만 보인다', (
    tester,
  ) async {
    await _openHealthGoals(tester);

    final carbs = _field(tester, 'goalCarbsField');
    expect(carbs.controller!.text, isEmpty, reason: '기본값이 값으로 채워졌다');
    // 기본값은 보이되 값이 되지는 않는다. 칼로리(1800)가 있으니 권장 배분
    // 225g 이 placeholder 로 온다.
    expect(carbs.decoration!.hintText, isNotNull);

    // 세워 둔 목표는 그대로 보인다.
    expect(_field(tester, 'goalProteinField').controller!.text, '120');
  });

  testWidgets('열고 그대로 저장해도 세우지 않은 목표는 null 로 남는다', (tester) async {
    final repository = await _openHealthGoals(tester);

    await _save(tester);

    expect(repository.called, isTrue);
    // 빈 칸은 '건드리지 않음'이 아니라 '값 없음'으로 나간다 — 그래야 회원이
    // 지운 목표가 되살아나지 않는다.
    expect(repository.lastCarbs, isNotNull);
    expect(repository.lastCarbs!.value, isNull);
    expect(repository.lastProtein!.value, 120);

    final UserProfile saved = await repository.fetchProfile();
    expect(saved.dailyCarbsG, isNull, reason: '기본값이 목표로 굳었다');
    expect(saved.dailyProteinG, 120);
    // 화면이 아니라 getter 가 기본값을 책임진다.
    expect(saved.effectiveDailyCarbsG, UserProfile.defaultDailyCarbsG);
  });

  testWidgets('세워 둔 목표를 지우고 저장하면 해제된다', (tester) async {
    final repository = await _openHealthGoals(tester);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('goalProteinField')),
        matching: find.byType(TextField),
      ),
      '',
    );
    await tester.pump();
    await _save(tester);

    expect(repository.lastProtein!.value, isNull);
    expect((await repository.fetchProfile()).dailyProteinG, isNull);
  });
}
