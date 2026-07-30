import 'dart:typed_data';

import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';

/// In-memory stateful mock for demo mode (`useMockApi`). Seeds a realistic day,
/// then keeps analyze(=add)/update/delete in memory for
/// the app session so the diet-tab list and the "오늘의 영양 요약" totals
/// reflect edits made through the app (issue #294). A single instance is
/// created by [dietRepositoryProvider] and lives for the session, so the drift
/// persists until the app is restarted.
///
/// Per-food nutrition is the single source of truth for the seeded meal and
/// daily totals. CRUD applies calories, sodium, and sugar deltas on top of the
/// seed; macro totals are derived from the current entries.
class MockDietRepository implements DietRepository {
  MockDietRepository();

  static const String _aiCoachMessage =
      '오늘 나트륨 섭취량이 권장량을 초과했어요. 점심의 김치찌개와 배추김치가 가장 큰 영향을 주었어요.';

  final List<DietEntry> _entries = <DietEntry>[
    const DietEntry(
      id: 'mock-breakfast',
      mealType: MealType.breakfast,
      timeLabel: '08:20',
      totalCalories: 330,
      sodiumMg: 136,
      sugarG: 22,
      carbsG: 39.6,
      proteinG: 21.8,
      fatG: 9.7,
      aiComment: '요거트와 달걀로 단백질을 챙기고 바나나로 아침 에너지를 보충했어요.',
      foods: <FoodItem>[
        FoodItem(
          name: '그릭요거트',
          calories: 150,
          sodiumMg: 70,
          sugarG: 8,
          carbsG: 12,
          proteinG: 14,
          fatG: 4,
        ),
        FoodItem(
          name: '바나나',
          calories: 105,
          sodiumMg: 1,
          sugarG: 14,
          carbsG: 27,
          proteinG: 1.3,
          fatG: 0.4,
        ),
        FoodItem(
          name: '삶은 달걀',
          calories: 75,
          sodiumMg: 65,
          carbsG: 0.6,
          proteinG: 6.5,
          fatG: 5.3,
        ),
      ],
    ),
    const DietEntry(
      id: 'mock-lunch',
      mealType: MealType.lunch,
      timeLabel: '12:40',
      totalCalories: 780,
      sodiumMg: 1643,
      sugarG: 7,
      carbsG: 86,
      proteinG: 40,
      fatG: 29.3,
      aiComment: '김치찌개와 반찬의 간으로 나트륨이 높아 국물과 김치 양을 줄이는 편이 좋아요.',
      foods: <FoodItem>[
        FoodItem(
          name: '김치찌개',
          calories: 285,
          sodiumMg: 900,
          sugarG: 4,
          carbsG: 16,
          proteinG: 20,
          fatG: 15.5,
        ),
        FoodItem(
          name: '흰쌀밥',
          calories: 280,
          sodiumMg: 3,
          carbsG: 61,
          proteinG: 5.5,
          fatG: 0.5,
        ),
        FoodItem(
          name: '계란말이',
          calories: 190,
          sodiumMg: 320,
          sugarG: 1,
          carbsG: 5,
          proteinG: 13,
          fatG: 13,
        ),
        FoodItem(
          name: '배추김치',
          calories: 25,
          sodiumMg: 420,
          sugarG: 2,
          carbsG: 4,
          proteinG: 1.5,
          fatG: 0.3,
        ),
      ],
    ),
    const DietEntry(
      id: 'mock-snack',
      mealType: MealType.snack,
      timeLabel: '15:30',
      totalCalories: 180,
      sodiumMg: 15,
      sugarG: 3,
      carbsG: 9,
      proteinG: 6.5,
      fatG: 13,
      foods: <FoodItem>[
        FoodItem(
          name: '아이스 아메리카노',
          calories: 10,
          sodiumMg: 10,
          carbsG: 2,
          proteinG: 0.5,
        ),
        FoodItem(
          name: '견과류 한 봉',
          calories: 170,
          sodiumMg: 5,
          sugarG: 3,
          carbsG: 7,
          proteinG: 6,
          fatG: 13,
        ),
      ],
    ),
    const DietEntry(
      id: 'mock-dinner',
      mealType: MealType.dinner,
      timeLabel: '19:00',
      totalCalories: 570,
      sodiumMg: 535,
      sugarG: 11,
      carbsG: 69,
      proteinG: 41,
      fatG: 14.5,
      foods: <FoodItem>[
        FoodItem(
          name: '닭가슴살 샐러드',
          calories: 260,
          sodiumMg: 180,
          sugarG: 4,
          carbsG: 14,
          proteinG: 36,
          fatG: 6.7,
        ),
        FoodItem(
          name: '현미밥',
          calories: 220,
          sodiumMg: 5,
          sugarG: 1,
          carbsG: 46,
          proteinG: 5,
          fatG: 1.8,
        ),
        FoodItem(
          name: '오리엔탈 드레싱',
          calories: 90,
          sodiumMg: 350,
          sugarG: 6,
          carbsG: 9,
          fatG: 6,
        ),
      ],
    ),
  ];

  int _totalCalories = 1860;
  int _totalSodiumMg = 2329;
  double _totalSugarG = 43;
  int _seq = 0;

  // idempotencyKey → 이미 기록한 분석 결과. 응답 유실 후 재시도(같은 키)에
  // 중복 기록되지 않도록 실제 서버의 멱등 동작을 흉내낸다.
  final Map<String, DietAnalysisResult> _analyzed =
      <String, DietAnalysisResult>{};

  @override
  Future<DietAnalysisResult> analyze({
    required Uint8List imageBytes,
    required String filename,
    required String mealType,
    String? idempotencyKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (idempotencyKey != null && _analyzed.containsKey(idempotencyKey)) {
      return _analyzed[idempotencyKey]!;
    }

    // 데모 모드는 실제 이미지 인식 대신 고정 결과(비빔밥+김치)를 반환한다.
    const List<RecognizedFood> foods = <RecognizedFood>[
      RecognizedFood(
        name: '비빔밥',
        calories: 600,
        sodiumMg: 900,
        sugarG: 8,
        source: 'db',
      ),
      RecognizedFood(
        name: '김치',
        calories: 15,
        sodiumMg: 300,
        sugarG: 1,
        source: 'db',
      ),
    ];
    const int cals = 615;
    const int sodium = 1200;
    const double sugar = 9;
    const String coach = '비빔밥은 채소가 풍부해 좋아요. 나트륨이 다소 높으니 장을 줄여보세요.';

    final String id = 'mock-diet-${++_seq}';
    _entries.add(
      DietEntry(
        id: id,
        mealType: _mealTypeOf(mealType),
        timeLabel: _nowLabel(),
        totalCalories: cals,
        sodiumMg: sodium,
        sugarG: sugar,
        aiComment: coach,
        foods: foods
            .map(
              (RecognizedFood f) => FoodItem(
                name: f.name,
                calories: f.calories,
                sodiumMg: f.sodiumMg,
                sugarG: f.sugarG.toDouble(),
              ),
            )
            .toList(),
      ),
    );
    _totalCalories += cals;
    _totalSodiumMg += sodium;
    _totalSugarG += sugar;

    final DietAnalysisResult result = DietAnalysisResult(
      entryId: id,
      foods: foods,
      totalCalories: cals,
      totalSodiumMg: sodium,
      totalSugarG: sugar.toInt(),
      coachComment: coach,
    );
    if (idempotencyKey != null) _analyzed[idempotencyKey] = result;
    return result;
  }

  @override
  Future<DietDay> fetchToday() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return DietDay(
      entries: List<DietEntry>.of(_entries),
      totalCalories: _totalCalories,
      totalSodiumMg: _totalSodiumMg,
      totalSugarG: _totalSugarG,
      macros: _toDietMacros(_sumMacroGrams(_entries)),
      aiCoachMessage: _aiCoachMessage,
    );
  }

  @override
  Future<void> deleteEntry(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final int idx = _entries.indexWhere((DietEntry e) => e.id == id);
    if (idx < 0) return;
    final DietEntry e = _entries[idx];
    _totalCalories = _nonNegInt(_totalCalories - e.totalCalories);
    _totalSodiumMg = _nonNegInt(_totalSodiumMg - e.sodiumMg);
    _totalSugarG = _nonNegDouble(_totalSugarG - e.sugarG);
    _entries.removeAt(idx);
    // 이 항목을 가리키던 멱등 캐시 키를 제거한다. 안 그러면 삭제 후 같은
    // idempotencyKey 로 재요청할 때 이미 사라진 항목의 낡은 결과만 반환되고
    // 목록에는 다시 추가되지 않는다(같은 키를 재기록 가능 상태로 되돌린다).
    _analyzed.removeWhere((String _, DietAnalysisResult r) => r.entryId == id);
  }

  @override
  Future<DietEntry> updateEntry({
    required String id,
    String? mealType,
    String? timeLabel,
    List<FoodItem>? foods,
    int? totalCalories,
    int? sodiumMg,
    double? sugarG,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final int idx = _entries.indexWhere((DietEntry e) => e.id == id);
    final DietEntry? old = idx >= 0 ? _entries[idx] : null;
    final List<FoodItem> updatedFoods =
        foods ?? old?.foods ?? const <FoodItem>[];
    final DietEntry updated = DietEntry(
      id: id,
      mealType: mealType != null
          ? MealType.values.byName(mealType)
          : (old?.mealType ?? MealType.lunch),
      timeLabel: timeLabel ?? old?.timeLabel ?? '',
      totalCalories:
          totalCalories ??
          updatedFoods.fold<int>(0, (int sum, FoodItem f) => sum + f.calories),
      sodiumMg: sodiumMg ?? old?.sodiumMg ?? 0,
      sugarG: sugarG ?? old?.sugarG ?? 0,
      carbsG: updatedFoods.fold<double>(
        0,
        (double sum, FoodItem food) => sum + food.carbsG,
      ),
      proteinG: updatedFoods.fold<double>(
        0,
        (double sum, FoodItem food) => sum + food.proteinG,
      ),
      fatG: updatedFoods.fold<double>(
        0,
        (double sum, FoodItem food) => sum + food.fatG,
      ),
      aiComment: old?.aiComment ?? '',
      photoAsset: old?.photoAsset,
      foods: updatedFoods,
    );
    if (old != null) {
      _totalCalories = _nonNegInt(
        _totalCalories + updated.totalCalories - old.totalCalories,
      );
      _totalSodiumMg = _nonNegInt(
        _totalSodiumMg + updated.sodiumMg - old.sodiumMg,
      );
      _totalSugarG = _nonNegDouble(_totalSugarG + updated.sugarG - old.sugarG);
      _entries[idx] = updated;
    }
    return updated;
  }

  MealType _mealTypeOf(String name) {
    for (final MealType m in MealType.values) {
      if (m.name == name) return m;
    }
    return MealType.snack;
  }

  String _nowLabel() {
    final DateTime now = DateTime.now();
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  int _nonNegInt(int v) => v < 0 ? 0 : v;
  double _nonNegDouble(double v) => v < 0 ? 0 : v;
}

typedef _MacroGrams = ({double carbsG, double proteinG, double fatG});

_MacroGrams _sumMacroGrams(Iterable<DietEntry> entries) => (
  carbsG: entries.fold<double>(
    0,
    (double sum, DietEntry entry) => sum + entry.carbsG,
  ),
  proteinG: entries.fold<double>(
    0,
    (double sum, DietEntry entry) => sum + entry.proteinG,
  ),
  fatG: entries.fold<double>(
    0,
    (double sum, DietEntry entry) => sum + entry.fatG,
  ),
);

// Keep this 4/4/9 largest-remainder calculation in sync with
// the backend calculate_macros implementation.
DietMacros _toDietMacros(_MacroGrams grams) {
  final energies = <double>[
    grams.carbsG * 4,
    grams.proteinG * 4,
    grams.fatG * 9,
  ];
  final totalEnergy = energies.fold<double>(
    0,
    (double sum, double energy) => sum + energy,
  );
  final percentages = <int>[0, 0, 0];
  if (totalEnergy > 0) {
    final raw = energies
        .map((double energy) => energy / totalEnergy * 100)
        .toList();
    for (var index = 0; index < percentages.length; index++) {
      percentages[index] = raw[index].floor();
    }
    final ranked = <int>[0, 1, 2]
      ..sort((int a, int b) {
        final fraction = (raw[b] - percentages[b]).compareTo(
          raw[a] - percentages[a],
        );
        return fraction == 0 ? b.compareTo(a) : fraction;
      });
    final remaining =
        100 - percentages.fold<int>(0, (int sum, int value) => sum + value);
    for (final index in ranked.take(remaining)) {
      percentages[index]++;
    }
  }
  return DietMacros(
    carbsG: grams.carbsG,
    proteinG: grams.proteinG,
    fatG: grams.fatG,
    carbsPct: percentages[0],
    proteinPct: percentages[1],
    fatPct: percentages[2],
  );
}
