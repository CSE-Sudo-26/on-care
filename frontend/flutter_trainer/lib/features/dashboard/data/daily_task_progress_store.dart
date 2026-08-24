import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/storage/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One day's 오늘 할 일 체크 현황.
///
/// [completedCarriedOver] is the subset of [completedToday] + itself that
/// was already pending on a *previous* day's snapshot — a real "이월된
/// 할 일을 오늘 해결했다" count, not a guess. [pendingKeys] is saved so the
/// *next* day can tell which of its own tasks are carry-overs.
class DailyTaskSnapshot {
  /// Creates a snapshot.
  const DailyTaskSnapshot({
    required this.total,
    required this.completedToday,
    required this.completedCarriedOver,
    required this.pendingKeys,
  });

  /// How many tasks were on the list that day.
  final int total;

  /// Checked, and not carried over from an earlier day.
  final int completedToday;

  /// Checked, and already pending on a previous day's snapshot.
  final int completedCarriedOver;

  /// Task keys (`alert-clientId`) still unchecked as of the last save —
  /// tomorrow's carry-over check reads this.
  final Set<String> pendingKeys;

  /// Total checked, either kind.
  int get completed => completedToday + completedCarriedOver;
}

/// Persists daily 오늘 할 일 completion so 할 일 진행률 can show a real
/// 월~일 history instead of only today's number.
///
/// SharedPreferences is the same local store this app already uses for
/// settings and 후속 관리 (`follow_up_task_repository.dart`) — a week of
/// small day summaries doesn't need a drift table.
class DailyTaskProgressStore {
  /// Creates the store over the app-wide prefs instance.
  const DailyTaskProgressStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefix = 'dashboard_task_progress:';

  /// Saves [snapshot] for [date] (`YYYY-MM-DD`).
  Future<void> save(String date, DailyTaskSnapshot snapshot) {
    return _prefs.setString(
      '$_prefix$date',
      jsonEncode(<String, Object?>{
        'total': snapshot.total,
        'completedToday': snapshot.completedToday,
        'completedCarriedOver': snapshot.completedCarriedOver,
        'pendingKeys': snapshot.pendingKeys.toList(growable: false),
      }),
    );
  }

  /// The snapshot saved for [date] (`YYYY-MM-DD`), or null if the trainer
  /// never opened the dashboard that day.
  DailyTaskSnapshot? read(String date) {
    final raw = _prefs.getString('$_prefix$date');
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final total = decoded['total'];
    final completedToday = decoded['completedToday'];
    final completedCarriedOver = decoded['completedCarriedOver'];
    final pendingKeys = decoded['pendingKeys'];
    if (total is! int ||
        completedToday is! int ||
        completedCarriedOver is! int ||
        pendingKeys is! List) {
      return null;
    }
    return DailyTaskSnapshot(
      total: total,
      completedToday: completedToday,
      completedCarriedOver: completedCarriedOver,
      pendingKeys: pendingKeys.whereType<String>().toSet(),
    );
  }
}

/// Provides the store over the app-wide prefs instance.
final dailyTaskProgressStoreProvider = Provider<DailyTaskProgressStore>((ref) {
  return DailyTaskProgressStore(ref.watch(sharedPreferencesProvider));
}, name: 'dailyTaskProgressStore');
