import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/auth/data/repositories/dio_trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, Object?>> _ok(Map<String, Object?> body, String path) =>
    Response<Map<String, Object?>>(
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
  late DioTrainerAuthRepository repo;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    dio = _MockDio();
    repo = DioTrainerAuthRepository(dio);
  });

  group('login', () {
    test('parses access/refresh tokens on success', () async {
      when(
        () => dio.post<Map<String, Object?>>(
          '/auth/login',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _ok(<String, Object?>{
          'access_token': 'a',
          'refresh_token': 'r',
        }, '/auth/login'),
      );

      final tokens = await repo.login(email: 'e@x.com', password: 'pw');
      expect(tokens.access, 'a');
      expect(tokens.refresh, 'r');
    });

    test('maps 401 to a friendly AuthException', () async {
      when(
        () => dio.post<Map<String, Object?>>(
          '/auth/login',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(_httpError(401, '/auth/login'));

      await expectLater(
        repo.login(email: 'e@x.com', password: 'bad'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('올바르지 않습니다'),
          ),
        ),
      );
    });

    test('maps a connection error to a network AuthException', () async {
      when(
        () => dio.post<Map<String, Object?>>(
          '/auth/login',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repo.login(email: 'e@x.com', password: 'pw'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('네트워크'),
          ),
        ),
      );
    });
  });

  group('register', () {
    test('maps 409 to a duplicate-email AuthException', () async {
      when(
        () => dio.post<Map<String, Object?>>(
          '/auth/register',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(_httpError(409, '/auth/register'));

      await expectLater(
        repo.register(email: 'e@x.com', password: 'pw', name: '김'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('이미 가입'),
          ),
        ),
      );
    });
  });

  group('fetchProfile', () {
    test('maps a trainer body to a profile', () async {
      when(
        () => dio.get<Map<String, Object?>>(
          '/trainer/me',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _ok(<String, Object?>{
          'name': '김트레이너',
          'email': 'trainer@oncare.com',
          'gym': <String, Object?>{'name': '온케어짐 신촌점'},
        }, '/trainer/me'),
      );

      final profile = await repo.fetchProfile('token');
      expect(profile.name, '김트레이너');
      expect(profile.gym.name, '온케어짐 신촌점');
    });

    test('maps 403 to NotTrainerException', () async {
      when(
        () => dio.get<Map<String, Object?>>(
          '/trainer/me',
          options: any(named: 'options'),
        ),
      ).thenThrow(_httpError(403, '/trainer/me'));

      await expectLater(
        repo.fetchProfile('member-token'),
        throwsA(isA<NotTrainerException>()),
      );
    });

    test('rethrows 401 so the session can refresh', () async {
      when(
        () => dio.get<Map<String, Object?>>(
          '/trainer/me',
          options: any(named: 'options'),
        ),
      ).thenThrow(_httpError(401, '/trainer/me'));

      await expectLater(
        repo.fetchProfile('stale'),
        throwsA(isA<UnauthorizedError>()),
      );
    });

    test('maps a network failure to NetworkError, NOT AuthException '
        '(so restore keeps the tokens)', () async {
      when(
        () => dio.get<Map<String, Object?>>(
          '/trainer/me',
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/trainer/me'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repo.fetchProfile('valid'),
        throwsA(isA<NetworkError>()),
      );
    });
  });
}
