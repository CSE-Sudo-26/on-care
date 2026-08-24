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

  Widget buildApp(List<AiRoutineItem> aiSuggestions) => MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProgramEditorWorkspace(
          clientGoal: '체중 감량',
          aiSuggestions: aiSuggestions,
          onReview: (draft) => reviewed = draft,
        ),
      ),
    ),
  );

  /// 프로그램 정보 박스는 AI 루틴을 반영하기 전까지 빈 상태로 시작한다
  /// (#1028) — 첫 빌드는 빈 목록으로 연다.
  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildApp(const <AiRoutineItem>[]));
    await tester.pump();
  }

  /// `aiSuggestions` 를 (새 리스트로) 다시 넘겨 [ProgramEditorWorkspace]
  /// 의 `didUpdateWidget` 병합을 유도한다 — 안내 배너의 `편집기에 반영`
  /// 단축 버튼은 이제 없고(#1028 후속), 실제 앱에서는 AI 요청 흐름의
  /// `템플릿에 반영`이 정확히 이 방식으로(넘어온 프롭이 바뀌면) 병합시킨다.
  Future<void> mergeSuggestions(WidgetTester tester) async {
    await tester.pumpWidget(buildApp(List<AiRoutineItem>.of(duplicateSuggestions)));
    await tester.pump();
  }

  testWidgets('AI suggestions are deduplicated within the same batch', (
    tester,
  ) async {
    await pumpEditor(tester);

    await mergeSuggestions(tester);

    expect(find.text('스쿼트'), findsOneWidget);
  });

  testWidgets('editing a draft metric keeps keyboard focus across rebuilds', (
    tester,
  ) async {
    await pumpEditor(tester);
    await mergeSuggestions(tester);

    final editMenu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const ValueKey<String>('exercise-edit-exercise-2')),
    );
    editMenu.onSelected?.call('edit');
    await tester.pump();

    final field = find.byKey(const ValueKey<String>('exercise-2-sets-field'));
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
    await mergeSuggestions(tester);

    expect(reviewed, isNull, reason: '검토 버튼을 누르기 전에는 넘어가는 것이 없다');

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('program-editor-review')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('program-editor-review')));
    await tester.pump();

    expect(reviewed, isNotNull);
    expect(reviewed!.sessions.single.exercises.single.name, '스쿼트');
  });

  group('운동 지표 요약 (programExerciseMetrics)', () {
    // [ProgramExerciseDraft] 는 유형에 상관없이 세트·중량 기본값을 늘 들고
    // 있다 — 근력이 아닌데도 그 기본값이 그대로 요약에 뜨면 안 된다.
    const nonStrength = ProgramExerciseDraft(
      id: 'e1',
      name: '가벼운 걷기',
      type: '유산소',
      minutes: 20,
    );

    test('근력이 아니면 세트·중량이 값이 있어도 요약에 뜨지 않는다', () {
      final metrics = programExerciseMetrics(nonStrength, korean: true);
      expect(metrics.any((m) => m.contains('세트') || m.contains('kg')), isFalse);
      expect(metrics, contains('20분'));
    });

    test('스트레칭·기타도 마찬가지다', () {
      for (final type in <String>['스트레칭', '기타']) {
        final metrics = programExerciseMetrics(
          nonStrength.copyWith(type: type),
          korean: true,
        );
        expect(
          metrics.any((m) => m.contains('세트') || m.contains('kg')),
          isFalse,
          reason: '$type 유형에 세트·중량이 남아 있다',
        );
      }
    });

    test('근력이면 세트와 중량을 보여준다', () {
      final metrics = programExerciseMetrics(
        nonStrength.copyWith(type: '근력', sets: 4, weight: 60),
        korean: true,
      );
      expect(metrics, contains('4세트'));
      expect(metrics, contains('60kg'));
    });
  });

  group('세션 초기화', () {
    // 더보기(⋯) 메뉴에 묻지 않고, 그 왼쪽에 따로 있는 아이콘 버튼이다.
    final resetIcon = find.byKey(const ValueKey<String>('session-reset-session-1'));

    testWidgets('운동이 없으면 초기화 아이콘이 비활성이다', (tester) async {
      await pumpEditor(tester);

      final button = tester.widget<IconButton>(resetIcon);
      expect(button.onPressed, isNull);
    });

    testWidgets('확인하면 그 세션의 운동만 모두 지워지고 세션은 남는다', (tester) async {
      await pumpEditor(tester);
      await mergeSuggestions(tester);
      expect(find.text('스쿼트'), findsOneWidget);

      await tester.tap(resetIcon);
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('session-reset-confirm')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('session-reset-submit')));
      await tester.pumpAndSettle();

      expect(find.text('스쿼트'), findsNothing);
      expect(find.byKey(const ValueKey<String>('session-actions-session-1')), findsOneWidget);
    });

    testWidgets('취소하면 운동이 그대로 남는다', (tester) async {
      await pumpEditor(tester);
      await mergeSuggestions(tester);

      await tester.tap(resetIcon);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('session-reset-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('스쿼트'), findsOneWidget);
    });
  });

  group('운동 추가', () {
    Future<void> openAddForm(WidgetTester tester) async {
      final addButton = find.text('운동 추가');
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pump();
    }

    Future<void> typeName(WidgetTester tester, String name) async {
      await tester.enterText(
        find.byKey(const ValueKey<String>('custom-exercise-name')),
        name,
      );
      await tester.pump();
    }

    Future<void> confirmAdd(WidgetTester tester) async {
      final confirm = find.text('추가');
      await tester.ensureVisible(confirm.last);
      await tester.tap(confirm.last);
      await tester.pump();
    }

    testWidgets('버튼을 누르면 새 운동이 실제로 목록에 추가되고 바로 렌더된다', (tester) async {
      await pumpEditor(tester);

      await openAddForm(tester);
      await typeName(tester, '런지');
      await confirmAdd(tester);

      expect(find.text('런지'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('program-editor-review')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('program-editor-review')),
      );
      await tester.pump();

      // 데이터 모델은 AI 제안과 같은 ProgramExerciseDraft 다 — 세트·중량
      // 기본값이 그대로 채워져 있다.
      final added = reviewed!.sessions.single.exercises.single;
      expect(added.name, '런지');
      expect(added.sets, 3);
      expect(added.weight, 20);
      expect(added.source, 'trainer');
      expect(reviewed!.supportsAssignment, isTrue);
    });

    testWidgets('근력이면 세트·중량을 바로 정해서 추가할 수 있다 (기본 유형)', (tester) async {
      await pumpEditor(tester);

      await openAddForm(tester);
      await typeName(tester, '레그컬');
      // 기본 유형이 근력이라 세트·중량 칸이 곧장 보인다 — 시간 칸은 없다.
      expect(
        find.byKey(const ValueKey<String>('custom-exercise-duration-field')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('custom-exercise-sets-field')),
        '5',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('custom-exercise-weight-field')),
        '62.5',
      );
      await tester.pump();
      await confirmAdd(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('program-editor-review')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('program-editor-review')),
      );
      await tester.pump();

      final added = reviewed!.sessions.single.exercises.single;
      expect(added.name, '레그컬');
      expect(added.sets, 5);
      expect(added.weight, 62.5);

      // 다음 추가는 방금 값이 아니라 기본값으로 다시 시작한다.
      await openAddForm(tester);
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey<String>('custom-exercise-sets-field'),
              ),
            )
            .controller!
            .text,
        '3',
      );
    });

    testWidgets('근력이 아니면 세트·중량 대신 시간을 정해서 추가한다', (tester) async {
      await pumpEditor(tester);

      await openAddForm(tester);
      await typeName(tester, '조깅');
      await tester.tap(
        find.byKey(const ValueKey<String>('custom-exercise-category-유산소')),
      );
      await tester.pump();
      // 유형을 바꾸면 세트·중량 칸은 사라지고 시간 칸으로 바뀐다.
      expect(
        find.byKey(const ValueKey<String>('custom-exercise-sets-field')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('custom-exercise-duration-field')),
        '90',
      );
      await tester.pump();
      await confirmAdd(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('program-editor-review')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('program-editor-review')),
      );
      await tester.pump();

      final added = reviewed!.sessions.single.exercises.single;
      expect(added.name, '조깅');
      expect(added.minutes, 90);
      // 근력이 아니므로 세트·중량은 기본값 그대로다.
      expect(added.sets, 3);
      expect(added.weight, 20);
    });

    testWidgets('−/+ 버튼은 값을 한 칸씩 옮긴다', (tester) async {
      await pumpEditor(tester);
      await openAddForm(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('custom-exercise-sets-plus')),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey<String>('custom-exercise-sets-field'),
              ),
            )
            .controller!
            .text,
        '4',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('custom-exercise-sets-minus')),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey<String>('custom-exercise-sets-field'),
              ),
            )
            .controller!
            .text,
        '3',
      );
    });

    testWidgets('운동 수정 모드도 같은 스테퍼로 값을 고친다', (tester) async {
      await pumpEditor(tester);
      await mergeSuggestions(tester);

      final editMenu = tester.widget<PopupMenuButton<String>>(
        find.byKey(const ValueKey<String>('exercise-edit-exercise-2')),
      );
      editMenu.onSelected?.call('edit');
      await tester.pump();

      // 병합된 스쿼트는 근력 제안이라 세트 칸으로 열린다 — 유형을 유산소로
      // 바꾸면 그 자리가 시간 칸이 된다.
      await tester.tap(
        find.byKey(const ValueKey<String>('exercise-2-type-유산소')),
      );
      await tester.pump();

      final durationField = find.byKey(
        const ValueKey<String>('exercise-2-duration-field'),
      );
      // AI 제안이 들고 온 20분이 그대로 열린다.
      expect(tester.widget<TextField>(durationField).controller!.text, '20');

      await tester.enterText(durationField, '80');
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('program-editor-review')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('program-editor-review')),
      );
      await tester.pump();

      final squat = reviewed!.sessions.single.exercises.firstWhere(
        (exercise) => exercise.name == '스쿼트',
      );
      expect(squat.minutes, 80);
    });

    testWidgets('이름이 비면 추가되지 않는다', (tester) async {
      await pumpEditor(tester);

      await openAddForm(tester);
      await confirmAdd(tester);

      expect(
        find.byKey(const ValueKey<String>('custom-exercise-name')),
        findsOneWidget,
        reason: '빈 이름은 추가로 이어지지 않고 입력 폼이 그대로 남는다',
      );
    });

    testWidgets('새 운동을 추가해도 기존 운동을 지우거나 덮어쓰지 않는다', (tester) async {
      await pumpEditor(tester);
      await mergeSuggestions(tester);
      expect(find.text('스쿼트'), findsOneWidget);

      await openAddForm(tester);
      await typeName(tester, '데드리프트');
      await confirmAdd(tester);

      expect(find.text('스쿼트'), findsOneWidget);
      expect(find.text('데드리프트'), findsOneWidget);
    });

    testWidgets('추가한 운동도 기존 수정·삭제 메뉴가 그대로 동작한다', (tester) async {
      await pumpEditor(tester);

      await openAddForm(tester);
      await typeName(tester, '버피');
      await confirmAdd(tester);

      // 새 인스턴스의 `_nextId` 는 2 부터 시작하니, 이 편집기에서 처음 손으로
      // 추가한 운동의 id 는 항상 `exercise-2` 다.
      final editMenu = tester.widget<PopupMenuButton<String>>(
        find.byKey(const ValueKey<String>('exercise-edit-exercise-2')),
      );
      editMenu.onSelected?.call('delete');
      await tester.pump();

      expect(find.text('버피'), findsNothing);
    });
  });
}
