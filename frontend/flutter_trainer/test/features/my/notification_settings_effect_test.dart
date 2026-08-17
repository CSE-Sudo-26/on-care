import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/my/data/trainer_settings.dart';

import '../../helpers/pump_app.dart';

/// 설정의 알림 항목이 실제로 화면을 바꾸는지. 예전에는 이 값을 설정 화면
/// 자신 말고 아무도 읽지 않아, 꺼도 사이드바 배지가 그대로였다(#817).
void main() {
  testWidgets('새 메시지 알림을 끄면 사이드바 배지가 사라진다', (tester) async {
    await withWideSurface(tester, () async {
      final container = await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.dashboard,
      );
      await tester.pumpAndSettle();

      // 시드에는 읽지 않은 대화가 있어 사이드바에 숫자 배지가 떠 있다.
      final beforeCounts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && RegExp(r'^\d+$').hasMatch(d))
          .toList();
      expect(beforeCounts, isNotEmpty, reason: '읽지 않은 대화가 있으면 사이드바에 숫자가 떠야 한다');

      // 설정을 끈다. 설정 화면을 거치지 않고 값만 바꿔도 같은 결과여야 한다 —
      // 배지는 이 설정을 읽는 쪽이지, 설정 화면이 그리는 것이 아니다.
      final controller = container.read(trainerSettingsProvider.notifier);
      await controller.setNewMessageAlerts(false);
      await tester.pumpAndSettle();

      final afterCounts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && RegExp(r'^\d+$').hasMatch(d))
          .toList();
      expect(
        afterCounts.length,
        lessThan(beforeCounts.length),
        reason: '알림을 껐는데 사이드바 배지가 그대로다',
      );

      // 다시 켜면 돌아온다 — 끄는 것이 데이터를 지우는 것이 아니다.
      await controller.setNewMessageAlerts(true);
      await tester.pumpAndSettle();
      final restored = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && RegExp(r'^\d+$').hasMatch(d))
          .toList();
      expect(restored.length, beforeCounts.length);
    });
  });
}
