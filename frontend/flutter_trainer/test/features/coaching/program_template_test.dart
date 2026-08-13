import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('programTemplates', () {
    test('every template is usable: named, attributed, and non-empty', () {
      expect(programTemplates, isNotEmpty);
      for (final template in programTemplates) {
        expect(template.name, isNotEmpty);
        expect(template.goal, isNotEmpty, reason: '${template.name}에 대상이 없어요');
        expect(
          template.exercises,
          isNotEmpty,
          reason: '${template.name}에 운동이 없어요',
        );
      }
    });

    test('ids are unique so a list key cannot collide', () {
      final ids = programTemplates.map((t) => t.id).toSet();
      expect(ids.length, programTemplates.length);
    });

    test('totalMinutes sums the block', () {
      final template = programTemplates.first;
      expect(
        template.totalMinutes,
        template.exercises.fold<int>(0, (sum, e) => sum + e.minutes),
      );
    });
  });

  group('AI 코칭 templates', () {
    Future<void> openCoaching(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1600, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpTrainerApp(
        tester,
        token: 'demo-trainer-token',
        at: AppRoutes.coaching,
      );
    }

    Future<void> revealTemplate(WidgetTester tester, String name) async {
      await tester.scrollUntilVisible(
        find.text(name),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('coaching-program-page-scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }

    testWidgets('the library lists the built-in templates', (tester) async {
      await openCoaching(tester);

      await revealTemplate(tester, programTemplates.first.name);

      expect(find.text('프로그램 템플릿'), findsOneWidget);
      expect(find.text(programTemplates.first.name), findsOneWidget);
    });

    testWidgets('applying a template ADDS to the AI suggestions rather '
        'than replacing them', (tester) async {
      await openCoaching(tester);

      // A seeded AI suggestion for 김민수 that must survive the apply.
      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);

      final template = programTemplates.first;
      await revealTemplate(tester, template.name);
      await tester.drag(
        find.byKey(const ValueKey<String>('coaching-program-page-scroll')),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(template.name));
      await settle(tester);

      // The template's exercises joined the composed routine…
      expect(find.text(template.exercises.first.name), findsWidgets);
      // …and the AI's own suggestion is still there.
      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
      // Template-added items carry the trainer accent, like any manual
      // addition.
      expect(find.text('트레이너 추가'), findsWidgets);
    });

    testWidgets('중복 전송 이력 대신 회원 요약을 한 번만 보여 준다', (tester) async {
      await openCoaching(tester);
      expect(find.text('회원 요약'), findsOneWidget);
      expect(find.text('전송 이력'), findsNothing);
    });
  });
}
