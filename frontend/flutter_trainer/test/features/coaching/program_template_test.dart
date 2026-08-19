import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_program_template_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';

import '../../helpers/pump_app.dart';

/// 데모가 보여 주는 시작 구성. 저장할 백엔드가 없는 빌드라 읽기 전용이고,
/// 실 API 가 '저장한 것이 없는 트레이너' 에게 주는 것과 같은 셋이다. (#920)
const List<ProgramTemplate> starterTemplates =
    MockTrainerProgramTemplateRepository.starters;

void main() {
  group('시작 구성', () {
    test('every template is usable: named, attributed, and non-empty', () {
      expect(starterTemplates, isNotEmpty);
      for (final template in starterTemplates) {
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
      final ids = starterTemplates.map((ProgramTemplate t) => t.id).toSet();
      expect(ids.length, starterTemplates.length);
    });

    test('totalMinutes sums the block', () {
      final template = starterTemplates.first;
      expect(
        template.totalMinutes,
        template.exercises.fold<int>(
          0,
          (int sum, TemplateExercise e) => sum + e.minutes,
        ),
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

    testWidgets('the library lists the starter templates', (tester) async {
      await openCoaching(tester);

      await revealTemplate(tester, starterTemplates.first.name);

      expect(find.text('프로그램 템플릿'), findsOneWidget);
      expect(find.text(starterTemplates.first.name), findsOneWidget);
    });

    testWidgets('applying a template ADDS to the AI suggestions rather '
        'than replacing them', (tester) async {
      await openCoaching(tester);

      // A seeded AI suggestion for 김민수 that must survive the apply.
      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);

      final template = starterTemplates.first;
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

    testWidgets('회원 요약과 전송 이력을 각각 한 번만 보여 준다', (tester) async {
      await openCoaching(tester);
      expect(find.text('고객 요약'), findsOneWidget);
      expect(find.text('전송 이력'), findsOneWidget);
    });
  });
}
