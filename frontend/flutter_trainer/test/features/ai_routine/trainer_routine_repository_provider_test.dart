import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/dio_trainer_routine_repository.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/trainer_routine_repository.dart';

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
  test('resolves the mock routine repository when USE_MOCK_API=true', () {
    expect(
      _containerFor(useMockApi: true).read(trainerRoutineRepositoryProvider),
      isA<MockTrainerRoutineRepository>(),
    );
  });

  test('resolves the Dio routine repository when USE_MOCK_API=false', () {
    expect(
      _containerFor(useMockApi: false).read(trainerRoutineRepositoryProvider),
      isA<DioTrainerRoutineRepository>(),
    );
  });
}
