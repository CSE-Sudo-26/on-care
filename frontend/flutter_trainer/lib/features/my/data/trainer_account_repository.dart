import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';

/// Account-level actions that change credentials.
///
/// Separate from the profile repository because the failure modes are
/// different: a wrong current password is a user error to show inline,
/// not a network error to retry.
abstract interface class TrainerAccountRepository {
  /// Whether this build can actually change the password.
  ///
  /// Demo/mock has no account behind it, so the UI disables the action
  /// and says why instead of pretending it worked.
  bool get supportsPasswordChange;

  /// Changes the password. Throws [AppError] on failure —
  /// [ValidationError] carries the server's reason (wrong current
  /// password, same as current) for inline display.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

/// Demo build: no server account to change.
class MockTrainerAccountRepository implements TrainerAccountRepository {
  /// Creates the demo no-op.
  const MockTrainerAccountRepository();

  @override
  bool get supportsPasswordChange => false;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    throw const ValidationError(message: '데모 모드에서는 비밀번호를 변경할 수 없어요');
  }
}

/// Real backend: `POST /v1/trainer/me/password`.
class DioTrainerAccountRepository implements TrainerAccountRepository {
  /// Creates the API-backed repository.
  const DioTrainerAccountRepository(this._dio);

  final Dio _dio;

  @override
  bool get supportsPasswordChange => true;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/trainer/me/password',
        data: <String, String>{
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      // 400 carries the server's own reason ("현재 비밀번호가 일치하지
      // 않습니다."), which is exactly what the trainer needs to read.
      final status = e.response?.statusCode;
      if (status == 400 || status == 422) {
        throw ValidationError(message: _detail(e) ?? '비밀번호를 변경할 수 없어요');
      }
      throw AppError.fromDio(e);
    }
  }

  String? _detail(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    return null;
  }
}

/// Provides the account repository for the current mode.
final trainerAccountRepositoryProvider = Provider<TrainerAccountRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return const MockTrainerAccountRepository();
  }
  return DioTrainerAccountRepository(ref.watch(dioProvider));
}, name: 'trainerAccountRepository');
