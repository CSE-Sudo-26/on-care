import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/weekly_exercise_trend_card.dart';

void main() {
  testWidgets('shows weekly count, time, and calorie trend', (tester) async {
    const week = ClientExerciseWeek(
      dayLabels: ['월', '화', '수', '목', '금', '토', '일'],
      dailyMinutes: [30, 0, 45, 0, 60, 0, 0],
      dailyCalories: [180, 0, 270, 0, 360, 0, 0],
      totalMinutes: 135,
      totalCalories: 810,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyExerciseTrendCard(week: AsyncData(week)),
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
}
