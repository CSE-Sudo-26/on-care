import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/storage/seed_data.dart';
import 'package:oncare_trainer/features/ai_routine/data/repositories/ai_routine_repository.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('AiRoutineRepository.watchRoutine', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedIfEmpty(db);
    });
    tearDown(() => db.close());

    test('returns the 3 seeded suggestions in order per client', () async {
      final repo = AiRoutineRepository(db);
      final minsu = await repo.watchRoutine('seed-client-1').first;
      expect(minsu.length, 3);
      expect(minsu.first.name, '저강도 유산소 (걷기)');
      expect(minsu.first.minutes, 30);
      expect(minsu.first.type, '유산소');

      final jisu = await repo.watchRoutine('seed-client-2').first;
      expect(jisu.first.name, '인터벌 런닝');
    });
  });

  group('AiRoutinePage', () {
    Future<void> openTab(WidgetTester tester) async {
      await pumpTrainerApp(tester, token: 'demo-trainer-token');
      await tester.tap(find.text('AI루틴')); // bottom-nav label
      await settle(tester);
    }

    testWidgets('defaults to the first client with verdict and routine', (
      tester,
    ) async {
      await openTab(tester);

      expect(find.text('AI 루틴 생성'), findsOneWidget);
      // 김민수 (2100mg, over) → cardio-boost verdict.
      expect(find.text('✦ AI 판단: 나트륨 초과 → 유산소 강화 권장'), findsOneWidget);
      expect(find.text('저강도 유산소 (걷기)'), findsOneWidget);
      expect(find.text('💡 혈압 안정에 효과적'), findsOneWidget);
    });

    testWidgets('switching client updates the verdict and suggestions', (
      tester,
    ) async {
      await openTab(tester);

      await tester.tap(find.text('이지수'));
      await settle(tester);

      // 이지수 (1800mg, under) → balanced verdict + her routine.
      expect(find.text('✦ AI 판단: 식단 균형 양호 → 근력 중심 루틴 유지'), findsOneWidget);
      expect(find.text('인터벌 런닝'), findsOneWidget);
      expect(find.text('저강도 유산소 (걷기)'), findsNothing);
    });

    testWidgets('adding and deleting a custom exercise', (tester) async {
      await openTab(tester);

      await tester.scrollUntilVisible(find.text('＋ 운동 직접 추가'), 150);
      await tester.ensureVisible(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.tap(find.text('＋ 운동 직접 추가'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '레그프레스 5세트');
      await tester.ensureVisible(find.text('추가하기'));
      await tester.pump();
      await tester.tap(find.text('추가하기'));
      await tester.pump();
      // The new custom card may land below the fold.
      await tester.scrollUntilVisible(find.text('레그프레스 5세트'), 150);

      expect(find.text('레그프레스 5세트'), findsOneWidget);
      expect(find.text('💡 트레이너 추가'), findsOneWidget);

      // Delete it again.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text('레그프레스 5세트'), findsNothing);
    });

    testWidgets('send reset also closes the add-exercise form', (tester) async {
      await openTab(tester);

      // Open the add form, then send with it still open.
      await tester.scrollUntilVisible(find.text('＋ 운동 직접 추가'), 150);
      await tester.ensureVisible(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      await tester.tap(find.text('＋ 운동 직접 추가'));
      await tester.pump();
      expect(find.text('운동 추가'), findsOneWidget);

      // The open form's TextField adds an inner Scrollable — target the
      // page ListView explicitly.
      await tester.scrollUntilVisible(
        find.textContaining('님에게 전송'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 4)); // reset window
      // The add form must be closed again after the reset.
      expect(find.text('운동 추가'), findsNothing);
      await tester.scrollUntilVisible(find.text('＋ 운동 직접 추가'), 150);
      expect(find.text('＋ 운동 직접 추가'), findsOneWidget);
    });

    testWidgets('send shows confirmation then resets edits', (tester) async {
      await openTab(tester);

      await tester.scrollUntilVisible(find.textContaining('님에게 전송'), 150);
      await tester.ensureVisible(find.textContaining('님에게 전송'));
      await tester.pump();
      await tester.tap(find.textContaining('님에게 전송'));
      await tester.pump();

      expect(find.text('✓ 김민수님에게 전송 완료!'), findsOneWidget);
      expect(find.text('고객 앱에 알림이 전송됐어요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4)); // reset window
      expect(find.textContaining('검토 완료'), findsOneWidget);
    });
  });
}
