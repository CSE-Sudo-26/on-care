import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/reservation_slot.dart';

abstract interface class ReservationSlotRepository {
  Future<List<ReservationSlot>> list();

  Future<ReservationSlot> create({
    required DateTime startsAt,
    required String sessionType,
  });

  Future<ReservationSlot> update(
    String id, {
    DateTime? startsAt,
    String? sessionType,
  });

  Future<ReservationSlot> close(String id);
}

class DioReservationSlotRepository implements ReservationSlotRepository {
  const DioReservationSlotRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<ReservationSlot>> list() async {
    final response = await _dio.get<List<dynamic>>(
      '/trainer/reservation-slots',
    );
    return (response.data ?? const <dynamic>[])
        .map((item) => ReservationSlot.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReservationSlot> create({
    required DateTime startsAt,
    required String sessionType,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/trainer/reservation-slots',
      data: <String, dynamic>{
        'starts_at': startsAt.toUtc().toIso8601String(),
        'session_type': sessionType,
      },
    );
    return ReservationSlot.fromJson(response.data!);
  }

  @override
  Future<ReservationSlot> update(
    String id, {
    DateTime? startsAt,
    String? sessionType,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/trainer/reservation-slots/$id',
      data: <String, dynamic>{
        'starts_at': ?startsAt?.toUtc().toIso8601String(),
        'session_type': ?sessionType,
      },
    );
    return ReservationSlot.fromJson(response.data!);
  }

  @override
  Future<ReservationSlot> close(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/trainer/reservation-slots/$id',
    );
    return ReservationSlot.fromJson(response.data!);
  }
}

/// 목 리포지토리가 던지는 검증 코드. **문구가 아니다** — 리포지토리는 로케일을
/// 모르므로 화면이 이 코드로 자기 언어의 문구를 고른다. (#501)
class SlotErrorCodes {
  static const String futureOnly = 'future_only';
  static const String notFound = 'not_found';

  /// 이미 예약이 걸린 자리의 종류를 바꾸려 했다(#1083).
  static const String typeLockedByBooking = 'type_locked_by_booking';
}

class MockReservationSlotRepository implements ReservationSlotRepository {
  final List<ReservationSlot> _slots = <ReservationSlot>[];

  void _validateFuture(DateTime startsAt) {
    if (!startsAt.isAfter(nowKst())) {
      throw StateError('future_only');
    }
  }

  @override
  Future<List<ReservationSlot>> list() async {
    final now = nowKst();
    return _slots.where((slot) => slot.startsAt.isAfter(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  @override
  Future<ReservationSlot> create({
    required DateTime startsAt,
    required String sessionType,
  }) async {
    _validateFuture(startsAt);
    // 슬롯은 늘 한 사람 몫이라 새로 연 자리는 비어 있는 상태로 시작한다
    // (#1012, #1072).
    final slot = ReservationSlot(
      id: 'slot-${DateTime.now().microsecondsSinceEpoch}',
      startsAt: startsAt,
      booked: false,
      isClosed: false,
      sessionType: sessionType,
    );
    _slots.add(slot);
    return slot;
  }

  @override
  Future<ReservationSlot> update(
    String id, {
    DateTime? startsAt,
    String? sessionType,
  }) async {
    final index = _slots.indexWhere((slot) => slot.id == id);
    if (index < 0) throw StateError('not_found');
    final old = _slots[index];
    if (startsAt != null) _validateFuture(startsAt);
    if (sessionType != null && sessionType != old.sessionType && old.booked) {
      throw StateError('type_locked_by_booking');
    }
    final updated = ReservationSlot(
      id: old.id,
      startsAt: startsAt ?? old.startsAt,
      booked: old.booked,
      isClosed: old.isClosed,
      sessionType: sessionType ?? old.sessionType,
    );
    _slots[index] = updated;
    return updated;
  }

  @override
  Future<ReservationSlot> close(String id) async {
    final index = _slots.indexWhere((slot) => slot.id == id);
    if (index < 0) throw StateError('not_found');
    final old = _slots[index];
    final closed = ReservationSlot(
      id: old.id,
      startsAt: old.startsAt,
      booked: old.booked,
      isClosed: true,
      sessionType: old.sessionType,
    );
    _slots[index] = closed;
    return closed;
  }
}

final reservationSlotRepositoryProvider = Provider<ReservationSlotRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).useMockApi) {
    return MockReservationSlotRepository();
  }
  return DioReservationSlotRepository(ref.watch(dioProvider));
}, name: 'reservationSlotRepository');

final reservationSlotsProvider = FutureProvider<List<ReservationSlot>>((ref) {
  return ref.watch(reservationSlotRepositoryProvider).list();
}, name: 'reservationSlots');
