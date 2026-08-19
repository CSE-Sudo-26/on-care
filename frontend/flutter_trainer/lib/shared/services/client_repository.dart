import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/storage/app_database.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/clients/data/dtos/client_dtos.dart'
    show prioritizeClients;
import 'package:oncare_trainer/features/clients/data/repositories/dio_client_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_diet_entry.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_exercise_week.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/features/clients/domain/entities/member_health_profile.dart';
import 'package:oncare_trainer/features/clients/domain/entities/routine_history_entry.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';

/// Reads a trainer's clients + their diet/history for the 고객 관리 tab.
///
/// Two implementations sit behind this contract (selected by
/// [clientRepositoryProvider] via [AppConfig.useMockApi]):
///  * [DriftClientRepository] — local drift, demo / `USE_MOCK_API=true`;
///  * [DioClientRepository] — the real FastAPI backend.
///
/// Reads are exposed as streams so the drift source can stay reactive; the
/// Dio source emits a single fetched value (loading/error surface through
/// the consuming `AsyncValue`).
abstract interface class ClientRepository {
  /// Whether this source can **add** clients to the roster.
  ///
  /// The real roster is defined by trainer↔member links created through
  /// consultation approval, and there is no add-client endpoint — so the
  /// 신규 고객 등록 entry stays demo-only.
  ///
  /// This no longer gates [setClientActive]: the 활성/휴면 state is a
  /// trainer-side management flag that both sources support (#707). The two
  /// used to share one flag, which kept the status badge read-only against
  /// the real API.
  bool get supportsRosterMutations;

  Stream<List<TrainerClient>> watchClients();

  /// Most recent chat activity per client id — the tiebreak used by
  /// [prioritizeClients]. Sources without a chat signal emit `{}`.
  Stream<Map<String, DateTime>> watchLastChatAt();

  Stream<List<ClientDietEntry>> watchDiet(String clientId);
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId);
  Future<RoutineHistoryEntry> updateHistoryFeedback(
    String clientId,
    String historyId,
    String feedback,
  );
  Future<MemberHealthProfile> fetchHealthProfile(String clientId);
  Future<MemberHealthProfile> updateHealthProfile(
    String clientId,
    Map<String, Object?> values,
  );

  /// [clientId] 의 한 주 운동 집계. [weekStart] 를 주지 않으면 이번 주다.
  ///
  /// 주를 인자로 받는 이유는 `이번 달` 때문이다 — 서버도 데모도 운동 이력을
  /// 주 단위로 들고 있어, 한 달을 그리려면 그 달에 걸친 주를 각각 읽어 이어
  /// 붙인다(#914).
  Future<ClientExerciseWeek> fetchExerciseWeek(
    String clientId, {
    DateTime? weekStart,
  });

  /// [range] 가 덮는 날들의 일별 식단 집계.
  ///
  /// 회원 앱 식단 탭의 기간 뷰와 같은 것을 트레이너에게도 준다. 두 구현 모두
  /// **주 단위 이력**에서 만든다 — 데모는 drift 의 일별 지표에서, 실서버는
  /// 리포트 응답(`calories_week` · `sodium_week` · `sugar_week`)에서.
  Future<ClientDietPeriod> fetchDietPeriod(
    String clientId,
    ClientDateRange range,
  );

  /// Demo-only roster additions — the backend roster comes from
  /// trainer↔member links, so these are unsupported against the real API.
  Future<bool> clientNameExists(String name);
  Future<bool> addClient({required String name, required String goal});

  /// Moves [id] between 활성 and 휴면.
  ///
  /// Supported by both sources. This is the trainer's own management state,
  /// **not** an unassignment — the member keeps their coach and every record
  /// behind the link (#707).
  Future<void> setClientActive(String id, bool active);
}

/// Reads client + schedule data from the local drift DB for the
/// 고객 관리 tab. Returns reactive streams so the UI updates if the
/// underlying rows change (e.g. a routine sent from another tab).
class DriftClientRepository implements ClientRepository {
  /// Creates the repository over [_db].
  const DriftClientRepository(this._db);

  final AppDatabase _db;

  @override
  Future<RoutineHistoryEntry> updateHistoryFeedback(
    String clientId,
    String historyId,
    String feedback,
  ) => throw UnsupportedError(
    'Assigned-routine feedback is available from the backend only.',
  );

  @override
  bool get supportsRosterMutations => true;

  /// All clients, ordered as seeded (sortOrder).
  @override
  Stream<List<TrainerClient>> watchClients() {
    final query = _db.select(_db.trainerClients)
      ..orderBy(<OrderingTerm Function($TrainerClientsTable)>[
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// Most recent message time per client.
  ///
  /// A plain grouped aggregate over the chat table — deliberately NOT a
  /// join against `trainerClients`. The joined form (`select(t).join(...)
  /// ..groupBy(...)`) never completes against the sqlite3 WASM build the
  /// web app runs on, which stalled the roster and the dashboard on a
  /// spinner with no error to show.
  @override
  Stream<Map<String, DateTime>> watchLastChatAt() {
    final chat = _db.clientChatMessages;
    final latest = chat.createdAt.max();
    final query = _db.selectOnly(chat)
      ..addColumns(<Expression<Object>>[chat.clientId, latest])
      ..groupBy(<Expression<Object>>[chat.clientId]);
    return query.watch().map((rows) {
      final out = <String, DateTime>{};
      for (final row in rows) {
        final id = row.read(chat.clientId);
        final at = row.read(latest);
        if (id != null && at != null) out[id] = at;
      }
      return out;
    });
  }

  /// Whether a client with this display name already exists
  /// (whitespace- and case-insensitive). Counts in SQL rather than
  /// loading every row into memory (review PR 243).
  @override
  Future<bool> clientNameExists(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return false;
    return _nameTaken(key);
  }

  /// SQL `COUNT(*)` of clients whose normalised name matches [key]
  /// (already trimmed + lower-cased). Runs inside the caller's
  /// transaction when there is one, so `addClient` can check-then-insert
  /// atomically.
  Future<bool> _nameTaken(String key) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM trainer_clients '
          'WHERE lower(trim(name)) = ?1',
          variables: <Variable<Object>>[Variable<String>(key)],
          readsFrom: <ResultSetImplementation<Object?, Object?>>{
            _db.trainerClients,
          },
        )
        .getSingle();
    return row.read<int>('c') > 0;
  }

  /// Registers a new client (e.g. after a 상담) with a fresh, empty
  /// profile. The non-`seed-` id survives the daily re-seed.
  ///
  /// Returns `false` — writing nothing — when the name is blank or
  /// already taken. Schedule rows reference a client by NAME (the chat
  /// shortcut and completion logging both look up `clientName`), so a
  /// duplicate name would attribute one client's chat/운동기록 to
  /// another. Keeping names unique closes that path until schedules
  /// carry a clientId (review PR 243).
  ///
  /// The duplicate check and the insert run in ONE transaction, so two
  /// concurrent adds of the same name can't both pass the check and both
  /// insert — exactly one wins, the other returns `false` (review 243).
  @override
  Future<bool> addClient({required String name, required String goal}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;
    return _db.transaction(() async {
      if (await _nameTaken(trimmedName.toLowerCase())) return false;
      final now = nowKst();
      await _db
          .into(_db.trainerClients)
          .insert(
            TrainerClientsCompanion.insert(
              id: 'client-${now.microsecondsSinceEpoch}',
              name: trimmedName,
              // runes.first survives surrogate pairs without pulling the
              // characters package into this pure-Dart service.
              avatar: String.fromCharCode(trimmedName.runes.first),
              goal: goal.trim().isEmpty ? '목표 설정 전' : goal.trim(),
              lastMessage: '아직 대화가 없어요',
              lastTime: '-',
              active: const Value(true),
              caloriesToday: 0,
              sodiumMg: 0,
              sugarG: 0,
              carbsG: const Value(0),
              proteinG: const Value(0),
              fatG: const Value(0),
              lastRoutine: '-',
              weekCompletionJson: '[0,0,0,0,0,0,0]',
              sodiumWeekJson: const Value('[]'),
              // Large key appends new clients after the seeded roster.
              sortOrder: Value(now.millisecondsSinceEpoch),
            ),
          );
      return true;
    });
  }

  /// Flips a client between 활성 and 휴면.
  @override
  Future<void> setClientActive(String id, bool active) async {
    await (_db.update(_db.trainerClients)..where((t) => t.id.equals(id))).write(
      TrainerClientsCompanion(active: Value(active)),
    );
  }

  @override
  Future<MemberHealthProfile> fetchHealthProfile(String clientId) async {
    final row = await (_db.select(
      _db.trainerClients,
    )..where((table) => table.id.equals(clientId))).getSingle();
    final savedJson = await _db.readValue('member_health_profile:$clientId');
    final saved = savedJson == null
        ? const <String, Object?>{}
        : jsonDecode(savedJson) as Map<String, Object?>;
    return MemberHealthProfile(
      memberId: clientId,
      memberName: row.name,
      // 키·체중은 저장된 적이 없으면 비운다. 예전에는 175/72 를 채웠는데,
      // 트레이너가 입력한 값과 앱이 지어낸 값이 화면에서 구분되지 않았고,
      // 그대로 저장하면 남의 신체 정보로 굳었다(#818).
      heightCm: (saved['height_cm'] as num?)?.toDouble(),
      weightKg: (saved['weight_kg'] as num?)?.toDouble(),
      // 성별은 로스터가 이미 말하고 있는 값을 따른다. 고정 'male' 을 두던
      // 시절에는 헤더가 '여성'인 회원의 대화상자가 '남성'으로 열렸다(#818).
      gender: saved['gender'] as String? ?? _toEntity(row).rosterGender,
      conditions: saved['conditions'] as String? ?? '',
      goals: saved['goals'] as String? ?? row.goal,
      weeklyWorkoutGoal: saved.containsKey('weekly_workout_goal')
          ? (saved['weekly_workout_goal'] as num?)?.toInt()
          : 3,
      weeklyExerciseMinutesGoal:
          saved.containsKey('weekly_exercise_minutes_goal')
          ? (saved['weekly_exercise_minutes_goal'] as num?)?.toInt()
          : 150,
      weeklyBurnGoal: saved.containsKey('weekly_burn_goal')
          ? (saved['weekly_burn_goal'] as num?)?.toInt()
          : 1500,
    );
  }

  @override
  Future<MemberHealthProfile> updateHealthProfile(
    String clientId,
    Map<String, Object?> values,
  ) async {
    final current = await fetchHealthProfile(clientId);
    Object? value(String key, Object? fallback) =>
        values.containsKey(key) ? values[key] : fallback;
    final saved = <String, Object?>{
      'height_cm': value('height_cm', current.heightCm),
      'weight_kg': value('weight_kg', current.weightKg),
      'gender': value('gender', current.gender),
      'conditions': value('conditions', current.conditions),
      'goals': value('goals', current.goals),
      'weekly_workout_goal': value(
        'weekly_workout_goal',
        current.weeklyWorkoutGoal,
      ),
      'weekly_exercise_minutes_goal': value(
        'weekly_exercise_minutes_goal',
        current.weeklyExerciseMinutesGoal,
      ),
      'weekly_burn_goal': value('weekly_burn_goal', current.weeklyBurnGoal),
    };
    await _db.putValue('member_health_profile:$clientId', jsonEncode(saved));
    if (values.containsKey('goals')) {
      await (_db.update(
        _db.trainerClients,
      )..where((table) => table.id.equals(clientId))).write(
        TrainerClientsCompanion(goal: Value(values['goals'] as String? ?? '')),
      );
    }
    return fetchHealthProfile(clientId);
  }

  /// 데모의 이행률 → 운동 시간 환산. 100% 를 30분으로 본다.
  ///
  /// 지난 주를 읽을 때도 **같은 규칙**을 쓴다 — 주마다 환산이 다르면 한 달
  /// 그래프에서 주 경계마다 값이 튄다.
  static int _minutesFromCompletion(int rate) =>
      rate == 0 ? 0 : (30 * rate / 100).round();

  @override
  Future<ClientExerciseWeek> fetchExerciseWeek(
    String clientId, {
    DateTime? weekStart,
  }) async {
    final monday = clientMondayOf(weekStart ?? nowKst());
    final completion = await _weekCompletion(clientId, monday);
    final minutes = completion
        .map(_minutesFromCompletion)
        .toList(growable: false);
    final calories = minutes.map((value) => value * 6).toList(growable: false);
    return ClientExerciseWeek(
      dayLabels: const ['월', '화', '수', '목', '금', '토', '일'],
      dailyMinutes: minutes,
      dailyCalories: calories,
      totalMinutes: minutes.fold(0, (sum, value) => sum + value),
      totalCalories: calories.fold(0, (sum, value) => sum + value),
    );
  }

  /// [monday] 주의 요일별 이행률(월→일, 길이 7).
  ///
  /// 일별 지표(`clientDailyMetrics`)를 먼저 본다 — 시드가 12주치를 쌓아 두므로
  /// 지난 주도 그 주의 값으로 읽힌다. 행이 하나도 없는 주는, 그 주가 이번
  /// 주라면 로스터의 계열로 떨어진다(시드 이전 상태에서도 이번 주는 그려야
  /// 한다). 그 밖에는 전부 0 — 기록이 없는 주다.
  Future<List<int>> _weekCompletion(String clientId, DateTime monday) async {
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final rows =
        await (_db.select(_db.clientDailyMetrics)..where(
              (t) =>
                  t.clientId.equals(clientId) &
                  t.date.isBiggerOrEqualValue(ymd(monday)) &
                  t.date.isSmallerOrEqualValue(ymd(sunday)),
            ))
            .get();
    if (rows.isEmpty) {
      if (monday != clientMondayOf(nowKst())) {
        return List<int>.filled(7, 0);
      }
      final row = await (_db.select(
        _db.trainerClients,
      )..where((table) => table.id.equals(clientId))).getSingle();
      final week = (jsonDecode(row.weekCompletionJson) as List<Object?>)
          .map((value) => (value as num).toInt())
          .toList(growable: false);
      return <int>[for (var d = 0; d < 7; d++) d < week.length ? week[d] : 0];
    }
    final byDate = <String, ClientDailyMetricRow>{
      for (final row in rows) row.date: row,
    };
    return <int>[
      for (var d = 0; d < 7; d++)
        byDate[ymd(DateTime(monday.year, monday.month, monday.day + d))]
                ?.completion ??
            0,
    ];
  }

  @override
  Future<ClientDietPeriod> fetchDietPeriod(
    String clientId,
    ClientDateRange range,
  ) async {
    final rows =
        await (_db.select(_db.clientDailyMetrics)..where(
              (t) =>
                  t.clientId.equals(clientId) &
                  t.date.isBiggerOrEqualValue(ymd(range.from)) &
                  t.date.isSmallerOrEqualValue(ymd(range.to)),
            ))
            .get();
    final byDate = <String, ClientDailyMetricRow>{
      for (final row in rows) row.date: row,
    };
    return ClientDietPeriod(
      range: range,
      days: <ClientDietDay>[
        for (final date in clientRangeDates(range))
          ClientDietDay(
            date: date,
            calories: byDate[ymd(date)]?.calories ?? 0,
            sodiumMg: byDate[ymd(date)]?.sodiumMg ?? 0,
            sugarG: byDate[ymd(date)]?.sugarG ?? 0,
          ),
      ],
    );
  }

  /// A client's meals for the 식단 sub-tab, in seeded order (아침 → 저녁).
  @override
  Stream<List<ClientDietEntry>> watchDiet(String clientId) {
    final query = _db.select(_db.clientDietEntries)
      ..where((t) => t.clientId.equals(clientId))
      ..orderBy(<OrderingTerm Function($ClientDietEntriesTable)>[
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ClientDietEntry(
              meal: row.meal,
              items: row.items,
              calories: row.calories,
              sodiumMg: row.sodiumMg,
              carbsG: row.carbsG,
              proteinG: row.proteinG,
              fatG: row.fatG,
              photoAsset: row.photoAsset,
            ),
          )
          .toList(),
    );
  }

  /// A client's workout history for the 운동기록 sub-tab, newest first
  /// (seeded order).
  @override
  Stream<List<RoutineHistoryEntry>> watchHistory(String clientId) {
    final query = _db.select(_db.clientRoutineHistory)
      ..where((t) => t.clientId.equals(clientId))
      ..orderBy(<OrderingTerm Function($ClientRoutineHistoryTable)>[
        (t) => OrderingTerm(expression: t.sortOrder),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => RoutineHistoryEntry(
              dateLabel: row.dateLabel,
              label: row.label,
              completionRate: row.completionRate,
              exercises: (jsonDecode(row.exercisesJson) as List<Object?>)
                  .map((e) => e! as String)
                  .toList(),
              clientFeedback: row.clientFeedback,
              trainerNote: row.trainerNote,
            ),
          )
          .toList(),
    );
  }

  TrainerClient _toEntity(TrainerClientRow row) {
    final week = (jsonDecode(row.weekCompletionJson) as List<Object?>)
        .map((e) => e as int)
        .toList();
    final sodiumWeek = (jsonDecode(row.sodiumWeekJson) as List<Object?>)
        // On web, JSON numbers can decode as double — `as int` would
        // throw, so normalise through num (review PR 247).
        .map((e) => (e as num).toInt())
        .toList();
    final caloriesWeek = (jsonDecode(row.caloriesWeekJson) as List<Object?>)
        .map((e) => (e as num).toInt())
        .toList();
    // 당류는 소수를 유지한다 — 반올림하면 식단 탭 수치와 어긋난다(#746).
    final sugarWeek = (jsonDecode(row.sugarWeekJson) as List<Object?>)
        .map((e) => (e as num).toDouble())
        .toList();
    return TrainerClient(
      id: row.id,
      name: row.name,
      avatar: row.avatar,
      goal: row.goal,
      lastMessage: row.lastMessage,
      lastTime: row.lastTime,
      active: row.active,
      calories: row.caloriesToday,
      sodiumMg: row.sodiumMg,
      sugarG: row.sugarG,
      carbsG: row.carbsG,
      proteinG: row.proteinG,
      fatG: row.fatG,
      lastRoutine: row.lastRoutine,
      weekCompletion: week,
      sodiumWeek: sodiumWeek,
      caloriesWeek: caloriesWeek,
      sugarWeek: sugarWeek,
    );
  }
}

/// Provides the [ClientRepository]: the real Dio-backed source against the
/// FastAPI backend, or the local drift source for demo / `USE_MOCK_API=true`.
final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockApi) {
    return DriftClientRepository(ref.watch(appDatabaseProvider));
  }
  return DioClientRepository(ref.watch(dioProvider));
});

/// Streams the client list for the 고객 관리 tab.
final clientsProvider = StreamProvider<List<TrainerClient>>((ref) {
  return ref.watch(clientRepositoryProvider).watchClients();
});

/// Streams the coaching-priority ordering of the client list.
///
/// Sodium over-target first, ties broken by the most recent chat. ONE
/// rule for both modes — the ordering lives in the pure
/// [prioritizeClients], and each source just supplies what it has (drift
/// has chat times, the real roster endpoint doesn't yet).
///
/// Derived from [clientsProvider] rather than issuing its own read, so a
/// screen watching both (the list + detail split) doesn't trigger two
/// `GET /trainer/clients` calls.
///
/// A plain `Provider<AsyncValue<…>>`, not a `StreamProvider`: re-wrapping
/// the roster in a stream meant the loading branch had to return an empty
/// stream, and an empty stream *completes* — the provider then sat in
/// `AsyncLoading` forever with nothing left to emit. Mapping the
/// `AsyncValue` keeps loading/error/data flowing through untouched.
final prioritizedClientsProvider = Provider<AsyncValue<List<TrainerClient>>>((
  ref,
) {
  final lastChat =
      ref.watch(lastChatAtProvider).valueOrNull ?? const <String, DateTime>{};
  return ref
      .watch(clientsProvider)
      .whenData((clients) => prioritizeClients(clients, lastChatAt: lastChat));
});

/// Streams the last chat time per client (priority tiebreak).
final lastChatAtProvider = StreamProvider<Map<String, DateTime>>((ref) {
  return ref.watch(clientRepositoryProvider).watchLastChatAt();
});

/// Today's booked-session count for the dashboard KPI ('오늘 예약').
///
/// Derived from [todayScheduleProvider] rather than the roster: the count is
/// a property of the schedule, and the dashboard already subscribes to that
/// stream, so composing here avoids a second request for the same data.
/// 공백 slots are placeholders, not bookings, so they don't count. 완료한
/// 세션은 **센다** — 오늘 잡혀 있던 일정이라는 사실은 끝나도 변하지 않는다.
/// 남은 일감을 세는 자리는 [todayPendingSessionCountProvider] 다(#860).
///
/// Stays an [AsyncValue] on purpose. When the schedule is loading or failed
/// there is no honest number to show, and `valueOrNull` is null — the UI
/// hides the badge instead of claiming "0명 예약", which would be wrong.
final todayReservationCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(todayScheduleProvider)
      .whenData(
        // 취소된 약속은 빠진다(#871) — 이 숫자는 "오늘 몇 건이 잡혀 있나" 이고,
        // 취소는 그 예약이 거두어졌다는 뜻이다. 노쇼는 센다: 자리는 그대로 잡혀
        // 있었고 회원이 오지 않았을 뿐이다.
        (sessions) => sessions.where((s) => !s.isGap && !s.isCancelled).length,
      );
});

/// 사이드바 스케줄 배지가 읽는 **아직 처리하지 않은** 오늘 세션 수. (#860)
///
/// [todayReservationCountProvider] 와 나뉘어 있는 이유: 두 자리가 서로 다른
/// 질문에 답한다. 대시보드 KPI '오늘 예약' 은 "오늘 몇 건이 잡혀 있나" 이므로
/// 끝난 수업도 세는 것이 맞다. 배지는 "여기 처리할 게 남았다" 는 신호라, 이미
/// 완료한 세션까지 세면 트레이너가 탭에 들어가 확인하고 나서야 남은 건이 더
/// 적다는 것을 알게 된다 — 그런 배지는 몇 번 겪고 나면 안 보게 된다.
///
/// 공백 슬롯은 예약이 아니고, 완료 세션은 할 일이 아니다. 따라서 예정만 센다.
/// 대시보드의 임박 강조(`startsWithin`)가 이미 쓰는 규칙과 같다(#817).
///
/// [todayReservationCountProvider] 와 같은 이유로 [AsyncValue] 로 남는다 —
/// 스케줄을 못 읽으면 0 이 아니라 값 없음이고, 화면은 배지를 감춘다.
final todayPendingSessionCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(todayScheduleProvider)
      .whenData((sessions) => sessions.where((s) => s.isUpcoming).length);
});

/// Streams a client's meals for the 식단 sub-tab.
final clientDietProvider = StreamProvider.family<List<ClientDietEntry>, String>(
  (ref, clientId) {
    return ref.watch(clientRepositoryProvider).watchDiet(clientId);
  },
);

/// Streams a client's workout history for the 운동 sub-tab.
final clientHistoryProvider =
    StreamProvider.family<List<RoutineHistoryEntry>, String>((ref, clientId) {
      return ref.watch(clientRepositoryProvider).watchHistory(clientId);
    });

final clientExerciseWeekProvider =
    FutureProvider.family<ClientExerciseWeek, String>((ref, clientId) {
      return ref.watch(clientRepositoryProvider).fetchExerciseWeek(clientId);
    });

/// 고객 기간 조회의 조회 키 — 누구의, 어느 기간을, **어느 날 기준으로**.
///
/// [day] 가 키에 들어 있는 이유는 자정 때문이다. 범위를 provider 안에서
/// `nowKst()` 로 잡으면, 콘솔을 켜 둔 채 KST 자정을 넘겨도 같은 키의 캐시가
/// 어제 범위를 그대로 들고 있다 — 트레이너는 날이 바뀐 줄 모르고 어제의
/// `오늘` 을 본다. 날짜가 키의 일부면 다음 rebuild 에서 자연히 새 범위를 묻는다.
typedef ClientPeriodKey = ({
  String clientId,
  ClientPeriod period,
  DateTime day,
});

/// 지금(KST) 기준의 조회 키. 화면은 이 함수로 키를 만든다.
ClientPeriodKey clientPeriodKeyNow(String clientId, ClientPeriod period) =>
    (clientId: clientId, period: period, day: todayKst());

/// [ClientPeriodKey] 의 일별 식단 집계. (#914)
///
/// `autoDispose` 다 — 날이 바뀌면 어제 키는 아무도 보지 않게 되므로, 캐시가
/// 계속 쌓이지 않고 스스로 정리된다.
final clientDietPeriodProvider = FutureProvider.autoDispose
    .family<ClientDietPeriod, ClientPeriodKey>((ref, key) {
      return ref
          .watch(clientRepositoryProvider)
          .fetchDietPeriod(key.clientId, clientRangeFor(key.period, key.day));
    });

/// [ClientPeriodKey] 의 일별 운동 집계. (#914)
///
/// 범위가 걸친 주를 각각 읽어 이어 붙인다 — 서버도 데모도 운동 이력을 주
/// 단위로 들고 있다. 한 주만 보는 경우에는 요청도 한 번이다.
final clientExercisePeriodProvider = FutureProvider.autoDispose
    .family<ClientExercisePeriod, ClientPeriodKey>((ref, key) async {
      final repository = ref.watch(clientRepositoryProvider);
      final ClientDateRange range = clientRangeFor(key.period, key.day);
      final Map<String, ClientExerciseDay> byDate =
          <String, ClientExerciseDay>{};
      for (final DateTime monday in clientRangeWeekStarts(range)) {
        final ClientExerciseWeek week = await repository.fetchExerciseWeek(
          key.clientId,
          weekStart: monday,
        );
        for (var d = 0; d < 7; d++) {
          final DateTime date = DateTime(
            monday.year,
            monday.month,
            monday.day + d,
          );
          byDate[ymd(date)] = ClientExerciseDay(
            date: date,
            minutes: d < week.dailyMinutes.length ? week.dailyMinutes[d] : 0,
            calories: d < week.dailyCalories.length ? week.dailyCalories[d] : 0,
          );
        }
      }
      return ClientExercisePeriod(
        range: range,
        days: <ClientExerciseDay>[
          for (final DateTime date in clientRangeDates(range))
            byDate[ymd(date)] ?? ClientExerciseDay(date: date),
        ],
      );
    });
