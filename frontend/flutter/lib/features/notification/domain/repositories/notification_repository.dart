import 'package:oncare/features/notification/domain/entities/alert_item.dart';

/// 알림 한 쪽의 크기.
///
/// 서버는 `limit` 을 1~100 으로 받고 기본이 50 이다. 앱은 더 작게 잡는다 — 첫 화면은
/// 몇 줄만 보이고, 나머지는 스크롤이 닿을 때 이어 받으면 된다.
const int notificationPageSize = 30;

abstract class NotificationRepository {
  /// 최신 알림 한 쪽(최신순).
  ///
  /// 예전에는 사용자의 알림을 **전부** 받았다. 알림은 식단·운동·일정 훅에서 계속
  /// 생기는데 지우는 경로가 없어, 오래 쓴 계정일수록 알림 탭을 열 때마다 응답과
  /// 파싱 비용이 선형으로 늘었다(#965).
  ///
  /// [before]·[beforeId] 는 **직전 쪽 마지막 알림**의 `createdAt` 과 `id` 다. 서버가
  /// 준 값을 그대로 되돌려 준다 — 같은 시각의 알림이 여러 건이어도 경계에서 빠지거나
  /// 겹치지 않는다.
  Future<List<AlertItem>> fetchPage({
    int limit,
    String? before,
    String? beforeId,
  });

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
