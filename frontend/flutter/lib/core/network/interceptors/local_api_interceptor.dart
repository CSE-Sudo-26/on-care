import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart'
    show OrderClauseGenerator, OrderingMode, OrderingTerm, Value;
import 'package:logger/logger.dart';

import 'package:oncare/core/storage/app_database.dart';

/// A drift-backed dummy backend. Intercepts dio requests and serves
/// them out of the local SQLite database so the app can run as a
/// "local backend" before the real FastAPI server exists.
///
/// Path dispatch is done in `_handle()` — handlers return `null` to
/// fall through to the next interceptor (and ultimately to the real
/// network when `USE_MOCK_API=false`).
///
/// snake_case payloads are produced/consumed via
/// `core/network/case_mapper.dart` so the contract matches the real
/// server's Pydantic models.
class LocalApiInterceptor extends Interceptor {
  LocalApiInterceptor(this._db, this._logger);

  final AppDatabase _db;
  final Logger _logger;

  // Path-pattern → handler map. Static paths get O(1) dispatch;
  // path-with-id endpoints (`/diet/entries/{id}`) fall to the regex
  // section below.
  late final Map<String, _Handler> _routes = <String, _Handler>{
    'GET /ping': _ping,
    'GET /healthz': _healthz,
    'GET /version': _version,
    'GET /dashboard/summary': _dashboardSummary,
    'GET /diet/days/today': _dietToday,
    'POST /diet/analyze': _dietAnalyze,
    'GET /exercise/weeks/current': _exerciseCurrentWeek,
    'POST /exercise/sessions': _exerciseAddSession,
    'GET /schedule/events': _scheduleEvents,
    'POST /schedule/events': _scheduleCreate,
    'GET /notifications': _notifications,
    'GET /ai-coach/feedback': _aiCoachFeedback,
    'POST /ai-coach/chat': _aiCoachChat,
    'POST /auth/login': _authLogin,
    'POST /auth/register': _authRegister,
    'POST /auth/social/kakao': _authSocial,
    'POST /auth/social/google': _authSocial,
    'GET /users/me': _usersMe,
    'GET /users/me/profile': _usersMeProfile,
    'PUT /users/me': _usersMeUpdate,
    'DELETE /users/me': _usersMeDelete,
    'POST /users/me/onboarding': _usersMeOnboarding,
    'PUT /users/me/health-goals': _usersMeHealthGoals,
    'GET /users/me/health': _usersMeHealth,
    'GET /places/nearby': _placesNearby,
    // Vitals — three fixed kinds (weight | blood-pressure | blood-sugar).
    'POST /vitals/weight': _vitalsSubmit,
    'POST /vitals/blood-pressure': _vitalsSubmit,
    'POST /vitals/blood-sugar': _vitalsSubmit,
    'GET /vitals/weight/latest': _vitalsLatest,
    'GET /vitals/blood-pressure/latest': _vitalsLatest,
    'GET /vitals/blood-sugar/latest': _vitalsLatest,
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final response = await _safeHandle(options);
    if (response != null) {
      handler.resolve(response);
      return;
    }
    handler.next(options);
  }

  Future<Response<Object?>?> _safeHandle(RequestOptions options) async {
    final method = options.method.toUpperCase();
    final path = options.path;
    final key = '$method $path';

    try {
      // Static dispatch first.
      final exact = _routes[key];
      if (exact != null) {
        _logger.d('[local-api] $key (exact)');
        return await exact(options);
      }
      // Path-param routes (can't be keyed exactly) — e.g. DELETE by id.
      final param = _paramRoute(method, path);
      if (param != null) {
        _logger.d('[local-api] $key (param)');
        return await param(options);
      }
      return null;
    } catch (e, st) {
      _logger.e('[local-api] $key failed', error: e, stackTrace: st);
      return Response<Object?>(
        requestOptions: options,
        statusCode: 500,
        data: <String, Object?>{
          'code': 'internal_error',
          'message': e.toString(),
        },
      );
    }
  }

  /// Resolve a handler for path-param routes (id in the URL). Returns null
  /// if none matches so [_safeHandle] falls through to the real network.
  _Handler? _paramRoute(String method, String path) {
    if (method == 'DELETE' && path.startsWith('/diet/entries/')) {
      return _dietDelete;
    }
    if (method == 'DELETE' && path.startsWith('/exercise/sessions/')) {
      return _exerciseDelete;
    }
    if (method == 'PUT' && path.startsWith('/diet/entries/')) {
      return _dietUpdate;
    }
    if (method == 'PUT' && path.startsWith('/exercise/sessions/')) {
      return _exerciseUpdate;
    }
    return null;
  }

  Future<Response<Object?>> _dietDelete(RequestOptions options) async {
    final id = options.path.split('/').last;
    final n = await (_db.delete(
      _db.dietEntries,
    )..where((t) => t.id.equals(id))).go();
    if (n == 0) return _notFound(options, '식단 기록을 찾을 수 없습니다.');
    return _ok(options, <String, Object?>{'status': 'deleted'});
  }

  Future<Response<Object?>> _exerciseDelete(RequestOptions options) async {
    final id = options.path.split('/').last;
    final n = await (_db.delete(
      _db.exerciseSessions,
    )..where((t) => t.id.equals(id))).go();
    if (n == 0) return _notFound(options, '운동 기록을 찾을 수 없습니다.');
    return _ok(options, <String, Object?>{'status': 'deleted'});
  }

  Future<Response<Object?>> _exerciseUpdate(RequestOptions options) async {
    final id = options.path.split('/').last;
    final existing = await (_db.select(
      _db.exerciseSessions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return _notFound(options, '운동 기록을 찾을 수 없습니다.');
    final body = _jsonBody(options);
    final type = (body['type'] as String? ?? existing.type).trim();
    final minutes = (body['minutes'] as num?)?.toInt() ?? existing.minutes;
    final calories = (body['calories'] as num?)?.toInt() ?? existing.calories;
    final intensity = (body['intensity'] as String? ?? existing.intensity).trim();
    final dayRaw = (body['day_label'] as String? ?? '').trim();
    final dayLabel = dayRaw.isEmpty ? existing.dayLabel : dayRaw;
    await (_db.update(
      _db.exerciseSessions,
    )..where((t) => t.id.equals(id))).write(
      ExerciseSessionsCompanion(
        type: Value(type),
        minutes: Value(minutes),
        calories: Value(calories),
        intensity: Value(intensity),
        dayLabel: Value(dayLabel),
      ),
    );
    return _ok(options, <String, Object?>{
      'id': id,
      'day_label': dayLabel,
      'type': type,
      'minutes': minutes,
      'calories': calories,
      'intensity': intensity,
      'date_label': _dateLabelForDayLabel(dayLabel),
      'time_label': _defaultTimeLabel(type),
      'items': _defaultItems(type),
    });
  }

  Future<Response<Object?>> _dietUpdate(RequestOptions options) async {
    final id = options.path.split('/').last;
    final existing = await (_db.select(
      _db.dietEntries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return _notFound(options, '식단 기록을 찾을 수 없습니다.');
    final body = _jsonBody(options);
    final mealType = (body['meal_type'] as String?)?.trim();
    final timeLabel = (body['time_label'] as String?)?.trim();
    await (_db.update(_db.dietEntries)..where((t) => t.id.equals(id))).write(
      DietEntriesCompanion(
        mealType: (mealType == null || mealType.isEmpty)
            ? const Value.absent()
            : Value(mealType),
        timeLabel: timeLabel == null ? const Value.absent() : Value(timeLabel),
      ),
    );
    final row = await (_db.select(
      _db.dietEntries,
    )..where((t) => t.id.equals(id))).getSingle();
    final foods = jsonDecode(row.foodsJson) as List<Object?>;
    return _ok(options, <String, Object?>{
      'id': row.id,
      'meal_type': row.mealType,
      'time_label': row.timeLabel,
      'foods': foods,
      'total_calories': row.totalCalories,
      'sodium_mg': row.sodiumMg,
      'sugar_g': row.sugarG,
    });
  }

  // ---- handlers ----

  Future<Response<Object?>> _ping(RequestOptions options) async {
    return _ok(options, <String, Object?>{'message': 'pong (local)'});
  }

  Future<Response<Object?>> _healthz(RequestOptions options) async {
    return _ok(options, <String, Object?>{
      'status': 'ok',
      'backend': 'drift-local',
    });
  }

  Future<Response<Object?>> _version(RequestOptions options) async {
    return _ok(options, <String, Object?>{
      'api_version': 'v1',
      'app_version': '0.2.0+2',
    });
  }

  // ---- Dashboard ----

  Future<Response<Object?>> _dashboardSummary(RequestOptions options) async {
    final today = _todayDateString();

    // Diet aggregates.
    final dietRows = await (_db.select(
      _db.dietEntries,
    )..where((t) => t.date.equals(today))).get();
    int totalCalories = 0;
    int totalSodium = 0;
    int totalSugar = 0;
    for (final r in dietRows) {
      totalCalories += r.totalCalories;
      totalSodium += r.sodiumMg;
      totalSugar += r.sugarG;
    }

    // Exercise minutes for today's day-label.
    final todayLabel = _weekdayLabels[DateTime.now().weekday - 1];
    final weekStart = _mondayOfThisWeekString();
    // Two chained .where() calls are AND-joined by drift.
    final exerciseRows =
        await (_db.select(_db.exerciseSessions)
              ..where((t) => t.weekStart.equals(weekStart))
              ..where((t) => t.dayLabel.equals(todayLabel)))
            .get();
    int exerciseMinutes = 0;
    for (final r in exerciseRows) {
      exerciseMinutes += r.minutes;
    }

    // (혈당 row removed from the home summary per the latest design ref —
    // the indicator list now ends at 당류.)

    // Today's schedule items.
    final schedRows = await (_db.select(
      _db.scheduleEvents,
    )..where((t) => t.date.equals(today))).get();
    final schedJson = <Map<String, Object?>>[
      for (final r in schedRows)
        <String, Object?>{'time': r.time, 'title': r.title, 'emoji': r.emoji},
    ];

    // Heuristic "week score": stretch diet+exercise into a 0..100 band
    // so the card always renders something even on an empty database.
    final calRatio = (totalCalories / 2000.0).clamp(0.0, 1.0);
    final exRatio = (exerciseMinutes / 60.0).clamp(0.0, 1.0);
    final score = (50 + calRatio * 25 + exRatio * 25).round();

    return _ok(options, <String, Object?>{
      'indicators': <Map<String, Object?>>[
        <String, Object?>{
          'label': '칼로리',
          'current': totalCalories,
          'max': 2000,
          'unit': 'kcal',
        },
        <String, Object?>{
          'label': '나트륨',
          'current': totalSodium,
          'max': 2000,
          'unit': 'mg',
          'over_budget': totalSodium > 2000,
        },
        <String, Object?>{
          'label': '당류',
          'current': totalSugar,
          'max': 50,
          'unit': 'g',
        },
      ],
      'diet_entries': dietRows.length,
      'exercise_minutes': exerciseMinutes,
      'today_schedule': schedJson,
      'week_score': score,
      // Delta is a static demo number for now — full week-over-week
      // diff lands in a later phase.
      'week_score_delta': 12,
      'sodium_warning': totalSodium > 2000
          ? '오늘의 나트륨 섭취량이 높아요. 저녁에는 담백한 구이나 샐러드를 추천해요!'
          : null,
      'exercise_feedback': exerciseMinutes >= 60
          ? '오늘 운동 목표를 달성했어요! 마무리 스트레칭도 잊지 마세요.'
          : '주간 운동 목표 80%를 달성했어요! 오늘 가볍게 걷기를 더해 100%를 채워봐요!',
    });
  }

  // ---- Diet ----

  Future<Response<Object?>> _dietToday(RequestOptions options) async {
    final today = _todayDateString();
    final rows = await (_db.select(
      _db.dietEntries,
    )..where((t) => t.date.equals(today))).get();

    int totalCalories = 0;
    int totalSodium = 0;
    int totalSugar = 0;
    final entriesJson = <Map<String, Object?>>[];
    for (final r in rows) {
      totalCalories += r.totalCalories;
      totalSodium += r.sodiumMg;
      totalSugar += r.sugarG;
      entriesJson.add(<String, Object?>{
        'id': r.id,
        'meal_type': r.mealType,
        'time_label': r.timeLabel,
        'foods': (jsonDecode(r.foodsJson) as List<Object?>).cast<Object?>(),
        'total_calories': r.totalCalories,
        'sodium_mg': r.sodiumMg,
        'sugar_g': r.sugarG,
      });
    }

    return _ok(options, <String, Object?>{
      'entries': entriesJson,
      'total_calories': totalCalories,
      'total_sodium_mg': totalSodium,
      'total_sugar_g': totalSugar,
      // Macro breakdown isn't tracked per entry yet — return the
      // demo split until a richer schema lands.
      'macros': <String, Object?>{
        'carbs_pct': 50,
        'protein_pct': 30,
        'fat_pct': 20,
      },
      'ai_coach_message': totalSodium > 2000
          ? '오늘 점심에 나트륨이 많았어요. 저녁은 담백한 구이/샐러드로 균형을 맞춰봐요!'
          : '균형 잡힌 하루였어요. 내일도 이대로 가요!',
    });
  }

  /// POST /diet/analyze — the mock can't see the uploaded image, so it
  /// returns a deterministic "recognized" meal (nutrition from the same
  /// public DB the real backend maps to) and persists a diet entry to
  /// drift so it shows up in GET /diet/days/today. `diet-` id (not
  /// `seed-`) means seedIfEmpty never wipes it.
  Future<Response<Object?>> _dietAnalyze(RequestOptions options) async {
    // meal_type·idempotency_key 는 multipart FormData 또는 Map 에서 추출.
    String mealType = 'lunch';
    String? idempotencyKey;
    final data = options.data;
    if (data is FormData) {
      for (final MapEntry<String, String> f in data.fields) {
        if (f.key == 'meal_type' && f.value.isNotEmpty) mealType = f.value;
        if (f.key == 'idempotency_key' && f.value.isNotEmpty) {
          idempotencyKey = f.value;
        }
      }
    } else if (data is Map) {
      mealType = (data['meal_type'] as String?) ?? 'lunch';
      idempotencyKey = data['idempotency_key'] as String?;
    }

    // 같은 멱등키가 이미 저장돼 있으면 새로 저장하지 않고 기존 entry 를 반환(재시도 중복 방지).
    if (idempotencyKey != null) {
      final existing = await (_db.select(
        _db.dietEntries,
      )..where((t) => t.idempotencyKey.equals(idempotencyKey!))).getSingleOrNull();
      if (existing != null) {
        final storedFoods = (jsonDecode(existing.foodsJson) as List<Object?>)
            .cast<Map<String, Object?>>();
        return _ok(options, <String, Object?>{
          'entry_id': existing.id,
          'analysis': <String, Object?>{
            'engine': 'stub',
            'foods': storedFoods,
            'total_calories': existing.totalCalories,
            'total_sodium_mg': existing.sodiumMg,
            'total_sugar_g': existing.sugarG,
            'coach_comment': '',
          },
        });
      }
    }

    final foods = <Map<String, Object?>>[
      <String, Object?>{
        'name': '비빔밥',
        'calories': 600,
        'sodium_mg': 900,
        'sugar_g': 8,
        'source': 'db',
      },
      <String, Object?>{
        'name': '김치',
        'calories': 15,
        'sodium_mg': 300,
        'sugar_g': 1,
        'source': 'db',
      },
    ];
    const int totalCal = 615;
    const int totalNa = 1200;
    const int totalSugar = 9;
    const String coach = '비빔밥은 채소가 풍부해 좋아요. 나트륨이 다소 높으니 고추장·간장을 조금 줄여보세요.';

    final now = DateTime.now();
    final id = 'diet-${now.microsecondsSinceEpoch}';
    await _db
        .into(_db.dietEntries)
        .insert(
          DietEntriesCompanion.insert(
            id: id,
            date: _todayDateString(),
            mealType: mealType,
            timeLabel:
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            foodsJson: jsonEncode(foods),
            totalCalories: totalCal,
            sodiumMg: const Value(totalNa),
            sugarG: const Value(totalSugar),
            idempotencyKey: Value(idempotencyKey),
          ),
        );

    return _ok(options, <String, Object?>{
      'entry_id': id,
      'analysis': <String, Object?>{
        'engine': 'stub',
        'foods': foods,
        'total_calories': totalCal,
        'total_sodium_mg': totalNa,
        'total_sugar_g': totalSugar,
        'coach_comment': coach,
      },
    });
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ---- Exercise ----

  static const List<String> _weekdayLabels = <String>[
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  Future<Response<Object?>> _exerciseCurrentWeek(RequestOptions options) async {
    final weekStart = _mondayOfThisWeekString();
    final rows = await (_db.select(
      _db.exerciseSessions,
    )..where((t) => t.weekStart.equals(weekStart))).get();

    // Aggregate minutes per day-label so the bar chart can render even
    // when a day is missing (React mock left Tue=0).
    final perDay = <String, int>{for (final l in _weekdayLabels) l: 0};
    final perDayCardio = <String, int>{for (final l in _weekdayLabels) l: 0};
    final perDayStrength = <String, int>{for (final l in _weekdayLabels) l: 0};
    final perDayStretching = <String, int>{
      for (final l in _weekdayLabels) l: 0,
    };
    int totalMinutes = 0;
    int totalCalories = 0;
    final sessionsJson = <Map<String, Object?>>[];

    for (final r in rows) {
      totalMinutes += r.minutes;
      totalCalories += r.calories;
      perDay.update(
        r.dayLabel,
        (m) => m + r.minutes,
        ifAbsent: () => r.minutes,
      );
      final bucket = switch (r.type) {
        'cardio' || 'walking' => perDayCardio,
        'strength' => perDayStrength,
        'yoga' || 'stretching' => perDayStretching,
        _ => perDayCardio,
      };
      bucket.update(
        r.dayLabel,
        (m) => m + r.minutes,
        ifAbsent: () => r.minutes,
      );
      sessionsJson.add(<String, Object?>{
        'id': r.id,
        'day_label': r.dayLabel,
        'type': r.type,
        'minutes': r.minutes,
        'calories': r.calories,
        'intensity': r.intensity,
        // Date/time labels are synthesized here so the React-style
        // session list ("오늘", "어제", "MM월 DD일") works without
        // a schema migration on the drift `exerciseSessions` table.
        'date_label': _dateLabelForDayLabel(r.dayLabel),
        'time_label': _defaultTimeLabel(r.type),
        'items': _defaultItems(r.type),
      });
    }
    // Most recent first so the prototype's grouping (today / yesterday
    // / older) reads top-down.
    sessionsJson.sort((a, b) {
      final ai = _weekdayLabels.indexOf(a['day_label']! as String);
      final bi = _weekdayLabels.indexOf(b['day_label']! as String);
      return bi - ai;
    });

    final dailyMinutes = <num>[for (final l in _weekdayLabels) perDay[l] ?? 0];
    final cardioSeries = <num>[
      for (final l in _weekdayLabels) perDayCardio[l] ?? 0,
    ];
    final strengthSeries = <num>[
      for (final l in _weekdayLabels) perDayStrength[l] ?? 0,
    ];
    final stretchingSeries = <num>[
      for (final l in _weekdayLabels) perDayStretching[l] ?? 0,
    ];

    // "Streak" = consecutive non-zero days ending at today's weekday
    // (or simply the count of non-zero days for the simple mock).
    final streak = dailyMinutes.where((m) => m > 0).length;

    return _ok(options, <String, Object?>{
      'sessions': sessionsJson,
      'daily_minutes': dailyMinutes,
      'cardio_minutes': cardioSeries,
      'strength_minutes': strengthSeries,
      'stretching_minutes': stretchingSeries,
      'day_labels': _weekdayLabels,
      'total_minutes': totalMinutes,
      'total_calories': totalCalories,
      'streak_days': streak,
      'ai_coach_message': totalMinutes >= 240
          ? '주간 운동 목표 80%를 달성했어요! 오늘 가볍게 걷기를 더해 100%를 채워봐요.'
          : '이번 주는 운동량이 조금 부족해요. 가벼운 산책부터 다시 시작해 봐요.',
    });
  }

  /// "오늘 / 어제 / N요일 / MM월 DD일" for a given weekday label.
  String _dateLabelForDayLabel(String dayLabel) {
    final now = DateTime.now();
    final todayIdx = now.weekday - 1; // 0=Mon
    final dayIdx = _weekdayLabels.indexOf(dayLabel);
    if (dayIdx < 0) return dayLabel;
    final delta = todayIdx - dayIdx;
    if (delta == 0) return '오늘';
    if (delta == 1) return '어제';
    if (delta > 1 && delta <= 6) {
      final date = now.subtract(Duration(days: delta));
      return '${date.month}월 ${date.day}일';
    }
    return '$dayLabel요일';
  }

  String _defaultTimeLabel(String type) => switch (type) {
    'cardio' => '07:30',
    'strength' => '18:00',
    'yoga' || 'stretching' => '20:00',
    'walking' => '12:00',
    _ => '15:00',
  };

  List<String> _defaultItems(String type) => switch (type) {
    'cardio' => const <String>['러닝머신 30분'],
    'strength' => const <String>['스쿼트 3세트', '데드리프트 3세트'],
    'yoga' || 'stretching' => const <String>['전신 스트레칭 20분'],
    'walking' => const <String>['공원 산책'],
    _ => const <String>[],
  };

  /// POST /exercise/sessions — persist a workout into drift so the next
  /// GET /exercise/weeks/current includes it (stats + chart + list). The
  /// `ex-` id prefix (not `seed-`) means seedIfEmpty never wipes it.
  Future<Response<Object?>> _exerciseAddSession(RequestOptions options) async {
    final body = options.data;
    Map<String, Object?> payload;
    if (body is Map) {
      payload = body.cast<String, Object?>();
    } else if (body is String && body.isNotEmpty) {
      payload = (jsonDecode(body) as Map<Object?, Object?>)
          .cast<String, Object?>();
    } else {
      payload = <String, Object?>{};
    }

    final type = (payload['type'] as String?) ?? 'cardio';
    final minutes = (payload['minutes'] as num?)?.toInt() ?? 0;
    if (minutes <= 0) {
      return _badRequest(options, 'minutes must be > 0');
    }
    final calories = (payload['calories'] as num?)?.toInt() ?? 0;
    final intensity = (payload['intensity'] as String?) ?? 'moderate';
    final dayLabel =
        (payload['day_label'] as String?) ??
        _weekdayLabels[DateTime.now().weekday - 1];

    final id = 'ex-${DateTime.now().microsecondsSinceEpoch}';
    await _db
        .into(_db.exerciseSessions)
        .insert(
          ExerciseSessionsCompanion.insert(
            id: id,
            weekStart: _mondayOfThisWeekString(),
            dayLabel: dayLabel,
            type: type,
            minutes: minutes,
            calories: calories,
            intensity: Value(intensity),
          ),
        );

    return _ok(options, <String, Object?>{
      'id': id,
      'day_label': dayLabel,
      'type': type,
      'minutes': minutes,
      'calories': calories,
      'intensity': intensity,
      'date_label': _dateLabelForDayLabel(dayLabel),
      'time_label': _defaultTimeLabel(type),
      'items': _defaultItems(type),
    });
  }

  // ---- Schedule ----

  Future<Response<Object?>> _scheduleEvents(RequestOptions options) async {
    // `?month=YYYY-MM` → whole month (calendar grid); otherwise
    // `?date=YYYY-MM-DD` (defaults to today). Filtered in Dart to keep the
    // drift import minimal (no LIKE extension needed); the demo table is
    // tiny.
    final month = options.queryParameters['month'] as String?;
    final all = await _db.select(_db.scheduleEvents).get();
    final rows = (month != null && month.isNotEmpty)
        ? all.where((r) => r.date.startsWith('$month-')).toList()
        : () {
            final date =
                (options.queryParameters['date'] as String?) ??
                _todayDateString();
            return all.where((r) => r.date == date).toList();
          }();

    final list = <Map<String, Object?>>[
      for (final r in rows)
        <String, Object?>{
          'id': r.id,
          'date': r.date,
          'time': r.time,
          'title': r.title,
          'category': r.category,
          'emoji': r.emoji,
          'color_hex': r.colorHex,
        },
    ];
    return _ok(options, list);
  }

  /// Category → (emoji, color) so created events look consistent with the
  /// seeded ones. Mirrors what a FastAPI build would fill server-side.
  (String, String) _scheduleStyle(String category) => switch (category) {
    'hospital' => ('🏥', '#DBEAFE'),
    'exercise' => ('💪', '#DCFCE7'),
    'meal' => ('🍽️', '#FFEDD5'),
    'medication' => ('💊', '#EDE9FE'),
    _ => ('📌', '#E0F2F7'),
  };

  /// POST /schedule/events — persist a new event to drift so it shows up in
  /// GET /schedule/events and the dashboard's "오늘의 일정" for that date.
  Future<Response<Object?>> _scheduleCreate(RequestOptions options) async {
    final body = _jsonBody(options);
    final date = (body['date'] as String? ?? '').trim();
    final title = (body['title'] as String? ?? '').trim();
    if (date.isEmpty || title.isEmpty) {
      return _badRequest(options, 'date and title are required');
    }
    final time = (body['time'] as String? ?? '').trim();
    final category = (body['category'] as String? ?? 'other').trim();
    final (emoji, colorHex) = _scheduleStyle(category);
    final id = 'evt-${DateTime.now().microsecondsSinceEpoch}';
    await _db
        .into(_db.scheduleEvents)
        .insert(
          ScheduleEventsCompanion.insert(
            id: id,
            date: date,
            time: time,
            title: title,
            category: category,
            emoji: Value(emoji),
            colorHex: Value(colorHex),
          ),
        );
    return Response<Object?>(
      requestOptions: options,
      statusCode: 201,
      data: <String, Object?>{
        'id': id,
        'date': date,
        'time': time,
        'title': title,
        'category': category,
        'emoji': emoji,
        'color_hex': colorHex,
      },
    );
  }

  // ---- Notifications ----

  Future<Response<Object?>> _notifications(RequestOptions options) async {
    final query = _db.select(_db.notificationItems)
      ..orderBy(<OrderClauseGenerator<$NotificationItemsTable>>[
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();

    final now = DateTime.now();
    final list = <Map<String, Object?>>[
      for (final r in rows)
        <String, Object?>{
          'id': r.id,
          'title': r.title,
          'body': r.body,
          'category': r.category,
          'read': r.read,
          'created_at': r.createdAt.toIso8601String(),
          'time_ago': _timeAgoKorean(now.difference(r.createdAt)),
        },
    ];
    return _ok(options, list);
  }

  // ---- AI Coach ----

  Future<Response<Object?>> _aiCoachFeedback(RequestOptions options) async {
    return _ok(options, <String, Object?>{
      'greeting': '안녕하세요, 오늘 컨디션은 어떠세요?',
      'suggestions': <Map<String, Object?>>[
        <String, Object?>{
          'tag': 'diet',
          'title': '점심에 단백질을 +10g 추가해 보세요',
          'body': '오전 운동량을 보면 점심에 단백질을 조금 더 채우는 것이 좋아요.',
        },
        <String, Object?>{
          'tag': 'exercise',
          'title': '저녁 산책 15분',
          'body': '저녁 시간대 가벼운 유산소는 수면의 질도 함께 끌어올립니다.',
        },
        <String, Object?>{
          'tag': 'hydration',
          'title': '수분 보충',
          'body': '오늘 평소보다 활동량이 많았어요. 물 한 컵 더 마셔봐요.',
        },
      ],
    });
  }

  /// Interactive coach chat. Reads `{ message, history[] }` and returns
  /// `{ reply, sources[] }`. Keyword-matched canned answers grounded in the
  /// same public guidelines the real RAG backend seeds, so the demo (mock
  /// mode) exchanges real messages without a server.
  Future<Response<Object?>> _aiCoachChat(RequestOptions options) async {
    final body = options.data;
    Map<String, Object?> payload;
    if (body is Map) {
      payload = body.cast<String, Object?>();
    } else if (body is String && body.isNotEmpty) {
      payload = (jsonDecode(body) as Map<Object?, Object?>)
          .cast<String, Object?>();
    } else {
      payload = <String, Object?>{};
    }
    final message = (payload['message'] as String? ?? '').trim();
    if (message.isEmpty) {
      return _badRequest(options, 'message is empty');
    }

    final (String reply, List<String> sources) = _mockCoachReply(message);
    return _ok(options, <String, Object?>{'reply': reply, 'sources': sources});
  }

  (String, List<String>) _mockCoachReply(String message) {
    bool has(List<String> keys) => keys.any(message.contains);

    if (has(<String>['나트륨', '혈압', '짜', '소금', '국물'])) {
      return (
        '나트륨을 줄이려면 국물은 남기고 건더기 위주로 드시고, 소금 대신 후추·마늘·레몬으로 '
        '간을 해보세요. 하루 나트륨을 2000mg 이하로 맞추면 혈압 관리에 큰 도움이 돼요. 🌿',
        <String>['나트륨 줄이기', 'DASH 식단 개요'],
      );
    }
    if (has(<String>['당', '혈당', '설탕', '단 것', '디저트'])) {
      return (
        '혈당 관리를 위해 가당 음료와 디저트 같은 단순당을 줄이고, 식이섬유가 풍부한 통곡물·채소를 '
        '늘려보세요. 음료는 물이나 무가당 차로 바꾸는 것만으로도 효과가 좋아요. 🍵',
        <String>['당류 관리'],
      );
    }
    if (has(<String>['운동', '걷', '헬스', '유산소', '근력'])) {
      return (
        '빠르게 걷기 같은 중강도 유산소를 주 5회, 하루 30분씩 해보세요. 여기에 주 2회 가벼운 근력 '
        '운동을 더하면 혈압·혈당 관리에 특히 좋아요. 식후 10분 걷기도 큰 도움이 됩니다. 🚶',
        <String>['고혈압과 운동', '유산소와 근력 균형'],
      );
    }
    if (has(<String>['뭐 먹', '식단', '점심', '저녁', '아침', '메뉴'])) {
      return (
        '채소·통곡물·저지방 단백질 위주의 DASH 식단을 추천해요. 국·찌개는 싱겁게, 튀김보다 구이·찜으로 '
        '드시면 좋아요. 혹시 최근 나트륨이 높았다면 담백한 샐러드나 생선구이가 균형을 맞춰줘요. 🥗',
        <String>['DASH 식단 개요'],
      );
    }
    if (has(<String>['물', '수분'])) {
      return (
        '하루 6~8잔의 물을 나눠 마시는 것이 혈압과 신진대사에 도움이 돼요. 카페인·가당 음료는 줄이고 '
        '물로 대체해보세요. 💧',
        <String>['수분 섭취'],
      );
    }
    if (has(<String>['체중', '살', '다이어트', '몸무게'])) {
      return (
        '급격한 감량보다 식단과 운동을 병행한 완만한 감량이 안전해요. 체중을 5~10%만 줄여도 혈압·혈당 '
        '지표가 눈에 띄게 좋아질 수 있어요. 함께 천천히 가봐요! 💪',
        <String>['체중 관리'],
      );
    }
    return (
      '좋은 질문이에요! 식단·운동·혈압·혈당·수분 관리에 대해 더 구체적으로 물어봐 주시면 온이가 '
      '맞춤으로 도와드릴게요. 예를 들어 "나트륨 줄이는 법"이나 "오늘 뭐 먹을까?"처럼요. 😊',
      <String>[],
    );
  }

  // ---- Users / Me ----

  /// POST /auth/login — the demo accepts any non-empty credentials and
  /// issues a token so the login flow works without a server. Real
  /// credentials are validated by FastAPI when USE_MOCK_API=false.
  Future<Response<Object?>> _authLogin(RequestOptions options) async {
    final body = _jsonBody(options);
    final username = (body['username'] as String? ?? '').trim();
    final password = (body['password'] as String? ?? '').trim();
    if (username.isEmpty || password.isEmpty) {
      return _badRequest(options, 'username and password are required');
    }
    return _ok(options, <String, Object?>{
      'access_token': 'demo-access-${DateTime.now().microsecondsSinceEpoch}',
      'refresh_token': 'demo-refresh',
      'token_type': 'bearer',
    });
  }

  /// POST /auth/register — mirrors FastAPI: returns the created user
  /// `{id, name, email}` with 201. The demo accepts any non-empty
  /// email/password (real duplicate/validation is enforced by FastAPI
  /// when USE_MOCK_API=false). `name` defaults to the email local-part.
  Future<Response<Object?>> _authRegister(RequestOptions options) async {
    final body = _jsonBody(options);
    final email = (body['email'] as String? ?? '').trim();
    final password = (body['password'] as String? ?? '').trim();
    final name = (body['name'] as String? ?? '').trim();
    if (email.isEmpty || password.isEmpty) {
      return _badRequest(options, 'email and password are required');
    }
    return Response<Object?>(
      requestOptions: options,
      statusCode: 201,
      data: <String, Object?>{
        'id': 'user-${DateTime.now().microsecondsSinceEpoch}',
        'name': name.isEmpty ? email.split('@').first : name,
        'email': email,
      },
    );
  }

  /// POST /auth/social/{provider} — the demo exchanges any non-empty
  /// provider token for a session. Real provider-token verification is
  /// done by FastAPI (+ provider SDK) when USE_MOCK_API=false.
  Future<Response<Object?>> _authSocial(RequestOptions options) async {
    final body = _jsonBody(options);
    final token = (body['token'] as String? ?? '').trim();
    if (token.isEmpty) {
      return _badRequest(options, 'token is required');
    }
    return _ok(options, <String, Object?>{
      'access_token': 'demo-social-${DateTime.now().microsecondsSinceEpoch}',
      'refresh_token': 'demo-refresh',
      'token_type': 'bearer',
    });
  }

  // ---- Profile (내 프로필 / 건강 목표) — AppKeyValues 로 영속 ----

  static const Map<String, Object?> _defaultProfile = <String, Object?>{
    'id': 'user-demo',
    'name': '김민수',
    'email': 'minsu@oncare.com',
    'phone': '010-1234-5678',
    'birth_date': '1990-01-15',
    'gender': '',
    'conditions': '',
    'goals': '',
    'goal_weight_kg': 70,
    'goal_bp_systolic': 120,
    'goal_blood_sugar': 100,
    'daily_calories': 2000,
    'daily_sodium_mg': 2000,
    'onboarded': true,
  };

  Future<Map<String, Object?>> _readProfileOverlay() async {
    final raw = await _db.readValue('profile_overlay');
    if (raw == null || raw.isEmpty) return <String, Object?>{};
    return (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>();
  }

  Future<Map<String, Object?>> _mergedProfile() async {
    return <String, Object?>{..._defaultProfile, ...await _readProfileOverlay()};
  }

  Future<void> _mergeProfileOverlay(Map<String, Object?> patch) async {
    final overlay = await _readProfileOverlay();
    overlay.addAll(patch);
    await _db.putValue('profile_overlay', jsonEncode(overlay));
  }

  Future<Response<Object?>> _usersMe(RequestOptions options) async {
    final p = await _mergedProfile();
    return _ok(options, <String, Object?>{
      'id': p['id'],
      'name': p['name'],
      'email': p['email'],
    });
  }

  Future<Response<Object?>> _usersMeProfile(RequestOptions options) async {
    return _ok(options, await _mergedProfile());
  }

  Future<Response<Object?>> _usersMeUpdate(RequestOptions options) async {
    final body = _jsonBody(options);
    final patch = <String, Object?>{};
    for (final String k in <String>['name', 'email', 'phone', 'birth_date']) {
      if (body[k] != null) patch[k] = body[k];
    }
    await _mergeProfileOverlay(patch);
    return _ok(options, await _mergedProfile());
  }

  Future<Response<Object?>> _usersMeHealthGoals(RequestOptions options) async {
    final body = _jsonBody(options);
    final patch = <String, Object?>{};
    for (final String k in <String>[
      'goal_weight_kg',
      'goal_bp_systolic',
      'goal_blood_sugar',
      'daily_calories',
      'daily_sodium_mg',
    ]) {
      if (body[k] != null) patch[k] = body[k];
    }
    await _mergeProfileOverlay(patch);
    return _ok(options, await _mergedProfile());
  }

  /// DELETE /users/me — withdraw. The demo wipes the profile overlay so a
  /// subsequent session starts clean, mirroring FastAPI's cascade delete.
  Future<Response<Object?>> _usersMeDelete(RequestOptions options) async {
    await _db.putValue('profile_overlay', '');
    return _ok(options, <String, Object?>{'status': 'deleted'});
  }

  /// POST /users/me/onboarding — first-run setup. Persists any provided
  /// fields and marks the profile onboarded; mirrors FastAPI's partial save.
  Future<Response<Object?>> _usersMeOnboarding(RequestOptions options) async {
    final body = _jsonBody(options);
    final patch = <String, Object?>{};
    for (final String k in <String>[
      'name',
      'birth_date',
      'gender',
      'height_cm',
      'weight_kg',
      'conditions',
      'goals',
      'goal_weight_kg',
      'goal_bp_systolic',
      'goal_blood_sugar',
      'daily_calories',
      'daily_sodium_mg',
    ]) {
      if (body[k] != null) patch[k] = body[k];
    }
    patch['onboarded'] = true;
    await _mergeProfileOverlay(patch);
    return _ok(options, await _mergedProfile());
  }

  Future<Response<Object?>> _usersMeHealth(RequestOptions options) async {
    return _ok(options, <String, Object?>{
      'profile': <String, Object?>{'name': '김민수', 'email': 'minsu@oncare.com'},
      'risk': <String, Object?>{
        'title': '고혈압·당뇨 위험 주의',
        'body': '최근 혈압과 혈당 추세가 다소 높습니다. 식단·운동 관리에 신경 써주세요.',
        'level': 'medium',
      },
      'indicators': <Map<String, Object?>>[
        <String, Object?>{
          'kind': 'weight',
          'label': '체중',
          'latest_value': '72',
          'unit': 'kg',
          'delta_text': '-10kg (2주 전 대비)',
          'improving': true,
          'last_7_days': <double>[0.62, 0.58, 0.52, 0.45, 0.36, 0.28, 0.20],
          'chart_values': <double>[
            82, 80, 79, 78, 78, 77, 77, 76, 75, 75, 74, 73, 73, 72,
          ],
          'chart_min_y': 70,
          'chart_max_y': 75,
          'chart_interval': 1,
          'recent_records': <Map<String, Object?>>[
            <String, Object?>{'label': '오늘', 'value': '72 kg'},
            <String, Object?>{'label': '1일 전', 'value': '72 kg'},
            <String, Object?>{'label': '2일 전', 'value': '73 kg'},
            <String, Object?>{'label': '3일 전', 'value': '73 kg'},
            <String, Object?>{'label': '4일 전', 'value': '74 kg'},
          ],
        },
        <String, Object?>{
          'kind': 'blood-pressure',
          'label': '혈압',
          'latest_value': '124',
          'unit': 'mmHg',
          'delta_text': '-21mmHg (2주 전 대비)',
          'improving': true,
          'last_7_days': <double>[0.80, 0.74, 0.66, 0.55, 0.42, 0.28, 0.16],
          'chart_values': <double>[
            145, 144, 142, 140, 140, 138, 136, 134, 132, 130, 129, 127, 126, 124,
          ],
          'chart_min_y': 100,
          'chart_max_y': 140,
          'chart_interval': 10,
          'recent_records': <Map<String, Object?>>[
            <String, Object?>{'label': '오늘', 'value': '124 mmHg'},
            <String, Object?>{'label': '1일 전', 'value': '125 mmHg'},
            <String, Object?>{'label': '2일 전', 'value': '126 mmHg'},
            <String, Object?>{'label': '3일 전', 'value': '127 mmHg'},
            <String, Object?>{'label': '4일 전', 'value': '128 mmHg'},
          ],
        },
        <String, Object?>{
          'kind': 'blood-sugar',
          'label': '혈당',
          'latest_value': '96',
          'unit': 'mg/dL',
          'delta_text': '-32mg/dL (2주 전 대비)',
          'improving': true,
          'last_7_days': <double>[0.78, 0.70, 0.60, 0.50, 0.40, 0.30, 0.18],
          'chart_values': <double>[
            128, 124, 120, 118, 116, 113, 110, 108, 106, 104, 102, 100, 98, 96,
          ],
          'chart_min_y': 80,
          'chart_max_y': 140,
          'chart_interval': 20,
          'recent_records': <Map<String, Object?>>[
            <String, Object?>{'label': '오늘', 'value': '96 mg/dL'},
            <String, Object?>{'label': '1일 전', 'value': '98 mg/dL'},
            <String, Object?>{'label': '2일 전', 'value': '99 mg/dL'},
            <String, Object?>{'label': '3일 전', 'value': '100 mg/dL'},
            <String, Object?>{'label': '4일 전', 'value': '102 mg/dL'},
          ],
        },
      ],
      'activity_points': 1240,
      'activity_rank': 14,
      'settings': <Map<String, Object?>>[
        <String, Object?>{
          'label': '내 프로필',
          'icon': '👤',
          'kind': 'my-profile',
        },
        <String, Object?>{
          'label': '건강 목표',
          'icon': '📊',
          'kind': 'health-goal',
        },
        <String, Object?>{
          'label': '알림 설정',
          'icon': '🔔',
          'kind': 'notification',
        },
        <String, Object?>{
          'label': '고객 지원',
          'icon': '💬',
          'kind': 'support',
        },
      ],
    });
  }

  // ---- Places ----

  Future<Response<Object?>> _placesNearby(RequestOptions options) async {
    return _ok(options, <Map<String, Object?>>[
      <String, Object?>{
        'id': 'p1',
        'name': '강남세브란스 가정의학과',
        'category': 'medical',
        'address': '서울특별시 강남구 테헤란로 123',
        'distance_meters': 420,
        'lat': 37.4979,
        'lng': 127.0276,
      },
      <String, Object?>{
        'id': 'p2',
        'name': '온케어 피트니스',
        'category': 'fitness',
        'address': '서울특별시 강남구 역삼로 55',
        'distance_meters': 680,
        'lat': 37.5005,
        'lng': 127.0319,
      },
      <String, Object?>{
        'id': 'p3',
        'name': '그린 샐러드 바',
        'category': 'healthy_food',
        'address': '서울특별시 강남구 강남대로 311',
        'distance_meters': 250,
        'lat': 37.4970,
        'lng': 127.0270,
      },
      <String, Object?>{
        'id': 'p4',
        'name': '24시간 메디팜약국',
        'category': 'pharmacy',
        'address': '서울특별시 강남구 테헤란로 99',
        'distance_meters': 800,
        'lat': 37.4995,
        'lng': 127.0263,
      },
    ]);
  }

  String _timeAgoKorean(Duration d) {
    if (d.inMinutes < 1) return '방금';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    if (d.inDays == 1) return '어제';
    return '${d.inDays}일 전';
  }

  String _mondayOfThisWeekString() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  // ---- Vitals ----

  /// Path tail → drift `kind` value. Centralised so POST and GET
  /// agree on the same string.
  String? _kindFromPath(String path) {
    if (path.startsWith('/vitals/weight')) return 'weight';
    if (path.startsWith('/vitals/blood-pressure')) return 'blood-pressure';
    if (path.startsWith('/vitals/blood-sugar')) return 'blood-sugar';
    return null;
  }

  Future<Response<Object?>> _vitalsSubmit(RequestOptions options) async {
    final kind = _kindFromPath(options.path);
    if (kind == null) {
      return _badRequest(options, 'unknown vital kind: ${options.path}');
    }

    final body = options.data;
    Map<String, Object?> payload;
    if (body is Map) {
      payload = body.cast<String, Object?>();
    } else if (body is String && body.isNotEmpty) {
      payload = (jsonDecode(body) as Map<Object?, Object?>)
          .cast<String, Object?>();
    } else {
      payload = <String, Object?>{};
    }

    // Pluck `recorded_at` off the payload (if provided) and store the
    // rest as the value blob.
    final recordedAtRaw = payload.remove('recorded_at');
    final recordedAt = recordedAtRaw is String && recordedAtRaw.isNotEmpty
        ? DateTime.parse(recordedAtRaw)
        : DateTime.now();

    final id = 'v-${DateTime.now().microsecondsSinceEpoch}';
    await _db
        .into(_db.vitals)
        .insert(
          VitalsCompanion(
            id: Value<String>(id),
            kind: Value<String>(kind),
            valueJson: Value<String>(jsonEncode(payload)),
            recordedAt: Value<DateTime>(recordedAt),
          ),
        );

    return _ok(options, <String, Object?>{
      'id': id,
      'kind': kind,
      'value': payload,
      'recorded_at': recordedAt.toIso8601String(),
    });
  }

  Future<Response<Object?>> _vitalsLatest(RequestOptions options) async {
    final kind = _kindFromPath(options.path);
    if (kind == null) {
      return _badRequest(options, 'unknown vital kind: ${options.path}');
    }

    final query = _db.select(_db.vitals)
      ..where((t) => t.kind.equals(kind))
      ..orderBy(<OrderClauseGenerator<$VitalsTable>>[
        (t) => OrderingTerm(expression: t.recordedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();

    if (row == null) {
      // No reading yet — return a 200 with empty body so the client
      // can treat null as "no data". (FastAPI will mirror this with
      // an explicit nullable response model.)
      return _ok(options, <String, Object?>{});
    }

    return _ok(options, <String, Object?>{
      'id': row.id,
      'kind': row.kind,
      'value': (jsonDecode(row.valueJson) as Map<Object?, Object?>)
          .cast<String, Object?>(),
      'recorded_at': row.recordedAt.toIso8601String(),
    });
  }

  // ---- helpers ----

  /// Parse a request body (JSON Map or raw String) into a Map.
  Map<String, Object?> _jsonBody(RequestOptions options) {
    final body = options.data;
    if (body is Map) return body.cast<String, Object?>();
    if (body is String && body.isNotEmpty) {
      return (jsonDecode(body) as Map<Object?, Object?>).cast<String, Object?>();
    }
    return <String, Object?>{};
  }

  /// Build a 200 OK response carrying [body]. Subclasses of handlers
  /// will build their bodies as plain Map/List structures (snake_case)
  /// before passing in.
  Response<Object?> _ok(RequestOptions options, Object? body) {
    return Response<Object?>(
      requestOptions: options,
      statusCode: 200,
      data: body,
    );
  }

  Response<Object?> _badRequest(RequestOptions options, String message) {
    return Response<Object?>(
      requestOptions: options,
      statusCode: 400,
      data: <String, Object?>{'code': 'bad_request', 'message': message},
    );
  }

  Response<Object?> _notFound(RequestOptions options, String message) {
    return Response<Object?>(
      requestOptions: options,
      statusCode: 404,
      data: <String, Object?>{'code': 'not_found', 'message': message},
    );
  }

  /// Expose the database to test scaffolding without leaking internals.
  AppDatabase get database => _db;
}

typedef _Handler = Future<Response<Object?>> Function(RequestOptions);
