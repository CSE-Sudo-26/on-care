import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';

ConsultationDraft _draft({
  String trainerId = 'trainer-1',
  HealthPurposeType purpose = HealthPurposeType.general,
  String? detail,
}) => ConsultationDraft(
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
    expect(json['trainer_id'], 'trainer-1');
    expect(json['exercise_goal'], 'fitness');
    expect(json['health_purpose_type'], 'general');
    expect(json['preferred_time_slot'], 'morning');
    // 서버 계약이 date 라 날짜만 보낸다.
    expect(json['preferred_date'], '2026-08-20');
  });

  test('폐지된 헬스장 대상 필드는 아예 싣지 않는다', () {
    // target_type 은 서버 기본값(trainer)에 맡기고, gym_id 는 보내지 않는다 —
    // 보내면 서버가 422 로 막는다.
    final json = _draft().toJson();
    expect(json.containsKey('gym_id'), isFalse);
    expect(json.containsKey('target_type'), isFalse);
  });

  test('대상 트레이너가 비면 직렬화 전에 막는다', () {
    // 그대로 나가면 원인을 찾기 어려운 422 로 돌아온다.
    expect(() => _draft(trainerId: '').toJson(), throwsArgumentError);
    expect(() => _draft(trainerId: '   ').toJson(), throwsArgumentError);
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
}
