import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/features/exercise/data/repositories/dio_gym_repository.dart';
import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/gym_search_area.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';

/// 백엔드 실응답을 그대로 돌려주는 어댑터. 필드명이 어긋나면 여기서 걸린다.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.routes);
  final Map<String, Object?> routes;
  final List<String> calls = <String>[];
  final Map<String, Map<String, dynamic>> queries = <String, Map<String, dynamic>>{};

  /// 경로에 실제로 실려 나간 query parameter.
  Map<String, dynamic> queryOf(String path) => queries[path] ?? <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    calls.add('${options.method} ${options.path}');
    queries[options.path] = Map<String, dynamic>.from(options.queryParameters);
    final body = routes[options.path];
    if (body == null) {
      return ResponseBody.fromString('{"detail":"not found"}', 404,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          });
    }
    return ResponseBody.fromString(_encode(body), 200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        });
  }

  static String _encode(Object? v) {
    // dart:convert 를 쓰지 않고 미리 만든 JSON 문자열을 그대로 쓴다.
    return v! as String;
  }

  @override
  void close({bool force = false}) {}
}

/// `GET /v1/gyms` 실응답(gym_service.GymOut) 그대로.
const String _gymsJson = '''
[{"id":"gym-oncare-sinchon","name":"온케어짐 신촌점","address":"서울 서대문구 신촌로 120",
  "distance_km":0.0,"rating":4.7,"tags":["다이어트","재활운동"],
  "weekday_hours":"06:00 – 23:00","weekend_hours":"08:00 - 20:00",
  "phone":"02-1234-5678","lat":37.5559,"lng":126.9368,"is_partner":true}]
''';

/// `GET /v1/gyms/{id}` 실응답(단일 객체).
const String _gymDetailJson = '''
{"id":"gym-oncare-sinchon","name":"온케어짐 신촌점","address":"서울 서대문구 신촌로 120",
 "distance_km":0.0,"rating":4.7,"tags":["다이어트","재활운동"],
 "weekday_hours":"06:00 – 23:00","weekend_hours":"08:00 - 20:00",
 "phone":"02-1234-5678","lat":37.5559,"lng":126.9368,"is_partner":true}
''';

const String _trainersJson = '''
[{"id":"trainer-demo","gym_id":"gym-oncare-sinchon","name":"김트레이너",
  "role":"퍼스널 트레이너","reason":"혈압 관리와 운동 병행 지도","career":"7년",
  "intro":"혈압 관리와 체중 감량을 함께 다루는 퍼스널 트레이너입니다.",
  "certifications":["생활스포츠지도사 2급","퍼스널트레이닝 CPT"]}]
''';

Dio _dio(_StubAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://x/v1'))..httpClientAdapter = adapter;

void main() {
  test('GET /gyms 응답이 Gym 으로 매핑된다', () async {
    final adapter = _StubAdapter(<String, Object?>{'/gyms': _gymsJson});
    final gyms = await DioGymRepository(_dio(adapter)).fetchNearby();

    expect(gyms, hasLength(1));
    final Gym g = gyms.single;
    expect(g.id, 'gym-oncare-sinchon');
    expect(g.name, '온케어짐 신촌점');
    expect(g.rating, 4.7);
    expect(g.tags, <String>['다이어트', '재활운동']);
    expect(g.phone, '02-1234-5678');
    expect(g.weekdayHours, '06:00 – 23:00');
    // 지도 핀에 필요하다.
    expect(g.hasCoordinates, isTrue);
  });

  test('거리 계산을 서버가 하도록 좌표를 함께 보낸다', () async {
    final adapter = _StubAdapter(<String, Object?>{'/gyms': _gymsJson});
    await DioGymRepository(_dio(adapter)).fetchNearby();

    expect(adapter.calls, contains('GET /gyms'));
    // 경로만 보면 lat/lng 가 빠져도 통과한다 — 값까지 확인한다.
    final Map<String, dynamic> q = adapter.queryOf('/gyms');
    expect(q['lat'], kGymSearchLat);
    expect(q['lng'], kGymSearchLng);
  });

  test('GET /trainers 응답이 Trainer 로 매핑된다', () async {
    final adapter = _StubAdapter(<String, Object?>{'/trainers': _trainersJson});
    final trainers = await DioGymRepository(_dio(adapter)).fetchAllTrainers();

    final Trainer t = trainers.single;
    expect(t.id, 'trainer-demo');
    expect(t.gymId, 'gym-oncare-sinchon');
    expect(t.role, '퍼스널 트레이너');
    expect(t.reason, '혈압 관리와 운동 병행 지도');
    expect(t.career, '7년');
    expect(t.certifications, hasLength(2));
  });

  test('담당이 없으면 404 를 null 로 바꾼다', () async {
    // /me/coach 미등록 → 404. 예외가 그대로 올라가면 화면이 오류로 덮인다.
    final repo = DioGymRepository(_dio(_StubAdapter(<String, Object?>{})));
    expect(await repo.fetchMyGym(), isNull);
    expect(await repo.fetchMyTrainer(), isNull);
  });

  test('내 헬스장은 요약이 아니라 상세를 읽어 평점·태그를 채운다', () async {
    const coachJson = '''
    {"trainer_id":"trainer-demo","name":"김트레이너","specialty":"퍼스널 트레이너",
     "career":"7년","intro":"소개","goal":"혈압 관리",
     "gym":{"id":"gym-oncare-sinchon","name":"온케어짐 신촌점",
            "address":"서울 서대문구 신촌로 120","hours":"06:00 – 23:00",
            "phone":"02-1234-5678"}}
    ''';
    final adapter = _StubAdapter(<String, Object?>{
      '/me/coach': coachJson,
      '/gyms/gym-oncare-sinchon': _gymDetailJson,
    });

    final gym = await DioGymRepository(_dio(adapter)).fetchMyGym();
    expect(gym, isNotNull);
    // 요약(TrainerGymOut)에는 평점·태그가 없다 — 상세를 읽어야 카드가 목록과 같다.
    expect(gym!.rating, 4.7);
    expect(gym.tags, isNotEmpty);
    expect(adapter.calls, contains('GET /gyms/gym-oncare-sinchon'));
  });

  test('연결 해제는 DELETE /me/coach 로 나간다', () async {
    final adapter = _StubAdapter(<String, Object?>{'/me/coach': '{}'});
    await DioGymRepository(_dio(adapter)).disconnectMyGym();
    expect(adapter.calls, contains('DELETE /me/coach'));
  });
}
