import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/member_coach/data/repositories/dio_member_coach_repository.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';

AppConfig _config({required bool useMockApi}) => AppConfig(
      environment: Environment.dev,
      apiBaseUrl: 'http://localhost/v1',
      useMockApi: useMockApi,
    );

void main() {
  test('resolves the mock repository when USE_MOCK_API=true', () {
    final container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(_config(useMockApi: true)),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(memberCoachRepositoryProvider),
      isA<MockMemberCoachRepository>(),
    );
  });

  test('resolves the Dio repository when USE_MOCK_API=false', () {
    final container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(_config(useMockApi: false)),
        dioProvider.overrideWithValue(Dio()),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(memberCoachRepositoryProvider),
      isA<DioMemberCoachRepository>(),
    );
  });
}
