import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/member_coach/data/dtos/member_coach_dtos.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';

void main() {
  test('memberCoachFromJson maps the coach summary (nested gym)', () {
    final c = memberCoachFromJson(<String, Object?>{
      'trainer_id': 't1',
      'name': '김트레이너',
      'specialty': '퍼스널 트레이너',
      'career': '7년',
      'intro': '안녕하세요',
      'gym': <String, Object?>{'name': '온케어짐 신촌점'},
      'goal': '혈압 관리',
    });
    expect(c.trainerId, 't1');
    expect(c.name, '김트레이너');
    expect(c.gymName, '온케어짐 신촌점');
    expect(c.goal, '혈압 관리');
  });

  test('coachRoutineFromJson maps a received routine (double minutes ok)', () {
    final r = coachRoutineFromJson(<String, Object?>{
      'id': 'r1',
      'name': '저강도 유산소',
      'minutes': 20.0,
      'type': '유산소',
      'reason': '혈압 안정',
      'source': 'ai',
    });
    expect(r.minutes, 20);
    expect(r.source, 'ai');
  });

  group('coachMessageFromJson (member viewpoint)', () {
    test('maps a coach (trainer) message', () {
      final m = coachMessageFromJson(<String, Object?>{
        'id': 'm1',
        'sender': 'trainer',
        'body': '안녕하세요',
        'time_label': '13:20',
        'created_at': '2026-08-07T13:20:00Z',
      });
      expect(m.sender, CoachSender.trainer);
      expect(m.fromMe, isFalse);
      expect(m.createdAt, DateTime.utc(2026, 8, 7, 13, 20));
    });

    test('maps my own message', () {
      final m = coachMessageFromJson(<String, Object?>{
        'id': 'm2',
        'sender': 'me',
        'body': '좋아요',
        'time_label': '13:21',
        'created_at': '2026-08-07T13:21:00Z',
      });
      expect(m.sender, CoachSender.me);
      expect(m.fromMe, isTrue);
    });

    test('rejects an unknown sender', () {
      expect(
        () => coachMessageFromJson(<String, Object?>{
          'id': 'm3',
          'sender': 'client',
          'body': '잘못된 발신자',
          'time_label': '13:22',
          'created_at': '2026-08-07T13:22:00Z',
        }),
        throwsFormatException,
      );
    });

    test('rejects an invalid created_at value', () {
      expect(
        () => coachMessageFromJson(<String, Object?>{
          'id': 'm4',
          'sender': 'trainer',
          'body': '잘못된 시간',
          'time_label': '13:23',
          'created_at': 'not-a-date',
        }),
        throwsFormatException,
      );
    });
  });
}
