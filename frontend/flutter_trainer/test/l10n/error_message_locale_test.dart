/// 리포지토리가 들고 온 문자열이 영어 화면으로 새지 않는지. (#501, CodeRabbit)
///
/// 오류 문구는 화면을 띄우지 않으면 눈에 잘 안 띄는 자리라, 두 통로를 직접 본다.
///  * [authFailureText] — 예외에 실려 온 `detail`(파서 메시지)을 그대로 쓰지 않는다.
///  * [serverDetailOr] — 서버가 준 한국어 사유는 한국어 화면에서만 쓴다.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/features/auth/domain/repositories/trainer_auth_repository.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations_en.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations_ko.dart';

final AppLocalizationsKo _ko = AppLocalizationsKo();
final AppLocalizationsEn _en = AppLocalizationsEn();

void main() {
  group('authFailureText', () {
    test('detail 이 있어도 실패 코드의 로케일 문구를 쓴다', () {
      // 지금 detail 에 들어오는 값은 서버가 준 사유가 아니라 토큰 파싱 실패의
      // FormatException 메시지다. 그대로 내보내면 파서 내부 문구가 사용자에게
      // 보이고, 로케일과도 무관해진다.
      const e = AuthException(
        AuthFailure.emptyResponse,
        detail: 'Invalid access_token',
      );
      expect(authFailureText(_en, e), _en.authErrEmptyResponse);
      expect(authFailureText(_ko, e), _ko.authErrEmptyResponse);
    });

    test('실패 코드마다 그 로케일의 문구가 나온다', () {
      const e = AuthException(AuthFailure.invalidCredentials);
      expect(authFailureText(_ko, e), _ko.authErrInvalidCredentials);
      expect(authFailureText(_en, e), _en.authErrInvalidCredentials);
    });
  });

  group('serverDetailOr', () {
    const detail = '현재 비밀번호가 일치하지 않습니다.';

    test('한국어 화면은 서버 사유를 그대로 쓴다', () {
      expect(serverDetailOr(_ko, detail, _ko.myPwChangeFailed), detail);
    });

    test('영어 화면은 기본 문구로 물러난다', () {
      expect(serverDetailOr(_en, detail, _en.myPwChangeFailed),
          _en.myPwChangeFailed);
    });

    test('사유가 비어 있으면 로케일과 무관하게 기본 문구', () {
      expect(serverDetailOr(_ko, null, _ko.myPwChangeFailed),
          _ko.myPwChangeFailed);
      expect(serverDetailOr(_ko, '   ', _ko.myPwChangeFailed),
          _ko.myPwChangeFailed);
    });
  });
}
