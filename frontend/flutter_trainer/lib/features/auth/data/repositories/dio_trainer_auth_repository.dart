import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/auth/data/dtos/trainer_me_dto.dart';
import 'package:oncare_trainer/features/auth/data/repositories/mock_trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/domain/entities/auth_tokens.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';

/// Real trainer auth against the FastAPI backend. Selected when
/// `USE_MOCK_API=false` (see [trainerAuthRepositoryProvider]).
class DioTrainerAuthRepository implements TrainerAuthRepository {
  DioTrainerAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<TrainerAuthTokens> login({
    required String email,
    required String password,
  }) async {
    return _tokenCall(
      () => _dio.post<Map<String, Object?>>(
        '/auth/login',
        data: <String, Object?>{'username': email, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
      on401: '이메일 또는 비밀번호가 올바르지 않습니다.',
    );
  }

  @override
  Future<TrainerAuthTokens> register({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) async {
    try {
      // 회원용 `/auth/register` 가 아니다 — 그쪽은 role='member' 를 만들어,
      // 가입은 되는데 `/trainer/me` 가 403 을 주는 계정이 생겼다. (#475)
      await _dio.post<Map<String, Object?>>(
        '/auth/trainer/register',
        data: <String, Object?>{
          'email': email,
          'password': password,
          'name': name,
          'invite_code': inviteCode,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const AuthException('이미 가입된 이메일입니다.');
      }
      if (e.response?.statusCode == 422) {
        // 서버는 없는·만료된·이미 쓰인 코드를 구분하지 않는다. 어느 경우든
        // 트레이너가 할 일은 헬스장에 코드를 다시 받는 것이라 결론이 같다.
        throw const AuthException('사용할 수 없는 초대 코드예요. 헬스장에 확인해 주세요.');
      }
      throw _asAuth(e);
    }
    // Registration returns the created user, not a token — sign in next.
    return login(email: email, password: password);
  }

  @override
  Future<TrainerAuthTokens> socialLogin({
    required String provider,
    required String token,
  }) async {
    return _tokenCall(
      () => _dio.post<Map<String, Object?>>(
        '/auth/social/$provider',
        data: <String, Object?>{'token': token},
      ),
      on401: '소셜 로그인에 실패했어요. 다시 시도해 주세요.',
    );
  }

  @override
  Future<TrainerAuthTokens> refresh(String refreshToken) async {
    return _tokenCall(
      () => _dio.post<Map<String, Object?>>(
        '/auth/refresh',
        data: <String, Object?>{'refresh_token': refreshToken},
      ),
      on401: '세션이 만료됐어요. 다시 로그인해 주세요.',
    );
  }

  @override
  Future<TrainerProfile> fetchProfile(String accessToken) async {
    try {
      final res = await _dio.get<Map<String, Object?>>(
        '/trainer/me',
        options: Options(
          headers: <String, Object?>{'Authorization': 'Bearer $accessToken'},
        ),
      );
      final data = res.data;
      if (data == null) {
        throw const ServerError(message: '프로필 응답이 비어 있어요.');
      }
      return trainerProfileFromJson(data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403) {
        throw const NotTrainerException();
      }
      if (code == 401) {
        // Surfaced to SessionController so it can attempt a token refresh.
        throw UnauthorizedError(message: e.message);
      }
      // Transport failures (network/timeout/5xx) surface as a typed
      // [AppError] — NOT [AuthException] — so SessionController's restore
      // keeps the stored tokens on a transient failure instead of forcing
      // a sign-out (review: don't discard a valid session on a blip).
      throw AppError.fromDio(e);
    }
  }

  /// Runs a token-issuing call and parses `{ access_token, refresh_token }`.
  Future<TrainerAuthTokens> _tokenCall(
    Future<Response<Map<String, Object?>>> Function() call, {
    required String on401,
  }) async {
    try {
      final res = await call();
      final data = res.data;
      if (data == null) throw const AuthException('로그인 응답이 비어 있어요.');
      return TrainerAuthTokens.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw AuthException(on401);
      throw _asAuth(e);
    } on FormatException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Converts a transport failure into a user-facing [AuthException].
  AuthException _asAuth(DioException e) {
    final err = AppError.fromDio(e);
    if (err is NetworkError) {
      return const AuthException('네트워크 연결을 확인해 주세요.');
    }
    return const AuthException('로그인 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.');
  }
}

/// Selects the trainer auth repository from [AppConfig]: the real
/// Dio-backed implementation against the FastAPI backend, or the
/// in-memory [MockTrainerAuthRepository] for demo / `USE_MOCK_API=true`.
final trainerAuthRepositoryProvider = Provider<TrainerAuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockApi) {
    return const MockTrainerAuthRepository();
  }
  return DioTrainerAuthRepository(ref.watch(dioProvider));
}, name: 'trainerAuthRepository');
