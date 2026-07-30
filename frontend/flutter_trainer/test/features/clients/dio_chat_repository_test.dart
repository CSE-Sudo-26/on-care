import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/clients/data/repositories/dio_chat_repository.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';

class _MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T body, String path) => Response<T>(
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
  late DioChatRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioChatRepository(dio);
  });

  test('watchThread parses the message list (oldest→newest)', () async {
    when(() => dio.get<List<dynamic>>('/trainer/clients/m1/chat')).thenAnswer(
      (_) async => _ok<List<dynamic>>(<dynamic>[
        <String, Object?>{
          'id': 'a',
          'sender': 'client',
          'body': '안녕',
          'time_label': '9:00',
          'created_at': '2026-07-30T09:00:00',
        },
        <String, Object?>{
          'id': 'b',
          'sender': 'trainer',
          'body': '네',
          'time_label': '9:01',
          'created_at': '2026-07-30T09:01:00',
        },
      ], '/trainer/clients/m1/chat'),
    );

    final thread = await repo.watchThread('m1').first;
    expect(thread.map((m) => m.id).toList(), <String>['a', 'b']);
    expect(thread.last.sender, ChatSender.trainer);
  });

  test('sendTrainerMessage POSTs the trimmed text', () async {
    when(
      () => dio.post<Map<String, Object?>>(
        '/trainer/clients/m1/chat',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => _ok<Map<String, Object?>>(<String, Object?>{
        'id': 'x',
      }, '/trainer/clients/m1/chat'),
    );

    await repo.sendTrainerMessage(clientId: 'm1', text: '  안녕하세요  ');

    verify(
      () => dio.post<Map<String, Object?>>(
        '/trainer/clients/m1/chat',
        data: <String, Object?>{'text': '안녕하세요'},
      ),
    ).called(1);
  });

  test('sendTrainerMessage skips the network call for blank text', () async {
    await repo.sendTrainerMessage(clientId: 'm1', text: '   ');
    verifyNever(
      () => dio.post<Map<String, Object?>>(any(), data: any(named: 'data')),
    );
  });

  test('sendTrainerMessage surfaces a failure as AppError', () async {
    when(
      () => dio.post<Map<String, Object?>>(
        '/trainer/clients/m1/chat',
        data: any(named: 'data'),
      ),
    ).thenThrow(_httpError(500, '/trainer/clients/m1/chat'));

    await expectLater(
      repo.sendTrainerMessage(clientId: 'm1', text: 'hi'),
      throwsA(isA<AppError>()),
    );
  });

  test('watchUnreadCounts parses the per-client map', () async {
    when(
      () => dio.get<Map<String, Object?>>('/trainer/chat/unread'),
    ).thenAnswer(
      (_) async => _ok<Map<String, Object?>>(<String, Object?>{
        'm1': 2,
        'm2': 0,
      }, '/trainer/chat/unread'),
    );

    final unread = await repo.watchUnreadCounts().first;
    expect(unread['m1'], 2);
    expect(unread['m2'], 0);
  });

  test('markThreadRead POSTs to the read endpoint', () async {
    when(
      () => dio.post<Map<String, Object?>>('/trainer/clients/m1/chat/read'),
    ).thenAnswer(
      (_) async => _ok<Map<String, Object?>>(<String, Object?>{
        'marked_read': 2,
      }, '/trainer/clients/m1/chat/read'),
    );

    await repo.markThreadRead('m1');
    verify(
      () => dio.post<Map<String, Object?>>('/trainer/clients/m1/chat/read'),
    ).called(1);
  });

  test('watchThread surfaces a 404 (not this trainer\'s client)', () async {
    when(
      () => dio.get<List<dynamic>>('/trainer/clients/x/chat'),
    ).thenThrow(_httpError(404, '/trainer/clients/x/chat'));

    await expectLater(repo.watchThread('x'), emitsError(isA<NotFoundError>()));
  });

  test('encodes an opaque member id in every client-scoped path', () async {
    const encoded = 'member%2Fwith%3Freserved';
    when(
      () => dio.get<List<dynamic>>('/trainer/clients/$encoded/chat'),
    ).thenAnswer(
      (_) async => _ok<List<dynamic>>(
        const <dynamic>[],
        '/trainer/clients/$encoded/chat',
      ),
    );
    when(
      () => dio.post<Map<String, Object?>>(
        '/trainer/clients/$encoded/chat',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => _ok<Map<String, Object?>>(
        const <String, Object?>{},
        '/trainer/clients/$encoded/chat',
      ),
    );
    when(
      () =>
          dio.post<Map<String, Object?>>('/trainer/clients/$encoded/chat/read'),
    ).thenAnswer(
      (_) async => _ok<Map<String, Object?>>(
        const <String, Object?>{},
        '/trainer/clients/$encoded/chat/read',
      ),
    );

    await repo.watchThread('member/with?reserved').first;
    await repo.sendTrainerMessage(clientId: 'member/with?reserved', text: 'hi');
    await repo.markThreadRead('member/with?reserved');

    verify(
      () => dio.get<List<dynamic>>('/trainer/clients/$encoded/chat'),
    ).called(1);
    verify(
      () => dio.post<Map<String, Object?>>(
        '/trainer/clients/$encoded/chat',
        data: <String, Object?>{'text': 'hi'},
      ),
    ).called(1);
    verify(
      () =>
          dio.post<Map<String, Object?>>('/trainer/clients/$encoded/chat/read'),
    ).called(1);
  });

  test('malformed thread entries fail instead of being dropped', () {
    when(() => dio.get<List<dynamic>>('/trainer/clients/m1/chat')).thenAnswer(
      (_) async => _ok<List<dynamic>>(<dynamic>[
        'not-an-object',
      ], '/trainer/clients/m1/chat'),
    );

    expect(repo.watchThread('m1'), emitsError(isA<FormatException>()));
  });
}
