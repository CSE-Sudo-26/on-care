import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';
import 'package:oncare/features/exercise/presentation/controllers/consultation_request_controller.dart';

final ConsultationRequest _pendingRequest = ConsultationRequest(
  id: 'request-user-a',
  targetType: ConsultationTargetType.gym,
  gymId: 'gym-1',
  gymName: 'A 사용자 상담 헬스장',
  trainerName: null,
  trainerRole: null,
  exerciseGoal: '체중 감량',
  healthPurpose: '혈압 관리',
  preferredDate: DateTime(2026, 7, 30),
  preferredTimeSlot: '오후',
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
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container
          .read(consultationRequestControllerProvider.notifier)
          .add(_pendingRequest),
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

  test('enterDemo clears consultation requests from an existing session', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(consultationRequestControllerProvider.notifier)
        .add(_pendingRequest);

    container.read(sessionControllerProvider.notifier).enterDemo();

    expect(container.read(consultationRequestControllerProvider), isEmpty);
  });
}
