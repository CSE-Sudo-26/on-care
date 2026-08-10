import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/member_coach/data/repositories/dio_member_coach_repository.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';

AppConfig _config({required bool useMockApi}) => AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'http://localhost/v1',
  useMockApi: useMockApi,
);

class _RetryingMemberCoachRepository extends MockMemberCoachRepository {
  var sessionLoads = 0;

  @override
  Future<List<CoachSession>> fetchSessions() async {
    sessionLoads += 1;
    if (sessionLoads == 2) {
      throw StateError('temporary session failure');
    }
    return <CoachSession>[
      CoachSession(
        id: sessionLoads == 1 ? 'previous-session' : 'refreshed-session',
        date: DateTime(2026, 8, 10),
        time: '18:00',
        type: '1:1 PT',
        durationMinutes: 50,
        status: '완료',
      ),
    ];
  }
}

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

  test(
    'session refresh keeps the last data on failure and can retry',
    () async {
      final repository = _RetryingMemberCoachRepository();
      final container = ProviderContainer(
        overrides: <Override>[
          memberCoachRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(
        (await container.read(coachSessionsProvider.future)).single.id,
        'previous-session',
      );

      container.invalidate(coachSessionsProvider);
      await expectLater(
        container.read(coachSessionsProvider.future),
        throwsStateError,
      );
      final failedRefresh = container.read(coachSessionsProvider);
      expect(failedRefresh.hasError, isTrue);
      expect(failedRefresh.valueOrNull?.single.id, 'previous-session');

      container.invalidate(coachSessionsProvider);
      expect(
        (await container.read(coachSessionsProvider.future)).single.id,
        'refreshed-session',
      );
      expect(repository.sessionLoads, 3);
    },
  );
}
