import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/consultations/data/dtos/consultation_dtos.dart';

Map<String, Object?> _json({
  Object? memberName = '김민수',
  Object? goal = 'weight_loss',
  Object? purpose = 'chronic',
  Object? detail,
  Object? date = '2026-08-12',
  Object? slot = 'evening',
  Object? message = '  상담 부탁드립니다.  ',
  Object? status = 'pending',
  Object? viaGym = false,
  Object? gymName,
  Object? note,
}) => <String, Object?>{
  'id': 'consult-1',
  'member_id': 'user-1',
  'member_name': memberName,
  'exercise_goal': goal,
  'health_purpose_type': purpose,
  'health_purpose_detail': detail,
  'preferred_date': date,
  'preferred_time_slot': slot,
  'message': message,
  'status': status,
  'via_gym': viaGym,
  'gym_name': gymName,
  'decision_note': note,
};

void main() {
  test('maps the request into display-ready labels', () {
    final request = consultationRequestFromJson(_json());

    expect(request.id, 'consult-1');
    expect(request.memberId, 'user-1');
    expect(request.memberName, '김민수');
    expect(request.goalLabel, '체중 감량');
    expect(request.purposeLabel, '만성질환 관리');
    expect(request.preferredDate, DateTime(2026, 8, 12));
    expect(request.preferredTimeLabel, '저녁');
    expect(request.isPending, isTrue);
  });

  test('trims free text and collapses blanks to null', () {
    final request = consultationRequestFromJson(
      _json(message: '   ', detail: '  혈압 관리  '),
    );

    // A whitespace-only note would otherwise render an empty quote block.
    expect(request.message, isNull);
    expect(request.purposeDetail, '혈압 관리');
  });

  test('an unknown enum code falls back to the raw code, not a blank', () {
    final request = consultationRequestFromJson(_json(goal: 'sports_rehab'));

    // A backend that adds a goal should still show something actionable.
    expect(request.goalLabel, 'sports_rehab');
  });

  test('a missing member name gets a placeholder', () {
    final request = consultationRequestFromJson(_json(memberName: null));

    expect(request.memberName, '알 수 없는 회원');
  });

  test('an unparseable date does not throw', () {
    // One malformed row must not blank the whole inbox.
    final request = consultationRequestFromJson(_json(date: 'not-a-date'));

    expect(request.preferredDate, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('carries the gym routing flag and decision note', () {
    final request = consultationRequestFromJson(
      _json(
        viaGym: true,
        gymName: '온케어짐 신촌점',
        status: 'rejected',
        note: '정원이 찼어요',
      ),
    );

    expect(request.viaGym, isTrue);
    expect(request.gymName, '온케어짐 신촌점');
    expect(request.isPending, isFalse);
    expect(request.decisionNote, '정원이 찼어요');
  });
}
