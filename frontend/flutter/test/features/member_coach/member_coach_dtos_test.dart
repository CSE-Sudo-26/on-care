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
      });
      expect(m.sender, CoachSender.trainer);
      expect(m.fromMe, isFalse);
    });

    test('maps my own message (me / anything else) to me', () {
      final m = coachMessageFromJson(<String, Object?>{
        'id': 'm2',
        'sender': 'me',
        'body': '좋아요',
        'time_label': '13:21',
      });
      expect(m.sender, CoachSender.me);
      expect(m.fromMe, isTrue);
    });
  });
}
