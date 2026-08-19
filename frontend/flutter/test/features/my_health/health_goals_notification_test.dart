import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/domain/entities/goal_update.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/my_health/presentation/widgets/my_flows.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

class _FailingAccountRepository extends MockAccountRepository {
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
  }) async {
    throw StateError('save failed');
  }
}

Future<void> _openHealthGoals(
  WidgetTester tester,
  MockAccountRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        accountRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/goals',
        routes: <String, WidgetBuilder>{
          '/': (_) => const Scaffold(body: Text('MY 화면')),
          '/goals': (_) => const HealthGoalsPage(),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final Finder saveButton = find.text('저장');
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('저장 성공 알림은 이전 화면의 상단에 표시된다', (tester) async {
    await _openHealthGoals(tester, MockAccountRepository());

    await _tapSave(tester);

    expect(find.text('건강 목표가 저장되었어요'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(tester.getTopLeft(find.byType(MaterialBanner)).dy, lessThan(150));
    expect(find.text('식단 일일 목표'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('저장 실패 알림도 현재 화면의 상단에 표시된다', (tester) async {
    await _openHealthGoals(tester, _FailingAccountRepository());

    await _tapSave(tester);

    expect(find.text('저장에 실패했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(tester.getTopLeft(find.byType(MaterialBanner)).dy, lessThan(150));
    expect(find.text('식단 일일 목표'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
