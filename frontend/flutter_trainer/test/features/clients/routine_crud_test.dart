/// 배정한 루틴 수정·삭제. (#504)
///
/// 전에는 배정만 되고 고칠 수 없어, 잘못 넣으면 새 루틴을 하나 더 배정했고
/// 회원 앱에는 둘 다 그대로 보였다.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';

import '../../helpers/pump_app.dart';

const AssignedRoutine _routine = AssignedRoutine(
  id: 'rt-1',
  name: '하체 근력 A',
  minutes: 40,
  type: '근력',
  reason: '무릎 부담 낮춰 시작',
  source: 'trainer',
);

/// 수정·삭제 호출을 기록하는 페이크.
class _FakeRoutineRepository implements TrainerRoutineRepository {
  _FakeRoutineRepository({this.fails = false});

  final bool fails;
  final List<
    ({String memberId, String routineId, String? name, int? minutes, String? reason})
  >
  updates = [];
  final List<String> deletes = <String>[];

  @override
  Future<void> assignRoutine(String memberId, AssignedRoutine routine) async {}

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) =>
      Stream<List<AssignedRoutine>>.value(const <AssignedRoutine>[_routine]);

  @override
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  }) async {
    if (fails) throw StateError('routine not found: $routineId');
    updates.add((
      memberId: memberId,
      routineId: routineId,
      name: name,
      minutes: minutes,
      reason: reason,
    ));
  }

  @override
  Future<void> deleteRoutine(String memberId, String routineId) async {
    if (fails) throw StateError('routine not found: $routineId');
    deletes.add(routineId);
  }
}

Future<_FakeRoutineRepository> _pumpWorkoutTab(
  WidgetTester tester, {
  bool fails = false,
}) async {
  final repo = _FakeRoutineRepository(fails: fails);
  await pumpTrainerApp(
    tester,
    token: 'demo-token',
    at: AppRoutes.clientDetail('seed-client-1', section: 'workout'),
    extraOverrides: <Override>[
      trainerRoutineRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return repo;
}

void main() {
  testWidgets('배정된 루틴에 수정·삭제 버튼이 있다', (tester) async {
    await _pumpWorkoutTab(tester);

    expect(find.text('하체 근력 A'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('routine-edit-rt-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('routine-delete-rt-1')),
      findsOneWidget,
    );
  });

  testWidgets('수정하면 바꾼 값만 저장소로 넘어간다', (tester) async {
    final repo = await _pumpWorkoutTab(tester);

    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-rt-1')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('routine-edit-minutes')),
      '55',
    );
    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-save')));
    await settle(tester);

    expect(repo.updates, hasLength(1));
    expect(repo.updates.single.routineId, 'rt-1');
    expect(repo.updates.single.minutes, 55);
    // 손대지 않은 이름은 원래 값 그대로 넘어간다.
    expect(repo.updates.single.name, '하체 근력 A');
  });

  testWidgets('범위를 벗어난 시간은 저장하지 않고 그 자리에서 알린다', (tester) async {
    final repo = await _pumpWorkoutTab(tester);

    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-rt-1')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('routine-edit-minutes')),
      '9999',
    );
    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-save')));
    await settle(tester);

    // 422 를 받아 오는 것보다 그 자리에서 알려 주는 편이 낫다.
    expect(find.textContaining('0~600분'), findsOneWidget);
    expect(repo.updates, isEmpty);
  });

  testWidgets('삭제는 확인을 받은 뒤에만 나간다', (tester) async {
    final repo = await _pumpWorkoutTab(tester);

    await tester.tap(find.byKey(const ValueKey<String>('routine-delete-rt-1')));
    await settle(tester);
    expect(find.text('루틴을 삭제할까요?'), findsOneWidget);

    // 취소하면 아무 일도 일어나지 않는다.
    await tester.tap(find.text('취소'));
    await settle(tester);
    expect(repo.deletes, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('routine-delete-rt-1')));
    await settle(tester);
    await tester.tap(find.text('삭제'));
    await settle(tester);
    expect(repo.deletes, <String>['rt-1']);
  });

  testWidgets('실패하면 사유를 알리고 목록은 그대로 둔다', (tester) async {
    final repo = await _pumpWorkoutTab(tester, fails: true);

    await tester.tap(find.byKey(const ValueKey<String>('routine-delete-rt-1')));
    await settle(tester);
    await tester.tap(find.text('삭제'));
    await settle(tester);

    expect(find.textContaining('삭제하지 못했어요'), findsOneWidget);
    expect(repo.deletes, isEmpty);
    expect(find.text('하체 근력 A'), findsOneWidget);
  });
}
