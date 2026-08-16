import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';

/// 대시보드의 임박 세션 강조가 읽는 규칙. 설정의 '알림 시점' 이 실제로 무엇을
/// 가리키는지가 여기서 정해진다(#817).
ScheduleSession _session({
  required String time,
  String status = ScheduleStatus.upcoming,
}) => ScheduleSession(
  id: 's1',
  date: '2026-08-17',
  time: time,
  clientName: '김민수',
  type: '1:1 PT',
  durationMinutes: 60,
  status: status,
  note: '',
  program: const <ProgramItem>[],
);

void main() {
  final now = DateTime(2026, 8, 17, 9, 40);

  test('알림 시점 안에 시작하는 예정 세션은 임박이다', () {
    expect(
      startsWithin(_session(time: '10:00'), 30, now: now),
      isTrue,
      reason: '20분 뒤 시작 · 30분 전 알림',
    );
    expect(
      startsWithin(_session(time: '10:00'), 10, now: now),
      isFalse,
      reason: '10분 전 알림이면 아직 이르다',
    );
  });

  test('이미 시작한 세션과 끝난 수업은 강조하지 않는다', () {
    // 강조는 "곧 해야 할 일" 을 가리킨다. 지난 시각을 다시 눈에 띄게 만들면
    // 트레이너가 놓친 것으로 읽는다.
    expect(startsWithin(_session(time: '09:40'), 30, now: now), isFalse);
    expect(startsWithin(_session(time: '09:00'), 30, now: now), isFalse);
    expect(
      startsWithin(
        _session(time: '10:00', status: ScheduleStatus.done),
        30,
        now: now,
      ),
      isFalse,
    );
  });

  test('시각을 알 수 없는 슬롯은 조용히 지나간다', () {
    // 빈 시간 행처럼 `HH:mm` 이 아닌 값이 들어와도 대시보드가 깨지지 않는다.
    expect(startsWithin(_session(time: ''), 30, now: now), isFalse);
    expect(startsWithin(_session(time: '빈 시간'), 30, now: now), isFalse);
    expect(startsWithin(_session(time: '25:00'), 30, now: now), isFalse);
  });

  test('알림 시점이 0이면 아무것도 임박하지 않는다', () {
    expect(startsWithin(_session(time: '09:41'), 0, now: now), isFalse);
  });
}
