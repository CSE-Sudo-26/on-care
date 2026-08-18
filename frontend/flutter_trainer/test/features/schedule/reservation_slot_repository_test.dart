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

  Map<String, dynamic> slotJson({int remaining = 2}) => <String, dynamic>{
    'id': 'slot-1',
    'trainer_id': 'trainer-1',
    'starts_at': '2026-08-10T01:00:00Z',
    'capacity': 3,
    'remaining': remaining,
    'is_closed': false,
  };

  test('list maps the trainer slot API response', () async {
    when(() => dio.get<List<dynamic>>('/trainer/reservation-slots')).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/trainer/reservation-slots'),
        statusCode: 200,
        data: <dynamic>[slotJson()],
      ),
    );

    final result = await repository.list();

    expect(result.single.id, 'slot-1');
    expect(result.single.capacity, 3);
    expect(result.single.remaining, 2);
    expect(result.single.booked, 1);
  });

  test('create sends UTC time and capacity', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/trainer/reservation-slots',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/trainer/reservation-slots'),
        statusCode: 201,
        data: slotJson(remaining: 3),
      ),
    );

    await repository.create(
      startsAt: DateTime.parse('2026-08-10T10:00:00+09:00'),
      capacity: 3,
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
      'capacity': 3,
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
        data: slotJson(),
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

    await repository.update('slot-1', capacity: 4);
    final closed = await repository.close('slot-1');

    verify(
      () => dio.put<Map<String, dynamic>>(
        '/trainer/reservation-slots/slot-1',
        data: <String, dynamic>{'capacity': 4},
      ),
    ).called(1);
    expect(closed.isClosed, isTrue);
  });

  group('MockReservationSlotRepository validation', () {
    test('create rejects past times and capacities outside 1 to 100', () async {
      final mockRepository = MockReservationSlotRepository();
      final future = nowKst().add(const Duration(days: 1));

      await expectLater(
        mockRepository.create(
          startsAt: nowKst().subtract(const Duration(minutes: 1)),
          capacity: 1,
        ),
        throwsStateError,
      );
      await expectLater(
        mockRepository.create(startsAt: future, capacity: 0),
        throwsStateError,
      );
      await expectLater(
        mockRepository.create(startsAt: future, capacity: 101),
        throwsStateError,
      );
      expect(await mockRepository.list(), isEmpty);
    });

    test('update rejects past times and capacities outside 1 to 100', () async {
      final mockRepository = MockReservationSlotRepository();
      final slot = await mockRepository.create(
        startsAt: nowKst().add(const Duration(days: 1)),
        capacity: 2,
      );

      await expectLater(
        mockRepository.update(slot.id, capacity: 0),
        throwsStateError,
      );
      await expectLater(
        mockRepository.update(slot.id, capacity: 101),
        throwsStateError,
      );
      await expectLater(
        mockRepository.update(
          slot.id,
          startsAt: nowKst().subtract(const Duration(minutes: 1)),
        ),
        throwsStateError,
      );

      final unchanged = (await mockRepository.list()).single;
      expect(unchanged.capacity, 2);
      expect(unchanged.startsAt, slot.startsAt);
    });
  });
}
