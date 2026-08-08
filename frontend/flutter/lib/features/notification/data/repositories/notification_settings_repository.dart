import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/core/network/dio_client.dart';
import 'package:oncare/core/storage/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 알림 수신 설정 항목. 키는 서버와 공유하는 계약이다. (#489)
///
/// 화면 라벨은 ARB 에서 키로 찾으므로 여기에 두지 않는다.
class NotificationSettingItem {
  /// Creates a toggle definition.
  const NotificationSettingItem(this.key, this.fallback);

  /// 저장 키. 로컬(SharedPreferences)과 서버 응답 필드가 이 값을 공유한다 —
  /// 서버는 `notif_` 접두사를 뗀 이름을 쓰므로 매핑은 repository 가 한다.
  final String key;

  /// 한 번도 바꾼 적 없을 때의 값.
  final bool fallback;
}

/// 화면에 보이는 순서 그대로. 주간 리포트만 기본 꺼짐이다.
const List<NotificationSettingItem> kNotificationSettingItems =
    <NotificationSettingItem>[
      NotificationSettingItem('notif_diet_log', true),
      NotificationSettingItem('notif_exercise_reminder', true),
      NotificationSettingItem('notif_trainer_message', true),
      NotificationSettingItem('notif_ai_coaching', true),
      NotificationSettingItem('notif_weekly_report', false),
    ];

/// 알림 수신 설정을 읽고 쓴다.
///
/// 두 구현이 [notificationSettingsRepositoryProvider] 뒤에 있고 `useMockApi` 로
/// 갈린다.
///
///  * [LocalNotificationSettingsRepository] — 데모/목. 기기에만 남는다.
///  * [DioNotificationSettingsRepository] — 실 백엔드. **계정 단위**라 기기를
///    바꿔도 유지되고, 무엇보다 서버가 설정을 알아야 알림을 만들 때 끌 수 있다.
///
/// 데모를 로컬로 남겨 두는 이유: 데모에는 설정을 저장할 백엔드가 없다. 서버로
/// 보내면 설정 화면이 로딩 실패로 뜨고, 지금 화면과 달라진다.
abstract class NotificationSettingsRepository {
  /// 전체 설정. 저장한 적 없는 항목은 기본값으로 채워 온다.
  Future<Map<String, bool>> fetch();

  /// 한 항목을 바꾼다.
  Future<void> setValue(String key, bool value);
}

/// 데모/목 — 기존 동작 그대로 SharedPreferences 에 남긴다.
class LocalNotificationSettingsRepository
    implements NotificationSettingsRepository {
  /// Creates the local source over [_prefs].
  const LocalNotificationSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<Map<String, bool>> fetch() async => <String, bool>{
    for (final NotificationSettingItem item in kNotificationSettingItems)
      item.key: _prefs.getBool(item.key) ?? item.fallback,
  };

  @override
  Future<void> setValue(String key, bool value) async {
    await _prefs.setBool(key, value);
  }
}

/// 실 백엔드 — `GET`/`PUT /users/me/notification-settings`.
class DioNotificationSettingsRepository
    implements NotificationSettingsRepository {
  /// Creates the API-backed source.
  const DioNotificationSettingsRepository(this._dio);

  final Dio _dio;

  static const String _path = '/users/me/notification-settings';

  @override
  Future<Map<String, bool>> fetch() async {
    final Response<Map<String, Object?>> res = await _dio
        .get<Map<String, Object?>>(_path);
    final Map<String, Object?> body = res.data ?? const <String, Object?>{};
    return <String, bool>{
      for (final NotificationSettingItem item in kNotificationSettingItems)
        item.key: switch (body[_wireName(item.key)]) {
          final bool value => value,
          // 서버가 모르는 항목은 기본값으로 둔다 — 배포 시점이 어긋나
          // 필드가 빠져 와도 토글이 사라지지 않는다.
          _ => item.fallback,
        },
    };
  }

  @override
  Future<void> setValue(String key, bool value) async {
    await _dio.put<Map<String, Object?>>(
      _path,
      data: <String, Object?>{_wireName(key): value},
    );
  }

  /// `notif_trainer_message` → `trainer_message`. 서버 필드는 접두사가 없다.
  static String _wireName(String key) => key.replaceFirst('notif_', '');
}

/// 데모/목은 로컬, 실모드는 백엔드.
final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
      if (ref.watch(appConfigProvider).useMockApi) {
        return LocalNotificationSettingsRepository(
          ref.watch(sharedPreferencesProvider),
        );
      }
      return DioNotificationSettingsRepository(ref.watch(dioProvider));
    }, name: 'notificationSettingsRepository');

/// 현재 설정. 실패하면 기본값으로 화면을 그린다 — 설정을 못 읽었다고 토글을
/// 감추면 사용자가 끌 방법이 사라진다.
final notificationSettingsProvider = FutureProvider<Map<String, bool>>((
  ref,
) async {
  try {
    return await ref.watch(notificationSettingsRepositoryProvider).fetch();
  } on Object {
    return <String, bool>{
      for (final NotificationSettingItem item in kNotificationSettingItems)
        item.key: item.fallback,
    };
  }
}, name: 'notificationSettings');
