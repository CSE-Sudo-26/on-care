import 'dart:typed_data';

import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';

/// In-memory stateful mock for demo mode (`useMockApi`). Seeds today's
/// "짬뽕 점심" scenario, then keeps analyze(=add)/update/delete in memory for
/// the app session so the diet-tab list and the "오늘의 영양 요약" totals
/// reflect edits made through the app (issue #294). A single instance is
/// created by [dietRepositoryProvider] and lives for the session, so the drift
/// persists until the app is restarted.
///
/// Per-food nutrition of the two seeded meals is the single source of truth
/// (아침 217/221/6.3 + 점심 750/3,200/8.5 = 967/3,421/14.8); CRUD only applies
/// deltas on top of the seeded totals. Macro percentages aren't derivable from
/// per-food data, so they stay fixed.
class MockDietRepository implements DietRepository {
  MockDietRepository();

  static const DietMacros _macros = DietMacros(
    carbsPct: 50,
    proteinPct: 30,
    fatPct: 20,
  );
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
      photoAsset: 'assets/images/breakfast-scrambled-egg-strawberry.jpg',
      aiComment: '단백질과 식이섬유의 깔끔한 조합으로, 소금 간과 기름만 조절하면 혈당과 혈압 모두 잡는 우수한 식단입니다.',
      foods: <FoodItem>[
        FoodItem(name: '스크램블 에그', calories: 185, sodiumMg: 220, sugarG: 0.8),
        FoodItem(name: '딸기', calories: 32, sodiumMg: 1, sugarG: 5.5),
      ],
    ),
    const DietEntry(
      id: 'mock-lunch',
      mealType: MealType.lunch,
      timeLabel: '12:40',
      totalCalories: 750,
      sodiumMg: 3200,
      sugarG: 8.5,
      photoAsset: 'assets/images/lunch-jjamppong.jpg',
      aiComment: '정제 면과 높은 나트륨으로 혈압·혈당 부담이 매우 크니, 국물은 남기고 해물과 야채 위주로 드시는 것이 좋습니다.',
      foods: <FoodItem>[
        FoodItem(name: '짬뽕', calories: 750, sodiumMg: 3200, sugarG: 8.5),
      ],
    ),
  ];

  int _totalCalories = 967;
  int _totalSodiumMg = 3421;
  double _totalSugarG = 14.8;
  int _seq = 0;

  // idempotencyKey → 이미 기록한 분석 결과. 응답 유실 후 재시도(같은 키)에
  // 중복 기록되지 않도록 실제 서버의 멱등 동작을 흉내낸다.
  final Map<String, DietAnalysisResult> _analyzed = <String, DietAnalysisResult>{};

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
      macros: _macros,
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
      _totalSugarG = _nonNegDouble(
        _totalSugarG + updated.sugarG - old.sugarG,
      );
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
