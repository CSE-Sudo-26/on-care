import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/schedule/domain/schedule_format.dart';

void main() {
  group('isScheduleDate', () {
    test('계약 형식의 실제 날짜만 받는다', () {
      expect(isScheduleDate('2026-08-16'), isTrue);
      expect(isScheduleDate('2024-02-29'), isTrue); // 윤년
    });

    test('형식이 어긋난 값을 막는다', () {
      // 예전에 저장까지 통과하던 값들이다 — 저장은 되고 조회에서 걸러져
      // 어디에도 보이지 않는 일정이 됐다(#785).
      expect(isScheduleDate('2026/08/16'), isFalse);
      expect(isScheduleDate('8월 16일'), isFalse);
      expect(isScheduleDate('2026-8-16'), isFalse);
      expect(isScheduleDate('20260816'), isFalse);
      expect(isScheduleDate(''), isFalse);
    });

    test('달력에 없는 날을 막는다', () {
      // 형식만 보면 통과한다. DateTime.parse 는 이런 값을 다음 달로 굴리므로
      // 파싱 결과까지 비교해야 걸러진다.
      expect(isScheduleDate('2026-02-30'), isFalse);
      expect(isScheduleDate('2026-13-01'), isFalse);
      expect(isScheduleDate('2026-02-29'), isFalse); // 평년
      expect(isScheduleDate('2026-04-31'), isFalse);
    });
  });

  group('isScheduleTime', () {
    test('빈 값과 HH:mm 을 받는다', () {
      expect(isScheduleTime(''), isTrue); // 시간은 선택 항목
      expect(isScheduleTime('09:00'), isTrue);
      expect(isScheduleTime('23:59'), isTrue);
    });

    test('형식이 어긋나거나 범위를 넘긴 값을 막는다', () {
      expect(isScheduleTime('9:00'), isFalse);
      expect(isScheduleTime('오전 9시'), isFalse);
      expect(isScheduleTime('24:00'), isFalse);
      expect(isScheduleTime('10:60'), isFalse);
    });
  });
}
