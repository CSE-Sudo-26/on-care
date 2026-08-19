import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_program_template_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/program_template.dart';
import 'package:oncare_trainer/features/coaching/presentation/widgets/program_template_dialog.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 저장된 템플릿이 없는 트레이너에게 보이는 시작 구성은 **저장된 행이 아니다**.
/// 고치면 그 트레이너의 첫 템플릿으로 새로 저장된다 — 그래야 "지웠는데 되살아
/// 난다" 가 생기지 않는다. 그 규약을 화면이 지키는지 본다. (#920)
class _FakeTemplateRepository implements TrainerProgramTemplateRepository {
  _FakeTemplateRepository();

  List<ProgramTemplate> templates = const <ProgramTemplate>[];
  final List<({String name, String goal, List<TemplateExercise> exercises})>
  created = <({String name, String goal, List<TemplateExercise> exercises})>[];
  final List<({String id, String name})> updated =
      <({String id, String name})>[];
  final List<String> deleted = <String>[];
  AppError? failure;

  @override
  bool get supportsEditing => true;

  @override
  Future<List<ProgramTemplate>> list() async => templates;

  @override
  Future<ProgramTemplate> create({
    required String name,
    required String goal,
    required List<TemplateExercise> exercises,
  }) async {
    if (failure case final AppError error) throw error;
    created.add((name: name, goal: goal, exercises: exercises));
    return ProgramTemplate(
      id: 'tpl-new',
      name: name,
      goal: goal,
      exercises: exercises,
    );
  }

  @override
  Future<ProgramTemplate> update(
    String id, {
    required String name,
    required String goal,
    required List<TemplateExercise> exercises,
  }) async {
    if (failure case final AppError error) throw error;
    updated.add((id: id, name: name));
    return ProgramTemplate(
      id: id,
      name: name,
      goal: goal,
      exercises: exercises,
    );
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

const ProgramTemplate _starter = ProgramTemplate(
  id: 'starter:0',
  name: '혈압 관리 기본',
  goal: '혈압 관리 · 초급',
  exercises: <TemplateExercise>[
    TemplateExercise(name: '저강도 걷기', minutes: 20, type: '유산소'),
  ],
);

const ProgramTemplate _mine = ProgramTemplate(
  id: 'tpl-1',
  name: '내 블록',
  goal: '체중 감량',
  exercises: <TemplateExercise>[
    TemplateExercise(name: '전신 서킷', minutes: 20, type: '근력'),
  ],
);

Future<void> _pumpDialog(
  WidgetTester tester,
  _FakeTemplateRepository repository, {
  ProgramTemplate? template,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        trainerProgramTemplateRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ProgramTemplateDialog(template: template)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('엔티티', () {
    test('시작 구성은 id 로 구분된다', () {
      expect(_starter.isStarter, isTrue);
      expect(_mine.isStarter, isFalse);
    });

    test('서버 응답 한 건을 읽는다', () {
      final template = ProgramTemplate.fromJson(<String, Object?>{
        'id': 'tpl-1',
        'name': '내 블록',
        'goal': '체중 감량',
        'exercises': <Object?>[
          <String, Object?>{'name': '걷기', 'minutes': 30, 'type': '걷기'},
        ],
        'updated_at': '2026-08-19T09:00:00Z',
      });

      expect(template.exercises.single.minutes, 30);
      expect(template.totalMinutes, 30);
    });
  });

  group('다이얼로그', () {
    testWidgets('시작 구성을 고치면 새 템플릿으로 저장된다', (tester) async {
      final repository = _FakeTemplateRepository();
      await _pumpDialog(tester, repository, template: _starter);

      expect(find.text('기본 구성이에요. 고치면 내 템플릿으로 저장돼요'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('template-name')),
        '내가 고친 혈압 블록',
      );
      await tester.tap(find.byKey(const ValueKey<String>('template-save')));
      await tester.pumpAndSettle();

      // 고치기가 아니라 만들기다 — 시작 구성에는 고칠 행이 없다.
      expect(repository.updated, isEmpty);
      expect(repository.created.single.name, '내가 고친 혈압 블록');
      expect(repository.created.single.exercises.single.name, '저강도 걷기');
    });

    testWidgets('내 템플릿을 고치면 그 행을 고친다', (tester) async {
      final repository = _FakeTemplateRepository();
      await _pumpDialog(tester, repository, template: _mine);

      await tester.enterText(
        find.byKey(const ValueKey<String>('template-name')),
        '고친 이름',
      );
      await tester.tap(find.byKey(const ValueKey<String>('template-save')));
      await tester.pumpAndSettle();

      expect(repository.created, isEmpty);
      expect(repository.updated.single, (id: 'tpl-1', name: '고친 이름'));
    });

    testWidgets('이름이 비면 저장하지 않고 이유를 말한다', (tester) async {
      final repository = _FakeTemplateRepository();
      await _pumpDialog(tester, repository);

      await tester.tap(find.byKey(const ValueKey<String>('template-save')));
      await tester.pumpAndSettle();

      expect(find.text('템플릿 이름을 입력해 주세요'), findsOneWidget);
      expect(repository.created, isEmpty);
    });

    testWidgets('운동이 하나도 없으면 저장하지 않는다', (tester) async {
      final repository = _FakeTemplateRepository();
      await _pumpDialog(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey<String>('template-name')),
        '빈 블록',
      );
      await tester.tap(find.byKey(const ValueKey<String>('template-save')));
      await tester.pumpAndSettle();

      // 운동 줄은 있지만 이름이 비어 있다 — 끼워 넣어도 아무 일이 없는 블록이다.
      expect(find.text('운동을 하나 이상 넣어 주세요'), findsOneWidget);
      expect(repository.created, isEmpty);
    });

    testWidgets('서버가 거절하면 사유가 남고 다이얼로그는 닫히지 않는다', (tester) async {
      final repository = _FakeTemplateRepository()
        ..failure = const ValidationError(message: '템플릿은 최대 30개까지 저장할 수 있습니다.');
      await _pumpDialog(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey<String>('template-name')),
        '하나 더',
      );
      await tester.enterText(find.byType(TextField).at(2), '걷기');
      await tester.tap(find.byKey(const ValueKey<String>('template-save')));
      await tester.pumpAndSettle();

      expect(find.text('템플릿은 최대 30개까지 저장할 수 있습니다.'), findsOneWidget);
      expect(find.byType(ProgramTemplateDialog), findsOneWidget);
    });
  });

  group('데모', () {
    test('읽기 전용이다 — 저장할 백엔드가 없다', () async {
      const demo = MockTrainerProgramTemplateRepository();

      expect(demo.supportsEditing, isFalse);
      expect(await demo.list(), MockTrainerProgramTemplateRepository.starters);
      expect(
        () => demo.create(
          name: 'x',
          goal: '',
          exercises: const <TemplateExercise>[],
        ),
        throwsA(isA<ValidationError>()),
      );
    });
  });
}
