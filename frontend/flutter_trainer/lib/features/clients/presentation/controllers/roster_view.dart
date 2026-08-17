import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로스터를 관리 상태로 좁히는 필터. URL 의 `f` 프리셋과는 다른 축이다 —
/// 그쪽은 대시보드가 걸어 주는 것이고, 이쪽은 트레이너가 툴바에서 고른다.
enum RosterManagementFilter { all, attention, active, dormant }

/// 로스터 정렬 기준.
enum RosterSort { priority, name }

/// 고객 탭의 보기 설정 한 벌.
class RosterView {
  /// Creates a view state.
  const RosterView({
    this.filter = RosterManagementFilter.all,
    this.sort = RosterSort.priority,
  });

  /// 툴바에서 고른 관리 필터.
  final RosterManagementFilter filter;

  /// 툴바에서 고른 정렬.
  final RosterSort sort;

  /// Returns a copy with the given fields replaced.
  RosterView copyWith({RosterManagementFilter? filter, RosterSort? sort}) =>
      RosterView(filter: filter ?? this.filter, sort: sort ?? this.sort);
}

/// 고객 탭의 정렬·관리 필터.
///
/// 화면이 아니라 여기에 두는 이유: `/clients` 와 `/clients/<id>/<section>` 은
/// 서로 다른 라우트라 각각 자기 `ClientsPage` 를 만든다. 이 값을 화면의 지역
/// 상태로 들고 있으면 목록에서 고객을 여는 순간 새 상태가 만들어져 방금 고른
/// 정렬이 기본값으로 돌아갔다 — 주의 고객만 추려 차례로 확인하는 흐름이 첫
/// 고객에서 끊겼다(#816).
final rosterViewProvider = StateProvider<RosterView>(
  (ref) => const RosterView(),
  name: 'rosterView',
);
