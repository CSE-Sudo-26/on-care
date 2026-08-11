import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/dashboard/domain/dashboard_summary.dart'
    show elapsedWeekdays;
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

/// Seeded client ids by display name — the detail is addressed by id.
const Map<String, String> seedClientIds = <String, String>{
  '김민수': 'seed-client-1',
  '이지수': 'seed-client-2',
  '박성호': 'seed-client-3',
};

/// Fails the first `watchHistory`; every other read still succeeds.
class _HistoryFailsOnceRepository extends DriftClientRepository {
  _HistoryFailsOnceRepository(super.db);

  int watchHistoryCalls = 0;

  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) {
    watchHistoryCalls++;
    if (watchHistoryCalls == 1) {
      return Stream<List<RoutineHistoryEntry>>.error(
        Exception('history transport detail'),
      );
    }
    return super.watchHistory(clientId);
  }
}

class _AssignedFailsOnceRepository extends MockTrainerRoutineRepository {
  int watchAssignedCalls = 0;

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) {
    watchAssignedCalls++;
    if (watchAssignedCalls == 1) {
      return Stream<List<AssignedRoutine>>.error(
        Exception('routine transport detail'),
      );
    }
    return Stream<List<AssignedRoutine>>.value(const <AssignedRoutine>[
      AssignedRoutine(
        id: 'routine-recovered',
        name: '복구 루틴',
        minutes: 40,
        type: '근력',
        reason: '재시도 검증',
        source: 'trainer',
      ),
    ]);
  }
}

class _SessionsFailsOnceRepository extends DriftScheduleRepository {
  _SessionsFailsOnceRepository(super.db);

  int watchSessionCalls = 0;

  @override
  Stream<List<ScheduleSession>> watchClientSessions(ScheduleClientKey client) {
    watchSessionCalls++;
    if (watchSessionCalls == 1) {
      return Stream<List<ScheduleSession>>.error(
        Exception('schedule transport detail'),
      );
    }
    return Stream<List<ScheduleSession>>.value(const <ScheduleSession>[
      ScheduleSession(
        id: 'session-recovered',
        date: '2026-08-11',
        time: '10:00',
        clientId: 'seed-client-1',
        clientName: '김민수',
        type: '복구 PT',
        durationMinutes: 50,
        status: ScheduleStatus.upcoming,
        note: '',
        program: <ProgramItem>[],
      ),
    ]);
  }
}

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

      // The tab now opens on the routines it absorbed from the old 루틴
      // tab, so the completion card starts below the fold.
      expect(find.text('배정된 루틴'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('이번 주 완료율'), 150);
      expect(find.text('이번 주 완료율'), findsOneWidget);
      expect(find.text('$expected%'), findsOneWidget);
      // '완료' is also a PT session's status in the card above, so the
      // legend is matched loosely; 부분/미완료 are legend-only.
      expect(find.text('완료'), findsWidgets);
      expect(find.text('부분'), findsOneWidget);
      expect(find.text('미완료'), findsOneWidget);

      // History entries with feedback + note boxes. Lower list items are
      // built lazily — scroll each into view before asserting.
      await tester.scrollUntilVisible(find.text('7/12 (오늘)'), 150);
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

    testWidgets('a failed 운동 기록 load does not take the routines with it', (
      tester,
    ) async {
      // 배정된 루틴 and the PT sessions used to be their own tab, so they
      // stayed reachable when the history endpoint was down. Gating the
      // whole list on the history provider silently undid that.
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail(seedClientIds['김민수']!, section: 'workout'),
        extraOverrides: <Override>[
          clientRepositoryProvider.overrideWith(
            (ref) =>
                _HistoryFailsOnceRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );

      // The sections above the history still rendered — they are the
      // first thing on the tab, so the failure did not blank it.
      expect(find.text('배정된 루틴'), findsOneWidget);
      expect(find.text('PT 프로그램 이력'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('이번 주 완료율'), 150);
      expect(find.text('이번 주 완료율'), findsOneWidget);
      // The failure is reported in place, where the history would be.
      await tester.scrollUntilVisible(find.text('운동 기록을 불러오지 못했어요'), 150);
      expect(find.text('운동 기록을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('history transport detail'), findsNothing);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workout-history-retry-seed-client-1'),
        ),
      );
      await settle(tester);
      await tester.scrollUntilVisible(find.text('7/12 (오늘)'), 150);

      final repository =
          container.read(clientRepositoryProvider)
              as _HistoryFailsOnceRepository;
      expect(repository.watchHistoryCalls, 2);
      expect(find.text('7/12 (오늘)'), findsOneWidget);
    });

    testWidgets('배정 루틴 실패만 재시도해 다른 영역을 보존한다', (tester) async {
      final repository = _AssignedFailsOnceRepository();
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail('seed-client-1', section: 'workout'),
        extraOverrides: <Override>[
          trainerRoutineRepositoryProvider.overrideWithValue(repository),
        ],
      );

      expect(find.text('루틴을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('PT 프로그램 이력'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey<String>('assigned-routines-retry-seed-client-1'),
        ),
      );
      await settle(tester);

      expect(repository.watchAssignedCalls, 2);
      expect(find.text('복구 루틴'), findsOneWidget);
      expect(find.text('PT 프로그램 이력'), findsOneWidget);
    });

    testWidgets('PT 일정 실패만 재시도해 다른 영역을 보존한다', (tester) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail('seed-client-1', section: 'workout'),
        extraOverrides: <Override>[
          scheduleRepositoryProvider.overrideWith(
            (ref) =>
                _SessionsFailsOnceRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );

      expect(find.text('일정을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('배정된 루틴'), findsOneWidget);
      final retry = find.byKey(const ValueKey<String>('client-sessions-retry'));
      await tester.drag(find.byType(ListView).last, const Offset(0, -180));
      await tester.pump();
      await tester.tap(retry);
      await settle(tester);

      final repository =
          container.read(scheduleRepositoryProvider)
              as _SessionsFailsOnceRepository;
      expect(repository.watchSessionCalls, 2);
      expect(find.textContaining('복구 PT'), findsOneWidget);
      expect(find.text('이번 주 완료율'), findsOneWidget);
    });
  });
}
