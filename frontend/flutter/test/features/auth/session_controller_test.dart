import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare/features/exercise/data/repositories/dio_consultation_repository.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';

import '../../support/consultation_test_support.dart';

final ConsultationRequest _pendingRequest = ConsultationRequest(
  id: 'request-user-a',
  targetType: ConsultationTargetType.gym,
  gymId: 'gym-1',
  gymName: 'A 사용자 상담 헬스장',
  trainerId: null,
  trainerName: null,
  trainerRole: null,
  exerciseGoal: ExerciseGoal.weightLoss,
  healthPurposeType: HealthPurposeType.chronic,
  healthPurposeDetail: null,
  preferredDate: DateTime(2026, 7, 30),
  preferredTimeSlot: PreferredTimeSlot.afternoon,
  message: 'A 사용자의 문의 내용',
  status: ConsultationStatus.pending,
  createdAt: DateTime(2026, 7, 29),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('signOut clears consultation requests for the next user', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        // 상담 컨트롤러가 appConfig 를 타므로 repository 를 직접 고정한다(#327).
        consultationRepositoryProvider.overrideWithValue(
          const MockConsultationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await seedPending(
        container.read(consultationRequestControllerProvider.notifier),
        _pendingRequest,
      ),
      isTrue,
    );

    await container.read(sessionControllerProvider.notifier).signOut();

    expect(container.read(consultationRequestControllerProvider), isEmpty);
    expect(
      container
          .read(consultationRequestControllerProvider.notifier)
          .hasPending(
            targetType: _pendingRequest.targetType,
            gymId: _pendingRequest.gymId,
          ),
      isFalse,
    );
  });

  test('enterDemo clears existing consultation requests', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        // 상담 컨트롤러가 appConfig 를 타므로 repository 를 직접 고정한다(#327).
        consultationRepositoryProvider.overrideWithValue(
          const MockConsultationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await seedPending(
        container.read(consultationRequestControllerProvider.notifier),
        _pendingRequest,
      ),
      isTrue,
    );

    container.read(sessionControllerProvider.notifier).enterDemo();

    expect(container.read(consultationRequestControllerProvider), isEmpty);
    expect(
      container
          .read(consultationRequestControllerProvider.notifier)
          .hasPending(
            targetType: _pendingRequest.targetType,
            gymId: _pendingRequest.gymId,
          ),
      isFalse,
    );
  });

  test('login clears consultation requests created in demo mode', () async {
    final Dio dio = _authDio(<String, Object?>{
      'access_token': 'login-access-token',
      'refresh_token': 'login-refresh-token',
    });
    addTearDown(dio.close);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        dioProvider.overrideWithValue(dio),
        consultationRepositoryProvider.overrideWithValue(
          const MockConsultationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final SessionController controller = container.read(
      sessionControllerProvider.notifier,
    );
    await _waitForSessionStatus(container, SessionStatus.signedOut);
    controller.enterDemo();

    expect(
      await seedPending(
        container.read(consultationRequestControllerProvider.notifier),
        _pendingRequest,
      ),
      isTrue,
    );

    await controller.login(email: 'member@example.com', password: 'password');

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.authenticated,
    );
    expect(container.read(consultationRequestControllerProvider), isEmpty);
    expect(
      container
          .read(consultationRequestControllerProvider.notifier)
          .hasPending(
            targetType: _pendingRequest.targetType,
            gymId: _pendingRequest.gymId,
          ),
      isFalse,
    );
  });

  test('login without an access token keeps consultation requests', () async {
    final Dio dio = _authDio(<String, Object?>{
      'refresh_token': 'refresh-token-only',
    });
    addTearDown(dio.close);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        dioProvider.overrideWithValue(dio),
        consultationRepositoryProvider.overrideWithValue(
          const MockConsultationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final SessionController controller = container.read(
      sessionControllerProvider.notifier,
    );
    await _waitForSessionStatus(container, SessionStatus.signedOut);
    controller.enterDemo();

    expect(
      await seedPending(
        container.read(consultationRequestControllerProvider.notifier),
        _pendingRequest,
      ),
      isTrue,
    );

    await expectLater(
      controller.login(email: 'member@example.com', password: 'password'),
      throwsException,
    );

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.demo,
    );
    expect(
      container.read(consultationRequestControllerProvider),
      <ConsultationRequest>[_pendingRequest],
    );
    expect(
      container
          .read(consultationRequestControllerProvider.notifier)
          .hasPending(
            targetType: _pendingRequest.targetType,
            gymId: _pendingRequest.gymId,
          ),
      isTrue,
    );
  });
}

Dio _authDio(Map<String, Object?> response) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        handler.resolve(
          Response<Map<String, Object?>>(
            requestOptions: options,
            statusCode: 200,
            data: response,
          ),
        );
      },
    ),
  );
  return dio;
}

Future<void> _waitForSessionStatus(
  ProviderContainer container,
  SessionStatus expected,
) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (container.read(sessionControllerProvider).status == expected) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Session did not reach $expected');
}
