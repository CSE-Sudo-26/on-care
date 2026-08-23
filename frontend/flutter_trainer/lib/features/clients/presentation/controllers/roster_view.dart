import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로스터를 관리 상태로 좁히는 필터. URL 의 `f` 프리셋과는 다른 축이다 —
/// 그쪽은 대시보드가 걸어 주는 것이고, 이쪽은 트레이너가 툴바에서 고른다.
///
/// 복수 선택이 가능하다(#1026) — 선택된 조건 중 하나라도 맞으면 그 고객을
/// 보여준다(OR). `active`/`dormant` 처럼 서로 배타적인 값을 동시에 골라도
/// "둘 다 보기" 로 자연스럽게 읽히는 쪽은 AND 가 아니라 OR 뿐이다.
///
/// `나트륨 초과`/`당류 초과` 는 `TrainerClient.sodiumOverBudget`/
/// `sugarOverBudget` 을 그대로 재사용한다 — 새 임계값을 여기서 만들지 않는다.
/// `칼로리 초과` 는 넣지 않는다: 방향이 회원마다 다르다는 이유로 #767 에서
/// 이미 배지 후보에서 제외된 결정이다. `식단 이행률 저조`/`운동 이행률 저조`
/// 를 나눈 필터도 없다 — 모델에 `weekCompletion` 하나뿐이라 분리된 값을
/// 지어낼 수 없다(#1026 §3). `활동 저조` 도 마지막 기록 시각 필드가 없어
/// 뺐다.
enum RosterManagementFilter {
  attention,
  active,
  dormant,
  sodiumOver,
  sugarOver,
}

/// 로스터 정렬 기준.
///
/// `recentMessage` is backed by an actual chat timestamp: Drift's grouped
/// `ChatMessage.createdAt`, or the API's `last_message_at`. `lastTime` remains
/// display-only. A general activity/record sort is intentionally absent because
/// the roster contract has no last-activity timestamp.
enum RosterSort {
  priority,
  recentMessage,
  activeFirst,
  nameAscending,
  nameDescending,
}

/// 고객 탭의 보기 설정 한 벌.
class RosterView {
  /// Creates a view state.
  const RosterView({
    this.filters = const <RosterManagementFilter>{},
    this.sort = RosterSort.priority,
  });

  /// 툴바에서 고른 관리 필터. 비어 있으면 전체 보기.
  final Set<RosterManagementFilter> filters;

  /// 툴바에서 고른 정렬.
  final RosterSort sort;

  /// Returns a copy with the given fields replaced.
  RosterView copyWith({
    Set<RosterManagementFilter>? filters,
    RosterSort? sort,
  }) => RosterView(filters: filters ?? this.filters, sort: sort ?? this.sort);
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
