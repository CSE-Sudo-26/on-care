/// 상담의 색과 상담 요청 버튼의 그리드. (#1013)
///
/// 블록의 색이 상태만 가르던 때에는 `10:00 1:1 PT` 와 `17:00 상담` 이 둘 다
/// 예정이면 똑같은 남색이었다. 시간표를 훑는 동안 읽는 것은 색과 자리인데,
/// 종류는 셋째 줄 글씨로만 있었다.
///
/// 헤더의 상담 요청 버튼도 배지 자리를 비우느라 옆 버튼보다 6px 아래에 서서,
/// 한 줄에 선 세 버튼이 서로 다른 격자를 썼다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/features/schedule/presentation/widgets/schedule_week_timetable.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> openSchedule(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
    );
  }

  /// [name] 블록의 면 색. 면이 종류를 말한다.
  Color surfaceOf(WidgetTester tester, String name) {
    final block = find
        .ancestor(
          of: find
              .descendant(
                of: find.byType(ScheduleWeekTimetable),
                matching: find.textContaining(name),
              )
              .first,
          matching: find.byType(Material),
        )
        .first;
    return tester.widget<Material>(block).color!;
  }

  testWidgets('상담 블록이 1:1 PT 블록과 다른 색으로 보인다', (tester) async {
    await openSchedule(tester);

    final Color pt = surfaceOf(tester, '박성호');
    final Color consult = surfaceOf(tester, '윤가온(신규)');

    expect(pt, isNot(consult), reason: '종류가 색으로 갈려야 한다');
    expect(
      consult,
      AppColors.sessionConsultation.withValues(alpha: 0.12),
      reason: '상담은 상담의 색을 쓴다',
    );
    expect(pt, AppColors.sessionPersonalTraining.withValues(alpha: 0.12));
  });

  testWidgets('색만으로 구분하지 않는다 — 글씨가 종류를 함께 말한다', (tester) async {
    await openSchedule(tester);

    // 색을 못 보는 경우에도 블록에서 종류를 알 수 있어야 한다.
    expect(find.textContaining('상담'), findsWidgets);
    expect(find.textContaining('1:1 PT'), findsWidgets);
  });

  testWidgets('상담 요청 버튼이 예약 슬롯과 같은 그리드에 선다', (tester) async {
    await openSchedule(tester);

    final Rect inbox = tester.getRect(
      find.byKey(const Key('consult-inbox-entry')),
    );
    final Rect slots = tester.getRect(
      find.byKey(const ValueKey<String>('schedule-open-slots')),
    );

    expect(
      inbox.height,
      closeTo(slots.height, 0.5),
      reason: '높이가 같아야 한 줄로 읽힌다',
    );
    expect(
      inbox.center.dy,
      closeTo(slots.center.dy, 0.5),
      reason: '같은 줄의 가운데에 서야 한다',
    );
  });

  testWidgets('상담 요청 버튼이 상담의 색을 쓴다', (tester) async {
    await pumpTrainerApp(
      tester,
      token: 'demo-trainer-token',
      at: AppRoutes.schedule,
      seed: false,
    );

    final Icon glyph = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('consult-inbox-entry')),
        matching: find.byIcon(Icons.mark_email_unread_outlined),
      ),
    );
    expect(glyph.color, AppColors.sessionConsultation);
  });
}
