import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare/features/member_coach/data/repositories/dio_member_coach_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';

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
  late DioMemberCoachRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioMemberCoachRepository(dio);
  });

  test('fetchCoach returns the coach', () async {
    when(() => dio.get<Map<String, Object?>>('/me/coach')).thenAnswer(
      (_) async => _ok<Map<String, Object?>>(
        <String, Object?>{'trainer_id': 't1', 'name': '김트레이너'},
        '/me/coach',
      ),
    );
    final coach = await repo.fetchCoach();
    expect(coach?.name, '김트레이너');
  });

  test('fetchCoach returns null when the member has no coach (404)', () async {
    when(() => dio.get<Map<String, Object?>>('/me/coach'))
        .thenThrow(_httpError(404, '/me/coach'));
    expect(await repo.fetchCoach(), isNull);
  });

  test('fetchRoutines parses the received routines', () async {
    when(() => dio.get<List<dynamic>>('/me/coach/routines')).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/me/coach/routines'),
        statusCode: 200,
        data: <dynamic>[
          <String, Object?>{'id': 'r1', 'name': '저강도 유산소', 'minutes': 20, 'type': '유산소', 'reason': '', 'source': 'ai'},
        ],
      ),
    );
    final routines = await repo.fetchRoutines();
    expect(routines.single.name, '저강도 유산소');
  });

  test('fetchChat parses the thread', () async {
    when(() => dio.get<List<dynamic>>('/me/coach/chat')).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/me/coach/chat'),
        statusCode: 200,
        data: <dynamic>[
          <String, Object?>{'id': 'm1', 'sender': 'trainer', 'body': '안녕', 'time_label': '13:20'},
        ],
      ),
    );
    final chat = await repo.fetchChat();
    expect(chat.single.sender, CoachSender.trainer);
  });

  test('sendMessage POSTs the trimmed text; skips blank', () async {
    when(() => dio.post<Map<String, Object?>>(
          '/me/coach/chat',
          data: any(named: 'data'),
        )).thenAnswer(
      (_) async => _ok<Map<String, Object?>>(<String, Object?>{'id': 'x'}, '/me/coach/chat'),
    );

    await repo.sendMessage('  좋아요  ');
    verify(() => dio.post<Map<String, Object?>>(
          '/me/coach/chat',
          data: <String, Object?>{'text': '좋아요'},
        )).called(1);

    await repo.sendMessage('   ');
    verifyNoMoreInteractions(dio);
  });

  test('unreadCount reads the unread field', () async {
    when(() => dio.get<Map<String, Object?>>('/me/coach/chat/unread')).thenAnswer(
      (_) async => _ok<Map<String, Object?>>(
        <String, Object?>{'unread': 3},
        '/me/coach/chat/unread',
      ),
    );
    expect(await repo.unreadCount(), 3);
  });
}
