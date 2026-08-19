import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/features/notifications/data/repositories/notification_repository.dart';

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

/// 알림함이 **다시 읽는지**를 본다. 한 번 읽고 끝나는 구현에서는 트레이너가
/// 알림함을 열어 보기 전까지 배지가 처음 센 숫자에 멈춰 있었다. (#917)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String unreadPath = '/trainer/notifications/unread-count';

  late _MockDio dio;

  setUp(() => dio = _MockDio());

  test('watchUnreadCount keeps reading while something listens', () async {
    var calls = 0;
    when(() => dio.get<Map<String, Object?>>(unreadPath)).thenAnswer((_) async {
      calls += 1;
      return _ok<Map<String, Object?>>(<String, Object?>{
        'unread': calls,
      }, unreadPath);
    });

    final emissions = await DioNotificationRepository(
      dio,
      pollInterval: const Duration(milliseconds: 5),
    ).watchUnreadCount().take(2).toList().timeout(const Duration(seconds: 1));

    expect(emissions, <int>[1, 2]);
  });

  test(
    'watchUnreadCount holds the last count through a transient failure',
    () async {
      var calls = 0;
      when(() => dio.get<Map<String, Object?>>(unreadPath)).thenAnswer((
        _,
      ) async {
        calls += 1;
        if (calls == 2) throw _httpError(503, unreadPath);
        return _ok<Map<String, Object?>>(<String, Object?>{
          'unread': calls,
        }, unreadPath);
      });

      final emissions = await DioNotificationRepository(
        dio,
        pollInterval: const Duration(milliseconds: 5),
      ).watchUnreadCount().take(2).toList().timeout(const Duration(seconds: 1));

      // 실패한 폴은 스트림에 오류로 새지 않는다 — 배지가 0 으로 깜빡였다가
      // 돌아오면, 트레이너는 알림이 사라졌다고 읽는다.
      expect(emissions, <int>[1, 3]);
    },
  );

  test('watch re-reads the inbox so the open list matches the badge', () async {
    var calls = 0;
    when(() => dio.get<List<dynamic>>('/trainer/notifications')).thenAnswer((
      _,
    ) async {
      calls += 1;
      return _ok<List<dynamic>>(<dynamic>[
        <String, Object?>{
          'id': 'noti-$calls',
          'title': '새 메시지',
          'body': '김민수님이 메시지를 보냈어요',
          'category': 'message',
          'read': false,
          'created_at': '2026-08-19T09:00:00Z',
          'time_ago': '방금',
        },
      ], '/trainer/notifications');
    });

    final emissions = await DioNotificationRepository(
      dio,
      pollInterval: const Duration(milliseconds: 5),
    ).watch().take(2).toList().timeout(const Duration(seconds: 1));

    expect(emissions.map((rows) => rows.single.id).toList(), <String>[
      'noti-1',
      'noti-2',
    ]);
  });

  test(
    'the demo source stays inert — no backend makes notifications',
    () async {
      const repo = DemoNotificationRepository();

      expect(await repo.watchUnreadCount().first, 0);
      expect(await repo.watch().first, isEmpty);
    },
  );
}
