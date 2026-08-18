import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/weekly_exercise_trend_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

void main() {
  test('counts every session when multiple workouts occur on one day', () {
    final week = ClientExerciseWeek.fromJson(<String, Object?>{
      'day_labels': <String>['월'],
      'daily_minutes': <int>[60],
      'daily_calories': <int>[420],
      'total_minutes': 60,
      'total_calories': 420,
      'sessions': <Object?>[
        <String, Object?>{'duration_minutes': 30},
        <String, Object?>{'duration_minutes': 30},
      ],
    });

    expect(week.workoutCount, 2);
  });

  testWidgets('shows weekly count, time, and calorie trend', (tester) async {
    const week = ClientExerciseWeek(
      dayLabels: ['월', '화', '수', '목', '금', '토', '일'],
      dailyMinutes: [30, 0, 45, 0, 60, 0, 0],
      dailyCalories: [180, 0, 270, 0, 360, 0, 0],
      totalMinutes: 135,
      totalCalories: 810,
    );
    await tester.pumpWidget(
      MaterialApp(
        // 카드 문구가 l10n 에서 오므로 로케일을 고정한다 — 비워 두면 실행
        // 환경의 시스템 로케일에 따라 영어로 그려진다.
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyExerciseTrendCard(
              week: const AsyncData(week),
              onRetry: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('이번 주 운동 추이'), findsOneWidget);
    expect(find.text('운동 횟수'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^3 '), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp(r'^135 '), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp(r'^810 '), findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('칼로리'));
    await tester.pumpAndSettle();
    expect(find.text('180kcal'), findsOneWidget);
    expect(find.text('360kcal'), findsOneWidget);
  });

  testWidgets('retries only when the error action is pressed', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WeeklyExerciseTrendCard(
            week: AsyncError(Exception('network'), StackTrace.empty),
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('weekly-exercise-retry')),
    );
    expect(retries, 1);
  });
}
