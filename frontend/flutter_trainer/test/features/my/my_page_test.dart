import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('MyPage', () {
    Future<void> openTab(WidgetTester tester) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');
      await tester.tap(find.text('MY')); // bottom-nav label
      await settle(tester);
    }

    testWidgets('renders profile, certs, stats, gym — and no 역할 전환', (
      tester,
    ) async {
      await openTab(tester);

      expect(find.text('김트레이너'), findsOneWidget);
      expect(find.text('trainer@oncare.com'), findsOneWidget);
      expect(find.text('퍼스널 트레이너'), findsOneWidget);
      expect(find.text('경력 7년'), findsOneWidget);
      expect(find.text('생활스포츠지도사 2급'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('담당 고객'), 150);
      expect(find.text('3'), findsOneWidget); // live client count
      expect(find.text('완료 세션'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('온케어짐 신촌점'), 150);
      expect(find.text('● 영업 중'), findsOneWidget);

      // 역할 전환은 계정 분리 정책상 존재하지 않는다.
      expect(find.textContaining('역할 전환'), findsNothing);
      await tester.scrollUntilVisible(find.text('로그아웃'), 150);
      expect(find.text('로그아웃'), findsOneWidget);
    });

    testWidgets('로그아웃 returns to the login screen', (tester) async {
      await openTab(tester);

      await tester.scrollUntilVisible(find.text('로그아웃'), 150);
      await tester.ensureVisible(find.text('로그아웃'));
      await tester.pump();
      await tester.tap(find.text('로그아웃'));
      await settle(tester);

      expect(find.text('로그인 없이 데모 둘러보기'), findsOneWidget);
    });

    testWidgets('edit mode saves changes with a confirmation flash', (
      tester,
    ) async {
      await openTab(tester);

      await tester.tap(find.text('✎ 프로필 수정'));
      await tester.pump();
      expect(find.text('저장'), findsOneWidget);

      // First edit field is 이름.
      await tester.enterText(find.byType(TextField).first, '박트레이너');
      await tester.tap(find.text('저장'));
      await tester.pump();

      expect(find.text('✓ 변경사항이 저장됐어요'), findsOneWidget);
      expect(find.text('박트레이너'), findsOneWidget);

      // Flash expires (no pending timers at test end).
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('✓ 변경사항이 저장됐어요'), findsNothing);
    });
  });
}
