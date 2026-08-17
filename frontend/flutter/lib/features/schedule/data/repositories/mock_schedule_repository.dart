import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';
import 'package:oncare/features/schedule/domain/repositories/schedule_repository.dart';

class MockScheduleRepository implements ScheduleRepository {
  const MockScheduleRepository();

  @override
  Future<List<ScheduleEvent>> fetchByDate(String date) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return <ScheduleEvent>[
      ScheduleEvent(
        id: 'mock-hospital',
        date: date,
        time: '10:00',
        title: '병원 정기검진',
        category: ScheduleCategory.hospital,
        emoji: '🏥',
        colorHex: '#FEE2E2',
      ),
      ScheduleEvent(
        id: 'mock-gym',
        date: date,
        time: '18:00',
        title: '헬스장 운동',
        category: ScheduleCategory.exercise,
        emoji: '💪',
        colorHex: '#DCFCE7',
      ),
    ];
  }

  @override
  Future<List<ScheduleEvent>> fetchByMonth(String month) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return <ScheduleEvent>[
      ScheduleEvent(
        id: 'mock-month-hospital',
        date: '$month-14',
        time: '10:00',
        title: '병원 정기검진',
        category: ScheduleCategory.hospital,
      ),
      ScheduleEvent(
        id: 'mock-month-gym',
        date: '$month-14',
        time: '18:00',
        title: '헬스장 운동',
        category: ScheduleCategory.exercise,
      ),
    ];
  }

  @override
  Future<ScheduleEvent> createEvent({
    required String date,
    required String title,
    String time = '',
    ScheduleCategory category = ScheduleCategory.other,
  }) async {
    return ScheduleEvent(
      id: 'mock-${category.name}',
      date: date,
      time: time,
      title: title,
      category: category,
    );
  }

  @override
  Future<ScheduleEvent> updateEvent(
    String id, {
    String? date,
    String? time,
    String? title,
    ScheduleCategory? category,
  }) async {
    return ScheduleEvent(
      id: id,
      date: date ?? '',
      time: time ?? '',
      title: title ?? '',
      category: category ?? ScheduleCategory.other,
    );
  }

  @override
  Future<void> deleteEvent(String id) async {}
}
