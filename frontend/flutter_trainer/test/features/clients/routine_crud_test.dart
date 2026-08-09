/// 배정한 루틴 수정·삭제. (#504)
///
/// 전에는 배정만 되고 고칠 수 없어, 잘못 넣으면 새 루틴을 하나 더 배정했고
/// 회원 앱에는 둘 다 그대로 보였다.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
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

/// 실패 갈래. 리포지토리가 404 를 [StateError] 로, 나머지를 [AppError] 로
/// 바꾸므로(`DioTrainerRoutineRepository._routineCall`) 화면 처리도 갈린다.
enum _Fail {
  none,

  /// 404 — 서버에 이미 없다. 화면이 목록을 다시 읽어야 한다.
  notFound,

  /// 타임아웃·5xx. 루틴은 그대로 있으므로 목록을 다시 읽을 이유가 없다.
  network,
}

/// 수정·삭제 호출을 기록하는 페이크.
class _FakeRoutineRepository implements TrainerRoutineRepository {
  _FakeRoutineRepository({this.fail = _Fail.none});

  final _Fail fail;
  // `type` 도 기록한다 — 다이얼로그가 종류를 다루지 않는다는 계약을 테스트로
  // 고정해 두지 않으면, 나중에 실수로 넘겨도 조용히 통과한다.
  final List<
    ({
      String memberId,
      String routineId,
      String? name,
      int? minutes,
      String? type,
      String? reason,
    })
  >
  updates = [];
  final List<String> deletes = <String>[];

  /// 목록을 몇 번 읽었는가 — `invalidate` 가 실제로 일어났는지 보는 눈.
  int watchCount = 0;

  void _maybeThrow(String routineId) => switch (fail) {
    _Fail.none => null,
    _Fail.notFound => throw StateError('routine not found: $routineId'),
    _Fail.network => throw const NetworkError(),
  };

  @override
  Future<void> assignRoutine(String memberId, AssignedRoutine routine) async {}

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) {
    watchCount += 1;
    return Stream<List<AssignedRoutine>>.value(const <AssignedRoutine>[
      _routine,
    ]);
  }

  @override
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  }) async {
    _maybeThrow(routineId);
    updates.add((
      memberId: memberId,
      routineId: routineId,
      name: name,
      minutes: minutes,
      type: type,
      reason: reason,
    ));
  }

  @override
  Future<void> deleteRoutine(String memberId, String routineId) async {
    _maybeThrow(routineId);
    deletes.add(routineId);
  }
}

Future<_FakeRoutineRepository> _pumpWorkoutTab(
  WidgetTester tester, {
  _Fail fail = _Fail.none,
}) async {
  final repo = _FakeRoutineRepository(fail: fail);
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
    // 종류는 다이얼로그에서 다루지 않으므로 보내지 않는다 — 부분 수정이라
    // 안 보낸 필드는 서버에서 그대로 남는다.
    expect(repo.updates.single.type, isNull);
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

  testWidgets('길이는 서버와 같은 문자 단위로 센다', (tester) async {
    final repo = await _pumpWorkoutTab(tester);

    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-rt-1')));
    await settle(tester);

    // 이모지 100자 = UTF-16 코드 유닛 200. String.length 로 세면 서버가 받아
    // 줄 값을 화면이 먼저 막는다.
    await tester.enterText(
      find.byKey(const ValueKey<String>('routine-edit-name')),
      '😀' * 100,
    );
    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-save')));
    await settle(tester);

    expect(find.textContaining('100자 이내'), findsNothing);
    expect(repo.updates, hasLength(1));
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

  testWidgets('네트워크 실패는 사유를 알리고 목록을 그대로 둔다', (tester) async {
    final repo = await _pumpWorkoutTab(tester, fail: _Fail.network);
    final before = repo.watchCount;

    await tester.tap(find.byKey(const ValueKey<String>('routine-delete-rt-1')));
    await settle(tester);
    await tester.tap(find.text('삭제'));
    await settle(tester);

    expect(find.textContaining('삭제하지 못했어요'), findsOneWidget);
    expect(repo.deletes, isEmpty);
    expect(find.text('하체 근력 A'), findsOneWidget);
    // 루틴은 서버에 그대로 있다 — 다시 읽을 이유가 없다.
    expect(repo.watchCount, before);
  });

  testWidgets('이미 없는 루틴(404)은 목록을 다시 읽어 화면을 맞춘다', (tester) async {
    // 다른 기기에서 먼저 지웠거나 담당이 풀린 경우. 그대로 두면 없는 루틴이
    // 화면에 남아 다시 눌러도 계속 실패하고, 새로고침 방법을 트레이너가
    // 스스로 찾아야 한다.
    final repo = await _pumpWorkoutTab(tester, fail: _Fail.notFound);
    final before = repo.watchCount;

    await tester.tap(find.byKey(const ValueKey<String>('routine-delete-rt-1')));
    await settle(tester);
    await tester.tap(find.text('삭제'));
    await settle(tester);

    expect(find.textContaining('이미 삭제된 루틴'), findsOneWidget);
    expect(repo.deletes, isEmpty);
    expect(repo.watchCount, greaterThan(before));
  });

  testWidgets('수정도 404 면 같은 방식으로 화면을 맞춘다', (tester) async {
    final repo = await _pumpWorkoutTab(tester, fail: _Fail.notFound);
    final before = repo.watchCount;

    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-rt-1')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('routine-edit-minutes')),
      '55',
    );
    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-save')));
    await settle(tester);

    expect(find.textContaining('이미 삭제된 루틴'), findsOneWidget);
    expect(repo.updates, isEmpty);
    expect(repo.watchCount, greaterThan(before));
  });

  testWidgets('서버 제약을 넘는 이름·사유는 그 자리에서 거른다', (tester) async {
    final repo = await _pumpWorkoutTab(tester);

    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-rt-1')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('routine-edit-name')),
      'ㄱ' * 101,
    );
    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-save')));
    await settle(tester);
    expect(find.textContaining('100자'), findsOneWidget);
    expect(repo.updates, isEmpty);

    // 이름을 되돌리고 사유만 길게 — 422 대신 그 자리에서 알린다.
    await tester.enterText(
      find.byKey(const ValueKey<String>('routine-edit-name')),
      '하체 근력 A',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('routine-edit-reason')),
      'ㄴ' * 201,
    );
    await tester.tap(find.byKey(const ValueKey<String>('routine-edit-save')));
    await settle(tester);
    expect(find.textContaining('200자'), findsOneWidget);
    expect(repo.updates, isEmpty);
  });
}
