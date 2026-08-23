import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/coaching/data/repositories/dio_trainer_routine_repository.dart';
import 'package:oncare_trainer/features/coaching/domain/entities/assigned_routine.dart';

/// Assigns a routine to a member and reads their assigned routines.
///
/// Assigning is how a member *receives* a routine (the same record the
/// member app reads via `/me/coach/routines`). Two implementations sit
/// behind this contract, selected by [trainerRoutineRepositoryProvider] via
/// [AppConfig.useMockApi]:
///  * [MockTrainerRoutineRepository] — demo / `USE_MOCK_API=true` (no-op
///    send; the demo has no member app to receive it);
///  * [DioTrainerRoutineRepository] — the real FastAPI backend.
abstract interface class TrainerRoutineRepository {
  /// Assigns [routine] to [memberId] (POST /trainer/clients/{id}/routines).
  ///
  /// [clientRequestId] 는 **전송 시도**의 멱등키다. 재시도할 때 같은 값을 다시
  /// 넘기면 회원에게 같은 루틴이 두 번 배정되지 않는다(#581). 새 내용을 보낼
  /// 때만 새로 만든다 — 매 호출 새로 만들면 아무것도 막지 못한다.
  Future<void> assignRoutine(
    String memberId,
    AssignedRoutine routine, {
    String? clientRequestId,
  });

  /// Assigns a whole program — one routine per session (#709).
  ///
  /// [payload] comes from `programAssignToJson`, which carries the session
  /// order and each session's exercises. A program with one session lands as
  /// the same single routine the flat path produces, so the member's screen
  /// does not suddenly grow a session label.
  Future<void> assignProgram(String memberId, Map<String, Object?> payload);

  /// The member's currently assigned routines (newest first).
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId);

  /// 배정한 루틴을 고친다(PUT). 보낸 필드만 바뀐다. (#504)
  ///
  /// 없는 루틴·남의 배정은 [StateError] — 배정 실패와 같은 규칙으로, 목과
  /// 실서버가 같은 예외를 낸다.
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  });

  /// 배정한 루틴을 철회한다(DELETE). 회원 앱에서도 사라진다. (#504)
  Future<void> deleteRoutine(String memberId, String routineId);
}

/// 데모용 배정 저장소 — 메모리에 들고 있는다.
///
/// 예전에는 목록이 늘 비어 있고 취소는 `StateError` 를 던지는 no-op 이었다.
/// 데모에는 루틴을 받을 회원 백엔드가 없다는 이유였는데, 그 바람에 **개인 운동
/// 취소를 데모에서 확인할 방법이 없었다**(#1020). 배정을 실제로 들고 있으면
/// 취소가 목록에서 사라지는 것까지 데모로 보인다.
///
/// 배정(`assignRoutine`)은 여전히 조용히 성공한다 — 데모의 '전송됨' 피드백은
/// 로컬 채팅·스케줄 쓰기가 만든다.
class MockTrainerRoutineRepository implements TrainerRoutineRepository {
  /// Creates the demo repository, seeded for [seedClientId].
  MockTrainerRoutineRepository();

  /// 회원별 배정. 시연에 쓰는 고객만 채워 둔다.
  final Map<String, List<AssignedRoutine>> _byMember =
      <String, List<AssignedRoutine>>{
        for (final String memberId in _seededMembers)
          memberId: List<AssignedRoutine>.from(_seedRoutines),
      };

  final Map<String, StreamController<List<AssignedRoutine>>> _controllers =
      <String, StreamController<List<AssignedRoutine>>>{};

  /// 열어 둔 스트림을 모두 닫는다. provider 가 버려질 때 불린다.
  void dispose() {
    for (final StreamController<List<AssignedRoutine>> c
        in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }

  /// 데모 시드가 만드는 고객 id. 김민수 하나면 시연에 충분하다 — 명단 전원에게
  /// 배정을 뿌리면 어느 고객을 열어도 같은 루틴이 있어 오히려 가짜처럼 보인다.
  static const List<String> _seededMembers = <String>['seed-client-1'];

  /// 아직 하지 않은 개인 운동 둘. 하나는 AI 추천, 하나는 트레이너가 보낸 것이라
  /// 두 출처가 화면에서 어떻게 갈리는지 함께 보인다.
  static const List<AssignedRoutine> _seedRoutines = <AssignedRoutine>[
    AssignedRoutine(
      id: 'demo-routine-1',
      name: '저강도 유산소',
      minutes: 20,
      type: '유산소',
      reason: '어제 근력 위주였어요. 오늘은 가볍게 풀어 주세요.',
      source: 'ai',
    ),
    AssignedRoutine(
      id: 'demo-routine-2',
      name: '코어 서킷',
      minutes: 15,
      type: '근력',
      reason: '무릎 부담 없이 코어를 잡아 보죠.',
      source: 'trainer',
    ),
  ];

  List<AssignedRoutine> _listFor(String memberId) =>
      _byMember[memberId] ?? const <AssignedRoutine>[];

  void _emit(String memberId) {
    _controllers[memberId]?.add(
      List<AssignedRoutine>.unmodifiable(_listFor(memberId)),
    );
  }

  @override
  Future<void> assignRoutine(
    String memberId,
    AssignedRoutine routine, {
    String? clientRequestId,
  }) async {}

  @override
  Future<void> assignProgram(
    String memberId,
    Map<String, Object?> payload,
  ) async {}

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutines(String memberId) {
    // 수명은 [dispose] 가 쥔다 — provider 가 버려질 때 한꺼번에 닫는다. 여기서
    // 닫으면 다음 구독자가 죽은 스트림을 받는다.
    // ignore: close_sinks
    final StreamController<List<AssignedRoutine>> controller = _controllers
        .putIfAbsent(
          memberId,
          () => StreamController<List<AssignedRoutine>>.broadcast(),
        );
    // 구독하는 쪽이 첫 값을 곧바로 받아야 한다 — 브로드캐스트 스트림은 지난
    // 값을 다시 주지 않는다.
    return controller.stream.startWith(
      List<AssignedRoutine>.unmodifiable(_listFor(memberId)),
    );
  }

  // 데모에는 배정을 고치는 화면이 없다. 조용히 성공하면 화면이 '고쳤다'고
  // 말하게 되므로 없는 것을 지적한다.
  @override
  Future<void> updateRoutine(
    String memberId,
    String routineId, {
    String? name,
    int? minutes,
    String? type,
    String? reason,
  }) async => throw StateError('routine not found: $routineId');

  @override
  Future<void> deleteRoutine(String memberId, String routineId) async {
    final List<AssignedRoutine>? mine = _byMember[memberId];
    final int at =
        mine?.indexWhere((AssignedRoutine r) => r.id == routineId) ?? -1;
    // 실서버와 같은 예외다 — 없는 것을 지우려 하면 404 를 `StateError` 로
    // 옮기므로, 화면이 한 갈래만 다루면 된다.
    if (mine == null || at < 0) {
      throw StateError('routine not found: $routineId');
    }
    mine.removeAt(at);
    _emit(memberId);
  }
}

/// 브로드캐스트 스트림에 첫 값을 얹는다. 구독 시점의 현재 목록을 곧바로
/// 흘려보내야 화면이 빈 채로 기다리지 않는다.
extension _StartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}

/// Selects the real Dio-backed routine repository against the FastAPI
/// backend, or the demo no-op for `USE_MOCK_API=true`.
final trainerRoutineRepositoryProvider = Provider<TrainerRoutineRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockApi) {
    // 배정을 메모리에 들고 있으므로 const 가 아니다. provider 가 한 번만
    // 만들어 앱이 사는 동안 같은 목록을 보게 한다.
    final MockTrainerRoutineRepository demo = MockTrainerRoutineRepository();
    ref.onDispose(demo.dispose);
    return demo;
  }
  return DioTrainerRoutineRepository(ref.watch(dioProvider));
}, name: 'trainerRoutineRepository');

/// Streams the routines currently assigned to a member (newest first).
///
/// 데모에서도 비어 있지 않다 — [MockTrainerRoutineRepository] 가 아직 하지
/// 않은 개인 운동을 들고 있어, 취소가 목록에서 사라지는 것까지 보인다(#1020).
final assignedRoutinesProvider =
    StreamProvider.family<List<AssignedRoutine>, String>((ref, memberId) {
      return ref
          .watch(trainerRoutineRepositoryProvider)
          .watchAssignedRoutines(memberId);
    });
