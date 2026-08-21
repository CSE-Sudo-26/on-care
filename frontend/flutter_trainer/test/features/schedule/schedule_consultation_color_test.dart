/// 상담의 표현과 상담 요청 버튼의 그리드. (#1013)
///
/// 블록의 색이 상태만 가르던 때에는 `10:00 1:1 PT` 와 `17:00 상담` 이 둘 다
/// 예정이면 똑같이 보였다. 색을 하나 더 들이는 대신 **채움과 비움**으로 가른다 —
/// 헤더의 `예약 슬롯` 버튼이 이미 쓰고 있는 어휘다.
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

  /// [name] 블록의 면 색. 채웠는가 비웠는가가 종류를 말한다.
  Color surfaceOf(WidgetTester tester, String name) {
    final block = find
        .ancestor(
          of: find
              .descendant(
                of: find.byType(ScheduleWeekTimetable),
                matching: find.text(name),
              )
              .first,
          matching: find.byType(Material),
        )
        .first;
    return tester.widget<Material>(block).color!;
  }

  testWidgets('상담 블록은 비우고 1:1 PT 블록은 채운다', (tester) async {
    await openSchedule(tester);

    expect(
      surfaceOf(tester, '박성호'),
      AppColors.primary.withValues(alpha: 0.12),
      reason: '1:1 PT 는 연한 남색으로 채운다',
    );
    expect(
      surfaceOf(tester, '윤가온(신규)'),
      AppColors.card,
      reason: '상담은 흰 바탕에 윤곽선으로 — `예약 슬롯` 과 같은 표현이다',
    );
  });

  testWidgets('색만으로 구분하지 않는다 — 글씨가 종류를 함께 말한다', (tester) async {
    await openSchedule(tester);

    expect(find.text('상담'), findsWidgets);
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

  testWidgets('상담 요청 버튼이 예약 슬롯과 같은 남색을 쓴다', (tester) async {
    await openSchedule(tester);

    // 대기 건이 있어도 테두리까지 빨갛게 물들이지 않는다 — 알리는 일은 배지
    // 하나로 충분하다.
    final Icon glyph = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('consult-inbox-entry')),
        matching: find.byIcon(Icons.mark_email_unread_outlined),
      ),
    );
    expect(glyph.color, AppColors.primary);
  });
}
