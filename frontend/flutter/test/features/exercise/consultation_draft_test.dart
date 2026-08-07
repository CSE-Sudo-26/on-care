import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';

ConsultationDraft _draft({
  String? gymId = 'gym-1',
  String? trainerId,
  HealthPurposeType purpose = HealthPurposeType.general,
  String? detail,
}) => ConsultationDraft(
  gymId: gymId,
  trainerId: trainerId,
  exerciseGoal: ExerciseGoal.fitness,
  healthPurposeType: purpose,
  healthPurposeDetail: detail,
  preferredDate: DateTime(2026, 8, 20),
  preferredTimeSlot: PreferredTimeSlot.morning,
  message: null,
);

void main() {
  test('wire 값이 백엔드 Literal 과 같다', () {
    final json = _draft().toJson();
    expect(json['target_type'], 'gym');
    expect(json['exercise_goal'], 'fitness');
    expect(json['health_purpose_type'], 'general');
    expect(json['preferred_time_slot'], 'morning');
    // 서버 계약이 date 라 날짜만 보낸다.
    expect(json['preferred_date'], '2026-08-20');
  });

  test('대상이 둘 다이거나 둘 다 없으면 직렬화 전에 막는다', () {
    // 그대로 나가면 원인을 찾기 어려운 422 로 돌아온다.
    expect(
      () => _draft(trainerId: 'trainer-1').toJson(),
      throwsArgumentError,
    );
    expect(() => _draft(gymId: null).toJson(), throwsArgumentError);
  });

  test('기타 목적인데 상세가 비면 막는다', () {
    expect(
      () => _draft(purpose: HealthPurposeType.other, detail: '  ').toJson(),
      throwsArgumentError,
    );
    expect(
      _draft(purpose: HealthPurposeType.other, detail: '허리 통증')
          .toJson()['health_purpose_detail'],
      '허리 통증',
    );
  });

  test('트레이너 대상이면 gym_id 를 비운다', () {
    final json = _draft(gymId: null, trainerId: 'trainer-1').toJson();
    expect(json['target_type'], 'trainer');
    expect(json['gym_id'], isNull);
    expect(json['trainer_id'], 'trainer-1');
  });
}
