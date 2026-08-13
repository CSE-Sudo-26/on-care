import 'package:oncare/features/notification/domain/entities/alert_item.dart';
import 'package:oncare/features/notification/domain/repositories/notification_repository.dart';

/// 데모(둘러보기)·로컬 목 모드에서 노출되는 고정 알림.
///
/// 실서비스(실로그인) 화면은 `/notifications` 백엔드를 읽지만, 데모 둘러보기는
/// 기존과 동일하게 보이도록 이 하드코딩 목록을 유지한다. 컨트롤러가 목 모드에서
/// 이 목록을 즉시 시드로 사용한다.
///
/// 각 알림은 실서버가 내려 주는 것과 같은 모양의 목적지(`action`)를 갖는다 —
/// 없으면 데모에서는 눌러도 읽음 처리만 되어, 구현돼 있는 이동 기능이 없는 것처럼
/// 보인다(#667). 목록의 생김새는 달라지지 않는다: `action` 은 그려지지 않는다.
const List<AlertItem> demoAlerts = <AlertItem>[
  AlertItem(
    id: 'a1',
    title: '나트륨 섭취 주의',
    body: '점심 짬뽕으로 오늘 나트륨이 3,421mg까지 올랐어요. 물을 충분히 드세요.',
    timeAgo: '10분 전',
    category: AlertCategory.reminder,
    action: AlertAction(label: '식단 보기', target: AlertTarget.diet),
  ),
  AlertItem(
    id: 'a2',
    title: 'PT 수업 완료',
    body: '오늘 18:00 김트레이너와 12회차 PT를 마쳤어요!',
    timeAgo: '1시간 전',
    category: AlertCategory.achievement,
    action: AlertAction(label: '운동 기록 보기', target: AlertTarget.exercise),
  ),
  AlertItem(
    id: 'a3',
    title: '트레이너 피드백 도착',
    body: '마무리로 어깨 회전근개 스트레칭을 꼭 해주세요.',
    timeAgo: '2시간 전',
    category: AlertCategory.reminder,
    action: AlertAction(label: '대화 보기', target: AlertTarget.coachChat),
  ),
  AlertItem(
    id: 'a4',
    title: '서비스 점검 안내',
    body: '내일 02:00~03:00 점검 예정입니다.',
    timeAgo: '어제',
    category: AlertCategory.system,
    read: true,
    // 갈 곳을 일부러 주지 않는다. **목적지 없는 알림이 목록에서 사라지거나
    // 엉뚱한 곳으로 가지 않는지**를 데모에서도 볼 수 있어야 한다.
  ),
];

/// 데모/로컬 모드용 [NotificationRepository].
///
/// 목록은 [demoAlerts] 로 시작하고 읽음 처리를 **세션 동안 기억한다.** 예전에는
/// 읽음이 no-op 이라, 미읽음 수를 물으면 늘 처음 상태를 답했다 — 데모에서 "모두 읽음"
/// 을 눌러도 벨의 점이 남아, 목록과 배지가 서로 다른 말을 했다(리뷰).
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository();

  List<AlertItem> _items = List<AlertItem>.of(demoAlerts);

  @override
  Future<List<AlertItem>> fetchAll() async => List<AlertItem>.of(_items);

  @override
  Future<void> markRead(String id) async {
    _items = _items
        .map((AlertItem a) => a.id == id ? a.copyWith(read: true) : a)
        .toList();
  }

  @override
  Future<void> markAllRead() async {
    _items = _items.map((AlertItem a) => a.copyWith(read: true)).toList();
  }

  @override
  Future<int> unreadCount() async =>
      _items.where((AlertItem a) => !a.read).length;
}
