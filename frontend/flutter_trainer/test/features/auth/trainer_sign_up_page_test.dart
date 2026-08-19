import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/features/auth/data/repositories/dio_trainer_auth_repository.dart';
import 'package:oncare_trainer/features/auth/domain/entities/auth_tokens.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';

import '../../helpers/pump_app.dart';

/// 가입 호출의 인자를 기록하는 페이크. 로그인까지는 성공시킨다.
class _RecordingAuthRepository implements TrainerAuthRepository {
  String? email;
  String? name;
  String? inviteCode;
  int registerCalls = 0;

  static const TrainerAuthTokens _tokens = TrainerAuthTokens(
    access: 'a',
    refresh: 'r',
  );

  @override
  Future<TrainerAuthTokens> login({
    required String email,
    required String password,
  }) async => _tokens;

  @override
  Future<TrainerAuthTokens> register({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) async {
    registerCalls++;
    this.email = email;
    this.name = name;
    this.inviteCode = inviteCode;
    return _tokens;
  }

  @override
  Future<TrainerAuthTokens> socialLogin({
    required String provider,
    required String token,
  }) async => _tokens;

  @override
  Future<TrainerAuthTokens> refresh(String refreshToken) async => _tokens;

  @override
  Future<TrainerProfile> fetchProfile(String accessToken) async =>
      const TrainerProfile(
        name: '신규 트레이너',
        email: 'new@oncare.com',
        phone: '',
        specialty: '',
        career: '',
        intro: '',
        certifications: <String>[],
        gym: TrainerGym(name: '', address: '', hours: '', phone: ''),
      );
}

/// 실 API 모드 설정 — 초대 코드 입력이 그려지는 쪽.
const AppConfig _realConfig = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'http://localhost/v1',
  useMockApi: false,
);

Future<_RecordingAuthRepository> _pumpSignUp(
  WidgetTester tester, {
  bool demo = false,
}) async {
  final repo = _RecordingAuthRepository();
  await pumpTrainerApp(
    tester,
    at: AppRoutes.signUp,
    extraOverrides: <Override>[
      if (!demo) ...<Override>[
        appConfigProvider.overrideWithValue(_realConfig),
        // 가입 흐름을 보는 테스트다. 대시보드에 내려앉은 뒤의 배지 폴링까지
        // 안고 끝나지 않게 멈춰 둔다.
        ...stillBadges(),
        // 명단도 실 API 에서는 스스로 다시 읽는다(#918). 이 테스트가 보는
        // 것은 가입 요청의 인자다.
        stillRoster(),
      ],
      trainerAuthRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return repo;
}

Future<void> _fill(
  WidgetTester tester, {
  String name = '김신규',
  String email = 'new@oncare.com',
  String password = 'signup-pw-1234',
  String confirm = 'signup-pw-1234',
  String? code,
}) async {
  await tester.enterText(find.widgetWithText(TextField, '이름'), name);
  await tester.enterText(find.widgetWithText(TextField, '이메일'), email);
  await tester.enterText(
    find.widgetWithText(TextField, '비밀번호 (8자 이상)'),
    password,
  );
  await tester.enterText(find.widgetWithText(TextField, '비밀번호 확인'), confirm);
  if (code != null) {
    await tester.enterText(find.widgetWithText(TextField, '헬스장 초대 코드'), code);
  }
  await tester.pump();
}

void main() {
  testWidgets('가입 화면에 초대 코드 입력이 있다', (WidgetTester tester) async {
    await _pumpSignUp(tester);

    expect(find.widgetWithText(TextField, '헬스장 초대 코드'), findsOneWidget);
    expect(find.text('소속 헬스장에서 발급받은 코드를 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('초대 코드를 그대로 실어 보낸다', (WidgetTester tester) async {
    final repo = await _pumpSignUp(tester);
    await _fill(tester, code: 'ONCARE1');

    await tester.tap(find.text('가입하고 시작하기'));
    await settle(tester);

    expect(repo.registerCalls, 1);
    expect(repo.inviteCode, 'ONCARE1');
    expect(repo.email, 'new@oncare.com');
  });

  testWidgets('코드 앞뒤 공백은 정리해서 보낸다', (WidgetTester tester) async {
    final repo = await _pumpSignUp(tester);
    await _fill(tester, code: '  ONCARE1  ');

    await tester.tap(find.text('가입하고 시작하기'));
    await settle(tester);

    expect(repo.inviteCode, 'ONCARE1');
  });

  testWidgets('코드 없이는 가입 요청을 보내지 않는다', (WidgetTester tester) async {
    // 코드가 소속을 결정하므로, 없으면 서버에 물어볼 것도 없다.
    final repo = await _pumpSignUp(tester);
    await _fill(tester);

    await tester.tap(find.text('가입하고 시작하기'));
    await settle(tester);

    expect(repo.registerCalls, 0);
    expect(find.text('헬스장에서 받은 초대 코드를 입력해 주세요'), findsOneWidget);
  });

  testWidgets('비밀번호가 다르면 코드가 있어도 보내지 않는다', (WidgetTester tester) async {
    final repo = await _pumpSignUp(tester);
    await _fill(tester, confirm: 'different-pw', code: 'ONCARE1');

    await tester.tap(find.text('가입하고 시작하기'));
    await settle(tester);

    expect(repo.registerCalls, 0);
  });

  // --- 데모 불변 -----------------------------------------------------------

  testWidgets('데모 가입 화면에는 코드 입력이 없다', (WidgetTester tester) async {
    // 데모에는 코드를 검증할 백엔드가 없다. 무엇을 넣어도 통과하는 죽은 입력을
    // 두느니 그리지 않는다 — 데모 화면이 지금 그대로여야 한다.
    await _pumpSignUp(tester, demo: true);

    expect(find.widgetWithText(TextField, '헬스장 초대 코드'), findsNothing);
    expect(find.text('소속 헬스장에서 발급받은 코드를 입력해 주세요.'), findsNothing);
  });

  testWidgets('데모에서는 코드 없이도 가입이 진행된다', (WidgetTester tester) async {
    final repo = await _pumpSignUp(tester, demo: true);
    await _fill(tester);

    await tester.tap(find.text('가입하고 시작하기'));
    await settle(tester);

    expect(repo.registerCalls, 1);
    expect(repo.inviteCode, '');
  });
}
