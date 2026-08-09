import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/entities/meal_recommendation.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_entry_detail_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// updateEntry 호출 여부·인자를 기록하는 페이크. 그 외는 미사용.
class _RecordingDietRepository implements DietRepository {
  int updateCalls = 0;
  double? lastSugarG;

  @override
  Future<MealRecommendations> fetchRecommendations() async =>
      MealRecommendations.fallback;

  @override
  Future<DietEntry> updateEntry({
    required String id,
    String? mealType,
    String? timeLabel,
    List<FoodItem>? foods,
    int? totalCalories,
    int? sodiumMg,
    double? sugarG,
  }) async {
    updateCalls += 1;
    lastSugarG = sugarG;
    return DietEntry(
      id: id,
      mealType: MealType.lunch,
      timeLabel: timeLabel ?? '',
      foods: foods ?? const <FoodItem>[],
      totalCalories: totalCalories ?? 0,
      sodiumMg: sodiumMg ?? 0,
      sugarG: sugarG ?? 0,
    );
  }

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<DietDay> fetchByDate(DateTime date) async =>
      throw UnimplementedError();

  @override
  Future<DietDay> fetchToday() async => throw UnimplementedError();

  @override
  Future<DietAnalysisResult> analyze({
    required Uint8List imageBytes,
    required String filename,
    required String mealType,
    String? idempotencyKey,
  }) async => throw UnimplementedError();
}

DietEntry _entry() => const DietEntry(
  id: 'e1',
  mealType: MealType.lunch,
  timeLabel: '12:40',
  totalCalories: 750,
  sodiumMg: 3200,
  sugarG: 8.5,
  foods: <FoodItem>[FoodItem(name: '짬뽕', calories: 750, sodiumMg: 3200, sugarG: 8.5)],
);

Future<void> _pump(WidgetTester tester, _RecordingDietRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        dietRepositoryProvider.overrideWithValue(repo as DietRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: DietEntryDetailPage(entry: _entry()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DietEntryDetailPage 당류 입력 검증 (리뷰 #292)', () {
    testWidgets('잘못된 당류 값은 저장을 막고 안내 메시지를 보여준다', (tester) async {
      final repo = _RecordingDietRepository();
      await _pump(tester, repo);

      // 소수점이 두 개인 잘못된 값(파싱 실패) 입력.
      await tester.enterText(find.byKey(const Key('sugarField')), '8.5.3');
      await tester.tap(find.text('수정 완료'));
      await tester.pumpAndSettle();

      // 안내 메시지 노출 + 저장 차단(예전엔 조용히 0으로 저장됐다).
      expect(find.text('0 이상의 숫자만 입력해 주세요.'), findsOneWidget);
      expect(repo.updateCalls, 0);
    });

    testWidgets('유효한 소수 당류 값은 그대로 저장된다', (tester) async {
      final repo = _RecordingDietRepository();
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('sugarField')), '12.5');
      await tester.tap(find.text('수정 완료'));
      await tester.pumpAndSettle();

      expect(repo.updateCalls, 1);
      expect(repo.lastSugarG, 12.5);
    });
  });
}
