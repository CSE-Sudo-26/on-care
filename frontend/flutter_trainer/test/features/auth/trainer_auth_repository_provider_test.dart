import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/features/auth/data/repositories/dio_trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/data/repositories/mock_trainer_auth_repository.dart';

ProviderContainer _containerFor({required bool useMockApi}) {
  final container = ProviderContainer(
    overrides: <Override>[
      appConfigProvider.overrideWithValue(
        AppConfig(
          environment: Environment.dev,
          apiBaseUrl: 'http://localhost/v1',
          useMockApi: useMockApi,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('resolves the mock repository when USE_MOCK_API=true', () {
    final container = _containerFor(useMockApi: true);
    expect(
      container.read(trainerAuthRepositoryProvider),
      isA<MockTrainerAuthRepository>(),
    );
  });

  test('resolves the Dio repository when USE_MOCK_API=false', () {
    final container = _containerFor(useMockApi: false);
    expect(
      container.read(trainerAuthRepositoryProvider),
      isA<DioTrainerAuthRepository>(),
    );
  });
}
