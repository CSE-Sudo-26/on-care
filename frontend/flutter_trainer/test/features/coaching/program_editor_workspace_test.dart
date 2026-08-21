import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
import 'package:oncare_trainer/features/coaching/domain/program_editor_state.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_editor_workspace.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

void main() {
  const duplicateSuggestions = <AiRoutineItem>[
    AiRoutineItem(
      id: 'one',
      name: '스쿼트',
      minutes: 20,
      type: '근력',
      reason: '하체 강화',
    ),
    AiRoutineItem(
      id: 'two',
      name: '스쿼트',
      minutes: 30,
      type: '근력',
      reason: '중복 제안',
    ),
  ];

  ProgramEditorState? reviewed;

  setUp(() => reviewed = null);

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgramEditorWorkspace(
              clientGoal: '체중 감량',
              aiSuggestions: duplicateSuggestions,
              onReview: (draft) => reviewed = draft,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('AI suggestions are deduplicated within the same batch', (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.tap(find.text('편집기에 반영'));
    await tester.pump();

    expect(find.text('스쿼트'), findsOneWidget);
  });

  testWidgets('editing a draft metric keeps keyboard focus across rebuilds', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.tap(find.text('편집기에 반영'));
    await tester.pump();

    final editMenu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const ValueKey<String>('exercise-edit-exercise-2')),
    );
    editMenu.onSelected?.call('edit');
    await tester.pump();

    final field = find.byKey(const ValueKey<String>('exercise-2-sets'));
    await tester.tap(field);
    await tester.enterText(field, '4');
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('편집기에는 전송 버튼이 없다 — 배정·PT 등록은 최종 검토에만 있다 (#1028)', (
    tester,
  ) async {
    await pumpEditor(tester);

    // 예전 버튼 키가 이 위젯 안에 남아 있으면, 편집 중 아무 때나 회원에게
    // 보낼 수 있는 자리가 다시 생긴 것이다.
    expect(
      find.byKey(const ValueKey<String>('program-editor-assign')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('program-editor-register')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('program-editor-review')),
      findsOneWidget,
    );
  });

  testWidgets('최종 검토는 지금 구성의 스냅샷을 그대로 넘긴다 (#1028)', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('편집기에 반영'));
    await tester.pump();

    expect(reviewed, isNull, reason: '검토 버튼을 누르기 전에는 넘어가는 것이 없다');

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('program-editor-review')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('program-editor-review')));
    await tester.pump();

    expect(reviewed, isNotNull);
    expect(reviewed!.sessions.single.exercises.single.name, '스쿼트');
  });
}
