import 'package:dio/dio.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/clients/domain/entities/trainer_memo.dart';
import 'package:oncare_trainer/shared/services/trainer_memo_repository.dart';

/// Stores a trainer's per-member memos on the FastAPI backend so they
/// survive a re-login and follow the trainer to another browser (#706).
///
/// Selected when `USE_MOCK_API=false` (see [trainerMemoRepositoryProvider]).
/// A client this trainer isn't assigned to answers 404, which surfaces as a
/// typed [AppError] exactly like the other client-scoped reads.
class DioTrainerMemoRepository implements TrainerMemoRepository {
  const DioTrainerMemoRepository(this._dio);

  final Dio _dio;

  String _base(String clientId) =>
      '/trainer/clients/${Uri.encodeComponent(clientId)}/memos';

  @override
  Future<List<TrainerMemo>> fetch(String clientId) async {
    try {
      final response = await _dio.get<List<dynamic>>(_base(clientId));
      final data = response.data ?? const <dynamic>[];
      return data
          .map(
            (item) => TrainerMemo.fromJson(
              (item! as Map<Object?, Object?>).cast<String, Object?>(),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }

  @override
  Future<TrainerMemo> create(
    String clientId, {
    required String body,
    TrainerMemoSource source = TrainerMemoSource.trainer,
    String? insightId,
    String insightKind = '',
  }) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        _base(clientId),
        data: <String, Object?>{
          'body': body,
          'source': source.wire,
          // The server de-duplicates on this key, so a retried save of the
          // same chat insight returns the stored memo instead of adding one.
          'insight_id': ?insightId,
          if (insightKind.isNotEmpty) 'insight_kind': insightKind,
        },
      );
      return TrainerMemo.fromJson(response.data!);
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }

  @override
  Future<TrainerMemo> update(
    String clientId,
    String memoId,
    String body,
  ) async {
    try {
      final response = await _dio.put<Map<String, Object?>>(
        '${_base(clientId)}/${Uri.encodeComponent(memoId)}',
        data: <String, Object?>{'body': body},
      );
      return TrainerMemo.fromJson(response.data!);
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }

  @override
  Future<void> delete(String clientId, String memoId) async {
    try {
      await _dio.delete<Map<String, Object?>>(
        '${_base(clientId)}/${Uri.encodeComponent(memoId)}',
      );
    } on DioException catch (error) {
      throw AppError.fromDio(error);
    }
  }
}
