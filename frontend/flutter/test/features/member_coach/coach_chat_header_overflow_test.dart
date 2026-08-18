/// 트레이너 채팅 헤더가 넘치지 않는지 (#840).
///
/// 헤더의 상태 점 + 부제가 든 `Row` 가 고정 폭이라, 부제가 길어지면 그대로
/// 넘쳤다. 영어 부제(`Personal trainer · Available`)가 한국어(`담당 트레이너 ·
/// 상담 가능`)보다 길어 같은 자리에서 먼저 샌다 — #743 과 같은 계열이다.
///
/// 430px 는 iPhone 15 Pro Max 의 논리 폭이다. E2E 로그에는
/// `RenderFlex overflowed by 59 pixels on the right` 로 남아 있었다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/features/member_coach/data/repositories/mock_member_coach_repository.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_chat_sheet.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

const AppConfig _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: 'https://dev.api.test',
  useMockApi: true,
);

void main() {
  Future<void> pumpChat(
    WidgetTester tester, {
    required String lang,
    required Size size,
    String trainerName = '김트레이너',
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_config),
          memberCoachRepositoryProvider.overrideWithValue(
            MockMemberCoachRepository(),
          ),
        ],
        child: MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrainerChatPage(trainerName: trainerName),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('트레이너 채팅 헤더 레이아웃 (#840)', () {
    for (final String lang in <String>['ko', 'en']) {
      for (final double scale in <double>[1.0, 1.3]) {
        testWidgets('폭 430 · $lang · 글자 배율 $scale 에서 넘치지 않는다', (
          WidgetTester tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pumpChat(tester, lang: lang, size: const Size(430, 932));

          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('아주 긴 트레이너 이름에도 헤더가 넘치지 않는다', (WidgetTester tester) async {
      await pumpChat(
        tester,
        lang: 'ko',
        size: const Size(430, 932),
        trainerName: '아주아주긴이름을가진트레이너선생님입니다정말로깁니다',
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('부제는 잘려도 트레이너 이름은 그대로 보인다', (WidgetTester tester) async {
      await pumpChat(tester, lang: 'en', size: const Size(430, 932));

      expect(find.text('김트레이너'), findsOneWidget);
    });
  });
}
