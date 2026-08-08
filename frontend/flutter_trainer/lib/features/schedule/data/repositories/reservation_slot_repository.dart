import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/reservation_slot.dart';

abstract interface class ReservationSlotRepository {
  Future<List<ReservationSlot>> list();

  Future<ReservationSlot> create({
    required DateTime startsAt,
    required int capacity,
  });

  Future<ReservationSlot> update(
    String id, {
    DateTime? startsAt,
    int? capacity,
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
    required int capacity,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/trainer/reservation-slots',
      data: <String, dynamic>{
        'starts_at': startsAt.toUtc().toIso8601String(),
        'capacity': capacity,
      },
    );
    return ReservationSlot.fromJson(response.data!);
  }

  @override
  Future<ReservationSlot> update(
    String id, {
    DateTime? startsAt,
    int? capacity,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/trainer/reservation-slots/$id',
      data: <String, dynamic>{
        'starts_at': ?startsAt?.toUtc().toIso8601String(),
        'capacity': ?capacity,
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

class MockReservationSlotRepository implements ReservationSlotRepository {
  final List<ReservationSlot> _slots = <ReservationSlot>[];

  void _validateCapacity(int capacity) {
    if (capacity < 1 || capacity > 100) {
      throw StateError('정원은 1명 이상 100명 이하이어야 합니다.');
    }
  }

  void _validateFuture(DateTime startsAt) {
    if (!startsAt.isAfter(DateTime.now())) {
      throw StateError('현재보다 이후 시간만 예약 슬롯으로 설정할 수 있습니다.');
    }
  }

  @override
  Future<List<ReservationSlot>> list() async {
    final now = DateTime.now();
    return _slots.where((slot) => slot.startsAt.isAfter(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  @override
  Future<ReservationSlot> create({
    required DateTime startsAt,
    required int capacity,
  }) async {
    _validateFuture(startsAt);
    _validateCapacity(capacity);
    final slot = ReservationSlot(
      id: 'slot-${DateTime.now().microsecondsSinceEpoch}',
      startsAt: startsAt,
      capacity: capacity,
      remaining: capacity,
      isClosed: false,
    );
    _slots.add(slot);
    return slot;
  }

  @override
  Future<ReservationSlot> update(
    String id, {
    DateTime? startsAt,
    int? capacity,
  }) async {
    final index = _slots.indexWhere((slot) => slot.id == id);
    if (index < 0) throw StateError('예약 슬롯을 찾을 수 없습니다.');
    final old = _slots[index];
    final nextCapacity = capacity ?? old.capacity;
    _validateCapacity(nextCapacity);
    if (startsAt != null) _validateFuture(startsAt);
    if (nextCapacity < old.booked) {
      throw StateError('이미 예약된 인원보다 정원을 줄일 수 없습니다.');
    }
    final updated = ReservationSlot(
      id: old.id,
      startsAt: startsAt ?? old.startsAt,
      capacity: nextCapacity,
      remaining: nextCapacity - old.booked,
      isClosed: old.isClosed,
    );
    _slots[index] = updated;
    return updated;
  }

  @override
  Future<ReservationSlot> close(String id) async {
    final index = _slots.indexWhere((slot) => slot.id == id);
    if (index < 0) throw StateError('예약 슬롯을 찾을 수 없습니다.');
    final old = _slots[index];
    final closed = ReservationSlot(
      id: old.id,
      startsAt: old.startsAt,
      capacity: old.capacity,
      remaining: old.remaining,
      isClosed: true,
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
