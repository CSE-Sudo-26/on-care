import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('ClientRepository', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('watchClients returns the 3 seeded clients in order', () async {
      final clients = await ClientRepository(db).watchClients().first;
      expect(clients.map((c) => c.name).toList(), <String>[
        '김민수',
        '이지수',
        '박성호',
      ]);
    });

    test('sodiumOverBudget flags only clients above 2000mg', () async {
      final clients = await ClientRepository(db).watchClients().first;
      expect(
        clients.where((c) => c.sodiumOverBudget).map((c) => c.name).toSet(),
        <String>{'김민수', '박성호'}, // 2100, 2400; 이지수 1800 is under
      );
    });

    test('reservation count excludes 공백 slots', () async {
      final count = await ClientRepository(
        db,
      ).watchTodayReservationCount().first;
      expect(count, 4); // 6 slots − 2 공백
    });

    test('reservation count excludes non-today schedule rows', () async {
      // A booked session on a different date must NOT inflate today's badge.
      await db
          .into(db.trainerScheduleEntries)
          .insert(
            TrainerScheduleEntriesCompanion.insert(
              id: 'schedule-other-day',
              date: '2020-01-01',
              time: '10:00',
              status: '예정',
              clientName: const Value('과거 고객'),
            ),
          );

      final count = await ClientRepository(
        db,
      ).watchTodayReservationCount().first;
      expect(count, 4); // still 4 — the 2020 row is excluded
    });
  });

  group('ClientsPage', () {
    testWidgets('renders the 3 clients, AI summary count, and badge', (
      tester,
    ) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');

      // Top-of-list assertions first (the header/badge/AI card scroll away
      // once we scroll down to reach the lazily-built third card).
      expect(find.text('고객 관리'), findsWidgets);
      // 2 clients over the sodium target (김민수 2100, 박성호 2400).
      // The AI summary is a Text.rich, so match with findRichText.
      expect(
        find.textContaining('나트륨 초과 고객 2명', findRichText: true),
        findsOneWidget,
      );
      // 4 booked sessions today (6 slots − 2 gaps).
      expect(find.text('오늘 4명 예약'), findsOneWidget);

      // Priority order: sodium-over clients (김민수, 박성호) come first;
      // 이지수 is last and lazily built, so scroll to reach her.
      expect(find.text('김민수'), findsOneWidget);
      expect(find.text('박성호'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('이지수'), 150);
      expect(find.text('이지수'), findsOneWidget);
    });

    testWidgets('tapping a client card opens the detail screen', (
      tester,
    ) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');

      await tester.tap(find.text('김민수'));
      await settle(tester);

      // Detail screen opened — its 채팅/식단/운동기록 sub-tabs are unique to it.
      expect(find.text('채팅'), findsOneWidget);
      expect(find.text('운동기록'), findsOneWidget);
    });
  });
}
