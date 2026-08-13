/// 실 백엔드 알림 계약 — #636 리뷰.
///
/// 미읽음 수를 서버에서 읽는 부분이 **키를 잘못 보고 있었다.** 서버는 `unread` 를
/// 내려주는데 `count` 로 읽어, 실서버에서는 늘 값을 못 찾았다. 목 모드에서는 그 경로가
/// 아예 돌지 않아 기존 테스트로는 드러나지 않았다.
///
/// 여기서 계약을 못 박는다 — 키 이름, 그리고 잘못된 응답을 **조용히 0 으로 삼키지
/// 않는다**는 것.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/notification/data/repositories/dio_notification_repository.dart';
import 'package:oncare/features/notification/domain/entities/alert_item.dart';

/// 지정한 본문으로만 답하는 가짜 서버.
Dio _dio(Object? body, {int status = 200}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: status,
            data: body,
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('unreadCount', () {
    test('서버가 쓰는 키(unread)를 읽는다', () async {
      final repo = DioNotificationRepository(
        _dio(<String, Object?>{'unread': 3}),
      );

      expect(await repo.unreadCount(), 3);
    });

    test('읽을 것이 없으면 0 이다', () async {
      final repo = DioNotificationRepository(
        _dio(<String, Object?>{'unread': 0}),
      );

      expect(await repo.unreadCount(), 0);
    });

    test('키가 없으면 0 으로 삼키지 않고 던진다', () async {
      // 0 으로 돌려주면 읽지 않은 알림이 있는데도 배지가 즉시 꺼진다. 던져야
      // 폴링이 마지막 좋은 값을 유지한다.
      final repo = DioNotificationRepository(
        _dio(<String, Object?>{'count': 3}),
      );

      expect(repo.unreadCount(), throwsA(isA<FormatException>()));
    });

    test('소수는 잘라 내지 않고 던진다', () async {
      // toInt() 로 잘라 내면 1.5 가 1 이 되어 틀린 수를 조용히 보여 준다.
      final repo = DioNotificationRepository(
        _dio(<String, Object?>{'unread': 1.5}),
      );

      expect(repo.unreadCount(), throwsA(isA<FormatException>()));
    });

    test('음수는 던진다', () async {
      final repo = DioNotificationRepository(
        _dio(<String, Object?>{'unread': -1}),
      );

      expect(repo.unreadCount(), throwsA(isA<FormatException>()));
    });
  });

  group('fetchAll', () {
    test('서버가 준 action 을 이동 경로로 옮긴다', () async {
      final repo = DioNotificationRepository(
        _dio(<Object?>[
          <String, Object?>{
            'id': 'n1',
            'title': '제목',
            'body': '본문',
            'time_ago': '방금',
            'category': 'reminder',
            'read': false,
            'action': <String, Object?>{
              'label': '기록하러 가기',
              'target': 'dashboard',
            },
          },
        ]),
      );

      final AlertItem item = (await repo.fetchAll()).single;
      expect(item.action?.label, '기록하러 가기');
      expect(item.action?.target, AlertTarget.dashboard);
      expect(item.action?.isNavigable, isTrue);
    });

    test('모르는 target 은 목록에서 빼지 않고 이동만 하지 않는다', () async {
      final repo = DioNotificationRepository(
        _dio(<Object?>[
          <String, Object?>{
            'id': 'n1',
            'title': '제목',
            'body': '본문',
            'time_ago': '방금',
            'category': 'system',
            'read': false,
            'action': <String, Object?>{
              'label': '어딘가로',
              'target': 'not_yet_known_to_the_app',
            },
          },
        ]),
      );

      final AlertItem item = (await repo.fetchAll()).single;
      // 안 보이는 알림보다 갈 곳 없는 알림이 낫다(트레이너 웹과 같은 규칙).
      expect(item.action?.target, AlertTarget.unknown);
      expect(item.action?.isNavigable, isFalse);
    });

    test('action 이 없는 알림도 그대로 실린다', () async {
      final repo = DioNotificationRepository(
        _dio(<Object?>[
          <String, Object?>{
            'id': 'n1',
            'title': '제목',
            'body': '본문',
            'time_ago': '방금',
            'category': 'system',
            'read': true,
          },
        ]),
      );

      final AlertItem item = (await repo.fetchAll()).single;
      expect(item.action, isNull);
      expect(item.read, isTrue);
    });
  });
}
