import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
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
  Future<DietAnalysisResult> analyze({
    required Uint8List imageBytes,
    required String filename,
    required String mealType,
    String? idempotencyKey,
  }) async {
    final form = FormData.fromMap(<String, Object?>{
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: filename,
        contentType: DioMediaType('image', 'jpeg'),
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
    int? sugarG,
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
                },
              )
              .toList(),
        'total_calories': ?totalCalories,
        'sodium_mg': ?sodiumMg,
        'sugar_g': ?sugarG,
      },
    );
    final returned = DietEntry.fromJson(res.data!);
    final updated = DietEntry(
      id: returned.id,
      mealType: mealType == null
          ? returned.mealType
          : MealType.values.byName(mealType),
      timeLabel: timeLabel ?? returned.timeLabel,
      foods: foods ?? returned.foods,
      totalCalories: totalCalories ?? returned.totalCalories,
      sodiumMg: sodiumMg ?? returned.sodiumMg,
      sugarG: sugarG ?? returned.sugarG,
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
      macros: day.macros,
      totalSodiumMg: entries.fold<int>(
        0,
        (int total, DietEntry entry) => total + entry.sodiumMg,
      ),
      totalSugarG: entries.fold<int>(
        0,
        (int total, DietEntry entry) => total + entry.sugarG,
      ),
      aiCoachMessage: day.aiCoachMessage,
    );
  }
}
