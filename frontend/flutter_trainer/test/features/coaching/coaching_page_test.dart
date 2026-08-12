import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/ai_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/auth/data/repositories/dio_trainer_auth_repository.dart'
    show trainerAuthRepositoryProvider;
import 'package:oncare_trainer/features/auth/domain/entities/auth_tokens.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/domain/entities/member_health_profile.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

import '../../helpers/pump_app.dart';

/// A chat repository whose sends always fail.
class _FailingChatRepository extends DriftChatRepository {
  const _FailingChatRepository(super.db);

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async => throw Exception('chat write failed');
}

/// A chat repository whose sends resolve slowly, so a client switch can
/// land while a send is still in flight (review PR 239).
class _SlowChatRepository extends DriftChatRepository {
  const _SlowChatRepository(super.db);

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return super.sendTrainerMessage(clientId: clientId, text: text);
  }
}

/// Counts registration calls and delays them, to test the in-flight
/// double-tap guard.
class _SlowCountingScheduleRepository extends DriftScheduleRepository {
  _SlowCountingScheduleRepository(super.db);

  int registerCalls = 0;

  @override
  Future<bool> registerProgram({
    required String date,
    required String clientId,
    required String clientName,
    required String time,
    required List<ProgramItem> program,
  }) async {
    registerCalls++;
    // Keep the write in flight across client-switching/scroll animations.
    await Future<void>.delayed(const Duration(seconds: 5));
    return super.registerProgram(
      date: date,
      clientId: clientId,
      clientName: clientName,
      time: time,
      program: program,
    );
  }
}

/// Captures the schedule operation selected by the coaching page without
/// performing a local write. Dio behavior is covered by its repository test.
class _CapturingScheduleRepository extends DriftScheduleRepository {
  _CapturingScheduleRepository(super.db);

  int registerCalls = 0;
  String? clientId;
  List<ProgramItem>? program;

  @override
  Future<bool> registerProgram({
    required String date,
    required String clientId,
    required String clientName,
    required String time,
    required List<ProgramItem> program,
  }) async {
    registerCalls++;
    this.clientId = clientId;
    this.program = program;
    return true;
  }
}

/// Supplies explicit non-drift suggestions to tests that focus on real API
/// assignment behavior rather than on the initial recommendation source.
class _FixedAiRoutineRepository implements AiRoutineRepository {
  const _FixedAiRoutineRepository(this.items);

  final List<AiRoutineItem> items;

  @override
  Stream<List<AiRoutineItem>> watchRoutine(
    String clientId, {
    String? clientName,
  }) => Stream<List<AiRoutineItem>>.value(items);
}

/// A fixed one-client roster for real-API-mode tests (real
/// `ClientRepository` has no roster mutations and a single fetch, unlike
/// the reactive drift source).
class _FixedClientRepository implements ClientRepository {
  const _FixedClientRepository(this._clients);

  final List<TrainerClient> _clients;

  @override
  bool get supportsRosterMutations => false;

  @override
  Stream<List<TrainerClient>> watchClients() => Stream.value(_clients);

  @override
  Stream<Map<String, DateTime>> watchLastChatAt() =>
      Stream<Map<String, DateTime>>.value(const <String, DateTime>{});

  @override
  Stream<List<ClientDietEntry>> watchDiet(String clientId) =>
      Stream.value(const <ClientDietEntry>[]);

  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) =>
      Stream.value(const <RoutineHistoryEntry>[]);

  @override
  Future<MemberHealthProfile> fetchHealthProfile(String clientId) async =>
      MemberHealthProfile(memberId: clientId, memberName: '회원');

  @override
  Future<MemberHealthProfile> updateHealthProfile(
    String clientId,
    Map<String, Object?> values,
  ) => fetchHealthProfile(clientId);
  @override
  Future<ClientExerciseWeek> fetchExerciseWeek(String clientId) async =>
      const ClientExerciseWeek(
        dayLabels: <String>[],
        dailyMinutes: <int>[],
        dailyCalories: <int>[],
        totalMinutes: 0,
        totalCalories: 0,
      );

  @override
  Future<bool> clientNameExists(String name) async => false;

  @override
  Future<bool> addClient({required String name, required String goal}) async =>
      false;

  @override
  Future<void> setClientActive(String id, bool active) async {}
}

/// Spies on `assignRoutine` (captures the [AssignedRoutine] sent) and can
/// be configured to throw a specific error, so tests can distinguish the
/// ambiguous (network) failure message from the generic one (subin21cc
/// review Major#2a).
class _SpyTrainerRoutineRepository implements TrainerRoutineRepository {
  @override
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  }) async {}

  @override
  Future<void> deleteRoutine(String memberId, String routineId) async {}

  _SpyTrainerRoutineRepository({this.throwOnAssign});

  final Object? throwOnAssign;
  AssignedRoutine? lastAssigned;

  /// 전송 시도마다 넘어온 멱등키. 재시도가 같은 키를 쓰는지 본다(#581).
  final List<String?> assignAttempts = <String?>[];

  @override
  Future<void> assignRoutine(
    String memberId,
    AssignedRoutine routine, {
    String? clientRequestId,
  }) async {
    assignAttempts.add(clientRequestId);
    if (throwOnAssign != null) throw throwOnAssign!;
    lastAssigned = routine;
  }

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) =>
      Stream.value(const <AssignedRoutine>[]);
}

/// A real-API-mode chat repository whose send can be made to fail, to
/// prove routine delivery (assignRoutine) doesn't touch chat at all — a
/// failing chat repo must have zero effect on the "전송 완료" claim
/// (subin21cc review Major#2a).
class _FakeRealChatRepository implements ChatRepository {
  _FakeRealChatRepository({this.failSend = false});

  final bool failSend;

  @override
  Stream<List<ClientChatMessage>> watchThread(String clientId) =>
      Stream.value(const <ClientChatMessage>[]);

  @override
  Future<void> sendTrainerMessage({
    required String clientId,
    required String text,
  }) async {
    if (failSend) throw Exception('note failed');
  }

  @override
  Stream<Map<String, int>> watchUnreadCounts() =>
      Stream.value(const <String, int>{});

  @override
  Future<void> markThreadRead(String clientId) async {}
}

/// Resolves `fetchProfile` immediately with the seed trainer profile, so
/// `SessionController._restore()` doesn't hit a real Dio call during
/// real-API-mode tests (the persisted token would otherwise trigger
/// `DioTrainerAuthRepository.fetchProfile`).
class _FakeTrainerAuthRepository implements TrainerAuthRepository {
  const _FakeTrainerAuthRepository();

  static const _tokens = TrainerAuthTokens(access: 'a', refresh: 'r');

  @override
  Future<TrainerAuthTokens> login({
    required String email,
    required String password,
  }) async => _tokens;

  @override
  Future<TrainerAuthTokens> register({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) async => _tokens;

  @override
  Future<TrainerAuthTokens> socialLogin({
    required String provider,
    required String token,
  }) async => _tokens;

  @override
  Future<TrainerAuthTokens> refresh(String refreshToken) async => _tokens;

  @override
  Future<TrainerProfile> fetchProfile(String accessToken) async =>
      seedTrainerProfile;
}

void main() {
  test('real API mode never exposes bundled drift recommendations', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: Environment.dev,
            apiBaseUrl: 'http://localhost/v1',
            useMockApi: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(aiRoutineRepositoryProvider),
      isA<EmptyAiRoutineRepository>(),
    );
    expect(
      await container.read(
        aiRoutineProvider((id: 'real-client-1', name: '김민수')).future,
      ),
      isEmpty,
    );
  });

  group('demo coaching repositories', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('returns the 3 seeded suggestions in order per client', () async {
      final repo = DriftAiRoutineRepository(db);
      final minsu = await repo.watchRoutine('seed-client-1').first;
      expect(minsu.length, 3);
      expect(minsu.first.name, '저강도 유산소 (걷기)');
      expect(minsu.first.minutes, 30);
      expect(minsu.first.type, '유산소');

      final jisu = await repo.watchRoutine('seed-client-2').first;
      expect(jisu.first.name, '인터벌 런닝');
    });

    test(
      'resolves live backend ids through the matching client name',
      () async {
        final repo = DriftAiRoutineRepository(db);

        final minsu = await repo
            .watchRoutine('user-demo', clientName: '김민수')
            .first;

        expect(minsu.length, 3);
        expect(minsu.first.name, '저강도 유산소 (걷기)');
      },
    );

    test(
      'registerToTodaySchedule attaches to an existing 예정 session',
      () async {
        final repo = DriftScheduleRepository(db);
        // 박성호 has a seeded 15:00 예정 session.
        final attached = await repo.registerProgram(
          date: ymd(DateTime.now()),
          clientId: 'seed-client-3',
          clientName: '박성호',
          time: '10:00',
          program: const <ProgramItem>[
            ProgramItem(name: '저강도 유산소', sets: 1, reps: '30분', weight: '-'),
          ],
        );
        expect(attached, isTrue);

        final rows = await db.select(db.trainerScheduleEntries).get();
        final his = rows.where((r) => r.clientName == '박성호').toList();
        expect(his.length, 1); // no extra slot booked
        expect(his.single.programJson, contains('저강도 유산소'));
      },
    );

    test(
      'registerToTodaySchedule books a new slot when no 예정 exists',
      () async {
        final repo = DriftScheduleRepository(db);
        // 김민수's only session today is 완료 — a new slot gets booked.
        final attached = await repo.registerProgram(
          date: ymd(DateTime.now()),
          clientId: 'seed-client-1',
          clientName: '김민수',
          time: '10:00',
          program: const <ProgramItem>[
            ProgramItem(name: '코어 강화', sets: 1, reps: '10분', weight: '-'),
          ],
        );
        expect(attached, isFalse);

        final rows = await db.select(db.trainerScheduleEntries).get();
        final his = rows.where((r) => r.clientName == '김민수').toList();
        expect(his.length, 2);
        final booked = his.firstWhere((r) => r.status == '예정');
        expect(booked.programJson, contains('코어 강화'));
        expect(booked.id.startsWith('seed-'), isFalse);
      },
    );
  });

  group('CoachingPage', () {
    Future<void> openTab(WidgetTester tester) async {
      // Desktop surface: the workspace splits into overview | editor,
      // so both columns are on screen the way a trainer sees them.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1600, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.coaching,
      );
    }

    testWidgets('defaults to the first client with verdict and routine', (
      tester,
    ) async {
      await openTab(tester);

      expect(find.text('AI 코칭'), findsWidgets);
      // 김민수 (3428mg, over) → cardio-boost verdict.
      expect(find.text('AI 판단: 나트륨 초과 → 유산소 강화 권장'), findsOneWidget);
      expect(find.text('17.8'), findsOneWidget);
      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
      expect(find.text('혈압 안정에 효과적'), findsOneWidget);
    });

    testWidgets('opens the A/B assistant inline in the AI routine tab', (
      tester,
    ) async {
      await openTab(tester);

      expect(find.text('AI에게 맞춤 루틴 요청하기'), findsOneWidget);
      await tester.tap(find.text('AI에게 맞춤 루틴 요청하기'));
      await tester.pumpAndSettle();

      expect(find.text('고객 데이터를 분석했어요'), findsOneWidget);
      expect(find.text('추천 목록으로'), findsOneWidget);
      // The persistent shell proves this was not opened as a dialog/page.
      // Asserted on the sidebar's profile footer rather than a nav label,
      // which now also appears as the page title.
      expect(
        find.byKey(const ValueKey<String>('sidebar-profile')),
        findsOneWidget,
      );
    });

    testWidgets('reviewed AI option remains in the recommendation list', (
      tester,
    ) async {
      await openTab(tester);
      await tester.tap(find.text('AI에게 맞춤 루틴 요청하기'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('generate-routine-options')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('generate-routine-options')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('complete-routine-review')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('complete-routine-review')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('추천 목록으로'));
      await tester.pump();
      await tester.tap(find.text('추천 목록으로'));
      await tester.pumpAndSettle();

      expect(find.text('저강도 걷기'), findsOneWidget);
      expect(find.text('AI 생성 후 트레이너 검토 완료'), findsWidgets);
    });

    testWidgets('switching client updates the verdict and suggestions', (
      tester,
    ) async {
      await openTab(tester);

      await tester.tap(find.text('이지수'));
      await settle(tester);

      // 이지수 (1800mg, under) → balanced verdict + her routine.
      expect(find.text('AI 판단: 식단 균형 양호 → 근력 중심 루틴 유지'), findsOneWidget);
      expect(find.text('인터벌 런닝'), findsOneWidget);
      expect(find.text('저강도 유산소 (걷기)'), findsNothing);
    });

    testWidgets('adding and deleting a custom exercise', (tester) async {
      await openTab(tester);

      await tester.scrollUntilVisible(
        find.text('＋ 운동 직접 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.tap(find.text('＋ 운동 직접 추가'));
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey<String>('custom-exercise-name')),
        '레그프레스 5세트',
      );
      await tester.ensureVisible(find.text('추가하기'));
      await tester.pump();
      await tester.tap(find.text('추가하기'));
      await tester.pump();
      // The new custom card may land below the fold.
      await tester.scrollUntilVisible(
        find.text('레그프레스 5세트'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('레그프레스 5세트'), findsOneWidget);
      expect(find.text('트레이너 추가'), findsOneWidget);

      // Delete it again.
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pump();
      expect(find.text('레그프레스 5세트'), findsNothing);
    });

    testWidgets('send reset also closes the add-exercise form', (tester) async {
      await openTab(tester);

      // Open the add form, then send with it still open.
      await tester.scrollUntilVisible(
        find.text('＋ 운동 직접 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.tap(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      expect(find.text('운동 추가'), findsOneWidget);

      // The open form's TextField adds an inner Scrollable — target the
      // page ListView explicitly.
      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 4)); // reset window
      // The add form must be closed again after the reset.
      expect(find.text('운동 추가'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('＋ 운동 직접 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('＋ 운동 직접 추가'), findsOneWidget);
    });

    testWidgets('an AI suggestion can be removed for this round', (
      tester,
    ) async {
      await openTab(tester);

      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
      // Every card carries an X now — the first belongs to the first
      // AI suggestion.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(find.text('저강도 유산소 (걷기)'), findsNothing);

      // Switching clients and back restores the full suggestion list.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
      await tester.pump();
      await tester.tap(find.text('이지수'));
      await settle(tester);
      await tester.tap(find.text('김민수'));
      await settle(tester);
      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
    });

    testWidgets('오늘 스케줄에 등록 writes the routine onto the schedule tab', (
      tester,
    ) async {
      await openTab(tester);

      // 박성호 → his 15:00 예정 session receives the program.
      await tester.tap(find.text('박성호'));
      await settle(tester);

      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();
      await tester.tap(find.text('오늘 PT 스케줄에 등록'));
      await settle(tester);

      expect(find.text('오늘 스케줄에 등록됨'), findsOneWidget);
      expect(find.text('스케줄 탭에서 오늘 세션의 프로그램으로 확인할 수 있어요'), findsOneWidget);

      // The 스케줄 tab shows the registered plan on his 예정 session.
      await goTo(tester, AppRoutes.schedule);
      await tester.ensureVisible(find.text('박성호'));
      await tester.pump();
      await tester.tap(find.text('박성호'));
      await settle(tester);
      await tester.ensureVisible(find.text('벤치프레스 4세트'));
      expect(find.text('벤치프레스 4세트'), findsOneWidget); // AI routine item
    });

    testWidgets('homework send does not create a trainer chat bubble', (
      tester,
    ) async {
      await openTab(tester);

      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await settle(tester);
      expect(find.text('김민수님에게 전송 완료!'), findsOneWidget);

      // Routine delivery is shown in the member's routine feed, not as a
      // trainer-authored blue chat bubble.
      await goTo(
        tester,
        AppRoutes.clientDetail('seed-client-1', section: 'chat'),
      );
      expect(find.textContaining('📋 AI 루틴 숙제를 보냈어요'), findsNothing);
    });

    testWidgets('내일 chip registers the routine on the next day', (
      tester,
    ) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
      );
      await goTo(tester, AppRoutes.coaching);

      await tester.scrollUntilVisible(
        find.text('내일'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('내일'));
      await tester.pump();
      await tester.tap(find.text('내일'));
      await tester.pump();

      await tester.tap(find.textContaining('내일 PT 스케줄에 등록'));
      await settle(tester);
      expect(find.text('내일 스케줄에 등록됨'), findsOneWidget);

      // Booked under tomorrow's date, not today's. Reading a drift stream
      // must run outside the fake-async zone (`runAsync`), otherwise the
      // subscription never flushes and the test hangs.
      final tomorrow = ymd(DateTime.now().add(const Duration(days: 1)));
      final rows = await tester.runAsync(
        () => container
            .read(scheduleRepositoryProvider)
            .watchDate(tomorrow)
            .first,
      );
      expect(rows!.single.clientName, '김민수');
      expect(rows.single.program, isNotEmpty);

      // Drain the 3s confirmation timer so it isn't left pending.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('send shows confirmation then resets edits', (tester) async {
      await openTab(tester);

      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await tester.pump();

      expect(find.text('김민수님에게 전송 완료!'), findsOneWidget);
      expect(find.text('고객 앱에 알림이 전송됐어요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4)); // reset window
      expect(find.textContaining('검토 완료'), findsOneWidget);
    });

    testWidgets('mashing 스케줄 등록 registers only once', (tester) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          scheduleRepositoryProvider.overrideWith(
            (ref) =>
                _SlowCountingScheduleRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(tester, AppRoutes.coaching);

      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();
      await tester.tap(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump(const Duration(milliseconds: 50));
      // Second tap lands mid-flight — the button is now disabled and its
      // label has flipped, so this must NOT trigger a second register.
      await tester.tap(
        find.textContaining('스케줄에 등록').first,
        warnIfMissed: false,
      );
      await settle(tester);

      final repo =
          container.read(scheduleRepositoryProvider)
              as _SlowCountingScheduleRepository;
      expect(repo.registerCalls, 1);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
    });

    testWidgets('switching clients mid-registration does not flash success '
        'on the new client', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          scheduleRepositoryProvider.overrideWith(
            (ref) =>
                _SlowCountingScheduleRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(tester, AppRoutes.coaching);

      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();
      await tester.tap(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump(const Duration(milliseconds: 50));

      // Switch client while the write for 김민수 is still in flight —
      // the picker is above the button, so scroll back up to it.
      await tester.scrollUntilVisible(
        find.text('이지수'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('이지수'));
      await tester.pump();
      await tester.tap(find.text('이지수'));
      await settle(tester);

      // 이지수's card must not claim the registration, and her button
      // must not be left disabled by the previous client's guard. The
      // editor is a lazy list, so bring the button back into view first.
      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('오늘 스케줄에 등록됨'), findsNothing);
      expect(find.text('오늘 PT 스케줄에 등록'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
    });

    testWidgets('homework delivery does not depend on the chat repository', (
      tester,
    ) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          chatRepositoryProvider.overrideWith(
            (ref) => _FailingChatRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(tester, AppRoutes.coaching);

      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await settle(tester);

      expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsNothing);
      expect(find.text('김민수님에게 전송 완료!'), findsOneWidget);
    });

    testWidgets('A → B → A cannot double-register while A is still saving', (
      tester,
    ) async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          scheduleRepositoryProvider.overrideWith(
            (ref) =>
                _SlowCountingScheduleRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(tester, AppRoutes.coaching);

      // Matches both the idle '📅 …등록' and the in-flight/disabled
      // '✓ …등록됨' label so it works before and during a save.
      Future<void> tapRegister() async {
        final f = find.textContaining('스케줄에 등록');
        await tester.scrollUntilVisible(
          f,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(f);
        await tester.pump();
        await tester.tap(f, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 30));
      }

      Future<void> selectClient(String name) async {
        await tester.scrollUntilVisible(
          find.text(name),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text(name));
        await tester.pump();
        await tester.tap(find.text(name));
        await tester.pump(const Duration(milliseconds: 30));
      }

      // Start 김민수 and 이지수 independently, then return to 김민수 while
      // both writes are still pending.
      await tapRegister();
      await selectClient('이지수');
      await tapRegister();
      await selectClient('김민수');
      // Back on 김민수 while the first write is still in flight — the
      // button stays disabled, so this tap must NOT start a second one.
      await tapRegister();
      await settle(tester);

      final repo =
          container.read(scheduleRepositoryProvider)
              as _SlowCountingScheduleRepository;
      expect(repo.registerCalls, 2);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
    });

    testWidgets('switching clients mid-send does not flash send success '
        'on the new client and keeps their edits', (tester) async {
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          chatRepositoryProvider.overrideWith(
            (ref) => _SlowChatRepository(ref.watch(appDatabaseProvider)),
          ),
        ],
      );
      await goTo(tester, AppRoutes.coaching);

      // Start 김민수's (slow) send, then switch to 이지수 mid-flight.
      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.scrollUntilVisible(
        find.text('이지수'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('이지수'));
      await tester.pump();
      await tester.tap(find.text('이지수'));
      await tester.pump(const Duration(milliseconds: 30));

      // Make a fresh edit on 이지수 while 김민수's send is still in flight.
      await tester.scrollUntilVisible(
        find.text('＋ 운동 직접 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.tap(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('custom-exercise-name')),
        '레그프레스 5세트',
      );
      await tester.ensureVisible(find.text('추가하기'));
      await tester.pump();
      await tester.tap(find.text('추가하기'));
      await tester.pump();
      await settle(tester); // let 김민수's send + reset window elapse

      // 김민수's send resolved while 이지수 is on screen: no success flash
      // lands on 이지수, and her edit survives — 김민수's reset timer must
      // not fire against her (review PR 239).
      expect(find.text('김민수님에게 전송 완료!'), findsNothing);
      expect(find.text('이지수님에게 전송 완료!'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('레그프레스 5세트'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('레그프레스 5세트'), findsOneWidget);
    });

    testWidgets('registering with every exercise removed shows a hint', (
      tester,
    ) async {
      await openTab(tester);

      // Remove all three seeded AI suggestions for 김민수.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.close).first);
        await tester.pump();
      }

      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();
      await tester.tap(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();

      expect(find.text('운동을 하나 이상 추가해 주세요'), findsOneWidget);
    });
  });

  group('CoachingPage — real API mode (subin21cc review)', () {
    const realClient = TrainerClient(
      id: 'real-client-1',
      name: '김민수',
      avatar: '김',
      goal: '혈압 관리',
      lastMessage: '-',
      lastTime: '-',
      active: true,
      calories: 0,
      sodiumMg: 2100,
      sugarG: 0,
      lastRoutine: '-',
      weekCompletion: <int>[0, 0, 0, 0, 0, 0, 0],
      sodiumWeek: <int>[],
    );

    const realSuggestions = <AiRoutineItem>[
      AiRoutineItem(
        id: 'real-suggestion-1',
        name: '저강도 유산소 (걷기)',
        minutes: 30,
        type: '유산소',
        reason: '실 API 배정 테스트',
      ),
      AiRoutineItem(
        id: 'real-suggestion-2',
        name: '코어 스트레칭',
        minutes: 15,
        type: '스트레칭',
        reason: '실 API 배정 테스트',
      ),
      AiRoutineItem(
        id: 'real-suggestion-3',
        name: '스쿼트',
        minutes: 15,
        type: '근력',
        reason: '실 API 배정 테스트',
      ),
    ];

    const realConfig = AppConfig(
      environment: Environment.dev,
      apiBaseUrl: 'http://localhost/v1',
      useMockApi: false,
    );

    Future<_SpyTrainerRoutineRepository> openRealApiTab(
      WidgetTester tester, {
      bool chatFails = false,
      Object? assignError,
      bool includeInitialSuggestions = true,
      void Function(_CapturingScheduleRepository repo)? captureSchedule,
    }) async {
      final routineRepo = _SpyTrainerRoutineRepository(
        throwOnAssign: assignError,
      );
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          appConfigProvider.overrideWithValue(realConfig),
          clientRepositoryProvider.overrideWithValue(
            _FixedClientRepository(<TrainerClient>[realClient]),
          ),
          trainerAuthRepositoryProvider.overrideWithValue(
            const _FakeTrainerAuthRepository(),
          ),
          trainerRoutineRepositoryProvider.overrideWithValue(routineRepo),
          if (includeInitialSuggestions)
            aiRoutineRepositoryProvider.overrideWithValue(
              const _FixedAiRoutineRepository(realSuggestions),
            ),
          if (captureSchedule != null)
            scheduleRepositoryProvider.overrideWith((ref) {
              final repo = _CapturingScheduleRepository(
                ref.watch(appDatabaseProvider),
              );
              captureSchedule(repo);
              return repo;
            }),
          chatRepositoryProvider.overrideWithValue(
            _FakeRealChatRepository(failSend: chatFails),
          ),
        ],
      );
      await goTo(tester, AppRoutes.coaching);
      return routineRepo;
    }

    Future<void> tapSend(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await settle(tester);
    }

    testWidgets(
      'real-API schedule registration uses the selected member id and the '
      'shared schedule repository',
      (tester) async {
        late _CapturingScheduleRepository scheduleRepo;
        await openRealApiTab(
          tester,
          captureSchedule: (repo) => scheduleRepo = repo,
        );

        await tester.scrollUntilVisible(
          find.text('오늘 PT 스케줄에 등록'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
        await tester.pump();
        await tester.tap(find.text('오늘 PT 스케줄에 등록'));
        await settle(tester);

        expect(scheduleRepo.registerCalls, 1);
        expect(scheduleRepo.clientId, 'real-client-1');
        expect(scheduleRepo.program, isNotEmpty);
        expect(find.text('오늘 스케줄에 등록됨'), findsOneWidget);
      },
    );

    testWidgets(
      'real-API assign delivery does not depend on the chat repository '
      '(routine delivery shows in the member routine feed, not as a chat '
      'bubble)',
      (tester) async {
        final routineRepo = await openRealApiTab(tester, chatFails: true);

        await tapSend(tester);

        expect(find.text('김민수님에게 전송 완료!'), findsOneWidget);
        expect(routineRepo.lastAssigned, isNotNull);
      },
    );

    testWidgets(
      '네트워크 실패도 재시도를 안내한다 — 멱등키를 함께 보내므로 다시 눌러도 '
      '회원에게 루틴이 두 번 배정되지 않는다 (#581)',
      (tester) async {
        await openRealApiTab(tester, assignError: const NetworkError());

        await tapSend(tester);

        expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
        expect(
          find.text('응답을 받지 못했어요. 고객의 받은 루틴을 확인한 뒤 필요한 경우에만 다시 보내주세요'),
          findsNothing,
          reason: '멱등해진 뒤에는 "먼저 확인하라"고 막을 이유가 없다',
        );
      },
    );

    testWidgets('a non-network assign failure shows the generic retry message '
        '(a clear failure, safe to retry)', (tester) async {
      await openRealApiTab(tester, assignError: const ServerError());

      await tapSend(tester);

      expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
      expect(
        find.text('응답을 받지 못했어요. 고객의 받은 루틴을 확인한 뒤 필요한 경우에만 다시 보내주세요'),
        findsNothing,
      );
    });

    testWidgets(
      '실패 후 재시도는 같은 멱등키를 다시 보낸다 (#581)',
      (tester) async {
        // 키가 매번 새로 생기면 서버의 유니크 제약이 아무것도 막지 못한다.
        final routineRepo = await openRealApiTab(
          tester,
          assignError: const NetworkError(),
        );

        await tapSend(tester);
        await tapSend(tester);

        expect(routineRepo.assignAttempts, hasLength(2));
        expect(routineRepo.assignAttempts.first, isNotNull);
        expect(
          routineRepo.assignAttempts.first,
          routineRepo.assignAttempts.last,
          reason: '재시도가 새 키를 만들면 중복 배정이 그대로 생긴다',
        );
      },
    );

    testWidgets(
      'an all-custom send (every AI suggestion removed) assigns type/source '
      "from the custom exercises, not '근력'/'ai' by default",
      (tester) async {
        final routineRepo = await openRealApiTab(tester);

        // Remove all 3 seeded AI suggestions for 김민수. Scroll each delete
        // icon into view first — the new AI-assistant prompt banner above
        // the routine cards can push the first card below the fold.
        for (var i = 0; i < 3; i++) {
          final closeIcon = find.byIcon(Icons.close).first;
          await tester.scrollUntilVisible(
            closeIcon,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(closeIcon);
          await tester.pump();
          await tester.tap(closeIcon);
          await tester.pump();
        }

        await tester.scrollUntilVisible(
          find.text('＋ 운동 직접 추가'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('＋ 운동 직접 추가'));
        await tester.pump();
        await tester.tap(find.text('＋ 운동 직접 추가'));
        await tester.pump();

        await tester.enterText(
          find.byKey(const ValueKey<String>('custom-exercise-name')),
          '스트레칭 A',
        );
        // Default category is 근력 — switch to 스트레칭 so the assigned
        // type is provably derived from the custom exercise, not a
        // coincidental default.
        await tester.tap(
          find.byKey(const ValueKey<String>('custom-exercise-category-스트레칭')),
        );
        await tester.pump();
        await tester.ensureVisible(find.text('추가하기'));
        await tester.pump();
        await tester.tap(find.text('추가하기'));
        await tester.pump();

        await tapSend(tester);

        expect(find.text('김민수님에게 전송 완료!'), findsOneWidget);
        expect(routineRepo.lastAssigned?.type, '스트레칭');
        expect(routineRepo.lastAssigned?.source, 'trainer');
      },
    );
  });
}
