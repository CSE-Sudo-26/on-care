import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_status.dart';
import 'package:oncare_trainer/features/search/domain/client_search_scope.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

import '../../helpers/client_factory.dart';

ScheduleSession session({
  required String date,
  required String time,
  String? clientId,
  String clientName = '',
  String status = ScheduleStatus.upcoming,
}) {
  return ScheduleSession(
    id: '$date-$time',
    date: date,
    time: time,
    clientId: clientId,
    clientName: clientName,
    type: SessionType.personalTraining,
    durationMinutes: 60,
    status: status,
    note: '',
    program: const <ProgramItem>[],
  );
}

void main() {
  final TrainerClient minsu = makeClient(id: 'c1', name: '김민수');
  final TrainerClient jisu = makeClient(id: 'c2', name: '이지수');

  group('nextSessionsByClient', () {
    test('가장 이른 예정 세션을 고객별로 고른다', () {
      final map = nextSessionsByClient(
        <TrainerClient>[minsu, jisu],
        <ScheduleSession>[
          session(date: '2026-08-20', time: '10:00', clientId: 'c1'),
          session(date: '2026-08-13', time: '15:00', clientId: 'c1'),
          session(date: '2026-08-13', time: '09:00', clientId: 'c2'),
        ],
      );

      expect(map['c1']!.date, '2026-08-13');
      expect(map['c1']!.time, '15:00');
      expect(map['c2']!.time, '09:00');
    });

    test('완료된 세션과 공백은 다음 예약이 아니다', () {
      final map = nextSessionsByClient(
        <TrainerClient>[minsu],
        <ScheduleSession>[
          session(
            date: '2026-08-11',
            time: '10:00',
            clientId: 'c1',
            status: ScheduleStatus.done,
          ),
          session(date: '2026-08-11', time: '12:00', status: ScheduleStatus.gap),
        ],
      );

      expect(map, isEmpty);
    });

    test('client_id 가 없는 옛 행은 이름으로 이어 붙인다 (#386)', () {
      // v3 이전에 저장된 행은 이름만 들고 있다. 공백·대소문자가 어긋나도
      // 같은 사람으로 봐야 스케줄 탭과 고객 탭이 다른 말을 하지 않는다.
      final map = nextSessionsByClient(
        <TrainerClient>[minsu],
        <ScheduleSession>[
          session(date: '2026-08-13', time: '11:00', clientName: ' 김민수 '),
        ],
      );

      expect(map['c1']!.time, '11:00');
    });
  });

  group('clientSearchDestination', () {
    test('탭마다 다른 곳으로 보낸다', () {
      const empty = ClientSearchFacts.none;

      expect(
        clientSearchDestination(ClientSearchScope.dashboard, minsu, empty),
        '/clients/c1/diet',
      );
      expect(
        clientSearchDestination(
          ClientSearchScope.clients,
          minsu,
          empty,
          clientSection: 'workout',
        ),
        '/clients/c1/workout',
        reason: '보고 있던 하위 탭을 유지해야 한다',
      );
      expect(
        clientSearchDestination(
          ClientSearchScope.clients,
          minsu,
          empty,
          clientSection: 'chat',
        ),
        '/clients/c1/diet',
        reason: '채팅만은 예외 — 열자마자 읽음 처리돼 답장 대기 배지가 지워진다',
      );
      expect(
        clientSearchDestination(ClientSearchScope.coaching, minsu, empty),
        '/coaching?client=c1',
      );
      expect(
        clientSearchDestination(ClientSearchScope.reports, minsu, empty),
        '/reports?client=c1',
      );
    });

    test('스케줄은 다음 예약 날짜로 보낸다', () {
      final facts = ClientSearchFacts(
        nextSession: <String, ScheduleSession>{
          'c1': session(date: '2026-08-13', time: '11:00', clientId: 'c1'),
        },
      );

      expect(
        clientSearchDestination(ClientSearchScope.schedule, minsu, facts),
        '/schedule?v=day&d=2026-08-13',
      );
    });

    test('예정된 예약이 없으면 스케줄은 갈 곳이 없다', () {
      // null 은 "아무 데나 보내지 말라"는 뜻이다 — 호출부가 대신 이유를
      // 스낵바로 알린다.
      expect(
        clientSearchDestination(
          ClientSearchScope.schedule,
          minsu,
          ClientSearchFacts.none,
        ),
        isNull,
      );
    });
  });
}
