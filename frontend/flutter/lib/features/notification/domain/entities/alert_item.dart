enum AlertCategory { reminder, healthCheck, achievement, system }

/// 알림을 눌렀을 때 갈 곳. 서버가 알림마다 내려준다(`action.target`).
///
/// 앱이 모르는 target 은 [unknown] 이 되고, 그 알림은 읽음 처리만 하고 이동하지
/// 않는다 — 서버가 새 종류를 추가했을 때 **갈 곳 없는 알림**이 되는 편이 목록에서
/// 사라지거나 엉뚱한 화면으로 보내는 것보다 낫다.
enum AlertTarget { dashboard, schedule, coachChat, exercise, diet, unknown }

/// 알림 항목의 행동 유도 — 문구는 서버가, 이동은 앱이 정한다.
class AlertAction {
  const AlertAction({required this.label, required this.target});

  /// 버튼/힌트에 쓰는 서버 문구.
  final String label;

  /// 눌렀을 때 갈 곳.
  final AlertTarget target;

  /// 앱이 실제로 이동할 수 있는 행동인가.
  bool get isNavigable => target != AlertTarget.unknown;
}

class AlertItem {
  const AlertItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.category,
    this.read = false,
    this.action,
  });

  final String id;
  final String title;
  final String body;
  final String timeAgo;
  final AlertCategory category;
  final bool read;

  /// 서버가 지정한 이동 경로. 없으면 읽음 처리만 한다.
  final AlertAction? action;

  AlertItem copyWith({bool? read}) => AlertItem(
    id: id,
    title: title,
    body: body,
    timeAgo: timeAgo,
    category: category,
    read: read ?? this.read,
    action: action,
  );
}

/// 알림 목록 화면이 그리는 상태.
///
/// [items] 와 [failedToLoad] 를 함께 들고 있는 이유: 조회가 실패해도 **이미 받아 둔
/// 목록을 지우지 않는다.** 지하철에서 새로고침했다고 알림이 사라지면, 사용자는 읽지
/// 않은 알림이 있었는지조차 알 수 없게 된다.
class NotificationState {
  const NotificationState({
    required this.items,
    this.loading = false,
    this.failedToLoad = false,
  });

  final List<AlertItem> items;

  /// 첫 조회가 진행 중인가. 새로고침 중에는 기존 목록을 그대로 보여 준다.
  final bool loading;

  /// 마지막 조회가 실패했는가. 화면이 재시도를 제안하는 근거다.
  final bool failedToLoad;

  int get unreadCount => items.where((AlertItem i) => !i.read).length;

  NotificationState copyWith({
    List<AlertItem>? items,
    bool? loading,
    bool? failedToLoad,
  }) => NotificationState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    failedToLoad: failedToLoad ?? this.failedToLoad,
  );
}
