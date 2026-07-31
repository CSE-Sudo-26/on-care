import 'package:oncare/features/notification/domain/entities/alert_item.dart';

abstract class NotificationRepository {
  /// All notifications, newest first.
  Future<List<AlertItem>> fetchAll();

  /// Persist a single notification as read.
  Future<void> markRead(String id);

  /// Persist all of the user's notifications as read.
  Future<void> markAllRead();
}
