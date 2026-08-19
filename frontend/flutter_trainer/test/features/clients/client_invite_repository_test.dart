import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_invite_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_invite.dart';

class _MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T body, String path) => Response<T>(
  requestOptions: RequestOptions(path: path),
  statusCode: 200,
  data: body,
);

DioException _httpError(int status, String path, {Object? body}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
        data: body,
      ),
    );

const AppConfig _demoConfig = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'http://localhost/v1',
  useMockApi: true,
);

const AppConfig _realConfig = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'http://localhost/v1',
  useMockApi: false,
);

/// 담당 요청은 **요청이지 등록이 아니다**(#919). 저장소가 그 계약을 지키는지 —
/// 어떤 실패를 어떤 타입으로 옮기는지, 데모에서 진입점을 감추는지 — 를 본다.
void main() {
  late _MockDio dio;
  late DioClientInviteRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioClientInviteRepository(dio);
  });

  group('lookup', () {
    test('parses the member the server found', () async {
      when(
        () => dio.get<Map<String, Object?>>(
          '/trainer/member-lookup',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _ok<Map<String, Object?>>(<String, Object?>{
          'member_id': 'm1',
          'name': '김민수',
          'email': 'minsu@oncare.com',
          'has_trainer': false,
          'coached_by_me': false,
          'invite_pending': false,
        }, '/trainer/member-lookup'),
      );

      final found = await repo.lookup('  minsu@oncare.com ');

      expect(found.memberId, 'm1');
      expect(found.canInvite, isTrue);
      // 공백은 서버로 넘어가지 않는다 — 붙여넣기 한 번에 404 가 되면 트레이너는
      // 이메일이 틀렸다고 읽는다.
      verify(
        () => dio.get<Map<String, Object?>>(
          '/trainer/member-lookup',
          queryParameters: <String, Object?>{'email': 'minsu@oncare.com'},
        ),
      ).called(1);
    });

    test('surfaces "no such member" as NotFoundError', () async {
      when(
        () => dio.get<Map<String, Object?>>(
          '/trainer/member-lookup',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(_httpError(404, '/trainer/member-lookup'));

      expect(
        () => repo.lookup('nobody@oncare.com'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('a member who already has a coach cannot be invited', () async {
      when(
        () => dio.get<Map<String, Object?>>(
          '/trainer/member-lookup',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _ok<Map<String, Object?>>(<String, Object?>{
          'member_id': 'm1',
          'name': '김민수',
          'email': 'minsu@oncare.com',
          'has_trainer': true,
          'coached_by_me': false,
          'invite_pending': false,
        }, '/trainer/member-lookup'),
      );

      expect((await repo.lookup('minsu@oncare.com')).canInvite, isFalse);
    });
  });

  group('invite', () {
    test('sends the member id and a trimmed message', () async {
      when(
        () => dio.post<Map<String, Object?>>(
          '/trainer/client-invites',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok<Map<String, Object?>>(<String, Object?>{
          'id': 'tci-1',
          'member_id': 'm1',
          'member_name': '김민수',
          'member_email': 'minsu@oncare.com',
          'message': '함께 해요',
          'status': 'pending',
          'created_at': '2026-08-19T09:00:00Z',
        }, '/trainer/client-invites'),
      );

      final invite = await repo.invite('m1', message: '  함께 해요  ');

      expect(invite.status, ClientInviteStatus.pending);
      verify(
        () => dio.post<Map<String, Object?>>(
          '/trainer/client-invites',
          data: <String, Object?>{'member_id': 'm1', 'message': '함께 해요'},
        ),
      ).called(1);
    });

    test('a blank message is left out entirely', () async {
      when(
        () => dio.post<Map<String, Object?>>(
          '/trainer/client-invites',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok<Map<String, Object?>>(<String, Object?>{
          'id': 'tci-1',
          'member_id': 'm1',
          'member_name': '김민수',
          'member_email': 'minsu@oncare.com',
          'status': 'pending',
          'created_at': '2026-08-19T09:00:00Z',
        }, '/trainer/client-invites'),
      );

      await repo.invite('m1', message: '   ');

      verify(
        () => dio.post<Map<String, Object?>>(
          '/trainer/client-invites',
          data: <String, Object?>{'member_id': 'm1'},
        ),
      ).called(1);
    });

    test('keeps the server\'s reason for a refused invite (409)', () async {
      when(
        () => dio.post<Map<String, Object?>>(
          '/trainer/client-invites',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        _httpError(
          409,
          '/trainer/client-invites',
          body: <String, Object?>{'detail': '이미 다른 트레이너가 담당 중인 회원이에요.'},
        ),
      );

      // 어느 쪽 이유인지는 서버만 안다 — 그 문장이 트레이너가 다음에 할 일을 정한다.
      await expectLater(
        repo.invite('m1'),
        throwsA(
          isA<ValidationError>().having(
            (e) => e.message,
            'message',
            '이미 다른 트레이너가 담당 중인 회원이에요.',
          ),
        ),
      );
    });
  });

  test('the sent list parses statuses', () async {
    when(
      () => dio.get<List<dynamic>>(
        '/trainer/client-invites',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => _ok<List<dynamic>>(<dynamic>[
        <String, Object?>{
          'id': 'tci-1',
          'member_id': 'm1',
          'member_name': '김민수',
          'member_email': 'a@b.com',
          'status': 'pending',
          'created_at': '2026-08-19T09:00:00Z',
        },
        <String, Object?>{
          'id': 'tci-2',
          'member_id': 'm2',
          'member_name': '이지수',
          'member_email': 'c@d.com',
          'status': 'accepted',
          'created_at': '2026-08-18T09:00:00Z',
        },
      ], '/trainer/client-invites'),
    );

    final rows = await repo.listSent(status: 'all');

    expect(rows.map((r) => r.status).toList(), <ClientInviteStatus>[
      ClientInviteStatus.pending,
      ClientInviteStatus.accepted,
    ]);
    expect(rows.first.isPending, isTrue);
  });

  test('cancelling an already-decided invite surfaces the reason', () async {
    when(
      () => dio.delete<Map<String, Object?>>('/trainer/client-invites/tci-1'),
    ).thenThrow(
      _httpError(
        409,
        '/trainer/client-invites/tci-1',
        body: <String, Object?>{'detail': '이미 처리된 요청이에요.'},
      ),
    );

    await expectLater(repo.cancel('tci-1'), throwsA(isA<ValidationError>()));
  });

  group('provider', () {
    test('demo mode hides the entry point', () {
      final container = ProviderContainer(
        overrides: <Override>[appConfigProvider.overrideWithValue(_demoConfig)],
      );
      addTearDown(container.dispose);

      expect(container.read(clientInvitesEnabledProvider), isFalse);
      expect(
        container.read(clientInviteRepositoryProvider),
        isA<DemoClientInviteRepository>(),
      );
    });

    test('real-API mode resolves the Dio source and shows the entry', () {
      final container = ProviderContainer(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_realConfig),
          dioProvider.overrideWithValue(Dio()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(clientInvitesEnabledProvider), isTrue);
      expect(
        container.read(clientInviteRepositoryProvider),
        isA<DioClientInviteRepository>(),
      );
    });

    test('the demo source refuses to pretend a request was sent', () {
      const demo = DemoClientInviteRepository();

      // 데모에서 조용히 성공하면 실제로 회원에게 닿았다고 읽힌다.
      expect(() => demo.invite('m1'), throwsA(isA<ValidationError>()));
    });
  });
}
