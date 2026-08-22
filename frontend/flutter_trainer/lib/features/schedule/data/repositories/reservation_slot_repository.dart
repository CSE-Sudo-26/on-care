import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/network/dio_client.dart';
import 'package:oncare_trainer/core/utils/clock.dart';
import 'package:oncare_trainer/features/schedule/domain/entities/reservation_slot.dart';

abstract interface class ReservationSlotRepository {
  Future<List<ReservationSlot>> list();

  Future<ReservationSlot> create({required DateTime startsAt});

  Future<ReservationSlot> update(String id, {DateTime? startsAt});

  Future<ReservationSlot> close(String id);
}

/// 서버에 보내는 좌석 수. 1:1 PT 라 늘 한 자리다(#1072).
const int _ptCapacity = 1;

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
  Future<ReservationSlot> create({required DateTime startsAt}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/trainer/reservation-slots',
      data: <String, dynamic>{
        'starts_at': startsAt.toUtc().toIso8601String(),
        // 서버 계약은 아직 좌석 수를 받는다. 1:1 PT 라 값은 늘 1이고, 트레이너가
        // 고를 것이 없으므로 화면까지 올리지 않는다(#1072).
        'capacity': _ptCapacity,
      },
    );
    return ReservationSlot.fromJson(response.data!);
  }

  @override
  Future<ReservationSlot> update(String id, {DateTime? startsAt}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/trainer/reservation-slots/$id',
      data: <String, dynamic>{
        'starts_at': ?startsAt?.toUtc().toIso8601String(),
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
  Future<ReservationSlot> create({required DateTime startsAt}) async {
    _validateFuture(startsAt);
    final slot = ReservationSlot(
      id: 'slot-${DateTime.now().microsecondsSinceEpoch}',
      startsAt: startsAt,
      booked: false,
      isClosed: false,
    );
    _slots.add(slot);
    return slot;
  }

  @override
  Future<ReservationSlot> update(String id, {DateTime? startsAt}) async {
    final index = _slots.indexWhere((slot) => slot.id == id);
    if (index < 0) throw StateError('not_found');
    final old = _slots[index];
    if (startsAt != null) _validateFuture(startsAt);
    final updated = ReservationSlot(
      id: old.id,
      startsAt: startsAt ?? old.startsAt,
      booked: old.booked,
      isClosed: old.isClosed,
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
