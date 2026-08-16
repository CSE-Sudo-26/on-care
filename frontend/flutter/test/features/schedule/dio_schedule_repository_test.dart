import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/schedule/data/repositories/dio_schedule_repository.dart';
import 'package:oncare/features/schedule/domain/entities/schedule_event.dart';

/// 나간 요청을 붙잡아 둔다 — 경로·본문이 FastAPI 계약과 맞는지가 관심사다.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? last;
  Object? lastBody;
  Map<String, Object?> reply = const <String, Object?>{
    'id': 'evt-1',
    'date': '2026-08-16',
    'time': '10:00',
    'title': '병원 정기검진',
    'category': 'hospital',
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    last = options;
    lastBody = options.data;
    return ResponseBody.fromString(
      jsonEncode(reply),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _RecordingAdapter adapter;
  late DioScheduleRepository repo;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/v1'))
      ..httpClientAdapter = adapter;
    repo = DioScheduleRepository(dio);
  });

  test('updateEvent 는 PUT 으로 준 필드만 보낸다', () async {
    await repo.updateEvent('evt-1', title: '병원 재검진');

    expect(adapter.last!.method, 'PUT');
    expect(adapter.last!.path, '/schedule/events/evt-1');
    // 넘기지 않은 항목은 아예 키가 없어야 한다. null 을 실어 보내면 서버가
    // "지워라" 로 읽을 여지가 생긴다.
    expect(adapter.lastBody, <String, Object?>{'title': '병원 재검진'});
  });

  test('시간을 지우는 것은 빈 문자열로 보낸다', () async {
    await repo.updateEvent('evt-1', time: '');

    // 생략(안 바꿈)과 빈 문자열(지움)은 다른 뜻이다.
    expect(adapter.lastBody, <String, Object?>{'time': ''});
  });

  test('updateEvent 는 카테고리를 이름으로 보낸다', () async {
    await repo.updateEvent('evt-1', category: ScheduleCategory.exercise);

    expect(adapter.lastBody, <String, Object?>{'category': 'exercise'});
  });

  test('deleteEvent 는 DELETE 로 부른다', () async {
    await repo.deleteEvent('evt-9');

    expect(adapter.last!.method, 'DELETE');
    expect(adapter.last!.path, '/schedule/events/evt-9');
  });
}
