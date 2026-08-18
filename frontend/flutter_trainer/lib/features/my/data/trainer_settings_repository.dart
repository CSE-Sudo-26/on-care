import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/storage/prefs_provider.dart';
import 'package:oncare_trainer/features/my/data/trainer_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes the trainer's notification settings.
///
/// Two sources, selected by [AppConfig.useMockApi]:
///  * [LocalTrainerSettingsRepository] — demo/mock. There is no account
///    behind the demo, so the device is the only place to keep this.
///  * [DioTrainerSettingsRepository] — the real backend, so the setting
///    follows the trainer between the centre PC and their tablet.
abstract interface class TrainerSettingsRepository {
  /// The current settings. Falls back to the shared defaults if the
  /// source has nothing stored.
  Future<TrainerSettings> load();

  /// Persists [settings]. Throws [AppError] when the write fails —
  /// callers roll the UI back rather than showing a value that was
  /// never saved.
  Future<TrainerSettings> save(TrainerSettings settings);
}

/// Device-local settings in [SharedPreferences].
class LocalTrainerSettingsRepository implements TrainerSettingsRepository {
  /// Creates the local source.
  const LocalTrainerSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _kNewMessage = 'trainer.notify.newMessage';
  static const String _kSession = 'trainer.notify.session';
  static const String _kLead = 'trainer.notify.leadMinutes';

  @override
  Future<TrainerSettings> load() async {
    final lead = _prefs.getInt(_kLead);
    return TrainerSettings(
      newMessageAlerts: _prefs.getBool(_kNewMessage) ?? true,
      sessionReminders: _prefs.getBool(_kSession) ?? true,
      // A value written by an older build (or a hand-edited store) must
      // not put the picker into a state it cannot render.
      reminderLeadMinutes: reminderLeadOptions.contains(lead) ? lead! : 30,
    );
  }

  @override
  Future<TrainerSettings> save(TrainerSettings settings) async {
    await _prefs.setBool(_kNewMessage, settings.newMessageAlerts);
    await _prefs.setBool(_kSession, settings.sessionReminders);
    await _prefs.setInt(_kLead, settings.reminderLeadMinutes);
    return settings;
  }
}

/// Account-level settings via `/v1/trainer/me/settings`.
class DioTrainerSettingsRepository implements TrainerSettingsRepository {
  /// Creates the API-backed source.
  const DioTrainerSettingsRepository(this._dio);

  final Dio _dio;

  @override
  Future<TrainerSettings> load() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/trainer/me/settings');
      return trainerSettingsFromJson(res.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  @override
  Future<TrainerSettings> save(TrainerSettings settings) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/trainer/me/settings',
        data: trainerSettingsToJson(settings),
      );
      // Echo the server's own view back — it owns the defaults, and a
      // rejected value must not linger on screen as if it stuck.
      return trainerSettingsFromJson(res.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }
}

/// Decodes `TrainerNotificationSettings`.
TrainerSettings trainerSettingsFromJson(Map<String, dynamic> json) {
  final lead = (json['reminder_lead_minutes'] as num?)?.toInt();
  return TrainerSettings(
    newMessageAlerts: json['notify_new_message'] as bool? ?? true,
    sessionReminders: json['notify_session_reminder'] as bool? ?? true,
    reminderLeadMinutes: reminderLeadOptions.contains(lead) ? lead! : 30,
  );
}

/// Encodes `TrainerNotificationSettingsUpdate`.
Map<String, Object?> trainerSettingsToJson(TrainerSettings settings) {
  return <String, Object?>{
    'notify_new_message': settings.newMessageAlerts,
    'notify_session_reminder': settings.sessionReminders,
    'reminder_lead_minutes': settings.reminderLeadMinutes,
  };
}

/// Provides the settings repository for the current mode.
final trainerSettingsRepositoryProvider = Provider<TrainerSettingsRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return LocalTrainerSettingsRepository(ref.watch(sharedPreferencesProvider));
  }
  return DioTrainerSettingsRepository(ref.watch(dioProvider));
}, name: 'trainerSettingsRepository');
