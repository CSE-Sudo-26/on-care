import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/dio_schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';

class _MockDio extends Mock implements Dio {}

Response<List<dynamic>> _okList(List<dynamic> body, String path) =>
    Response<List<dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body,
    );

Response<Map<String, dynamic>> _okMap(
  String path, [
  Map<String, dynamic> body = const <String, dynamic>{},
]) => Response<Map<String, dynamic>>(
  requestOptions: RequestOptions(path: path),
  statusCode: 200,
  data: body,
);

DioException _httpError(int status, String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.badResponse,
  response: Response<Object?>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
  ),
);

const String _schedulePath = '/trainer/schedule';

Map<String, dynamic> _session({
  String id = 's1',
  String date = '2026-08-06',
  String time = '10:00',
  String clientName = '김민수',
  String? memberId = 'm1',
  String status = '예정',
  List<dynamic> program = const <dynamic>[],
}) => <String, dynamic>{
  'id': id,
  'date': date,
  'time': time,
  'member_id': memberId,
  'client_name': clientName,
  'type': '1:1 PT',
  'duration_minutes': 60,
  'status': status,
  'note': '',
  'program': program,
};

void main() {
  late _MockDio dio;
  late DioScheduleRepository repo;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    dio = _MockDio();
    repo = DioScheduleRepository(dio);
    addTearDown(repo.dispose);
  });

  void stubGet(List<dynamic> body) {
    when(
      () => dio.get<List<dynamic>>(
        _schedulePath,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => _okList(body, _schedulePath));
  }

  Map<String, dynamic> capturedQuery() {
    return verify(
          () => dio.get<List<dynamic>>(
            _schedulePath,
            queryParameters: captureAny(named: 'queryParameters'),
          ),
        ).captured.last
        as Map<String, dynamic>;
  }

  test('watchDate asks for a single day', () async {
    stubGet(<dynamic>[_session()]);

    final slots = await repo.watchDate('2026-08-06').first;

    expect(slots.single.id, 's1');
    expect(capturedQuery(), <String, String>{'date': '2026-08-06'});
  });

  test('watchRange asks for the whole week in ONE request', () async {
    stubGet(<dynamic>[
      _session(id: 'a', date: '2026-08-03'),
      _session(id: 'b', date: '2026-08-09'),
    ]);

    final slots = await repo.watchRange('2026-08-03', '2026-08-09').first;

    expect(slots.map((s) => s.id), <String>['a', 'b']);
    // A day-at-a-time contract would make this seven round trips.
    final calls = verify(
      () => dio.get<List<dynamic>>(
        _schedulePath,
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured;
    expect(calls, hasLength(1));
    expect(calls.single, <String, String>{
      'from': '2026-08-03',
      'to': '2026-08-09',
    });
  });

  test(
    'watchClientSessions filters by member id and returns newest first',
    () async {
      stubGet(<dynamic>[
        _session(id: 'old', date: '2026-08-01'),
        _session(id: 'new', date: '2026-08-06'),
      ]);

      final slots = await repo.watchClientSessions((
        id: 'm1',
        name: '김민수',
      )).first;

      // Server returns oldest→newest; the drift source is newest-first, so
      // both sources agree for the 루틴 tab.
      expect(slots.map((s) => s.id), <String>['new', 'old']);

      final query = capturedQuery();
      expect(query['member_id'], 'm1');
      // No date bounds: a range would silently drop sessions outside it,
      // and the 루틴 tab reads a missing row as "no record".
      expect(query.containsKey('from'), isFalse);
      expect(query.containsKey('to'), isFalse);
      expect(query.containsKey('date'), isFalse);
    },
  );

  test('a mutation makes live readers re-fetch', () async {
    stubGet(<dynamic>[_session(id: 'before')]);
    when(
      () => dio.post<Map<String, dynamic>>(
        _schedulePath,
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _okMap(_schedulePath));

    final emissions = <List<ScheduleSession>>[];
    final sub = repo.watchDate('2026-08-06').listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(emissions, hasLength(1));

    stubGet(<dynamic>[_session(id: 'before'), _session(id: 'after')]);
    await repo.addSession(
      date: '2026-08-06',
      clientName: '김민수',
      time: '15:00',
      type: '1:1 PT',
      durationMinutes: 60,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // drift keeps screens in sync by watching a table; over HTTP the
    // write has to tell the readers itself.
    expect(emissions, hasLength(2));
    expect(emissions.last.map((s) => s.id), <String>['before', 'after']);
    await sub.cancel();
  });

  test('a FAILED mutation does not make readers re-fetch', () async {
    stubGet(<dynamic>[_session()]);
    when(
      () => dio.delete<Map<String, dynamic>>(any()),
    ).thenThrow(_httpError(500, _schedulePath));

    final emissions = <List<ScheduleSession>>[];
    final sub = repo.watchDate('2026-08-06').listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await expectLater(repo.deleteSession('s1'), throwsA(isA<ServerError>()));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Re-emitting here would flicker the timeline as if something had
    // changed when nothing did.
    expect(emissions, hasLength(1));
    await sub.cancel();
  });

  test(
    'updateProgram sends only the program and note (partial update)',
    () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => _okMap('$_schedulePath/s1'));

      await repo.updateProgram(
        's1',
        program: const <ProgramItem>[
          ProgramItem(name: '스쿼트', sets: 3, reps: '12회', weight: '60kg'),
        ],
        note: '무릎 주의',
      );

      final body =
          verify(
                () => dio.put<Map<String, dynamic>>(
                  any(),
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      // Omitting the booking fields is what leaves time/client/duration
      // untouched — sending them would silently rewrite the booking.
      expect(body.keys.toSet(), <String>{'program', 'note'});
      expect((body['program'] as List<dynamic>).single, <String, Object?>{
        'name': '스쿼트',
        'sets': 3,
        'reps': '12회',
        'weight': '60kg',
      });
    },
  );

  test(
    'registerProgram delegates lookup and write to one atomic command',
    () async {
      const path = '/trainer/clients/m1/schedule-program';
      when(
        () => dio.put<Map<String, dynamic>>(path, data: any(named: 'data')),
      ).thenAnswer(
        (_) async =>
            _okMap(path, <String, dynamic>{'attached_to_existing': true}),
      );

      final attached = await repo.registerProgram(
        date: '2026-08-06',
        clientId: 'm1',
        clientName: '김민수',
        time: '16:00',
        program: const <ProgramItem>[
          ProgramItem(name: '스쿼트', sets: 1, reps: '20분', weight: '-'),
        ],
      );

      expect(attached, isTrue);
      final body =
          verify(
                () => dio.put<Map<String, dynamic>>(
                  path,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(body.keys.toSet(), <String>{
        'date',
        'time',
        'client_name',
        'program',
      });
      expect(body['client_name'], '김민수');
      expect((body['program'] as List<Object?>).single, <String, Object?>{
        'name': '스쿼트',
        'sets': 1,
        'reps': '20분',
        'weight': '-',
      });
      verifyNever(
        () => dio.get<List<dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    },
  );

  test(
    'registerProgram returns whether the server created a session',
    () async {
      const path = '/trainer/clients/m1/schedule-program';
      when(
        () => dio.put<Map<String, dynamic>>(path, data: any(named: 'data')),
      ).thenAnswer(
        (_) async =>
            _okMap(path, <String, dynamic>{'attached_to_existing': false}),
      );

      final attached = await repo.registerProgram(
        date: '2026-08-06',
        clientId: 'm1',
        clientName: '김민수',
        time: '16:00',
        program: const <ProgramItem>[
          ProgramItem(name: '플랭크', sets: 1, reps: '10분', weight: '-'),
        ],
      );

      expect(attached, isFalse);
      verify(
        () => dio.put<Map<String, dynamic>>(path, data: any(named: 'data')),
      ).called(1);
    },
  );

  test('booked dates come from their own endpoint', () async {
    when(
      () => dio.get<List<dynamic>>('$_schedulePath/booked-dates'),
    ).thenAnswer(
      (_) async => _okList(<dynamic>[
        '2026-08-03',
        '2026-08-06',
      ], '$_schedulePath/booked-dates'),
    );

    expect(await repo.watchBookedDates().first, <String>{
      '2026-08-03',
      '2026-08-06',
    });
  });

  test('an HTTP failure surfaces as a typed AppError', () async {
    when(
      () => dio.get<List<dynamic>>(
        _schedulePath,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(_httpError(403, _schedulePath));

    expect(
      () => repo.watchDate('2026-08-06').first,
      throwsA(isA<ForbiddenError>()),
    );
  });

  test('JSON numbers that decode as double survive (web)', () async {
    stubGet(<dynamic>[
      <String, dynamic>{
        'id': 's1',
        'date': '2026-08-06',
        'time': '10:00',
        'client_name': '김민수',
        'type': '1:1 PT',
        'duration_minutes': 60.0,
        'status': '예정',
        'note': '',
        'program': <dynamic>[
          <String, dynamic>{
            'name': '스쿼트',
            'sets': 3.0,
            'reps': '12회',
            'weight': '60kg',
          },
        ],
      },
    ]);

    final slot = (await repo.watchDate('2026-08-06').first).single;
    expect(slot.durationMinutes, 60);
    expect(slot.program.single.sets, 3);
  });

  test('a malformed row does not blank the whole timeline', () async {
    stubGet(<dynamic>[
      <String, dynamic>{'id': 's1'}, // every other field missing
      _session(id: 's2'),
    ]);

    final slots = await repo.watchDate('2026-08-06').first;
    expect(slots, hasLength(2));
    expect(slots.first.clientName, isEmpty);
    expect(slots.last.id, 's2');
  });
}
