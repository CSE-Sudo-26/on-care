import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oncare_trainer/core/storage/prefs_provider.dart';

/// How long before a session the trainer wants reminding.
const List<int> reminderLeadOptions = <int>[10, 30, 60];

/// The trainer's notification preferences.
///
/// Stored on the device rather than the server: these decide what *this*
/// browser/app shows, and there is no push infrastructure behind them
/// yet. When server-side push lands, this class is what the sync layer
/// reads — the screen doesn't change.
class TrainerSettings {
  /// Creates a settings snapshot.
  const TrainerSettings({
    this.newMessageAlerts = true,
    this.sessionReminders = true,
    this.reminderLeadMinutes = 30,
  });

  /// Notify when a client sends a message.
  final bool newMessageAlerts;

  /// Notify before a booked session starts.
  final bool sessionReminders;

  /// Lead time for [sessionReminders], in minutes.
  final int reminderLeadMinutes;

  /// Returns a copy with the given fields replaced.
  TrainerSettings copyWith({
    bool? newMessageAlerts,
    bool? sessionReminders,
    int? reminderLeadMinutes,
  }) {
    return TrainerSettings(
      newMessageAlerts: newMessageAlerts ?? this.newMessageAlerts,
      sessionReminders: sessionReminders ?? this.sessionReminders,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
    );
  }
}

/// Reads/writes [TrainerSettings] in [SharedPreferences].
class TrainerSettingsController extends StateNotifier<TrainerSettings> {
  /// Loads the stored settings (defaults when absent).
  TrainerSettingsController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static const String _kNewMessage = 'trainer.notify.newMessage';
  static const String _kSession = 'trainer.notify.session';
  static const String _kLead = 'trainer.notify.leadMinutes';

  static TrainerSettings _read(SharedPreferences prefs) {
    final lead = prefs.getInt(_kLead);
    return TrainerSettings(
      newMessageAlerts: prefs.getBool(_kNewMessage) ?? true,
      sessionReminders: prefs.getBool(_kSession) ?? true,
      // A value written by an older build (or a hand-edited store) must
      // not put the picker into a state it cannot render.
      reminderLeadMinutes: reminderLeadOptions.contains(lead) ? lead! : 30,
    );
  }

  /// Toggles new-message notifications.
  Future<void> setNewMessageAlerts(bool value) async {
    state = state.copyWith(newMessageAlerts: value);
    await _prefs.setBool(_kNewMessage, value);
  }

  /// Toggles pre-session reminders.
  Future<void> setSessionReminders(bool value) async {
    state = state.copyWith(sessionReminders: value);
    await _prefs.setBool(_kSession, value);
  }

  /// Sets the reminder lead time; ignores values outside
  /// [reminderLeadOptions].
  Future<void> setReminderLead(int minutes) async {
    if (!reminderLeadOptions.contains(minutes)) return;
    state = state.copyWith(reminderLeadMinutes: minutes);
    await _prefs.setInt(_kLead, minutes);
  }
}

/// The trainer's notification settings.
final trainerSettingsProvider =
    StateNotifierProvider<TrainerSettingsController, TrainerSettings>((ref) {
      return TrainerSettingsController(ref.watch(sharedPreferencesProvider));
    }, name: 'trainerSettings');
