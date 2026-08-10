import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/ai_routine_repository.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/dio_schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';

ProviderContainer _containerFor({required bool useMockApi}) {
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
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('mock mode selects drift for recommendations and schedule', () {
    final container = _containerFor(useMockApi: true);

    expect(
      container.read(aiRoutineRepositoryProvider),
      isA<DriftAiRoutineRepository>(),
    );
    expect(
      container.read(scheduleRepositoryProvider),
      isA<DriftScheduleRepository>(),
    );
  });

  test('real mode never selects drift for recommendations or schedule', () {
    final container = _containerFor(useMockApi: false);

    expect(
      container.read(aiRoutineRepositoryProvider),
      isA<EmptyAiRoutineRepository>(),
    );
    expect(
      container.read(scheduleRepositoryProvider),
      isA<DioScheduleRepository>(),
    );
  });
}
