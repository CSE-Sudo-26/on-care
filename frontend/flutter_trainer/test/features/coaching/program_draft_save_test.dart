// 프로그램 탭의 저장·불러오기. (#708)
//
// 저장은 서버가 받은 뒤에만 성공으로 보이고, 실패해도 작성 중인 내용은 남는다.
// 저장한 프로그램을 다시 열면 편집기가 저장 당시 구성으로 돌아온다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_program_draft_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/trainer_program_draft.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

import '../../helpers/pump_app.dart';

/// In-memory stand-in for the draft store.
class _FakeDraftRepository implements TrainerProgramDraftRepository {
  _FakeDraftRepository({this.failWrites = false});

  final List<Map<String, Object?>> stored = <Map<String, Object?>>[];
  bool failWrites;
  int createCalls = 0;

  /// Blocks writes until completed, so a test can act mid-save.
  Completer<void>? gate;

  @override
  Future<List<TrainerProgramDraftSummary>> list() async => stored
      .map(
        (draft) => TrainerProgramDraftSummary(
          id: draft['id']! as String,
          name: draft['name']! as String,
          goal: draft['goal'] as String? ?? '',
          period: draft['period'] as String? ?? '',
          exerciseCount:
              ((draft['exercises'] as List<Object?>?) ?? const <Object?>[])
                  .length,
          updatedAt: DateTime.parse(draft['updated_at']! as String),
        ),
      )
      .toList(growable: false);

  @override
  Future<TrainerProgramDraft> read(String id) async =>
      TrainerProgramDraft.fromJson(
        stored.firstWhere((draft) => draft['id'] == id),
      );

  @override
  Future<TrainerProgramDraft> create(Map<String, Object?> payload) async {
    createCalls++;
    if (gate != null) await gate!.future;
    if (failWrites) throw const NetworkError();
    final draft = <String, Object?>{
      ...payload,
      'id': 'pgm-${stored.length + 1}',
      'updated_at': DateTime.utc(2026, 8, 14, stored.length).toIso8601String(),
    };
    stored.add(draft);
    return TrainerProgramDraft.fromJson(draft);
  }

  @override
  Future<TrainerProgramDraft> update(
    String id,
    Map<String, Object?> payload,
  ) async {
    if (failWrites) throw const NetworkError();
    final index = stored.indexWhere((draft) => draft['id'] == id);
    stored[index] = <String, Object?>{
      ...stored[index],
      ...payload,
      'id': id,
      'updated_at': DateTime.utc(2026, 8, 15).toIso8601String(),
    };
    return TrainerProgramDraft.fromJson(stored[index]);
  }

  @override
  Future<void> delete(String id) async {
    stored.removeWhere((draft) => draft['id'] == id);
  }
}

Finder get _saveButton =>
    find.byKey(const ValueKey<String>('program-editor-save'));

Future<void> _openCoaching(
  WidgetTester tester,
  TrainerProgramDraftRepository repository,
) async {
  await pumpTrainerApp(
    tester,
    token: 'demo-trainer-token',
    at: AppRoutes.coaching,
    extraOverrides: <Override>[
      trainerProgramDraftRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    _saveButton,
    -150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(_saveButton);
  await tester.pump();
  await tester.tap(_saveButton);
}

void main() {
  testWidgets('저장하면 초안이 남고 저장한 프로그램 카드가 나타난다', (tester) async {
    final repository = _FakeDraftRepository();
    await _openCoaching(tester, repository);

    // 아직 저장한 적이 없으면 카드 자체가 없다 — 기존 화면 그대로.
    expect(
      find.byKey(const ValueKey<String>('saved-programs-card')),
      findsNothing,
    );

    await _tapSave(tester);
    await settle(tester);

    expect(repository.stored, hasLength(1));
    expect(find.text('프로그램을 저장했어요'), findsOneWidget);
    // 페이지가 ListView 라 카드는 화면에 들어와야 만들어진다.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('saved-programs-card')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey<String>('saved-programs-card')),
      findsOneWidget,
    );
  });

  testWidgets('저장 중 다시 눌러도 초안이 하나만 만들어진다', (tester) async {
    final repository = _FakeDraftRepository()..gate = Completer<void>();
    await _openCoaching(tester, repository);

    await _tapSave(tester);
    await tester.pump();
    // 저장이 끝나기 전의 두 번째·세 번째 클릭.
    await tester.tap(_saveButton, warnIfMissed: false);
    await tester.tap(_saveButton, warnIfMissed: false);
    await tester.pump();
    expect(repository.createCalls, 1);

    repository.gate!.complete();
    await settle(tester);
    expect(repository.stored, hasLength(1));
  });

  testWidgets('저장에 실패해도 작성 중인 프로그램이 남고 다시 시도할 수 있다', (tester) async {
    final repository = _FakeDraftRepository(failWrites: true);
    await _openCoaching(tester, repository);

    // 편집기가 들고 있는 프로그램 이름(기본값)이 저장 실패 뒤에도 남아야 한다.
    final title = find.text('혈압 관리 · 체중 감량 프로그램');
    expect(title, findsWidgets);

    await _tapSave(tester);
    await settle(tester);

    expect(find.textContaining('프로그램을 저장하지 못했어요'), findsOneWidget);
    expect(repository.stored, isEmpty);
    expect(title, findsWidgets);
    // 버튼이 잠긴 채로 남지 않는다.
    expect(tester.widget<ActionButton>(_saveButton).onPressed, isNotNull);

    repository.failWrites = false;
    await _tapSave(tester);
    await settle(tester);
    expect(repository.stored, hasLength(1));
  });

  testWidgets('저장한 프로그램을 불러오면 편집기가 그 구성으로 돌아온다', (tester) async {
    final repository = _FakeDraftRepository();
    repository.stored.add(<String, Object?>{
      'id': 'pgm-saved',
      'name': '저장해 둔 하체 프로그램',
      'goal': '근력 향상',
      'period': '6주',
      'memo': '',
      'session_name': '세션 A',
      'exercises': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'exercise-2',
          'name': '레그프레스',
          'sets': '4',
          'reps': '12회',
          'weight': '60kg',
          'duration': '',
          'distance': '',
          'rest': '90',
          'rpe': '8',
          'memo': '',
          'type': '근력',
          'source': 'ai',
        },
      ],
      'updated_at': '2026-08-14T09:00:00Z',
    });
    await _openCoaching(tester, repository);

    final card = find.byKey(const ValueKey<String>('saved-program-pgm-saved'));
    await tester.scrollUntilVisible(
      card,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible 은 위젯이 만들어지면 멈춘다 — 화면 안으로 들어오지
    // 않으면 탭이 엉뚱한 곳을 친다.
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card);
    await settle(tester);

    // 편집기 제목이 저장한 이름으로 바뀌고 운동 구성이 살아난다.
    // 편집기는 목록 위쪽이라 다시 위로 끌어 올려야 트리에 만들어진다.
    await tester.scrollUntilVisible(
      find.text('레그프레스'),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('저장해 둔 하체 프로그램'), findsWidgets);
    expect(find.text('레그프레스'), findsWidgets);

    // 불러온 초안은 기존 배정 흐름에 그대로 쓸 수 있다 — 저장·복원이 배정
    // 가능 여부(supportsFlatRoutine)를 깨뜨리지 않는다.
    final assignButton = find.widgetWithText(ActionButton, '고객에게 배정');
    expect(tester.widget<ActionButton>(assignButton).onPressed, isNotNull);

    // 이제 저장은 기존 초안을 덮어쓴다 — 사본이 늘지 않는다.
    await _tapSave(tester);
    await settle(tester);
    expect(repository.stored, hasLength(1));
    expect(repository.createCalls, 0);
  });
}
