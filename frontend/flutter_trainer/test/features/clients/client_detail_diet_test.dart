import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations_ko.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/metric_tile.dart';

import '../../helpers/pump_app.dart';

final AppLocalizationsKo _ko = AppLocalizationsKo();

/// Seeded client ids by display name — the detail is addressed by id.
const Map<String, String> seedClientIds = <String, String>{
  '김민수': 'seed-client-1',
  '이지수': 'seed-client-2',
  '박성호': 'seed-client-3',
  // The brand-new client: no meals, no history, no sodium series.
  '임도현': 'seed-client-7',
};

void main() {
  group('ClientRepository.watchDiet', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('returns the 3 meals in seeded order for a client', () async {
      final meals = await DriftClientRepository(
        db,
      ).watchDiet('seed-client-1').first;
      expect(meals.map((m) => m.meal).toList(), <String>['아침', '점심', '저녁']);
      expect(meals.first.items, '오트밀, 바나나');
      expect(meals.first.calories, 315);
      expect(meals.first.sodiumMg, 380);
    });

    test('returns per-client data (clients differ)', () async {
      final repo = DriftClientRepository(db);
      final jisu = await repo.watchDiet('seed-client-2').first;
      final seongho = await repo.watchDiet('seed-client-3').first;
      expect(jisu.first.items, '그릭요거트, 과일');
      expect(seongho[1].items, '짜장면'); // 점심
    });

    test('client rows carry a sodium history ending at today', () async {
      final clients = await DriftClientRepository(db).watchClients().first;
      for (final c in clients) {
        // At most a week, and never more — the sparkline draws what it
        // is given. A client who only started logging this week has
        // fewer points, and one who has not started has none.
        expect(c.sodiumWeek.length, lessThanOrEqualTo(7), reason: c.name);
        // Whatever its length, the last entry mirrors today's total
        // shown on the metric tile beside it.
        if (c.sodiumWeek.isNotEmpty) {
          expect(c.sodiumWeek.last, c.sodiumMg, reason: c.name);
        }
      }
      // The fixture must keep covering the full-week case too, or the
      // seven-point sparkline stops being exercised at all.
      expect(clients.where((c) => c.sodiumWeek.length == 7), isNotEmpty);
      final minsu = clients.firstWhere((c) => c.name == '김민수');
      expect(minsu.sodiumOverDays, greaterThan(0)); // 2400/2200/2300… over
      expect(minsu.sodiumWeekAvg, isNotNull);

      final jisu = clients.firstWhere((c) => c.name == '이지수');
      expect(jisu.sodiumOverDays, 1); // only the 2100 day is over
    });
  });

  group('DietView', () {
    Future<void> openDiet(WidgetTester tester, String clientName) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail(seedClientIds[clientName]!, section: 'diet'),
      );
    }

    testWidgets('김민수 (sodium over target) shows warning + over AI comment', (
      tester,
    ) async {
      await openDiet(tester, '김민수');

      expect(find.text('오늘 영양 요약'), findsOneWidget);
      // Nutrition metrics live only in the diet tab, not in the shared
      // detail header. The alert badge remains visible above the tabs.
      expect(find.byType(MetricTile), findsNWidgets(3));
      expect(find.text('나트륨 초과'), findsOneWidget);
      final sodiumTile = find.byWidgetPredicate(
        (widget) => widget is MetricTile && widget.label == _ko.metricSodium,
      );
      expect(sodiumTile, findsOneWidget);
      expect(
        find.descendant(of: sodiumTile, matching: find.text('2100')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sodiumTile, matching: find.text('mg 초과')),
        findsOneWidget,
      );
      // The detail header plus the 7-day trend card push every meal card
      // down, so reach them by scrolling.
      await tester.scrollUntilVisible(find.text('아침'), 150);
      expect(find.text('아침'), findsOneWidget);
      expect(find.text('오트밀, 바나나'), findsOneWidget);
      expect(find.text('315 kcal'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('점심'), 150);
      expect(find.text('점심'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('저녁'), 150);
      expect(find.text('저녁'), findsOneWidget);
      // Over-target AI comment (2100 − 2000 = 100mg) — last list item,
      // built lazily, so scroll it into view first.
      await tester.scrollUntilVisible(
        find.textContaining('나트륨이 목표치를 100mg 초과했어요'),
        150,
      );
      expect(find.textContaining('나트륨이 목표치를 100mg 초과했어요'), findsOneWidget);
    });

    testWidgets('식단 shows the 7-day sodium trend with over-days count', (
      tester,
    ) async {
      await openDiet(tester, '김민수');

      // The trend card renders with 김민수's weekly average and a
      // pattern summary (his week has several over-target days).
      await tester.scrollUntilVisible(find.text('최근 7일 나트륨 추이'), 120);
      expect(find.text('최근 7일 나트륨 추이'), findsOneWidget);
      expect(find.textContaining('평균'), findsOneWidget);
      expect(find.textContaining('목표(2000mg)를 초과했어요'), findsOneWidget);
    });

    testWidgets('a client with no logged meals gets a hint, not a verdict', (
      tester,
    ) async {
      // 임도현 has not recorded anything yet. The tiles read 0 either
      // way, so without this the tab silently praised a blank day.
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail(seedClientIds['임도현']!, section: 'diet'),
      );

      expect(find.text('아직 기록된 식단이 없어요'), findsOneWidget);
      expect(find.textContaining('균형이 잘 맞아요'), findsNothing);
      expect(find.textContaining('나트륨이 목표치를'), findsNothing);
      // The trend card is skipped too — there is no series to draw.
      expect(find.text('최근 7일 나트륨 추이'), findsNothing);
    });

    testWidgets('이지수 (sodium under target) shows the balanced AI comment', (
      tester,
    ) async {
      await openDiet(tester, '이지수');

      // The detail header sits above the list, so her 아침 card can start
      // below the fold on the test viewport.
      await tester.scrollUntilVisible(find.text('그릭요거트, 과일'), 150);
      expect(find.text('그릭요거트, 과일'), findsOneWidget);
      // Under target in the diet summary.
      expect(find.text('mg 초과'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('오늘 식단은 균형이 잘 맞아요'),
        150,
      );
      expect(find.textContaining('오늘 식단은 균형이 잘 맞아요'), findsOneWidget);
    });
  });
}
