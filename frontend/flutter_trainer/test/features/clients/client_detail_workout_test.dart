import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays;
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

/// Seeded client ids by display name — the detail is addressed by id.
const Map<String, String> seedClientIds = <String, String>{
  '김민수': 'seed-client-1',
  '이지수': 'seed-client-2',
  '박성호': 'seed-client-3',
};

void main() {
  group('ClientRepository.watchHistory', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('returns 3 seeded workouts in order with decoded exercises', () async {
      final history = await DriftClientRepository(
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
      final seongho = await DriftClientRepository(
        db,
      ).watchHistory('seed-client-3').first;
      expect(seongho.last.completionRate, 0); // 7/3 · all skipped
      expect(seongho.first.trainerNote, contains('벤치 중량'));
    });
  });

  group('WorkoutView', () {
    Future<void> openWorkout(WidgetTester tester, String clientName) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail(
          seedClientIds[clientName]!,
          section: 'workout',
        ),
      );
    }

    testWidgets('김민수 averages only the weekdays that have happened', (
      tester,
    ) async {
      await openWorkout(tester, '김민수');

      // 김민수's seeded week is [100, 67, 100, 0, 100, 67, 100]. Days
      // after today haven't happened, so averaging all seven would report
      // a number the member could not have earned yet.
      const week = <int>[100, 67, 100, 0, 100, 67, 100];
      final elapsed = elapsedWeekdays(DateTime.now());
      final counted = week.take(elapsed).toList();
      final expected = (counted.reduce((a, b) => a + b) / counted.length)
          .round();

      expect(find.text('이번 주 완료율'), findsOneWidget);
      expect(find.text('$expected%'), findsOneWidget);
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
      await tester.scrollUntilVisible(find.text('스트레칭 (생략)'), 150);
      expect(find.text('스트레칭 (생략)'), findsOneWidget);
    });
  });
}
