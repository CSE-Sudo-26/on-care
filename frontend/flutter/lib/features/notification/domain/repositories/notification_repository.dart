import 'package:oncare/features/notification/domain/entities/alert_item.dart';

abstract class NotificationRepository {
  /// All notifications, newest first.
  Future<List<AlertItem>> fetchAll();

  /// Persist a single notification as read.
  Future<void> markRead(String id);

  /// Persist all of the user's notifications as read.
  Future<void> markAllRead();

  /// 서버 기준 미읽음 수.
  ///
  /// 목록을 통째로 받아 세지 않고 따로 두는 이유: 헤더 배지는 모든 탭에 떠 있어서
  /// 알림을 열지 않아도 최신이어야 하는데, 그때마다 전체 목록을 받는 것은 과하다.
  Future<int> unreadCount();
}
