import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('ClientRepository.watchDiet', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('returns the 3 meals in seeded order for a client', () async {
      final meals = await ClientRepository(db).watchDiet('seed-client-1').first;
      expect(meals.map((m) => m.meal).toList(), <String>['아침', '점심', '저녁']);
      expect(meals.first.items, '오트밀, 바나나');
      expect(meals.first.calories, 315);
      expect(meals.first.sodiumMg, 380);
    });

    test('returns per-client data (clients differ)', () async {
      final repo = ClientRepository(db);
      final jisu = await repo.watchDiet('seed-client-2').first;
      final seongho = await repo.watchDiet('seed-client-3').first;
      expect(jisu.first.items, '그릭요거트, 과일');
      expect(seongho[1].items, '짜장면'); // 점심
    });
  });

  group('DietView', () {
    Future<void> openDiet(WidgetTester tester, String clientName) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');
      // Lower-priority clients sit below the fold in the lazy list.
      await tester.scrollUntilVisible(find.text(clientName), 150);
      await tester.ensureVisible(find.text(clientName));
      await tester.pump();
      await tester.tap(find.text(clientName));
      await settle(tester);
      await tester.tap(find.text('식단'));
      await settle(tester);
    }

    testWidgets('김민수 (sodium over target) shows warning + over AI comment', (
      tester,
    ) async {
      await openDiet(tester, '김민수');

      expect(find.text('오늘 영양 요약'), findsOneWidget);
      // Summary totals from the client row.
      expect(find.text('2100'), findsOneWidget);
      expect(find.text('mg ⚠ 초과'), findsOneWidget);
      // 3 meals from the seed.
      expect(find.text('아침'), findsOneWidget);
      expect(find.text('점심'), findsOneWidget);
      expect(find.text('저녁'), findsOneWidget);
      expect(find.text('오트밀, 바나나'), findsOneWidget);
      expect(find.text('315 kcal'), findsOneWidget);
      // Over-target AI comment (2100 − 2000 = 100mg) — last list item,
      // built lazily, so scroll it into view first.
      await tester.scrollUntilVisible(
        find.textContaining('나트륨이 목표치를 100mg 초과했어요'),
        150,
      );
      expect(find.textContaining('나트륨이 목표치를 100mg 초과했어요'), findsOneWidget);
    });

    testWidgets('이지수 (sodium under target) shows the balanced AI comment', (
      tester,
    ) async {
      await openDiet(tester, '이지수');

      expect(find.text('그릭요거트, 과일'), findsOneWidget);
      expect(find.text('mg ⚠ 초과'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('오늘 식단은 균형이 잘 맞아요'),
        150,
      );
      expect(find.textContaining('오늘 식단은 균형이 잘 맞아요'), findsOneWidget);
    });
  });
}
