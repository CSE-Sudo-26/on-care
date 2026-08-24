import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/mock_gym_repository.dart';
import 'package:oncare/features/exercise/presentation/controllers/exercise_controller.dart';
import 'package:oncare/features/my_health/data/repositories/mock_my_health_repository.dart';
import 'package:oncare/features/my_health/presentation/controllers/my_health_controller.dart';
import 'package:oncare/features/my_health/presentation/pages/my_health_page.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// MY 탭 프로필 카드의 "내 회원 ID" — 트레이너웹 신규 고객 등록(회원 ID로
/// 찾아 연결)이 회원을 식별하는 값과 같은 것이 여기 보여야 한다. 회원이 이
/// ID를 트레이너에게 직접 알려주는 자리라, 복사도 되어야 한다.
void main() {
  Future<void> pumpMyTab(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gymRepositoryProvider.overrideWithValue(MockGymRepository()),
          myHealthRepositoryProvider.overrideWithValue(
            const MockMyHealthRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MyHealthPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('프로필 카드가 내 회원 ID를 보여준다', (tester) async {
    await pumpMyTab(tester);

    expect(find.text('내 회원 ID'), findsOneWidget);
    expect(find.text('user-7d4e9a2c5f18'), findsOneWidget);
  });

  testWidgets('복사 버튼을 누르면 회원 ID가 클립보드에 담긴다', (tester) async {
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpMyTab(tester);
    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();

    final setData = calls.singleWhere(
      (call) => call.method == 'Clipboard.setData',
    );
    final arguments = setData.arguments as Map<Object?, Object?>;
    expect(arguments['text'], 'user-7d4e9a2c5f18');
    expect(find.text('회원 ID를 복사했어요'), findsOneWidget);
  });
}
