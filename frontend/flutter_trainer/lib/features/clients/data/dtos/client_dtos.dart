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
    carbsG: _double(json['carbs_g']),
    proteinG: _double(json['protein_g']),
    fatG: _double(json['fat_g']),
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
    carbsG: _double(json['carbs_g']),
    proteinG: _double(json['protein_g']),
    fatG: _double(json['fat_g']),
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
///
/// `List.sort` isn't guaranteed stable, so the original position travels
/// with each client as a decorate-sort tie-breaker (undecorate after) —
/// unlike an id-keyed lookup, this can't collide on a duplicate/missing id
/// (review).
List<TrainerClient> prioritizeClients(
  List<TrainerClient> clients, {
  Map<String, DateTime> lastChatAt = const <String, DateTime>{},
}) {
  final decorated = <(TrainerClient client, int index)>[
    for (var i = 0; i < clients.length; i++) (clients[i], i),
  ];
  final epoch = DateTime.utc(1970);
  decorated.sort((a, b) {
    final over = (b.$1.sodiumOverBudget ? 1 : 0).compareTo(
      a.$1.sodiumOverBudget ? 1 : 0,
    );
    if (over != 0) return over;
    // Ties break on who spoke most recently — when two clients are both
    // over target, the one mid-conversation is the one to open first.
    // Absent when the source has no chat signal (the real API's roster
    // endpoint doesn't carry one), which degrades to the incoming order.
    final chat = (lastChatAt[b.$1.id] ?? epoch).compareTo(
      lastChatAt[a.$1.id] ?? epoch,
    );
    if (chat != 0) return chat;
    return a.$2.compareTo(b.$2);
  });
  return <TrainerClient>[for (final d in decorated) d.$1];
}

String _str(Object? v) => v is String ? v : '';

int _int(Object? v) => v is num ? v.toInt() : 0;

double _double(Object? v) => v is num ? v.toDouble() : 0;

// FastAPI emits JSON numbers that can decode as double on web — normalise
// through num so `as int` never throws.
List<int> _intList(Object? v) => v is List
    ? v.whereType<num>().map((n) => n.toInt()).toList(growable: false)
    : const <int>[];

List<String> _strList(Object? v) => v is List
    ? v.whereType<String>().toList(growable: false)
    : const <String>[];
