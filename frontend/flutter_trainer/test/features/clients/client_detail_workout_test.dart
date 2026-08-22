import 'dart:io';

import 'package:demo_fixture/demo_fixture.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
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

/// 김민수의 값은 시드가 아니라 공유 픽스처가 정한다(#757). 기대값을 여기에 적으면
/// 픽스처와 두 벌이 되어 한쪽만 고쳤을 때 조용히 갈린다.
final DemoFixture _fixture = DemoFixture.parse(
  File('../../shared/demo_fixture/assets/kim_minsu.json').readAsStringSync(),
);

/// 운동 이력 맨 위 줄의 날짜 라벨. 오늘을 따라 움직인다.
String _todayHistoryLabel() {
  final DateTime now = nowKst();
  return '${now.month}/${now.day} (오늘)';
}

/// 운동 이력 세 줄 안에서 김민수가 거른 항목의 이름. 화면은 ✓/✗ 표시를 떼고
/// 취소선으로 보여 주므로 이름만 남는다.
String _minsuSkippedExercise() {
  final List<FixtureDay> recent = _fixture
      .daysFor(nowKst())
      .reversed
      .where((FixtureDay d) => d.exercises.isNotEmpty)
      .take(3)
      .toList();
  for (final FixtureDay day in recent) {
    for (final FixtureExercise exercise in day.exercises) {
      if (!exercise.done) return exercise.name;
    }
  }
  throw StateError('최근 사흘에 거른 항목이 없다 — 취소선 렌더링을 볼 수 없다');
}

/// 운동 기록만 정해진 세 줄로 바꾼다 — 나머지는 데모 DB 그대로.
///
/// 기간 경계는 픽스처가 아니라 오늘을 기준으로 봐야 하므로, 시드가 무엇을
/// 담고 있든 흔들리지 않게 날짜를 직접 만든다(#1114).
class _DatedHistoryRepository extends DriftClientRepository {
  _DatedHistoryRepository(super.db);

  static const String todayLabel = '오늘-기록';
  static const String oldLabel = '한참-전-기록';
  static const String undatedLabel = '날짜-없는-기록';

  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) {
    final DateTime today = todayKst();
    return Stream<List<RoutineHistoryEntry>>.value(<RoutineHistoryEntry>[
      _entry(todayLabel, today),
      _entry(undatedLabel, null),
      _entry(oldLabel, today.subtract(const Duration(days: 30))),
    ]);
  }

  RoutineHistoryEntry _entry(String label, DateTime? completedAt) =>
      RoutineHistoryEntry(
        dateLabel: label,
        label: 'PT 세션 · 트레이너 지도',
        completionRate: 100,
        exercises: const <String>['스쿼트 3세트'],
        clientFeedback: '',
        trainerNote: '',
        completedAt: completedAt,
      );
}

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

class _FeedbackRepository extends DriftClientRepository {
  _FeedbackRepository(super.db)
    : entry = const RoutineHistoryEntry(
        id: 'assigned-ex-r1',
        dateLabel: '8/13 (오늘)',
        label: '코어 운동',
        completionRate: 100,
        exercises: <String>['코어 운동 · 30분'],
        clientFeedback: '마지막 세트가 힘들었어요',
        trainerNote: '',
        assignedRoutineId: 'r1',
      );

  RoutineHistoryEntry entry;
  int updateCalls = 0;

  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) =>
      Stream<List<RoutineHistoryEntry>>.value(<RoutineHistoryEntry>[entry]);

  @override
  Future<RoutineHistoryEntry> updateHistoryFeedback(
    String clientId,
    String historyId,
    String feedback,
  ) async {
    updateCalls += 1;
    entry = RoutineHistoryEntry(
      id: entry.id,
      dateLabel: entry.dateLabel,
      label: entry.label,
      completionRate: entry.completionRate,
      exercises: entry.exercises,
      clientFeedback: entry.clientFeedback,
      trainerNote: feedback,
      assignedRoutineId: entry.assignedRoutineId,
    );
    return entry;
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
      // 날짜 라벨은 오늘을 따라 움직인다. 예전에는 `'7/12 (오늘)'` 로 박혀 있어
      // 데모를 언제 열든 7월 12일이 "오늘"이었다(#757).
      final DateTime now = nowKst();
      expect(history.first.dateLabel, '${now.month}/${now.day} (오늘)');
      expect(history.first.completionRate, 100);
      // 종목 이름은 픽스처가 정한다 — 여기 적으면 두 벌이 된다.
      expect(
        history.first.exercises,
        contains('${_fixture.daysFor(nowKst()).last.exercises.first.name} ✓'),
      );
      expect(history.first.trainerNote, isNotEmpty);
      // Later entries have no trainer note (box hidden).
      expect(history[1].trainerNote, isEmpty);
      // 데모도 실 API 처럼 완료 날짜를 들고 온다 — 이 값이 비면 화면이
      // 기간으로 거를 수 없다(#1114). 라벨과 같은 날을 가리켜야 한다.
      final DateTime? completedAt = history.first.completedAt;
      expect(completedAt, isNotNull);
      expect(
        DateTime(completedAt!.year, completedAt.month, completedAt.day),
        DateTime(now.year, now.month, now.day),
      );
      // 피드백 수정이 가리킬 id 도 함께 온다 — 예전에는 로컬 모드에서만 늘
      // 빈 문자열이라, 실 API 와 다른 엔티티가 화면에 올라갔다.
      expect(history.first.id, 'seed-history-1-0');
    });

    test('returns per-client data (clients differ)', () async {
      final seongho = await DriftClientRepository(
        db,
      ).watchHistory('seed-client-3').first;
      expect(seongho.last.completionRate, 0); // 7/3 · all skipped
      expect(seongho.first.trainerNote, contains('벤치 중량'));
    });
  });

  group('ClientRepository.fetchExerciseWeek', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('derives demo weekly totals from the same client week', () async {
      final week = await DriftClientRepository(
        db,
      ).fetchExerciseWeek('seed-client-1');
      expect(week.dayLabels, hasLength(7));
      expect(week.dailyMinutes, hasLength(7));
      expect(week.workoutCount, greaterThan(0));
      expect(week.totalMinutes, week.dailyMinutes.reduce((a, b) => a + b));
      expect(week.totalCalories, week.dailyCalories.reduce((a, b) => a + b));
    });
  });

  group('WorkoutView', () {
    // 식단·운동은 자기 `ListView` 를 만들지 않는다(#1024) — 신체·목표·메모
    // 패널과 하나의 스크롤을 공유하도록 `embedded: true` 로 그려진다. 그
    // 공유 스크롤(`ListView`) 자체가 `client-detail-tabs-$clientId` 키를
    // 달고 있다.
    Finder detailScrollable(String clientId) => find
        .descendant(
          of: find.byKey(ValueKey<String>('client-detail-tabs-$clientId')),
          matching: find.byType(Scrollable),
        )
        .first;

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

    testWidgets('배정 루틴 수행 기록에 피드백을 작성하고 수정한다', (tester) async {
      late _FeedbackRepository repository;
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail('seed-client-1', section: 'workout'),
        extraOverrides: <Override>[
          clientRepositoryProvider.overrideWith((ref) {
            repository = _FeedbackRepository(ref.watch(appDatabaseProvider));
            return repository;
          }),
        ],
      );

      final Finder feedbackButton = find.byKey(
        const ValueKey<String>('routine-feedback-assigned-ex-r1'),
      );
      await tester.scrollUntilVisible(
        feedbackButton,
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      await tester.ensureVisible(feedbackButton);
      await settle(tester);
      await tester.tap(feedbackButton);
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('routine-feedback-input')),
        '자세가 안정적이었어요',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('routine-feedback-save')),
      );
      await settle(tester);

      expect(repository.updateCalls, 1);
      expect(find.text('자세가 안정적이었어요'), findsOneWidget);
      expect(find.text('피드백 수정'), findsOneWidget);
    });

    testWidgets('김민수 운동 기록이 날짜·이행률·메모와 함께 보인다', (tester) async {
      await openWorkout(tester, '김민수');

      // The tab opens on the routines it absorbed from the old 루틴 tab;
      // 이번 주는 운동 현황 카드 하나로만 요약한다 — 같은 주를 완료율 카드로
      // 한 번 더 세던 자리는 걷어냈다.
      expect(find.text('배정된 루틴'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('운동 현황'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.text('운동 현황'), findsOneWidget);
      expect(find.text('이번 주 완료율'), findsNothing);

      // 목록은 이제 고른 기간만 보여 준다(#1114). 이 테스트가 확인하려는
      // 카드 구성(날짜·이행률·메모·취소선)은 오늘 하루에 다 있지 않으므로
      // 전체로 넓혀 둔다 — 토글은 `운동 현황` 과 같은 줄에 있다.
      // `scrollUntilVisible` 은 위젯이 **지어지면** 멈추므로 캐시에만 있고
      // 화면 밖일 수 있다. 누르기 전에 실제로 보이는 자리까지 끌어온다.
      await tester.ensureVisible(find.byKey(const Key('client-period-month')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('client-period-month')));
      await settle(tester);

      // History entries with feedback + note boxes. Lower list items are
      // built lazily — scroll each into view before asserting.
      await tester.scrollUntilVisible(
        find.text(_todayHistoryLabel()),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.text(_todayHistoryLabel()), findsOneWidget);
      expect(find.text('100%'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('트레이너 메모'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.text('트레이너 메모'), findsOneWidget); // 오늘 것만 메모가 있다
      expect(find.text('무릎 가동범위 체크 필요. 다음 세션 중량 조절 예정.'), findsOneWidget);
      expect(find.text('고객 피드백'), findsWidgets);
      // A skipped exercise line renders (struck-through content present).
      // 어느 항목을 걸렀는지는 픽스처가 정한다 — 이름을 여기 적으면 두 벌이 된다.
      // 기록이 여러 달치라 같은 이름의 거른 항목이 여러 번 나온다.
      // `scrollUntilVisible` 은 대상이 **하나**일 때만 쓸 수 있으므로 직접
      // 내려가며 찾는다. (#1024 로 기록 카드가 한 스크롤에 함께 마운트되면서
      // 중복이 더 흔해졌다 — 이 방식은 그때도 그대로 통한다.)
      final String skipped = _minsuSkippedExercise();
      final Finder skippedLine = find.text(skipped);
      final Finder list = detailScrollable('seed-client-1');
      for (int i = 0; i < 40 && skippedLine.evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -150));
        await tester.pump();
      }
      expect(skippedLine, findsWidgets);
    });

    // 목록은 게으르게 지어진다 — 화면 밖 카드는 아직 위젯이 아니라, 한 자리에
    // 서서 `findsNothing` 을 물으면 없는 것과 아직 안 만든 것을 구분하지 못한다.
    // 맨 위부터 끝까지 훑으며 한 번이라도 보였는지 본다.
    Future<void> scrollListToTop(WidgetTester tester) async {
      final Finder list = detailScrollable('seed-client-1');
      for (int i = 0; i < 30; i++) {
        await tester.drag(list, const Offset(0, 300));
        await tester.pump();
      }
    }

    Future<bool> seenWhileScrolling(WidgetTester tester, Finder finder) async {
      final Finder list = detailScrollable('seed-client-1');
      await scrollListToTop(tester);
      for (int i = 0; i < 40; i++) {
        if (finder.evaluate().isNotEmpty) return true;
        await tester.drag(list, const Offset(0, -150));
        await tester.pump();
      }
      return finder.evaluate().isNotEmpty;
    }

    testWidgets('운동 기록 목록이 위 그래프와 같은 기간을 본다 (#1114)', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.clientDetail('seed-client-1', section: 'workout'),
        extraOverrides: <Override>[
          clientRepositoryProvider.overrideWith(
            (ref) => _DatedHistoryRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await settle(tester);

      final Finder todayRecord = find.text(_DatedHistoryRepository.todayLabel);
      final Finder oldRecord = find.text(_DatedHistoryRepository.oldLabel);
      final Finder undatedRecord = find.text(
        _DatedHistoryRepository.undatedLabel,
      );

      // 기본은 오늘 — 한 달 전 기록까지 늘어놓으면 위 그래프와 아래 목록이
      // 서로 다른 기간을 이야기한다.
      expect(await seenWhileScrolling(tester, todayRecord), isTrue);
      // 날짜를 모르는 기록은 어느 기간에서도 사라지지 않는다.
      expect(await seenWhileScrolling(tester, undatedRecord), isTrue);
      expect(await seenWhileScrolling(tester, oldRecord), isFalse);

      // 토글은 `운동 현황` 과 같은 줄에 있다. 훑고 난 목록은 맨 아래에 있으므로
      // 위로 되돌린 뒤 내려가며 찾는다.
      await scrollListToTop(tester);
      await tester.scrollUntilVisible(
        find.text('운동 현황'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      // `scrollUntilVisible` 은 위젯이 **지어지면** 멈춘다 — 캐시에만 있고
      // 화면 밖일 수 있어, 누르기 전에 실제로 보이는 자리까지 끌어온다.
      await tester.ensureVisible(find.byKey(const Key('client-period-month')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('client-period-month')));
      await settle(tester);

      expect(await seenWhileScrolling(tester, oldRecord), isTrue);
      expect(await seenWhileScrolling(tester, todayRecord), isTrue);
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
      await tester.scrollUntilVisible(
        find.text('운동 현황'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.text('운동 현황'), findsOneWidget);
      // The failure is reported in place, where the history would be.
      await tester.scrollUntilVisible(
        find.text('운동 기록을 불러오지 못했어요'),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.text('운동 기록을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('history transport detail'), findsNothing);

      // 재시도 버튼은 안내 문구 바로 아래라, 문구가 보이는 지점에서 아직
      // 화면 밖일 수 있다 — 눌러야 할 것을 직접 끌어올린다.
      final retry = find.byKey(
        const ValueKey<String>('workout-history-retry-seed-client-1'),
      );
      await tester.ensureVisible(retry);
      await settle(tester);
      await tester.tap(retry);
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text(_todayHistoryLabel()),
        150,
        scrollable: detailScrollable('seed-client-1'),
      );

      final repository =
          container.read(clientRepositoryProvider)
              as _HistoryFailsOnceRepository;
      expect(repository.watchHistoryCalls, 2);
      expect(find.text(_todayHistoryLabel()), findsOneWidget);
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
      await tester.scrollUntilVisible(
        retry,
        150,
        scrollable: detailScrollable('seed-client-1'),
      );
      await tester.ensureVisible(retry);
      await settle(tester);
      await tester.tap(retry);
      await settle(tester);

      final repository =
          container.read(scheduleRepositoryProvider)
              as _SessionsFailsOnceRepository;
      expect(repository.watchSessionCalls, 2);
      final scrollable = detailScrollable('seed-client-1');
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('복구 PT'),
        150,
        scrollable: scrollable,
      );
      expect(find.textContaining('복구 PT'), findsOneWidget);
      // 운동 현황 카드는 PT 일정 **위**에 있다. 복구 PT 까지 내려온 뒤에는
      // 위로 되짚어야 나온다 — 기간 토글이 카드 제목 줄로 들어가면서(#914)
      // 카드가 짧아져, 내려온 자리에서 그대로 보이지는 않는다.
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('운동 현황'),
        200,
        scrollable: detailScrollable('seed-client-1'),
      );
      expect(find.text('운동 현황'), findsOneWidget);
    });
  });
}
