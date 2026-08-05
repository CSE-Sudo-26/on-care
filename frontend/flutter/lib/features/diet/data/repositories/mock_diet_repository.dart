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
      '점심 짬뽕으로 나트륨과 혈당 부담이 크게 높아졌어요! 오늘 저녁은 간을 하지 않은 두부/닭가슴살 샐러드나 채소 위주 식단으로 가볍게 드시고, 물을 자주 드셔주세요.';

  final List<DietEntry> _entries = <DietEntry>[
    const DietEntry(
      id: 'mock-breakfast',
      mealType: MealType.breakfast,
      timeLabel: '08:20',
      totalCalories: 217,
      sodiumMg: 221,
      sugarG: 6.3,
      carbsG: 10,
      proteinG: 13.5,
      fatG: 14.5,
      photoAsset: 'assets/images/breakfast-scrambled-egg-strawberry.jpg',
      aiComment: '단백질과 식이섬유의 깔끔한 조합으로, 소금 간과 기름만 조절하면 혈당과 혈압 모두 잡는 우수한 식단입니다.',
      foods: <FoodItem>[
        FoodItem(
          name: '스크램블 에그',
          calories: 185,
          sodiumMg: 220,
          sugarG: 0.8,
          carbsG: 2,
          proteinG: 13,
          fatG: 14,
        ),
        FoodItem(
          name: '딸기',
          calories: 32,
          sodiumMg: 1,
          sugarG: 5.5,
          carbsG: 8,
          proteinG: 0.5,
          fatG: 0.5,
        ),
      ],
    ),
    const DietEntry(
      id: 'mock-lunch',
      mealType: MealType.lunch,
      timeLabel: '12:40',
      totalCalories: 750,
      sodiumMg: 3200,
      sugarG: 8.5,
      // 오늘 3끼 합계가 탄120·단45·지45g(→ 45/17/38%)이 되도록 맞춘 값.
      // 홈 대시보드 시드(seed_data.dart)의 짬뽕과 동일하게 유지한다.
      carbsG: 107,
      proteinG: 29,
      fatG: 22.5,
      photoAsset: 'assets/images/lunch-jjamppong.jpg',
      aiComment: '정제 면과 높은 나트륨으로 혈압·혈당 부담이 매우 크니, 국물은 남기고 야채 위주로 드시는 것이 좋습니다.',
      foods: <FoodItem>[
        FoodItem(
          name: '짬뽕',
          calories: 750,
          sodiumMg: 3200,
          sugarG: 8.5,
          carbsG: 107,
          proteinG: 29,
          fatG: 22.5,
        ),
      ],
    ),
    const DietEntry(
      id: 'mock-snack',
      mealType: MealType.snack,
      timeLabel: '15:30',
      totalCalories: 100,
      sodiumMg: 7,
      sugarG: 3,
      carbsG: 3,
      proteinG: 2.5,
      fatG: 8,
      photoAsset: 'assets/images/snack-coffee-nuts.jpg',
      aiComment: '당류와 칼로리가 낮고 견과류의 건강한 지방이 채워져 완벽한 간식입니다.',
      foods: <FoodItem>[
        FoodItem(
          name: '아이스 아메리카노',
          calories: 10,
          sodiumMg: 5,
          carbsG: 2,
          proteinG: 0.5,
        ),
        FoodItem(
          name: '견과류 한 봉',
          calories: 90,
          sodiumMg: 2,
          sugarG: 3,
          carbsG: 1,
          proteinG: 2,
          fatG: 8,
        ),
      ],
    ),
  ];

  int _totalCalories = 1067;
  int _totalSodiumMg = 3428;
  double _totalSugarG = 17.8;
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
      totalSugarG: sugar,
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
