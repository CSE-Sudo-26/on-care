import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';

import '../../helpers/client_factory.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> body, String path) =>
    Response<Map<String, dynamic>>(
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

void main() {
  late _MockDio dio;
  late DioReportRepository repo;
  final client = makeClient(id: 'm1', name: '김민수');
  final weekStart = DateTime(2026, 8, 3);
  const path = '/trainer/clients/m1/report';

  setUpAll(() {
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    dio = _MockDio();
    repo = DioReportRepository(dio);
  });

  test('sends the week as a YYYY-MM-DD query parameter', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        path,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => _ok(<String, dynamic>{'week_start': '2026-08-03'}, path),
    );

    await repo.watch(client: client, weekStart: weekStart).first;

    final captured =
        verify(
              () => dio.get<Map<String, dynamic>>(
                path,
                queryParameters: captureAny(named: 'queryParameters'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(captured['week_start'], '2026-08-03');
  });

  test('parses the aggregated figures', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        path,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => _ok(<String, dynamic>{
        'week_start': '2026-08-03',
        'sessions_booked': 3,
        'sessions_done': 2,
        'completion_avg': 74,
        'sodium_over_days': 2,
        'sodium_avg': 2150,
      }, path),
    );

    final report = await repo.watch(client: client, weekStart: weekStart).first;

    expect(report.sessionsBooked, 3);
    expect(report.sessionsDone, 2);
    expect(report.completionAvg, 74);
    expect(report.sodiumOverDays, 2);
    expect(report.sodiumAvg, 2150);
    expect(report.attendanceRate, 67);
    // The chart series stay on the client — the report endpoint doesn't
    // repeat what the roster already delivered.
    expect(report.client.weekCompletion, client.weekCompletion);
  });

  test('a null completion stays null rather than collapsing to 0%', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        path,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => _ok(<String, dynamic>{
        'week_start': '2026-08-03',
        'completion_avg': null,
        'sodium_avg': null,
      }, path),
    );

    final report = await repo.watch(client: client, weekStart: weekStart).first;

    expect(report.completionAvg, isNull);
    expect(report.sodiumAvg, isNull);
  });

  test('JSON numbers that decode as double survive (web)', () async {
    // On web every JSON number is a double; `as int` would throw.
    when(
      () => dio.get<Map<String, dynamic>>(
        path,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => _ok(<String, dynamic>{
        'week_start': '2026-08-03',
        'sessions_booked': 3.0,
        'sodium_avg': 2150.0,
      }, path),
    );

    final report = await repo.watch(client: client, weekStart: weekStart).first;

    expect(report.sessionsBooked, 3);
    expect(report.sodiumAvg, 2150);
  });

  test('an HTTP failure surfaces as a typed AppError', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        path,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(_httpError(404, path));

    expect(
      () => repo.watch(client: client, weekStart: weekStart).first,
      throwsA(isA<NotFoundError>()),
    );
  });

  test('send posts the week and the body the trainer saw', () async {
    const sendPath = '/trainer/clients/m1/report/send';
    when(
      () => dio.post<Map<String, dynamic>>(sendPath, data: any(named: 'data')),
    ).thenAnswer((_) async => _ok(<String, dynamic>{}, sendPath));

    await repo.send(
      clientId: 'm1',
      weekStart: weekStart,
      message: '이번 주 잘하셨어요',
    );

    final body =
        verify(
              () => dio.post<Map<String, dynamic>>(
                sendPath,
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body['week_start'], '2026-08-03');
    // The sent text must be what was previewed, not a server rebuild.
    expect(body['message'], '이번 주 잘하셨어요');
  });

  test('a failed send throws instead of reporting success', () async {
    const sendPath = '/trainer/clients/m1/report/send';
    when(
      () => dio.post<Map<String, dynamic>>(sendPath, data: any(named: 'data')),
    ).thenThrow(_httpError(500, sendPath));

    expect(
      () => repo.send(clientId: 'm1', weekStart: weekStart, message: 'x'),
      throwsA(isA<ServerError>()),
    );
  });
}
