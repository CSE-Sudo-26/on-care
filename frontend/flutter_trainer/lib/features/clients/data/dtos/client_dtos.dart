import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Maps the trainer clients/diet/history JSON (the FastAPI `TrainerClientOut`
/// / `ClientDietEntryOut` / `RoutineHistoryOut` schemas) into domain
/// entities. Kept separate from the Dio repository so the DTO ↔ domain
/// mapping is unit-testable and shared with any future source.

/// `GET /v1/trainer/clients` element → [TrainerClient].
TrainerClient trainerClientFromJson(Map<String, Object?> json) {
  return TrainerClient(
    id: _str(json['id']),
    name: _str(json['name']),
    avatar: _str(json['avatar']),
    goal: _str(json['goal']),
    lastMessage: _str(json['last_message']),
    lastTime: _str(json['last_time']),
    active: json['active'] == true,
    calories: _int(json['calories']),
    sodiumMg: _int(json['sodium_mg']),
    sugarG: _int(json['sugar_g']),
    lastRoutine: _str(json['last_routine']),
    weekCompletion: _intList(json['week_completion']),
    sodiumWeek: _intList(json['sodium_week']),
  );
}

/// `GET /v1/trainer/clients/{id}/diet` element → [ClientDietEntry].
ClientDietEntry clientDietEntryFromJson(Map<String, Object?> json) {
  return ClientDietEntry(
    meal: _str(json['meal']),
    items: _str(json['items']),
    calories: _int(json['calories']),
    sodiumMg: _int(json['sodium_mg']),
  );
}

/// `GET /v1/trainer/clients/{id}/history` element → [RoutineHistoryEntry].
RoutineHistoryEntry routineHistoryEntryFromJson(Map<String, Object?> json) {
  return RoutineHistoryEntry(
    dateLabel: _str(json['date_label']),
    label: _str(json['label']),
    completionRate: _int(json['completion_rate']),
    exercises: _strList(json['exercises']),
    clientFeedback: _str(json['client_feedback']),
    trainerNote: _str(json['trainer_note']),
  );
}

/// Orders the roster by coaching priority: clients over their sodium
/// target ("확인 필요") first, keeping the server order otherwise. Pure and
/// stable so both the Dio and drift repositories can share it and tests
/// can assert it directly.
List<TrainerClient> prioritizeClients(List<TrainerClient> clients) {
  final ordered = List<TrainerClient>.of(clients);
  // List.sort is not guaranteed stable; use the original index as a
  // tie-breaker so same-priority clients keep the server order.
  final index = <String, int>{
    for (var i = 0; i < ordered.length; i++) ordered[i].id: i,
  };
  ordered.sort((a, b) {
    final over = (b.sodiumOverBudget ? 1 : 0).compareTo(
      a.sodiumOverBudget ? 1 : 0,
    );
    if (over != 0) return over;
    return (index[a.id] ?? 0).compareTo(index[b.id] ?? 0);
  });
  return ordered;
}

String _str(Object? v) => v is String ? v : '';

int _int(Object? v) => v is num ? v.toInt() : 0;

// FastAPI emits JSON numbers that can decode as double on web — normalise
// through num so `as int` never throws.
List<int> _intList(Object? v) => v is List
    ? v.whereType<num>().map((n) => n.toInt()).toList(growable: false)
    : const <int>[];

List<String> _strList(Object? v) =>
    v is List ? v.whereType<String>().toList(growable: false) : const <String>[];
