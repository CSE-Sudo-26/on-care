import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/features/clients/data/repositories/dio_chat_repository.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';

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
  test('resolves the drift chat repository when USE_MOCK_API=true', () {
    expect(
      _containerFor(useMockApi: true).read(chatRepositoryProvider),
      isA<DriftChatRepository>(),
    );
  });

  test('resolves the Dio chat repository when USE_MOCK_API=false', () {
    expect(
      _containerFor(useMockApi: false).read(chatRepositoryProvider),
      isA<DioChatRepository>(),
    );
  });
}
