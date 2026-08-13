import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/features/coaching/domain/entities/ai_routine_item.dart';
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

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgramEditorWorkspace(
              clientGoal: '체중 감량',
              aiSuggestions: duplicateSuggestions,
              registerOffset: 0,
              onRegisterOffsetChanged: (_) {},
              onAssignFlat: (_) async {},
              onRegisterFlat: (_) async {},
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
}
