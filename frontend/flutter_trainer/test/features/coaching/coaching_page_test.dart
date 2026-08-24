import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/design_system/tokens/typography.dart';
import 'package:oncare_trainer/features/auth/data/repositories/dio_trainer_auth_repository.dart'
    show trainerAuthRepositoryProvider;
import 'package:oncare_trainer/features/auth/domain/entities/auth_tokens.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/domain/entities/member_health_profile.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_exercise_status_card.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/nutrition_summary_card.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/ai_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_editor_workspace.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/mini_charts.dart';

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
  Future<RoutineHistoryEntry> updateHistoryFeedback(
    String clientId,
    String historyId,
    String feedback,
  ) async => throw UnsupportedError('not used');

  @override
  Future<MemberHealthProfile> fetchHealthProfile(String clientId) async =>
      MemberHealthProfile(memberId: clientId, memberName: '회원');

  @override
  Future<MemberHealthProfile> updateHealthProfile(
    String clientId,
    Map<String, Object?> values,
  ) => fetchHealthProfile(clientId);
  @override
  Future<ClientExerciseWeek> fetchExerciseWeek(
    String clientId, {
    DateTime? weekStart,
  }) async => const ClientExerciseWeek(
    dayLabels: <String>[],
    dailyMinutes: <int>[],
    dailyCalories: <int>[],
    totalMinutes: 0,
    totalCalories: 0,
  );

  @override
  Future<String> fetchDietAdvice(String clientId, ClientPeriod period) async =>
      '';

  @override
  Future<String> fetchExerciseAdvice(
    String clientId,
    ClientPeriod period,
  ) async => '';

  @override
  Future<List<ClientDietEntry>> fetchDietOn(
    String clientId,
    DateTime date,
  ) async => const <ClientDietEntry>[];

  @override
  Future<List<String>> fetchExercisesOn(String clientId, DateTime date) async =>
      const <String>[];

  @override
  Future<ClientDietPeriod> fetchDietPeriod(
    String clientId,
    ClientDateRange range,
  ) async => ClientDietPeriod(range: range, days: const <ClientDietDay>[]);

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

  /// 마지막으로 배정된 프로그램 payload(세션·운동 구성 포함, #709).
  Map<String, Object?>? lastAssigned;

  /// 전송 시도마다 넘어온 멱등키. 재시도가 같은 키를 쓰는지 본다(#581).
  final List<String?> assignAttempts = <String?>[];

  @override
  Future<void> assignRoutine(
    String memberId,
    AssignedRoutine routine, {
    String? clientRequestId,
  }) async => throw UnsupportedError('프로그램 배정 경로만 쓴다 (#709)');

  @override
  Future<void> assignProgram(
    String memberId,
    Map<String, Object?> payload,
  ) async {
    assignAttempts.add(payload['client_request_id'] as String?);
    if (throwOnAssign != null) throw throwOnAssign!;
    lastAssigned = payload;
  }

  /// 배정된 첫 세션의 운동 목록 — 유형·출처 요약은 이제 서버가 접는다.
  List<Map<String, Object?>> get lastAssignedExercises {
    final sessions = lastAssigned?['sessions'] as List<Object?>?;
    if (sessions == null || sessions.isEmpty) {
      return const <Map<String, Object?>>[];
    }
    final first = sessions.first! as Map<String, Object?>;
    return ((first['exercises'] as List<Object?>?) ?? const <Object?>[])
        .map((item) => (item! as Map<Object?, Object?>).cast<String, Object?>())
        .toList();
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
  Future<void> logout(String refreshToken) async {}

  @override
  Future<TrainerProfile> fetchProfile(String accessToken) async =>
      seedTrainerProfile;
}

Finder _exerciseActionMenus() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return widget is PopupMenuButton<String> &&
      key is ValueKey<String> &&
      key.value.startsWith('exercise-edit-');
});

Future<void> _selectExerciseAction(
  WidgetTester tester,
  String action, {
  bool last = false,
}) async {
  final finder = last
      ? _exerciseActionMenus().last
      : _exerciseActionMenus().first;
  final menu = tester.widget<PopupMenuButton<String>>(finder);
  menu.onSelected?.call(action);
  await tester.pump();
}

void _expectNutritionStatusCardsInBounds(WidgetTester tester) {
  final nutrition = find.byKey(const Key('client-nutrition-summary-card'));
  expect(nutrition, findsOneWidget);
  final nutritionRect = tester.getRect(nutrition);
  final viewportWidth = tester.view.physicalSize.width;
  for (final status in <Finder>[
    find.byKey(const Key('client-nutrition-mineral-나트륨')),
    find.byKey(const Key('client-nutrition-mineral-당류')),
  ]) {
    expect(status, findsOneWidget);
    final statusRect = tester.getRect(status);
    expect(statusRect.left, greaterThanOrEqualTo(nutritionRect.left));
    expect(statusRect.right, lessThanOrEqualTo(nutritionRect.right));
    expect(statusRect.left, greaterThanOrEqualTo(0));
    expect(statusRect.right, lessThanOrEqualTo(viewportWidth));
  }
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

    test('returns the seeded suggestions in order per client', () async {
      final repo = DriftAiRoutineRepository(db);
      final minsu = await repo.watchRoutine('seed-client-1').first;
      // 김민수의 개인 운동은 공유 픽스처가 정한다 — 네 건이다 (#1170).
      expect(minsu.length, 4);
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

        expect(minsu.length, 4);
        expect(minsu.first.name, '저강도 유산소 (걷기)');
      },
    );

    test(
      'registerToTodaySchedule attaches to an existing 예정 session',
      () async {
        final repo = DriftScheduleRepository(db);
        // 박성호 has a seeded 15:00 예정 session.
        final attached = await repo.registerProgram(
          date: ymd(nowKst()),
          clientId: 'seed-client-3',
          clientName: '박성호',
          time: '10:00',
          program: const <ProgramItem>[
            ProgramItem(name: '저강도 유산소', sets: 1, reps: '30분', weight: '-'),
          ],
        );
        expect(attached, isTrue);

        // 오늘 자리만 센다 — 시드는 이번 주 다른 요일에도 수업을 둔다(#1210).
        final rows = await db.select(db.trainerScheduleEntries).get();
        final his = rows
            .where((r) => r.clientName == '박성호' && r.date == ymd(nowKst()))
            .toList();
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
          date: ymd(nowKst()),
          clientId: 'seed-client-1',
          clientName: '김민수',
          time: '10:00',
          program: const <ProgramItem>[
            ProgramItem(name: '코어 강화', sets: 1, reps: '10분', weight: '-'),
          ],
        );
        expect(attached, isFalse);

        final rows = await db.select(db.trainerScheduleEntries).get();
        final his = rows
            .where((r) => r.clientName == '김민수' && r.date == ymd(nowKst()))
            .toList();
        expect(his.length, 2);
        final booked = his.firstWhere((r) => r.status == '예정');
        expect(booked.programJson, contains('코어 강화'));
        expect(booked.id.startsWith('seed-'), isFalse);
      },
    );
  });

  group('CoachingPage', () {
    Future<void> openTab(
      WidgetTester tester, {
      Size size = const Size(1600, 1200),
    }) async {
      // Desktop surface: the workspace splits into overview | editor,
      // so both columns are on screen the way a trainer sees them.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.coaching,
      );
    }

    testWidgets(
      'defaults to the first client with nutrition graph and routine',
      (tester) async {
        await openTab(tester);

        expect(find.text('프로그램'), findsWidgets);
        expect(find.byType(NutritionSummaryCard), findsOneWidget);
        expect(
          find.byKey(const Key('client-nutrition-summary-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('client-nutrition-calorie-progress')),
          findsOneWidget,
        );
        expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
        expect(find.text('혈압 안정에 효과적'), findsOneWidget);
        final programCard = find.byKey(
          const ValueKey<String>('program-client-seed-client-1'),
        );
        expect(programCard, findsOneWidget);
        // 이행률은 [라벨][막대][값] 한 줄로 그린다(#899) — 값이 라벨과 같은
        // Text 에 붙어 있지 않다.
        expect(
          find.descendant(of: programCard, matching: find.text('운동 이행률')),
          findsOneWidget,
        );
        final completionBar = tester.widget<InlineBarValue>(
          find.descendant(
            of: programCard,
            matching: find.byType(InlineBarValue),
          ),
        );
        expect(completionBar.fraction, isNotNull);
        expect(completionBar.text, endsWith('%'));
        final avatar = tester.widget<ClientAvatar>(
          find.descendant(of: programCard, matching: find.byType(ClientAvatar)),
        );
        expect(avatar.size, 32);
      },
    );

    testWidgets(
      'full workspace keeps AI centered and client data in the right rail',
      (tester) async {
        await openTab(tester, size: const Size(1600, 900));

        final mainColumn = find.byKey(
          const ValueKey<String>('coaching-wide-main-column'),
        );
        final assistant = find.byKey(
          const ValueKey<String>('coaching-wide-ai-prompt'),
        );
        final overview = find.byKey(
          const ValueKey<String>('coaching-wide-client-overview'),
        );
        final switcher = find.byKey(
          const ValueKey<String>('program-client-data-switcher'),
        );
        final nutrition = find.byKey(
          const Key('client-nutrition-summary-card'),
        );
        final sodium = find.byKey(const Key('client-nutrition-mineral-나트륨'));
        final sugar = find.byKey(const Key('client-nutrition-mineral-당류'));

        expect(mainColumn, findsOneWidget);
        expect(assistant, findsOneWidget);
        expect(overview, findsOneWidget);
        expect(
          tester.getTopLeft(assistant).dy,
          closeTo(tester.getTopLeft(overview).dy, 1),
        );
        expect(
          tester.getCenter(assistant).dx,
          closeTo(tester.getCenter(mainColumn).dx, 1),
        );
        expect(
          tester.getCenter(overview).dx,
          greaterThan(tester.getCenter(mainColumn).dx),
        );
        // 고객 요약 카드는 없어졌고(#1027), 그 자리를 식단·운동 영역이
        // 가져갔다 — 오른쪽 열의 **맨 위**다.
        expect(find.text('고객 요약'), findsNothing);
        expect(switcher, findsOneWidget);
        expect(
          tester.getTopLeft(switcher).dy,
          closeTo(tester.getTopLeft(overview).dy, 1),
        );
        expect(
          find.byKey(const ValueKey<String>('program-member-completion-chart')),
          findsNothing,
        );
        expect(tester.getSize(nutrition).width, greaterThan(310));
        expect(
          tester.getBottomRight(nutrition).dy,
          lessThanOrEqualTo(tester.view.physicalSize.height),
        );
        expect(
          tester.getTopLeft(sodium).dx,
          lessThan(tester.getTopLeft(sugar).dx),
        );
        _expectNutritionStatusCardsInBounds(tester);
        // 전송 이력은 편집기 아래가 아니라 오른쪽 열이다 — 이 고객에게 이미
        // 무엇이 나갔는지는 편집을 다 읽고 나서야 알 일이 아니다. (#1027)
        expect(find.text('전송 이력'), findsOneWidget);
        expect(
          find.descendant(of: overview, matching: find.text('전송 이력')),
          findsOneWidget,
        );
        expect(
          tester.getBottomRight(sugar).dy,
          lessThanOrEqualTo(tester.view.physicalSize.height),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('three-column boundary preserves a usable editor width', (
      tester,
    ) async {
      await openTab(tester, size: const Size(1552, 900));

      final mainColumn = find.byKey(
        const ValueKey<String>('coaching-wide-main-column'),
      );
      final rightRail = find.byKey(
        const ValueKey<String>('coaching-wide-client-overview'),
      );
      expect(mainColumn, findsOneWidget);
      expect(rightRail, findsOneWidget);
      expect(tester.getSize(mainColumn).width, greaterThanOrEqualTo(600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('full workspace moves templates below the client list', (
      tester,
    ) async {
      await openTab(tester);

      final list = find.byKey(
        const ValueKey<String>('program-client-list-scroll'),
      );
      final templates = find.byKey(
        const ValueKey<String>('program-template-sidebar'),
      );
      expect(list, findsOneWidget);
      expect(templates, findsOneWidget);
      expect(
        tester.getTopLeft(templates).dy,
        greaterThan(tester.getBottomLeft(list).dy),
      );
      expect(
        tester.getCenter(templates).dx,
        closeTo(tester.getCenter(list).dx, 1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('client data buttons switch the diet summary to workout data', (
      tester,
    ) async {
      await openTab(tester);
      await tester.pumpAndSettle();

      final tabs = find.byKey(
        const ValueKey<String>('program-client-data-tabs'),
      );
      expect(tabs, findsOneWidget);
      expect(find.byType(NutritionSummaryCard), findsOneWidget);

      await tester.tap(find.descendant(of: tabs, matching: find.text('운동')));
      await tester.pumpAndSettle();

      expect(find.byType(NutritionSummaryCard), findsNothing);
      expect(find.byType(ClientExerciseStatusCard), findsOneWidget);
      final workout = find.byKey(
        const ValueKey<String>('program-workout-seed-client-1'),
      );
      expect(workout, findsOneWidget);
      expect(
        tester.getBottomRight(workout).dy,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('고객 목록 행에 상대시간이 남아 있지 않다 (#1027)', (tester) async {
      await openTab(tester);
      await tester.pumpAndSettle();

      // 씨앗 로스터의 `마지막 루틴` 은 `오늘`/`어제`/`5일 전` 같은 상대시간
      // 문자열이다. 완료율보다 시선을 먼저 가져가서 지웠다.
      final row = find.byKey(
        const ValueKey<String>('program-client-seed-client-1'),
      );
      expect(row, findsOneWidget);
      for (final String stale in <String>['오늘', '어제', '5일 전', '3주 전']) {
        expect(
          find.descendant(of: row, matching: find.text(stale)),
          findsNothing,
          reason: '$stale 이 아직 줄에 남아 있다',
        );
      }
      // 지운 것은 상대시간뿐이다 — 목표와 이행률은 그대로 있어야 한다.
      expect(
        find.descendant(of: row, matching: find.text('운동 이행률')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('운동 쪽에 세트·횟수까지 적힌 상세 내역이 있다 (#1027)', (tester) async {
      await openTab(tester);
      await tester.pumpAndSettle();

      final tabs = find.byKey(
        const ValueKey<String>('program-client-data-tabs'),
      );
      await tester.tap(find.descendant(of: tabs, matching: find.text('운동')));
      await tester.pumpAndSettle();

      // 그래프는 `얼마나 오래` 만 말한다. 다음 프로그램을 짜려면 `무엇을 몇
      // 세트` 가 함께 있어야 한다.
      final detail = find.byKey(
        const ValueKey<String>('client-exercise-detail'),
      );
      expect(detail, findsOneWidget);
      expect(
        find.descendant(of: detail, matching: find.text('운동 기록')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: detail, matching: find.text('벤치프레스 40kg · 4세트')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('오른쪽 고객 데이터 열은 편집기와 따로 스크롤한다 (#1027)', (tester) async {
      await openTab(tester, size: const Size(1600, 900));
      await tester.pumpAndSettle();

      final rail = find.byKey(
        const ValueKey<String>('coaching-wide-client-overview'),
      );
      final railScroll = find.byKey(
        const ValueKey<String>('coaching-client-rail-scroll'),
      );
      final pageScroll = find.byKey(
        const ValueKey<String>('coaching-program-page-scroll'),
      );
      expect(rail, findsOneWidget);
      // 열이 가운데 스크롤 **밖**에 있어야 편집기를 내려도 제자리에 남는다.
      expect(
        find.descendant(of: pageScroll, matching: railScroll),
        findsNothing,
      );

      final double before = tester.getTopLeft(rail).dy;
      await tester.drag(pageScroll, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(rail).dy, closeTo(before, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('wide breakpoint keeps nutrition status cards in bounds', (
      tester,
    ) async {
      await openTab(tester, size: const Size(900, 1200));

      _expectNutritionStatusCardsInBounds(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('short desktop keeps the complete diet status above the fold', (
      tester,
    ) async {
      await openTab(tester, size: const Size(1366, 768));

      final sugar = find.byKey(const Key('client-nutrition-mineral-당류'));
      expect(sugar, findsOneWidget);
      expect(
        tester.getBottomRight(sugar).dy,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('wide client list shows five rows and scrolls the rest', (
      tester,
    ) async {
      await openTab(tester);
      await tester.pumpAndSettle();

      final listFinder = find.byKey(
        const ValueKey<String>('program-client-list-scroll'),
      );
      expect(listFinder, findsOneWidget);
      // 한 줄에 이름 · 목표 · 이행률 세 줄이 들어간다 — `오늘`/`5일 전` 같은
      // 상대시간 줄을 지우면서 104 에서 88 로 내려왔다(#1027). 앱 기본 글씨
      // 배율이 올라가면 줄 높이도 함께 늘어난다 — 화면과 같은 식으로 기대값을
      // 잡는다. (#995)
      final double expectedRow =
          88 + 84 * (AppTypography.textScale - 1).clamp(0.0, 2.0);
      expect(tester.getSize(listFinder).height, expectedRow * 5);
      final list = tester.widget<ListView>(listFinder);
      expect(list.controller, isNotNull);
      expect(list.controller!.position.maxScrollExtent, greaterThan(0));

      await tester.drag(listFinder, const Offset(0, -240));
      await tester.pumpAndSettle();

      expect(list.controller!.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('client list keeps five rows usable with enlarged text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openTab(tester);
      await tester.pumpAndSettle();

      final listFinder = find.byKey(
        const ValueKey<String>('program-client-list-scroll'),
      );
      expect(listFinder, findsOneWidget);
      expect(tester.getSize(listFinder).height, greaterThan(84 * 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact client picker stacks demographics below the name', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.coaching,
      );

      final minsuIdentity = find.byWidgetPredicate(
        (widget) =>
            widget is ClientIdentity &&
            widget.stacked &&
            widget.client.id == 'seed-client-1',
      );
      expect(minsuIdentity, findsOneWidget);
      final identity = tester.widget<ClientIdentity>(minsuIdentity);
      final demographics = clientDemographicsLabel(
        tester.element(minsuIdentity),
        identity.client,
      );
      final name = find.descendant(
        of: minsuIdentity,
        matching: find.text(identity.client.name),
      );
      final detail = find.descendant(
        of: minsuIdentity,
        matching: find.text(demographics),
      );
      expect(
        tester.getTopLeft(detail).dy,
        greaterThan(tester.getTopLeft(name).dy),
      );
      expect(find.byType(NutritionSummaryCard), findsOneWidget);
      expect(tester.takeException(), isNull);
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

      // 편집기 안으로 범위를 좁힌다 — 같은 이름의 운동이 위쪽 `AI 개인운동
      // 제안` 영역(#790)에도 뜰 수 있고, 이 테스트가 확인하는 것은 검토한
      // 후보가 **추천 목록**에 남아 있는지다.
      expect(
        find.descendant(
          of: find.byType(ProgramEditorWorkspace),
          matching: find.text('저강도 걷기'),
        ),
        findsOneWidget,
      );
      expect(find.text('AI 생성 후 트레이너 검토 완료'), findsWidgets);
    });

    testWidgets(
      'switching client updates the nutrition graph and suggestions',
      (tester) async {
        await openTab(tester);

        final progressFinder = find.byKey(
          const Key('client-nutrition-calorie-progress'),
        );
        final initialProgress = tester
            .widget<CircularProgressIndicator>(progressFinder)
            .value;

        await tester.tap(find.text('이지수'));
        await settle(tester);

        expect(
          find.byKey(const Key('client-nutrition-summary-card')),
          findsOneWidget,
        );
        expect(
          tester.widget<CircularProgressIndicator>(progressFinder).value,
          isNot(initialProgress),
        );
        expect(find.text('인터벌 런닝'), findsOneWidget);
        expect(find.text('저강도 유산소 (걷기)'), findsNothing);
      },
    );

    testWidgets('adding and deleting a custom exercise', (tester) async {
      await openTab(tester);

      await tester.scrollUntilVisible(
        find.text('운동 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('운동 추가'));
      await tester.pump();
      await tester.tap(find.text('운동 추가'));
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey<String>('custom-exercise-name')),
        '레그프레스 5세트',
      );
      await tester.ensureVisible(find.text('추가'));
      await tester.pump();
      await tester.tap(find.text('추가'));
      await tester.pump();
      // The new custom card may land below the fold.
      await tester.scrollUntilVisible(
        find.text('레그프레스 5세트'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('레그프레스 5세트'), findsOneWidget);

      // Delete it again.
      await _selectExerciseAction(tester, 'delete', last: true);
      expect(find.text('레그프레스 5세트'), findsNothing);
    });

    testWidgets('send reset also closes the add-exercise form', (tester) async {
      await openTab(tester);

      // Open the add form, then send with it still open.
      await tester.scrollUntilVisible(
        find.text('운동 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('운동 추가'));
      await tester.pump();
      await tester.tap(find.text('운동 추가'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('custom-exercise-name')),
        findsOneWidget,
      );

      // The open form's TextField adds an inner Scrollable — target the
      // page ListView explicitly.
      await tester.scrollUntilVisible(
        find.text('고객에게 배정'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('고객에게 배정'));
      await tester.pump();
      await tester.tap(find.text('고객에게 배정'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 4)); // reset window
      // The add form must be closed again after the reset.
      expect(
        find.byKey(const ValueKey<String>('custom-exercise-name')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('운동 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('운동 추가'), findsOneWidget);
    });

    testWidgets('an AI suggestion can be removed for this round', (
      tester,
    ) async {
      await openTab(tester);

      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
      await _selectExerciseAction(tester, 'delete');
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
      // 시간표 블록의 둘째 줄은 `이름 종류` 다(#1010).
      final Finder block = find.textContaining('박성호').first;
      await tester.ensureVisible(block);
      await tester.pump();
      await tester.tap(block);
      await settle(tester);
      await tester.ensureVisible(find.text('벤치프레스 4세트'));
      expect(find.text('벤치프레스 4세트'), findsOneWidget); // AI routine item
    });

    testWidgets('homework send does not create a trainer chat bubble', (
      tester,
    ) async {
      await openTab(tester);

      await tester.scrollUntilVisible(
        find.text('고객에게 배정'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('고객에게 배정'));
      await tester.pump();
      await tester.tap(find.text('고객에게 배정'));
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
      final tomorrow = ymd(nowKst().add(const Duration(days: 1)));
      final rows = await tester.runAsync(
        () => container
            .read(scheduleRepositoryProvider)
            .watchDate(tomorrow)
            .first,
      );
      // 시드가 이번 주를 채우므로(#1210) 내일에도 다른 수업이 있을 수 있다 —
      // 방금 등록한 것만 골라 본다.
      final booked = rows!.where((s) => s.clientName == '김민수').toList();
      expect(booked, hasLength(1));
      expect(booked.single.program, isNotEmpty);

      // Drain the 3s confirmation timer so it isn't left pending.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('send shows confirmation then resets edits', (tester) async {
      await openTab(tester);

      await tester.scrollUntilVisible(
        find.text('고객에게 배정'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('고객에게 배정'));
      await tester.pump();
      await tester.tap(find.text('고객에게 배정'));
      await tester.pump();

      expect(find.text('김민수님에게 전송 완료!'), findsOneWidget);
      expect(find.text('고객 앱에 알림이 전송됐어요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4)); // reset window
      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
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
        find.text('고객에게 배정'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('고객에게 배정'));
      await tester.pump();
      await tester.tap(find.text('고객에게 배정'));
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
        find.text('고객에게 배정'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('고객에게 배정'));
      await tester.pump();
      await tester.tap(find.text('고객에게 배정'));
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
        find.text('운동 추가'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('운동 추가'));
      await tester.pump();
      await tester.tap(find.text('운동 추가'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('custom-exercise-name')),
        '레그프레스 5세트',
      );
      await tester.ensureVisible(find.text('추가'));
      await tester.pump();
      await tester.tap(find.text('추가'));
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

      // 김민수의 개인 운동을 모두 지운다 — 공유 픽스처가 정한 네 건이다
      // (#1170).
      for (var i = 0; i < 4; i++) {
        await _selectExerciseAction(tester, 'delete');
      }

      await tester.scrollUntilVisible(
        find.text('오늘 PT 스케줄에 등록'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('오늘 PT 스케줄에 등록'));
      await tester.pump();
      final disabledAction = find.widgetWithText(ActionButton, '오늘 PT 스케줄에 등록');
      expect(tester.widget<ActionButton>(disabledAction).onPressed, isNull);
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
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1600, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final routineRepo = _SpyTrainerRoutineRepository(
        throwOnAssign: assignError,
      );
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        extraOverrides: <Override>[
          appConfigProvider.overrideWithValue(realConfig),
          // AI 코칭 탭을 보는 테스트다 — 사이드바 배지의 폴링은 여기서
          // 검증할 것이 아니라 멈춰 둔다.
          ...stillBadges(),
          clientRepositoryProvider.overrideWithValue(
            const _FixedClientRepository(<TrainerClient>[realClient]),
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
        find.text('고객에게 배정'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('고객에게 배정'));
      await tester.pump();
      await tester.tap(find.text('고객에게 배정'));
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

    testWidgets('네트워크 실패도 재시도를 안내한다 — 멱등키를 함께 보내므로 다시 눌러도 '
        '회원에게 루틴이 두 번 배정되지 않는다 (#581)', (tester) async {
      await openRealApiTab(tester, assignError: const NetworkError());

      await tapSend(tester);

      expect(find.text('전송에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
      expect(
        find.text('응답을 받지 못했어요. 고객의 받은 루틴을 확인한 뒤 필요한 경우에만 다시 보내주세요'),
        findsNothing,
        reason: '멱등해진 뒤에는 "먼저 확인하라"고 막을 이유가 없다',
      );
    });

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

    testWidgets('실패 후 재시도는 같은 멱등키를 다시 보낸다 (#581)', (tester) async {
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
    });

    testWidgets(
      'an all-custom send (every AI suggestion removed) assigns type/source '
      "from the custom exercises, not '근력'/'ai' by default",
      (tester) async {
        final routineRepo = await openRealApiTab(tester);

        // Remove all 3 seeded AI suggestions for 김민수.
        for (var i = 0; i < 3; i++) {
          await _selectExerciseAction(tester, 'delete');
        }

        await tester.scrollUntilVisible(
          find.text('운동 추가'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('운동 추가'));
        await tester.pump();
        await tester.tap(find.text('운동 추가'));
        await tester.pump();

        await tester.enterText(
          find.byKey(const ValueKey<String>('custom-exercise-name')),
          '유연성 A',
        );
        // Default category is 근력 — switch to 유연성 so the assigned
        // type is provably derived from the custom exercise, not a
        // coincidental default.
        final stretching = find.byKey(
          const ValueKey<String>('custom-exercise-category-유연성'),
        );
        final chip = tester.widget<ChoiceChip>(stretching);
        chip.onSelected?.call(true);
        await tester.pump();
        await tester.ensureVisible(find.text('추가'));
        await tester.pump();
        await tester.tap(find.text('추가'));
        await tester.pump();

        await tapSend(tester);

        expect(find.text('김민수님에게 전송 완료!'), findsOneWidget);
        // 유형·출처 요약은 서버가 세션 단위로 접는다(#709) — 클라이언트는
        // 트레이너가 넣은 운동을 그대로 실어 보낸다.
        expect(
          routineRepo.lastAssignedExercises.map((e) => e['type']),
          everyElement('유연성'),
        );
        expect(
          routineRepo.lastAssignedExercises.map((e) => e['source']),
          everyElement('trainer'),
        );
      },
    );
  });
}
