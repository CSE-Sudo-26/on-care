import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/reservation_slot_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioReservationSlotRepository repository;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    dio = _MockDio();
    repository = DioReservationSlotRepository(dio);
  });

  Map<String, dynamic> slotJson({
    int remaining = 1,
    String sessionType = '1:1 PT',
  }) => <String, dynamic>{
    'id': 'slot-1',
    'trainer_id': 'trainer-1',
    'starts_at': '2026-08-10T01:00:00Z',
    'capacity': 1,
    'remaining': remaining,
    'is_closed': false,
    'session_type': sessionType,
  };

  test('list maps the trainer slot API response', () async {
    when(() => dio.get<List<dynamic>>('/trainer/reservation-slots')).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/trainer/reservation-slots'),
        statusCode: 200,
        data: <dynamic>[slotJson(remaining: 0)],
      ),
    );

    final result = await repository.list();

    expect(result.single.id, 'slot-1');
    // 서버가 좌석 수로 주더라도 앱은 예약 여부만 본다(#1072).
    expect(result.single.booked, isTrue);
    expect(result.single.sessionType, '1:1 PT');
  });

  test('좌석이 남아 있으면 비어 있는 자리로 읽는다', () async {
    when(() => dio.get<List<dynamic>>('/trainer/reservation-slots')).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/trainer/reservation-slots'),
        statusCode: 200,
        data: <dynamic>[slotJson()],
      ),
    );

    expect((await repository.list()).single.booked, isFalse);
  });

  test('create sends UTC time and session type', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/trainer/reservation-slots',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/trainer/reservation-slots'),
        statusCode: 201,
        data: slotJson(sessionType: '상담'),
      ),
    );

    await repository.create(
      startsAt: DateTime.parse('2026-08-10T10:00:00+09:00'),
      sessionType: '상담',
    );

    final data =
        verify(
              () => dio.post<Map<String, dynamic>>(
                '/trainer/reservation-slots',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(data, <String, dynamic>{
      'starts_at': '2026-08-10T01:00:00.000Z',
      'session_type': '상담',
    });
  });

  test('update and close use the slot-scoped endpoints', () async {
    when(
      () => dio.put<Map<String, dynamic>>(
        '/trainer/reservation-slots/slot-1',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: '/trainer/reservation-slots/slot-1',
        ),
        statusCode: 200,
        data: slotJson(sessionType: '상담'),
      ),
    );
    when(
      () =>
          dio.delete<Map<String, dynamic>>('/trainer/reservation-slots/slot-1'),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: '/trainer/reservation-slots/slot-1',
        ),
        statusCode: 200,
        data: <String, dynamic>{...slotJson(), 'is_closed': true},
      ),
    );

    await repository.update('slot-1', sessionType: '상담');
    final closed = await repository.close('slot-1');

    verify(
      () => dio.put<Map<String, dynamic>>(
        '/trainer/reservation-slots/slot-1',
        data: <String, dynamic>{'session_type': '상담'},
      ),
    ).called(1);
    expect(closed.isClosed, isTrue);
  });

  group('MockReservationSlotRepository validation', () {
    test('create rejects past times', () async {
      final mockRepository = MockReservationSlotRepository();

      await expectLater(
        mockRepository.create(
          startsAt: nowKst().subtract(const Duration(minutes: 1)),
          sessionType: '1:1 PT',
        ),
        throwsStateError,
      );
      expect(await mockRepository.list(), isEmpty);
    });

    test('새로 연 자리는 비어 있는 상태로 시작한다', () async {
      final mockRepository = MockReservationSlotRepository();
      final future = nowKst().add(const Duration(days: 1));

      final slot = await mockRepository.create(
        startsAt: future,
        sessionType: '상담',
      );

      expect(slot.booked, isFalse);
      expect(slot.isClosed, isFalse);
      expect(slot.sessionType, '상담');
    });

    test('update rejects past times', () async {
      final mockRepository = MockReservationSlotRepository();
      final slot = await mockRepository.create(
        startsAt: nowKst().add(const Duration(days: 1)),
        sessionType: '1:1 PT',
      );

      await expectLater(
        mockRepository.update(
          slot.id,
          startsAt: nowKst().subtract(const Duration(minutes: 1)),
        ),
        throwsStateError,
      );

      final unchanged = (await mockRepository.list()).single;
      expect(unchanged.sessionType, '1:1 PT');
      expect(unchanged.startsAt, slot.startsAt);
    });

    test('update can change the session type of an open slot', () async {
      final mockRepository = MockReservationSlotRepository();
      final slot = await mockRepository.create(
        startsAt: nowKst().add(const Duration(days: 1)),
        sessionType: '1:1 PT',
      );

      final changed = await mockRepository.update(slot.id, sessionType: '상담');

      expect(changed.sessionType, '상담');
    });
  });
}
