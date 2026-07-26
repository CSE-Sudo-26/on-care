import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('ClientRepository.watchHistory', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('returns 3 seeded workouts in order with decoded exercises', () async {
      final history = await ClientRepository(
        db,
      ).watchHistory('seed-client-1').first;
      expect(history.length, 3);
      expect(history.first.dateLabel, '7/12 (오늘)');
      expect(history.first.completionRate, 100);
      expect(history.first.exercises, contains('레그프레스 3세트'));
      expect(history.first.trainerNote, isNotEmpty);
      // Later entries have no trainer note (box hidden).
      expect(history[1].trainerNote, isEmpty);
    });

    test('returns per-client data (clients differ)', () async {
      final seongho = await ClientRepository(
        db,
      ).watchHistory('seed-client-3').first;
      expect(seongho.last.completionRate, 0); // 7/3 · all skipped
      expect(seongho.first.trainerNote, contains('벤치 중량'));
    });
  });

  group('WorkoutView', () {
    Future<void> openWorkout(WidgetTester tester, String clientName) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');
      await tester.tap(find.text(clientName));
      await settle(tester);
      await tester.tap(find.text('운동기록'));
      await settle(tester);
    }

    testWidgets('김민수 shows 76% weekly average, legend, and history', (
      tester,
    ) async {
      await openWorkout(tester, '김민수');

      // (100+67+100+0+100+67+100)/7 = 76.28 → 76%.
      expect(find.text('이번 주 완료율'), findsOneWidget);
      expect(find.text('76%'), findsOneWidget);
      expect(find.text('완료'), findsOneWidget);
      expect(find.text('부분'), findsOneWidget);
      expect(find.text('미완료'), findsOneWidget);

      // History entries with feedback + note boxes. Lower list items are
      // built lazily — scroll each into view before asserting.
      expect(find.text('7/12 (오늘)'), findsOneWidget);
      expect(find.text('100%'), findsWidgets);
      await tester.scrollUntilVisible(find.text('트레이너 메모'), 150);
      expect(find.text('트레이너 메모'), findsOneWidget); // only 7/12 has one
      expect(find.text('무릎 가동범위 체크 필요. 다음 세션 중량 조절 예정.'), findsOneWidget);
      expect(find.text('고객 피드백'), findsWidgets);
      // A skipped exercise line renders (struck-through content present).
      await tester.scrollUntilVisible(find.text('스트레칭 ✗ (생략)'), 150);
      expect(find.text('스트레칭 ✗ (생략)'), findsOneWidget);
    });
  });
}
