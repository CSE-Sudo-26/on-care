import 'package:dio/dio.dart';

import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/entities/meal_photo.dart';
import 'package:oncare/features/diet/domain/entities/meal_recommendation.dart';
import 'package:oncare/features/diet/domain/repositories/diet_repository.dart';

/// Real-network implementation of [DietRepository]. Issues HTTP
/// requests via [Dio]; the dev/local build serves them out of
/// `LocalApiInterceptor` (drift-backed). FastAPI takes over once
/// `USE_MOCK_API=false`.
class DioDietRepository implements DietRepository {
  DioDietRepository(this._dio);
  static const Duration _entryOverrideTtl = Duration(minutes: 5);

  final Dio _dio;
  final Map<String, DietEntry> _entryOverrides = <String, DietEntry>{};
  final Map<String, DateTime> _entryOverrideUpdatedAt = <String, DateTime>{};

  @override
  Future<DietDay> fetchToday() async {
    final res = await _dio.get<Map<String, Object?>>('/diet/days/today');
    final day = DietDay.fromJson(res.data!);
    _pruneStaleOverrides(day);
    return _applyOverrides(day);
  }

  @override
  Future<DietDay> fetchByDate(DateTime date) async {
    final res = await _dio.get<Map<String, Object?>>(
      '/diet/days/${_formatDate(date)}',
    );
    return DietDay.fromJson(res.data!);
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Future<MealRecommendations> fetchRecommendations() async {
    final res = await _dio.get<Map<String, Object?>>('/diet/recommendations');
    return MealRecommendations.fromJson(res.data!);
  }

  @override
  Future<DietAnalysisResult> analyze({
    required MealPhoto photo,
    required String mealType,
    String? idempotencyKey,
  }) async {
    final form = FormData.fromMap(<String, Object?>{
      'image': MultipartFile.fromBytes(
        photo.bytes,
        filename: photo.filename,
        // Sniffed from the bytes — the server 415s when the declared MIME
        // doesn't match what it can decode (an iPhone HEIC sent as JPEG).
        contentType: DioMediaType.parse(photo.mimeType),
      ),
      'meal_type': mealType,
      'idempotency_key': ?idempotencyKey,
    });
    final res = await _dio.post<Map<String, Object?>>(
      '/diet/analyze',
      data: form,
    );
    return DietAnalysisResult.fromResponse(res.data!);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _dio.delete<Map<String, Object?>>('/diet/entries/$id');
    _entryOverrides.remove(id);
    _entryOverrideUpdatedAt.remove(id);
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
    final res = await _dio.put<Map<String, Object?>>(
      '/diet/entries/$id',
      data: <String, Object?>{
        'meal_type': ?mealType,
        'time_label': ?timeLabel,
        if (foods != null)
          'foods': foods
              .map(
                (FoodItem food) => <String, Object?>{
                  'name': food.name,
                  'calories': food.calories,
                  'sodium_mg': food.sodiumMg,
                  'sugar_g': food.sugarG,
                  'carbs_g': food.carbsG,
                  'protein_g': food.proteinG,
                  'fat_g': food.fatG,
                },
              )
              .toList(),
        'total_calories': ?totalCalories,
        'sodium_mg': ?sodiumMg,
        'sugar_g': ?sugarG,
      },
    );
    final returned = DietEntry.fromJson(res.data!);
    final updatedFoods = foods ?? returned.foods;
    final editedMacros = foods == null
        ? null
        : (
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
          );
    final updated = DietEntry(
      id: returned.id,
      mealType: mealType == null
          ? returned.mealType
          : MealType.values.byName(mealType),
      timeLabel: timeLabel ?? returned.timeLabel,
      foods: updatedFoods,
      totalCalories: totalCalories ?? returned.totalCalories,
      sodiumMg: sodiumMg ?? returned.sodiumMg,
      sugarG: sugarG ?? returned.sugarG,
      carbsG: editedMacros?.carbsG ?? returned.carbsG,
      proteinG: editedMacros?.proteinG ?? returned.proteinG,
      fatG: editedMacros?.fatG ?? returned.fatG,
    );
    _entryOverrides[id] = updated;
    _entryOverrideUpdatedAt[id] = DateTime.now();
    return updated;
  }

  void _pruneStaleOverrides(DietDay day) {
    if (_entryOverrides.isEmpty) return;

    final now = DateTime.now();
    final serverIds = day.entries
        .map((DietEntry entry) => entry.id)
        .whereType<String>()
        .toSet();
    final staleIds = <String>[];

    for (final id in _entryOverrides.keys) {
      final updatedAt = _entryOverrideUpdatedAt[id];
      final isExpired =
          updatedAt == null || now.difference(updatedAt) > _entryOverrideTtl;
      if (isExpired || !serverIds.contains(id)) {
        staleIds.add(id);
      }
    }

    for (final id in staleIds) {
      _entryOverrides.remove(id);
      _entryOverrideUpdatedAt.remove(id);
    }
  }

  DietDay _applyOverrides(DietDay day) {
    if (_entryOverrides.isEmpty) return day;
    final entries = day.entries
        .map((DietEntry entry) => _entryOverrides[entry.id] ?? entry)
        .toList();
    return DietDay(
      entries: entries,
      totalCalories: entries.fold<int>(
        0,
        (int total, DietEntry entry) => total + entry.totalCalories,
      ),
      macros: _toDietMacros(_sumMacroGrams(entries)),
      totalSodiumMg: entries.fold<int>(
        0,
        (int total, DietEntry entry) => total + entry.sodiumMg,
      ),
      totalSugarG: entries.fold<double>(
        0,
        (double total, DietEntry entry) => total + entry.sugarG,
      ),
      aiCoachMessage: day.aiCoachMessage,
    );
  }
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
