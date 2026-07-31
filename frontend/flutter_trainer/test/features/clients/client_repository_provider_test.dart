import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/features/clients/data/repositories/dio_client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
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
  Stream<List<TrainerClient>> watchClientsPrioritized() =>
      throw UnimplementedError('not exercised by this test');
  @override
  Stream<int> watchTodayReservationCount() => const Stream<int>.empty();
  @override
  Stream<List<ClientDietEntry>> watchDiet(String clientId) =>
      const Stream<List<ClientDietEntry>>.empty();
  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) =>
      const Stream<List<RoutineHistoryEntry>>.empty();
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
    'watching clientsProvider + prioritizedClientsProvider together issues '
    'exactly one GET /trainer/clients in real-API mode (review: the two '
    'providers used to each fetch independently)',
    () async {
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
      final prioritized = await container.read(
        prioritizedClientsProvider.future,
      );

      verify(() => dio.get<List<dynamic>>('/trainer/clients')).called(1);
      expect(clients.map((c) => c.id), <String>['a', 'b']);
      expect(prioritized.map((c) => c.id), <String>['a', 'b']); // a is over
    },
  );

  test(
    'prioritizedClientsProvider re-derives on every clientsProvider '
    'emission, not just the first (review: watching `.future` would freeze '
    'on the first value since it only ever resolves once)',
    () async {
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

      final emissions = <List<String>>[];
      final sub = container.listen(prioritizedClientsProvider, (
        _,
        next,
      ) {
        next.whenData(
          (clients) => emissions.add(clients.map((c) => c.id).toList()),
        );
      });
      addTearDown(sub.close);

      // Each addition needs a couple of real event-loop ticks to travel
      // clientsProvider's stream -> its AsyncValue -> the rebuilt
      // Stream.value(...) -> prioritizedClientsProvider's own AsyncValue ->
      // this listener — a plain `Duration.zero` delay only drains
      // microtasks, not far enough through that chain.
      controller.add(<TrainerClient>[_client('a', sodiumMg: 100)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // A second emission on the SAME provider instance (no invalidation) —
      // an over-target client now leads the roster.
      controller.add(<TrainerClient>[
        _client('over', sodiumMg: 2500),
        _client('a', sodiumMg: 100),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(emissions, <List<String>>[
        <String>['a'],
        <String>['over', 'a'], // proves the second emission was reflected
      ]);
    },
  );
}
