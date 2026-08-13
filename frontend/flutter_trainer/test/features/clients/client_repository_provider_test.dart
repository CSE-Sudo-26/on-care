import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/clients/data/repositories/dio_client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/domain/entities/member_health_profile.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

class _MockDio extends Mock implements Dio {}

TrainerClient _client(String id, {required int sodiumMg}) => TrainerClient(
  id: id,
  name: id,
  avatar: id.substring(0, 1),
  goal: '',
  lastMessage: '',
  lastTime: '',
  active: true,
  calories: 0,
  sodiumMg: sodiumMg,
  sugarG: 0,
  lastRoutine: '',
  weekCompletion: const <int>[],
  sodiumWeek: const <int>[],
);

/// A [ClientRepository] whose `watchClients()` is a controllable
/// multi-emission stream, so tests can push more than one roster update
/// through the same provider instance (unlike the real Dio source, which
/// is one-shot) — used to prove [prioritizedClientsProvider] keeps up with
/// every emission, not just the first.
class _StreamingClientRepository implements ClientRepository {
  _StreamingClientRepository(this._controller);
  final StreamController<List<TrainerClient>> _controller;

  @override
  bool get supportsRosterMutations => false;
  @override
  Stream<List<TrainerClient>> watchClients() => _controller.stream;
  @override
  Stream<Map<String, DateTime>> watchLastChatAt() =>
      Stream<Map<String, DateTime>>.value(const <String, DateTime>{});
  @override
  Stream<List<ClientDietEntry>> watchDiet(String clientId) =>
      const Stream<List<ClientDietEntry>>.empty();
  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) =>
      const Stream<List<RoutineHistoryEntry>>.empty();
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

ProviderContainer _containerFor({
  required bool useMockApi,
  List<Override> extraOverrides = const <Override>[],
}) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: <Override>[
      appConfigProvider.overrideWithValue(
        AppConfig(
          environment: Environment.dev,
          apiBaseUrl: 'http://localhost/v1',
          useMockApi: useMockApi,
        ),
      ),
      appDatabaseProvider.overrideWithValue(db),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolves the drift repository when USE_MOCK_API=true', () {
    final container = _containerFor(useMockApi: true);
    expect(
      container.read(clientRepositoryProvider),
      isA<DriftClientRepository>(),
    );
  });

  test('resolves the Dio repository when USE_MOCK_API=false', () {
    final container = _containerFor(useMockApi: false);
    expect(
      container.read(clientRepositoryProvider),
      isA<DioClientRepository>(),
    );
  });

  test(
    'demo health-profile updates persist and preserve omitted fields',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seedIfEmpty(db);
      final repository = DriftClientRepository(db);

      final before = await repository.fetchHealthProfile('seed-client-1');
      final updated = await repository.updateHealthProfile('seed-client-1', {
        'weight_kg': 68.4,
        'weekly_workout_goal': 0,
        'goals': '체지방 감량',
      });
      final fetchedAgain = await repository.fetchHealthProfile('seed-client-1');

      expect(updated.weightKg, 68.4);
      expect(updated.weeklyWorkoutGoal, 0);
      expect(fetchedAgain.weightKg, 68.4);
      expect(fetchedAgain.weeklyWorkoutGoal, 0);
      expect(fetchedAgain.goals, '체지방 감량');
      expect(fetchedAgain.heightCm, before.heightCm);
    },
  );

  test('watching clientsProvider + prioritizedClientsProvider together issues '
      'exactly one GET /trainer/clients in real-API mode (review: the two '
      'providers used to each fetch independently)', () async {
    final dio = _MockDio();
    when(() => dio.get<List<dynamic>>('/trainer/clients')).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/trainer/clients'),
        statusCode: 200,
        data: <dynamic>[
          <String, Object?>{'id': 'a', 'name': 'A', 'sodium_mg': 2500},
          <String, Object?>{'id': 'b', 'name': 'B', 'sodium_mg': 500},
        ],
      ),
    );
    final container = _containerFor(
      useMockApi: false,
      extraOverrides: <Override>[dioProvider.overrideWithValue(dio)],
    );

    final clients = await container.read(clientsProvider.future);
    // Derived synchronously from the roster — no second fetch, and no
    // future to await.
    final prioritized = container.read(prioritizedClientsProvider).valueOrNull;

    verify(() => dio.get<List<dynamic>>('/trainer/clients')).called(1);
    expect(clients.map((c) => c.id), <String>['a', 'b']);
    expect(prioritized!.map((c) => c.id), <String>['a', 'b']); // a is over
  });

  test('prioritizedClientsProvider re-derives on every clientsProvider '
      'emission, not just the first (review: watching `.future` would freeze '
      'on the first value since it only ever resolves once)', () async {
    final controller = StreamController<List<TrainerClient>>();
    addTearDown(controller.close);
    final container = _containerFor(
      useMockApi: false,
      extraOverrides: <Override>[
        clientRepositoryProvider.overrideWithValue(
          _StreamingClientRepository(controller),
        ),
      ],
    );

    // Each addition needs a couple of real event-loop ticks to travel
    // clientsProvider's stream -> its AsyncValue -> the rebuilt
    // Stream.value(...) -> prioritizedClientsProvider's own AsyncValue ->
    // this listener. Rather than guess how long that takes (a fixed
    // delay is flaky on a slow CI runner), wait on a Completer that the
    // listener itself completes the moment each emission actually
    // arrives (review).
    final emissions = <List<String>>[];
    final gotFirst = Completer<void>();
    final gotSecond = Completer<void>();
    final sub = container.listen(prioritizedClientsProvider, (_, next) {
      next.whenData((clients) {
        emissions.add(clients.map((c) => c.id).toList());
        if (emissions.length == 1) {
          gotFirst.complete();
        } else if (emissions.length == 2) {
          gotSecond.complete();
        }
      });
    });
    addTearDown(sub.close);

    controller.add(<TrainerClient>[_client('a', sodiumMg: 100)]);
    await gotFirst.future.timeout(const Duration(seconds: 5));
    // A second emission on the SAME provider instance (no invalidation) —
    // an over-target client now leads the roster.
    controller.add(<TrainerClient>[
      _client('over', sodiumMg: 2500),
      _client('a', sodiumMg: 100),
    ]);
    await gotSecond.future.timeout(const Duration(seconds: 5));

    expect(emissions, <List<String>>[
      <String>['a'],
      <String>['over', 'a'], // proves the second emission was reflected
    ]);
  });
}
