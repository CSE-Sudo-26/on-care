import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';

/// `GET /consultations/me` 한 건. 처리 결과 필드는 케이스별로 덮어쓴다.
Map<String, Object?> _row({
  Object? status = 'pending',
  Object? note,
  Object? decidedAt,
}) => <String, Object?>{
  'id': 'consult-abc123',
  'member_id': 'user-7d4e9a2c5f18',
  'target_type': 'gym',
  'gym_id': 'gym-oncare-sinchon',
  'trainer_id': null,
  'gym_name': '온케어짐 신촌점',
  'trainer_name': null,
  'exercise_goal': 'weight_loss',
  'health_purpose_type': 'chronic',
  'health_purpose_detail': null,
  'preferred_date': '2026-08-20',
  'preferred_time_slot': 'afternoon',
  'message': '문의합니다',
  'status': status,
  'decision_note': note,
  'decided_at': decidedAt,
  'created_at': '2026-08-07T10:00:00Z',
  'updated_at': '2026-08-07T10:00:00Z',
};

void main() {
  test('대기 중인 요청은 처리 정보가 비어 있다', () {
    final ConsultationRequest request = consultationFromJson(_row());

    expect(request.status, ConsultationStatus.pending);
    expect(request.isPending, isTrue);
    expect(request.decisionNote, isNull);
    expect(request.decidedAt, isNull);
  });

  test('거절 사유와 처리 시각을 읽는다', () {
    final ConsultationRequest request = consultationFromJson(
      _row(
        status: 'rejected',
        note: '이번 달은 정원이 찼어요',
        decidedAt: '2026-08-08T04:30:00Z',
      ),
    );

    expect(request.status, ConsultationStatus.rejected);
    expect(request.isPending, isFalse);
    expect(request.decisionNote, '이번 달은 정원이 찼어요');
    expect(request.decidedAt, DateTime.parse('2026-08-08T04:30:00Z'));
  });

  test('공백뿐인 사유는 null 로 접는다', () {
    // 그대로 두면 화면에 빈 안내 줄이 그려진다.
    final ConsultationRequest request = consultationFromJson(
      _row(status: 'rejected', note: '   '),
    );

    expect(request.decisionNote, isNull);
  });

  test('사유 앞뒤 공백을 정리한다', () {
    final ConsultationRequest request = consultationFromJson(
      _row(status: 'rejected', note: '  일정이 어려워요  '),
    );

    expect(request.decisionNote, '일정이 어려워요');
  });

  test('승인은 사유 없이도 정상이다', () {
    final ConsultationRequest request = consultationFromJson(
      _row(status: 'accepted', decidedAt: '2026-08-08T04:30:00Z'),
    );

    expect(request.status, ConsultationStatus.accepted);
    expect(request.decisionNote, isNull);
    expect(request.decidedAt, isNotNull);
  });

  test('처리 정보가 없는 예전 응답도 그대로 읽힌다', () {
    // 배포된 서버가 아직 필드를 주지 않아도 화면이 깨지면 안 된다.
    final Map<String, Object?> legacy = _row()
      ..remove('decision_note')
      ..remove('decided_at');

    final ConsultationRequest request = consultationFromJson(legacy);

    expect(request.status, ConsultationStatus.pending);
    expect(request.decisionNote, isNull);
    expect(request.decidedAt, isNull);
  });

  test('copyWith 가 처리 정보를 잃지 않는다', () {
    // 접수 직후 서버 id 로 갈아끼울 때 쓰는 경로다.
    final ConsultationRequest request = consultationFromJson(
      _row(status: 'rejected', note: '정원이 찼어요'),
    ).copyWith(id: 'server-id');

    expect(request.id, 'server-id');
    expect(request.decisionNote, '정원이 찼어요');
  });
}
