/// 좁은 화면·큰 글자 배율에서 식단 탭이 넘치지 않는지 (#739).
///
/// 320px 는 아이폰 SE 1세대·구형 안드로이드의 논리 폭이고, 배율 2.0 은 접근성
/// 설정의 상한에 가깝다. 예전에는 이 조건에서 끼니 카드·음식 항목·기간 토글·칼로리
/// 링이 각각 넘쳐, 글자가 잘리거나 노랑·검정 줄무늬가 그려졌다.
///
/// 높이를 넉넉히 두는 이유는 `ListView` 가 보이는 자식만 만들기 때문이다 — 짧은
/// 화면에서는 아래쪽 카드가 아예 그려지지 않아 검증 대상이 사라진다.
///
/// **한국어만 검증한다.** 영어는 라벨이 훨씬 길어(`This month` vs `이번 달`) 날짜
/// 스트립이 배율 1.0 에서도 넘친다. 그쪽은 아직 고치지 않았고 별도로 다룬다 —
/// 이 파일을 en 으로 돌리면 네 배율 모두 실패한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/account/data/repositories/mock_account_repository.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/features/diet/presentation/pages/diet_record_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

import '../../helpers/fake_diet_repository.dart';

void main() {
  group('식단 탭 좁은 화면 레이아웃 (#739)', () {
    for (final double scale in <double>[1.0, 1.3, 1.6, 2.0]) {
      testWidgets('폭 320 · 글자 배율 $scale 에서 넘치지 않는다', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(320, 4000);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              dietRepositoryProvider.overrideWithValue(FakeDietRepository()),
              accountRepositoryProvider.overrideWithValue(
                MockAccountRepository(),
              ),
            ],
            child: const MaterialApp(
              locale: Locale('ko'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DietRecordPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // overflow 는 렌더링 예외로 보고된다. `pumpAndSettle` 이 예외 없이 끝났고
        // 화면이 그려졌다면 넘친 곳이 없다는 뜻이다.
        expect(tester.takeException(), isNull);
        expect(find.byType(DietRecordPage), findsOneWidget);
      });
    }
  });
}
