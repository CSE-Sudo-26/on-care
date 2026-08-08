import 'package:oncare_trainer/features/auth/domain/entities/auth_tokens.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';

/// Pure in-memory mock used for the demo bypass and `USE_MOCK_API=true`.
///
/// Accepts any non-empty email/password (mirroring the user app's demo
/// login), issues fake tokens, and returns the fixed [seedTrainerProfile]
/// from [fetchProfile]. No network, no real validation.
class MockTrainerAuthRepository implements TrainerAuthRepository {
  const MockTrainerAuthRepository();

  static const _loginDelay = Duration(milliseconds: 400);

  TrainerAuthTokens _demoTokens(String tag) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return TrainerAuthTokens(
      access: 'demo-trainer-$tag-$stamp',
      refresh: 'demo-trainer-$tag-refresh-$stamp',
    );
  }

  @override
  Future<TrainerAuthTokens> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_loginDelay);
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('이메일과 비밀번호를 입력해 주세요');
    }
    return _demoTokens('token');
  }

  @override
  Future<TrainerAuthTokens> register({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) async {
    await Future<void>.delayed(_loginDelay);
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('이메일과 비밀번호를 입력해 주세요');
    }
    // 데모에는 코드를 검증할 백엔드가 없다. 화면이 기존과 똑같이 동작하도록
    // 코드는 보지 않고 통과시킨다.
    return _demoTokens('signup');
  }

  @override
  Future<TrainerAuthTokens> socialLogin({
    required String provider,
    required String token,
  }) async {
    await Future<void>.delayed(_loginDelay);
    if (token.isEmpty) {
      throw const AuthException('소셜 로그인 토큰이 없어요');
    }
    return _demoTokens(provider);
  }

  @override
  Future<TrainerAuthTokens> refresh(String refreshToken) async {
    if (refreshToken.isEmpty) {
      throw const AuthException('세션이 만료됐어요. 다시 로그인해 주세요.');
    }
    return _demoTokens('token');
  }

  @override
  Future<TrainerProfile> fetchProfile(String accessToken) async {
    if (accessToken.isEmpty) {
      throw const AuthException('세션이 만료됐어요. 다시 로그인해 주세요.');
    }
    return seedTrainerProfile;
  }
}
