import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/clients/data/dtos/client_dtos.dart';
import 'package:oncare_trainer/features/clients/data/repositories/dio_client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDio dio;
  late DioClientRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioClientRepository(dio);
  });

  test('watchClients parses the roster', () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients')).thenAnswer(
      (_) async => _okList(<dynamic>[
        <String, Object?>{'id': 'm1', 'name': '김민수', 'sodium_mg': 2100},
        <String, Object?>{'id': 'm2', 'name': '이지수', 'sodium_mg': 1500},
      ], '/trainer/clients'),
    );

    final clients = await repo.watchClients().first;
    expect(clients.map((c) => c.id).toList(), <String>['m1', 'm2']);
    expect(clients.first.sodiumOverBudget, isTrue);
  });

  test('the roster ordering puts the over-target client first', () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients')).thenAnswer(
      (_) async => _okList(<dynamic>[
        <String, Object?>{'id': 'ok', 'name': 'A', 'sodium_mg': 1500},
        <String, Object?>{'id': 'over', 'name': 'B', 'sodium_mg': 2500},
      ], '/trainer/clients'),
    );

    // Ordering is one shared pure function now; the API source has no
    // chat-recency signal to feed it.
    final clients = prioritizeClients(await repo.watchClients().first);
    expect(clients.first.id, 'over');
    expect(await repo.watchLastChatAt().first, isEmpty);
  });

  test('watchDiet parses the meals', () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients/m1/diet')).thenAnswer(
      (_) async => _okList(<dynamic>[
        <String, Object?>{
          'meal': '점심',
          'items': '비빔밥',
          'calories': 600,
          'sodium_mg': 1200,
        },
      ], '/trainer/clients/m1/diet'),
    );

    final meals = await repo.watchDiet('m1').first;
    expect(meals.single.meal, '점심');
  });

  test(
    'updateHistoryFeedback writes and parses the shared history row',
    () async {
      const String path =
          '/trainer/clients/member%2F1/history/assigned-ex-r1/feedback';
      when(
        () => dio.put<Map<String, Object?>>(
          path,
          data: <String, Object?>{'feedback': '자세가 좋았어요'},
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, Object?>>(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: <String, Object?>{
            'id': 'assigned-ex-r1',
            'date_label': '8/13 (오늘)',
            'label': '코어 운동',
            'completion_rate': 100,
            'exercises': <Object?>['코어 운동 · 30분'],
            'client_feedback': '힘들었어요',
            'trainer_note': '자세가 좋았어요',
            'assigned_routine_id': 'r1',
          },
        ),
      );

      final updated = await repo.updateHistoryFeedback(
        'member/1',
        'assigned-ex-r1',
        '  자세가 좋았어요  ',
      );

      expect(updated.id, 'assigned-ex-r1');
      expect(updated.trainerNote, '자세가 좋았어요');
    },
  );

  test('a refresh failure keeps the last successful client data', () async {
    const String path = '/trainer/clients/m1/diet';
    var calls = 0;
    final Completer<void> firstValue = Completer<void>();
    final Completer<void> refreshAttempted = Completer<void>();
    when(() => dio.get<List<dynamic>>(path)).thenAnswer((_) async {
      calls += 1;
      if (calls == 1) {
        return _okList(<dynamic>[
          <String, Object?>{
            'meal': '점심',
            'items': '비빔밥',
            'calories': 600,
            'sodium_mg': 1200,
          },
        ], path);
      }
      if (!refreshAttempted.isCompleted) refreshAttempted.complete();
      throw _httpError(503, path);
    });
    final values = <List<ClientDietEntry>>[];
    final errors = <Object>[];
    final subscription = repo.watchDiet('m1').listen((
      List<ClientDietEntry> value,
    ) {
      values.add(value);
      if (!firstValue.isCompleted) firstValue.complete();
    }, onError: (Object error, StackTrace stackTrace) => errors.add(error));
    try {
      await firstValue.future.timeout(const Duration(seconds: 1));

      repo.refreshClientData('m1');
      await refreshAttempted.future.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
      expect(errors, isEmpty);
      expect(values, hasLength(1));
      expect(values.single.single.items, '비빔밥');
    } finally {
      await subscription.cancel();
    }
  });

  test(
    'an all-client refresh failure keeps the last successful roster',
    () async {
      const String path = '/trainer/clients';
      var calls = 0;
      final Completer<void> firstValue = Completer<void>();
      final Completer<void> refreshAttempted = Completer<void>();
      when(() => dio.get<List<dynamic>>(path)).thenAnswer((_) async {
        calls += 1;
        if (calls == 1) {
          return _okList(<dynamic>[
            <String, Object?>{'id': 'm1', 'name': '김민수', 'sodium_mg': 2100},
          ], path);
        }
        if (!refreshAttempted.isCompleted) refreshAttempted.complete();
        throw _httpError(503, path);
      });
      final values = <List<TrainerClient>>[];
      final errors = <Object>[];
      final subscription = repo.watchClients().listen((
        List<TrainerClient> value,
      ) {
        values.add(value);
        if (!firstValue.isCompleted) firstValue.complete();
      }, onError: (Object error, StackTrace stackTrace) => errors.add(error));
      try {
        await firstValue.future.timeout(const Duration(seconds: 1));

        repo.refreshAllClientData();
        await refreshAttempted.future.timeout(const Duration(seconds: 1));
        await Future<void>.delayed(Duration.zero);

        expect(calls, 2);
        expect(errors, isEmpty);
        expect(values, hasLength(1));
        expect(values.single.single.name, '김민수');
      } finally {
        await subscription.cancel();
      }
    },
  );

  test('active client data revalidates when the app regains focus', () async {
    var calls = 0;
    when(() => dio.get<List<dynamic>>('/trainer/clients/m1/diet')).thenAnswer((
      _,
    ) async {
      calls += 1;
      return _okList(<dynamic>[
        <String, Object?>{
          'meal': 'meal $calls',
          'items': 'items',
          'calories': 100,
          'sodium_mg': 100,
        },
      ], '/trainer/clients/m1/diet');
    });
    final first = Completer<void>();
    final subscription = repo.watchDiet('m1').listen((_) {
      if (!first.isCompleted) first.complete();
    });
    final binding = TestWidgetsFlutterBinding.instance;
    try {
      await first.future.timeout(const Duration(seconds: 1));
      expect(calls, 1);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
    } finally {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await subscription.cancel();
    }
  });

  test('encodes an opaque client id as one path segment', () async {
    when(
      () => dio.get<List<dynamic>>(
        '/trainer/clients/member%2Fwith%3Freserved/diet',
      ),
    ).thenAnswer(
      (_) async => _okList(
        const <dynamic>[],
        '/trainer/clients/member%2Fwith%3Freserved/diet',
      ),
    );

    await repo.watchDiet('member/with?reserved').first;

    verify(
      () => dio.get<List<dynamic>>(
        '/trainer/clients/member%2Fwith%3Freserved/diet',
      ),
    ).called(1);
  });

  test('malformed list entries fail instead of being silently dropped', () {
    when(() => dio.get<List<dynamic>>('/trainer/clients')).thenAnswer(
      (_) async => _okList(<dynamic>[
        <String, Object?>{'id': 'm1'},
        'not-an-object',
      ], '/trainer/clients'),
    );

    expect(repo.watchClients(), emitsError(isA<FormatException>()));
  });

  test(
    'watchHistory surfaces a 404 (not this trainer\'s client) as NotFoundError',
    () async {
      when(
        () => dio.get<List<dynamic>>('/trainer/clients/x/history'),
      ).thenThrow(_httpError(404, '/trainer/clients/x/history'));

      await expectLater(
        repo.watchHistory('x'),
        emitsError(isA<NotFoundError>()),
      );
    },
  );

  group('roster mutations are demo-only against the real API', () {
    test('advertises the roster as read-only', () {
      expect(repo.supportsRosterMutations, isFalse);
    });

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
