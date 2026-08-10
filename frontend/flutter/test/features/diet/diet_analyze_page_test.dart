import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/data/repositories/mock_diet_repository.dart';
import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/meal_photo.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_analyze_page.dart';

class _RetryDietRepository extends MockDietRepository {
  int calls = 0;
  final List<String?> idempotencyKeys = <String?>[];

  @override
  Future<DietAnalysisResult> analyze({
    required MealPhoto photo,
    required String mealType,
    String? idempotencyKey,
  }) async {
    calls += 1;
    idempotencyKeys.add(idempotencyKey);
    if (calls == 1) throw StateError('lost response');
    return const DietAnalysisResult(
      entryId: 'entry-1',
      foods: <RecognizedFood>[],
      totalCalories: 0,
      totalSodiumMg: 0,
      totalSugarG: 0,
      coachComment: '',
    );
  }
}

void main() {
  testWidgets('분석 재시도는 최초 요청과 같은 멱등키를 사용한다', (WidgetTester tester) async {
    final _RetryDietRepository repository = _RetryDietRepository();
    final MealPhoto photo = MealPhoto.fromBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    )!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          dietRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: DietAnalyzePage(photo: photo, mealType: 'lunch'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(repository.idempotencyKeys.first, isNotNull);
    expect(repository.idempotencyKeys.first, isNotEmpty);
    expect(repository.idempotencyKeys.last, repository.idempotencyKeys.first);
  });
}
