/// 로그인·회원가입·온보딩 화면의 현지화 — #642.
///
/// 세 화면만 한국어가 하드코딩돼 있어, 영어 로케일로 켜면 앱에서 처음 보는 세 화면이
/// 로케일을 따르지 않았다.
///
/// 여기서 고정하는 것은 둘이다.
///
///  * en 로케일에서 한국어가 남지 않는다.
///  * **ko 로케일 문구는 옮기기 전과 같다.** 로그인 화면은 "데모 둘러보기" 직전 화면이라
///    문구가 바뀌면 시연 첫 장면이 달라진다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/gen/l10n/app_localizations.dart';

/// 옮기기 전 화면에 있던 한국어 문구. 값이 바뀌면 시연 화면이 달라진다.
const Map<String, String> _koBefore = <String, String>{
  'authTagline': '고혈압·당뇨 관리를 위한 AI 헬스케어',
  'authEmailHint': '이메일',
  'authPasswordHint': '비밀번호',
  'authSignInAction': '로그인',
  'authNoAccountQuestion': '계정이 없으신가요?',
  'authSignUpAction': '회원가입',
  'authDemoAction': '로그인 없이 데모 둘러보기',
  'authOrDivider': '또는',
  'authKakaoAction': '카카오로 시작하기',
  'authGoogleAction': '구글로 시작하기',
  'authMissingCredentials': '이메일과 비밀번호를 입력해 주세요',
  'authSignInFailed': '로그인에 실패했어요. 이메일·비밀번호를 확인해 주세요',
  'authSocialSignInFailed': '소셜 로그인에 실패했어요. 잠시 후 다시 시도해 주세요',
  'signUpTitle': '회원가입',
  'signUpSubtitle': 'On-Care 계정을 만들어 건강 관리를 시작하세요',
  'signUpNameHint': '이름',
  'signUpPasswordHint': '비밀번호 (8자 이상)',
  'signUpPasswordConfirmHint': '비밀번호 확인',
  'signUpAction': '가입하고 시작하기',
  'signUpHaveAccountQuestion': '이미 계정이 있으신가요?',
  'signUpPasswordTooShort': '비밀번호는 8자 이상이어야 해요',
  'signUpPasswordMismatch': '비밀번호가 일치하지 않아요',
  'signUpEmailTaken': '이미 가입된 이메일이에요. 로그인해 주세요.',
  'signUpFailed': '회원가입에 실패했어요. 잠시 후 다시 시도해 주세요.',
  'onboardSkip': '나중에 하기',
  'onboardPrevious': '이전',
  'onboardNext': '다음',
  'onboardDone': '완료',
  'onboardSaveFailed': '저장에 실패했어요. 잠시 후 다시 시도해 주세요',
  'onboardBasicTitle': '기본 정보',
  'onboardBasicSubtitle': '맞춤 건강 관리를 위해 기본 정보를 알려주세요.',
  'onboardBirthHint': '생년월일 (YYYY-MM-DD)',
  'onboardHeightHint': '키 (cm)',
  'onboardHealthTitle': '건강 상태',
  'onboardHealthSubtitle': '관리 중인 만성질환을 선택해 주세요. (복수 선택 가능)',
  'onboardGoalTitle': '건강 목표',
  'onboardGoalSubtitle': '달성하고 싶은 목표를 입력해 주세요. 나중에 바꿀 수 있어요.',
  'onboardSodiumGoalHint': '하루 나트륨 목표 (mg)',
  'onboardGenderMale': '남성',
  'onboardGenderFemale': '여성',
  'onboardGenderOther': '기타',
  'onboardConditionHypertension': '고혈압',
  'onboardConditionDiabetes': '당뇨',
  'onboardConditionDyslipidemia': '고지혈증',
  'onboardConditionObesity': '비만',
};

/// 키 이름 → 그 로케일의 문구.
String _read(AppLocalizations l, String key) => switch (key) {
  'authTagline' => l.authTagline,
  'authEmailHint' => l.authEmailHint,
  'authPasswordHint' => l.authPasswordHint,
  'authSignInAction' => l.authSignInAction,
  'authNoAccountQuestion' => l.authNoAccountQuestion,
  'authSignUpAction' => l.authSignUpAction,
  'authDemoAction' => l.authDemoAction,
  'authOrDivider' => l.authOrDivider,
  'authKakaoAction' => l.authKakaoAction,
  'authGoogleAction' => l.authGoogleAction,
  'authMissingCredentials' => l.authMissingCredentials,
  'authSignInFailed' => l.authSignInFailed,
  'authSocialSignInFailed' => l.authSocialSignInFailed,
  'signUpTitle' => l.signUpTitle,
  'signUpSubtitle' => l.signUpSubtitle,
  'signUpNameHint' => l.signUpNameHint,
  'signUpPasswordHint' => l.signUpPasswordHint,
  'signUpPasswordConfirmHint' => l.signUpPasswordConfirmHint,
  'signUpAction' => l.signUpAction,
  'signUpHaveAccountQuestion' => l.signUpHaveAccountQuestion,
  'signUpPasswordTooShort' => l.signUpPasswordTooShort,
  'signUpPasswordMismatch' => l.signUpPasswordMismatch,
  'signUpEmailTaken' => l.signUpEmailTaken,
  'signUpFailed' => l.signUpFailed,
  'onboardSkip' => l.onboardSkip,
  'onboardPrevious' => l.onboardPrevious,
  'onboardNext' => l.onboardNext,
  'onboardDone' => l.onboardDone,
  'onboardSaveFailed' => l.onboardSaveFailed,
  'onboardBasicTitle' => l.onboardBasicTitle,
  'onboardBasicSubtitle' => l.onboardBasicSubtitle,
  'onboardBirthHint' => l.onboardBirthHint,
  'onboardHeightHint' => l.onboardHeightHint,
  'onboardHealthTitle' => l.onboardHealthTitle,
  'onboardHealthSubtitle' => l.onboardHealthSubtitle,
  'onboardGoalTitle' => l.onboardGoalTitle,
  'onboardGoalSubtitle' => l.onboardGoalSubtitle,
  'onboardSodiumGoalHint' => l.onboardSodiumGoalHint,
  'onboardGenderMale' => l.onboardGenderMale,
  'onboardGenderFemale' => l.onboardGenderFemale,
  'onboardGenderOther' => l.onboardGenderOther,
  'onboardConditionHypertension' => l.onboardConditionHypertension,
  'onboardConditionDiabetes' => l.onboardConditionDiabetes,
  'onboardConditionDyslipidemia' => l.onboardConditionDyslipidemia,
  'onboardConditionObesity' => l.onboardConditionObesity,
  _ => fail('알 수 없는 키: $key'),
};

/// [locale] 의 [AppLocalizations] 를 꺼낸다.
Future<AppLocalizations> _localizations(
  WidgetTester tester,
  Locale locale,
) async {
  late AppLocalizations found;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          found = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return found;
}

void main() {
  testWidgets('ko 문구가 옮기기 전과 같다', (WidgetTester tester) async {
    final AppLocalizations l = await _localizations(tester, const Locale('ko'));

    for (final MapEntry<String, String> entry in _koBefore.entries) {
      expect(_read(l, entry.key), entry.value, reason: entry.key);
    }
  });

  testWidgets('en 문구에 한국어가 남지 않는다', (WidgetTester tester) async {
    final AppLocalizations l = await _localizations(tester, const Locale('en'));

    final RegExp hangul = RegExp(r'[가-힣]');
    for (final String key in _koBefore.keys) {
      final String value = _read(l, key);
      expect(
        hangul.hasMatch(value),
        isFalse,
        reason: '$key 가 en 로케일에서 한국어다: $value',
      );
      expect(value.trim(), isNotEmpty, reason: '$key 가 비어 있다');
    }
  });

  testWidgets('두 로케일의 문구가 실제로 다르다', (WidgetTester tester) async {
    // 같은 값이면 ARB 에 en 번역을 빠뜨리고 ko 를 복사해 둔 것이다. 위 두 테스트만으로는
    // 잡히지 않는 실수라(영문 그대로 둔 키는 한글 검사를 통과한다) 여기서 함께 본다.
    final AppLocalizations ko = await _localizations(
      tester,
      const Locale('ko'),
    );
    final AppLocalizations en = await _localizations(
      tester,
      const Locale('en'),
    );

    for (final String key in _koBefore.keys) {
      expect(_read(en, key), isNot(_read(ko, key)), reason: key);
    }
  });
}
