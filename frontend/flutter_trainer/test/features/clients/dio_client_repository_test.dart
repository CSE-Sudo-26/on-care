import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/clients/data/repositories/dio_client_repository.dart';

class _MockDio extends Mock implements Dio {}

Response<List<dynamic>> _okList(List<dynamic> body, String path) =>
    Response<List<dynamic>>(
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
  late DioClientRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioClientRepository(dio);
  });

  test('watchClients parses the roster', () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients')).thenAnswer(
      (_) async => _okList(
        <dynamic>[
          <String, Object?>{'id': 'm1', 'name': '김민수', 'sodium_mg': 2100},
          <String, Object?>{'id': 'm2', 'name': '이지수', 'sodium_mg': 1500},
        ],
        '/trainer/clients',
      ),
    );

    final clients = await repo.watchClients().first;
    expect(clients.map((c) => c.id).toList(), <String>['m1', 'm2']);
    expect(clients.first.sodiumOverBudget, isTrue);
  });

  test('watchClientsPrioritized puts the over-target client first', () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients')).thenAnswer(
      (_) async => _okList(
        <dynamic>[
          <String, Object?>{'id': 'ok', 'name': 'A', 'sodium_mg': 1500},
          <String, Object?>{'id': 'over', 'name': 'B', 'sodium_mg': 2500},
        ],
        '/trainer/clients',
      ),
    );

    final clients = await repo.watchClientsPrioritized().first;
    expect(clients.first.id, 'over');
  });

  test('watchDiet parses the meals', () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients/m1/diet')).thenAnswer(
      (_) async => _okList(
        <dynamic>[
          <String, Object?>{'meal': '점심', 'items': '비빔밥', 'calories': 600, 'sodium_mg': 1200},
        ],
        '/trainer/clients/m1/diet',
      ),
    );

    final meals = await repo.watchDiet('m1').first;
    expect(meals.single.meal, '점심');
  });

  test('watchHistory surfaces a 404 (not this trainer\'s client) as NotFoundError',
      () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients/x/history'))
        .thenThrow(_httpError(404, '/trainer/clients/x/history'));

    await expectLater(
      repo.watchHistory('x'),
      emitsError(isA<NotFoundError>()),
    );
  });

  test('watchTodayReservationCount emits nothing (schedule wired later)',
      () async {
    expect(await repo.watchTodayReservationCount().isEmpty, isTrue);
  });

  group('roster mutations are demo-only against the real API', () {
    test('addClient throws UnsupportedError', () {
      expect(
        () => repo.addClient(name: 'x', goal: 'y'),
        throwsUnsupportedError,
      );
    });
    test('setClientActive throws UnsupportedError', () {
      expect(() => repo.setClientActive('id', false), throwsUnsupportedError);
    });
    test('clientNameExists throws UnsupportedError', () {
      expect(() => repo.clientNameExists('x'), throwsUnsupportedError);
    });
  });
}
