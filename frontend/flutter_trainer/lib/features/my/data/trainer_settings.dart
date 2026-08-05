import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/features/my/data/trainer_settings_repository.dart';

/// How long before a session the trainer wants reminding.
///
/// Mirrors the server's `REMINDER_LEAD_OPTIONS` — the backend owns the
/// contract and rejects anything else, so the picker must not offer more.
const List<int> reminderLeadOptions = <int>[10, 30, 60];

/// The trainer's notification preferences.
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

/// Drives the 설정 screen's notification section.
///
/// Writes optimistically — a switch that waits for a round trip feels
/// broken — but **rolls back and surfaces the error** if the write
/// fails. Silently keeping a value the server rejected is how a settings
/// screen starts lying about itself.
class TrainerSettingsController extends StateNotifier<TrainerSettings> {
  /// Creates the controller and loads the stored settings.
  TrainerSettingsController(this._repository) : super(const TrainerSettings()) {
    _load();
  }

  final TrainerSettingsRepository _repository;

  /// Set when the last write failed; the UI shows it once and clears it.
  String? lastError;

  Future<void> _load() async {
    try {
      state = await _repository.load();
    } catch (_) {
      // Keep the defaults on screen — an unreachable settings endpoint
      // shouldn't block the rest of the page.
    }
  }

  /// Toggles new-message notifications.
  Future<void> setNewMessageAlerts(bool value) =>
      _apply(state.copyWith(newMessageAlerts: value));

  /// Toggles pre-session reminders.
  Future<void> setSessionReminders(bool value) =>
      _apply(state.copyWith(sessionReminders: value));

  /// Sets the reminder lead time; ignores values the server would refuse.
  Future<void> setReminderLead(int minutes) {
    if (!reminderLeadOptions.contains(minutes)) return Future<void>.value();
    return _apply(state.copyWith(reminderLeadMinutes: minutes));
  }

  Future<void> _apply(TrainerSettings next) async {
    final previous = state;
    state = next;
    lastError = null;
    try {
      state = await _repository.save(next);
    } catch (_) {
      state = previous;
      lastError = '설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요';
    }
  }

  /// Clears [lastError] once the UI has shown it.
  void clearError() => lastError = null;
}

/// The trainer's notification settings.
final trainerSettingsProvider =
    StateNotifierProvider<TrainerSettingsController, TrainerSettings>((ref) {
      return TrainerSettingsController(
        ref.watch(trainerSettingsRepositoryProvider),
      );
    }, name: 'trainerSettings');
