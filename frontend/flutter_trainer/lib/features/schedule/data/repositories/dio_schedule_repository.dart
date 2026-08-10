import 'dart:async';

import 'package:dio/dio.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/date_format.dart';
import 'package:oncare_trainer/features/schedule/data/dtos/schedule_dtos.dart';
import 'package:oncare_trainer/features/schedule/data/repositories/schedule_repository.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/schedule_session.dart';

/// The trainer's timeline against the FastAPI backend
/// (`/v1/trainer/schedule*`). Selected when `USE_MOCK_API=false`.
///
/// The drift source is reactive — a booking written in one tab shows up
/// in another because both watch the same table. HTTP has no such
/// channel, so this keeps a broadcast "revision" tick: every mutation
/// bumps it, and every read re-fetches. That reproduces the behaviour the
/// screens already rely on (add a session → the timeline updates itself)
/// without each of them having to remember to invalidate providers.
class DioScheduleRepository implements ScheduleRepository {
  /// Creates the repository over [_dio].
  DioScheduleRepository(this._dio);

  final Dio _dio;

  final StreamController<void> _revisions = StreamController<void>.broadcast();

  /// Emits once on listen, then again after every mutation.
  ///
  /// Written with an explicit controller rather than `async*` + `await
  /// for`: a generator suspended on the revision stream only resumes when
  /// the consumer pulls, which made "write, then observe the re-read"
  /// depend on listener timing instead of on the write.
  Stream<T> _live<T>(Future<T> Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? revisions;

    Future<void> emit() async {
      if (controller.isClosed) return;
      try {
        final value = await read();
        if (!controller.isClosed) controller.add(value);
      } catch (error, stackTrace) {
        // Surface as a stream error so the consuming AsyncValue shows its
        // error state rather than hanging in loading.
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        unawaited(emit());
        revisions = _revisions.stream.listen((_) => unawaited(emit()));
      },
      onCancel: () async {
        await revisions?.cancel();
        revisions = null;
      },
    );
    return controller.stream;
  }

  void _bump() {
    if (!_revisions.isClosed) _revisions.add(null);
  }

  /// Closes the revision channel. Called by the provider's `onDispose`.
  void dispose() => unawaited(_revisions.close());

  @override
  Stream<List<ScheduleSession>> watchToday() => watchDate(ymd(DateTime.now()));

  @override
  Stream<List<ScheduleSession>> watchDate(String date) =>
      _live(() => _fetch(<String, String>{'date': date}));

  @override
  Stream<List<ScheduleSession>> watchRange(String fromDate, String toDate) =>
      _live(() => _fetch(<String, String>{'from': fromDate, 'to': toDate}));

  /// `member_id` on its own means "every session for this client" — no
  /// date bounds. Standing in for that with a wide range would silently
  /// drop anything older than the range, and the screen reads a missing
  /// row as "no record" rather than "not fetched".
  /// Newest first, to match the drift source's ordering.
  @override
  Stream<List<ScheduleSession>> watchClientSessions(ScheduleClientKey client) {
    return _live(() async {
      final sessions = await _fetch(<String, String>{'member_id': client.id});
      return sessions.reversed.toList();
    });
  }

  /// Booked dates come from their own endpoint (a 90-day window server
  /// side), so this doesn't page the whole timeline to find them.
  @override
  Stream<Set<String>> watchBookedDates() {
    return _live(() async {
      try {
        final res = await _dio.get<List<dynamic>>(
          '/trainer/schedule/booked-dates',
        );
        return <String>{
          for (final d in res.data ?? const <dynamic>[])
            if (d is String) d,
        };
      } on DioException catch (e) {
        throw AppError.fromDio(e);
      }
    });
  }

  @override
  Future<void> addSession({
    required String date,
    required String clientName,
    String? clientId,
    required String time,
    required String type,
    required int durationMinutes,
    String note = '',
  }) async {
    await _mutate(
      () => _dio.post<Map<String, dynamic>>(
        '/trainer/schedule',
        data: <String, Object?>{
          'date': date,
          'time': time,
          'client_name': clientName,
          'member_id': ?clientId,
          'type': type,
          'duration_minutes': durationMinutes,
          'note': note,
        },
      ),
    );
  }

  @override
  Future<void> updateSession(
    String id, {
    required String clientName,
    String? clientId,
    required String time,
    required String type,
    required int durationMinutes,
    required String note,
  }) async {
    await _mutate(
      () => _dio.put<Map<String, dynamic>>(
        '/trainer/schedule/${Uri.encodeComponent(id)}',
        data: <String, Object?>{
          'client_name': clientName,
          'member_id': ?clientId,
          'time': time,
          'type': type,
          'duration_minutes': durationMinutes,
          'note': note,
        },
      ),
    );
  }

  /// Sends only `program`/`note` — the update endpoint is partial, so
  /// omitting the booking fields leaves them untouched.
  @override
  Future<void> updateProgram(
    String id, {
    required List<ProgramItem> program,
    required String note,
  }) async {
    await _mutate(
      () => _dio.put<Map<String, dynamic>>(
        '/trainer/schedule/${Uri.encodeComponent(id)}',
        data: <String, Object?>{
          'program': programToJson(program),
          'note': note,
        },
      ),
    );
  }

  @override
  Future<bool> registerProgram({
    required String date,
    required String clientId,
    required String clientName,
    required String time,
    required List<ProgramItem> program,
  }) async {
    late bool attachedToExisting;
    final memberId = Uri.encodeComponent(clientId);
    await _mutate(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/trainer/clients/$memberId/schedule-program',
        data: <String, Object?>{
          'date': date,
          'time': time,
          'client_name': clientName,
          'program': programToJson(program),
        },
      );
      final attached = response.data?['attached_to_existing'];
      if (attached is! bool) {
        throw const FormatException(
          'schedule-program response is missing attached_to_existing',
        );
      }
      attachedToExisting = attached;
      return response;
    });
    return attachedToExisting;
  }

  @override
  Future<void> deleteSession(String id) async {
    await _mutate(
      () => _dio.delete<Map<String, dynamic>>(
        '/trainer/schedule/${Uri.encodeComponent(id)}',
      ),
    );
  }

  @override
  Future<void> completeSession(String id, {String note = ''}) async {
    await _mutate(
      () => _dio.post<Map<String, dynamic>>(
        '/trainer/schedule/${Uri.encodeComponent(id)}/complete',
        data: <String, Object?>{'note': note},
      ),
    );
  }

  Future<List<ScheduleSession>> _fetch(Map<String, String> query) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/trainer/schedule',
        queryParameters: query,
      );
      return <ScheduleSession>[
        for (final row in res.data ?? const <dynamic>[])
          if (row is Map<String, dynamic>) scheduleSessionFromJson(row),
      ];
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
  }

  /// Runs a write and, only on success, tells the readers to re-fetch —
  /// a failed write must not make the timeline flicker as if something
  /// had changed.
  Future<void> _mutate(Future<Object?> Function() write) async {
    try {
      await write();
    } on DioException catch (e) {
      throw AppError.fromDio(e);
    }
    _bump();
  }
}
