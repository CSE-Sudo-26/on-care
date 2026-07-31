import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/features/clients/data/repositories/dio_client_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';

class _MockDio extends Mock implements Dio {}

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
}
