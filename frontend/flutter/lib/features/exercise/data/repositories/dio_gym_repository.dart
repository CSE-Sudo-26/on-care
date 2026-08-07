import 'package:dio/dio.dart';

import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';

/// 헬스장·트레이너 디렉터리 실 API. (#324)
///
/// 회원의 "내 헬스장/트레이너"는 별도 링크가 아니라 **담당 트레이너의 소속**에서
/// 나온다(`GET /me/coach`). 백엔드에 회원↔헬스장 링크가 따로 없기 때문이다.
class DioGymRepository implements GymRepository {
  DioGymRepository(this._dio);
  final Dio _dio;

  /// 헬스장 찾기가 쓰는 기준 좌표(신촌). 거리를 서버가 계산하도록 함께 보낸다.
  static const double _centerLat = 37.5559;
  static const double _centerLng = 126.9368;

  static Gym _gym(Map<String, Object?> j) => Gym(
    id: j['id']! as String,
    name: j['name']! as String,
    address: (j['address'] as String?) ?? '',
    distanceKm: ((j['distance_km'] as num?) ?? 0).toDouble(),
    rating: ((j['rating'] as num?) ?? 0).toDouble(),
    tags: <String>[...?(j['tags'] as List<Object?>?)?.cast<String>()],
    weekdayHours: j['weekday_hours'] as String?,
    weekendHours: j['weekend_hours'] as String?,
    phone: j['phone'] as String?,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
  );

  static Trainer _trainer(Map<String, Object?> j) => Trainer(
    id: j['id']! as String,
    gymId: (j['gym_id'] as String?) ?? '',
    name: j['name']! as String,
    role: j['role'] as String?,
    reason: j['reason'] as String?,
    career: j['career'] as String?,
    intro: j['intro'] as String?,
    certifications: <String>[
      ...?(j['certifications'] as List<Object?>?)?.cast<String>(),
    ],
  );

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, Object?>) map, {
    Map<String, Object?>? query,
  }) async {
    final res = await _dio.get<List<Object?>>(path, queryParameters: query);
    return (res.data ?? const <Object?>[])
        .cast<Map<String, Object?>>()
        .map(map)
        .toList();
  }

  /// 담당 트레이너 요약. 담당이 없으면 서버가 404 를 주므로 null 로 바꾼다.
  Future<Map<String, Object?>?> _coach() async {
    try {
      final res = await _dio.get<Map<String, Object?>>('/me/coach');
      return res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<Gym>> fetchNearby() => _list(
    '/gyms',
    _gym,
    query: <String, Object?>{'lat': _centerLat, 'lng': _centerLng},
  );

  @override
  Future<List<Trainer>> fetchTrainersByGym(String gymId) =>
      _list('/gyms/$gymId/trainers', _trainer);

  @override
  Future<List<Trainer>> fetchAllTrainers() => _list('/trainers', _trainer);

  @override
  Future<List<Trainer>> fetchRecommendedTrainers() =>
      _list('/trainers/recommended', _trainer);

  @override
  Future<Trainer?> fetchTrainer(String trainerId) async {
    try {
      final res = await _dio.get<Map<String, Object?>>('/trainers/$trainerId');
      return res.data == null ? null : _trainer(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Gym?> fetchMyGym() async {
    final coach = await _coach();
    final gym = coach?['gym'] as Map<String, Object?>?;
    final gymId = gym?['id'] as String?;
    if (gymId == null) return null;
    // 요약에는 평점·태그가 없다. 상세를 한 번 더 읽어 목록과 같은 카드를 만든다.
    try {
      final res = await _dio.get<Map<String, Object?>>(
        '/gyms/$gymId',
        queryParameters: <String, Object?>{'lat': _centerLat, 'lng': _centerLng},
      );
      if (res.data != null) return _gym(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }
    return null;
  }

  @override
  Future<Trainer?> fetchMyTrainer() async {
    final coach = await _coach();
    final trainerId = coach?['trainer_id'] as String?;
    if (trainerId == null) return null;
    // 요약에는 자격증·추천 사유가 없어 상세를 읽는다.
    return fetchTrainer(trainerId);
  }

  @override
  Future<void> disconnectMyGym() => _dio.delete<void>('/me/coach');

  /// 서버에는 회원↔헬스장 링크가 따로 없어 "트레이너만 해제"를 표현할 수 없다.
  /// 담당 링크를 끊으면 헬스장도 함께 사라진다 — mock 과 달리 헬스장이 남지 않는다.
  /// 회원↔헬스장 링크가 생기면(#301 후속) 여기를 나눈다.
  @override
  Future<void> disconnectMyTrainer() => _dio.delete<void>('/me/coach');
}
