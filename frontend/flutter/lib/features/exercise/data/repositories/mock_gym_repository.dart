import 'package:oncare/features/exercise/domain/entities/gym.dart';
import 'package:oncare/features/exercise/domain/entities/trainer.dart';
import 'package:oncare/features/exercise/domain/repositories/gym_repository.dart';

/// In-memory gym + trainer data matching the prototype's `GymCard` /
/// `GymFinder` mocks. The user starts connected to 온케어짐 신촌점 and to
/// 김트레이너 — the same gym and person the trainer app's
/// `seedTrainerProfile` describes, so both apps show one relationship.
///
/// Stateful (not const) so the two links can be dropped for the session. The
/// provider holds one instance, so MY 탭과 운동 탭이 같은 연결 상태를 본다.
class MockGymRepository implements GymRepository {
  MockGymRepository();

  /// 연결 상태는 id 만 들고 있다 — 목록과 어긋날 수 없다.
  String? _myGymId = 'gym-oncare-sinchon';
  String? _myTrainerId = 'trainer-kim';

  static const Gym _sinchon = Gym(
    id: 'gym-oncare-sinchon',
    name: '온케어짐 신촌점',
    address: '서울 서대문구 신촌로 120',
    distanceKm: 0.8,
    rating: 4.7,
    tags: <String>['다이어트', '재활운동'],
    weekdayHours: '06:00 – 23:00',
    weekendHours: '08:00 - 20:00',
    phone: '02-1234-5678',
    lat: 37.5559,
    lng: 126.9368,
  );

  static const Gym _healthmate = Gym(
    id: 'gym-healthmate',
    name: '헬스메이트 신촌점',
    address: '서울 서대문구 신촌로 83',
    distanceKm: 1.2,
    rating: 4.5,
    tags: <String>['근력운동', '만성질환 관리'],
    weekdayHours: '05:30 - 24:00',
    weekendHours: '07:00 - 22:00',
    phone: '02-2345-6789',
    lat: 37.5548,
    lng: 126.9385,
  );

  static const Gym _bodyAndSoul = Gym(
    id: 'gym-bodyandsoul',
    name: '바디앤소울 피트니스',
    address: '서울 마포구 백범로 23',
    distanceKm: 1.5,
    rating: 4.8,
    tags: <String>['PT', '식단 상담'],
    weekdayHours: '06:00 - 22:00',
    weekendHours: '09:00 - 18:00',
    phone: '02-3456-7890',
    lat: 37.5455,
    lng: 126.9425,
  );

  static const List<Gym> _gyms = <Gym>[_sinchon, _healthmate, _bodyAndSoul];

  /// 트레이너 앱 `seedTrainerProfile` 과 같은 값이어야 한다.
  static const Trainer _kim = Trainer(
    id: 'trainer-kim',
    gymId: 'gym-oncare-sinchon',
    name: '김트레이너',
    role: '퍼스널 트레이너',
    reason: '혈압 관리와 운동을 함께 봐드려요',
    career: '7년',
    intro:
        '혈압 관리와 체중 감량 전문 트레이너입니다. 고객 맞춤형 AI 루틴으로 '
        '안전하고 효과적인 운동을 도와드려요.',
    certifications: <String>['생활스포츠지도사 2급', '퍼스널트레이닝 CPT', '스포츠 영양사'],
  );

  /// 같은 헬스장 소속 트레이너들 — 헬스장당 1명 제약이 없음을 보여준다.
  static const List<Trainer> _trainers = <Trainer>[
    _kim,
    Trainer(
      id: 'trainer-park',
      gymId: 'gym-oncare-sinchon',
      name: '박트레이너',
      role: '재활 트레이너',
      reason: '무릎·허리 통증 관리 경험이 많아요',
      career: '11년',
      intro: '수술 후 회복과 만성 통증 관리를 주로 맡습니다. 무리하지 않는 범위부터 '
          '차근차근 가동 범위를 넓혀 드려요.',
      certifications: <String>['물리치료사', '재활 트레이닝 NASM-CES'],
    ),
    Trainer(
      id: 'trainer-choi',
      gymId: 'gym-oncare-sinchon',
      name: '최트레이너',
      role: '그룹 PT 트레이너',
      reason: '혼자 하기 어려울 때 소그룹으로 함께해요',
      career: '4년',
      intro: '2~4인 소그룹 수업을 진행합니다. 혼자 운동하기 어려운 분께 권해 드려요.',
      certifications: <String>['생활스포츠지도사 2급'],
    ),
    Trainer(
      id: 'trainer-kang',
      gymId: 'gym-healthmate',
      name: '강트레이너',
      role: '퍼스널 트레이너',
      reason: '교대근무 스케줄 케어 경험이 풍부해요',
      career: '5년',
      intro: '불규칙한 근무 일정에 맞춘 운동 설계를 주로 합니다. 짧은 시간에 '
          '집중도를 높이는 근력 프로그램을 준비해 드려요.',
      certifications: <String>['건강운동관리사', '퍼스널트레이닝 CPT'],
    ),
    Trainer(
      id: 'trainer-yoon',
      gymId: 'gym-healthmate',
      name: '윤트레이너',
      role: '근력 전문 트레이너',
      reason: '기초 근력부터 단계별로 올려드려요',
      career: '8년',
      intro: '기초 근력부터 파워리프팅까지 단계별로 지도합니다.',
      certifications: <String>['퍼스널트레이닝 CPT'],
    ),
    Trainer(
      id: 'trainer-lee',
      gymId: 'gym-bodyandsoul',
      name: '이트레이너',
      role: '퍼스널 트레이너',
      reason: '간단한 운동 루틴에 특화되어 있어요',
      career: '9년',
      intro: '운동을 처음 시작하는 분을 오래 지도했습니다. 식단 상담을 함께 '
          '진행해 생활 습관부터 차근차근 바꿔 드려요.',
      certifications: <String>[
        '생활스포츠지도사 2급',
        '스포츠 영양사',
        '재활 트레이닝 NASM-CES',
      ],
    ),
    Trainer(
      id: 'trainer-cho',
      gymId: 'gym-bodyandsoul',
      name: '조트레이너',
      role: '시니어 운동 트레이너',
      reason: '어르신 균형 운동을 오래 지도했어요',
      career: '12년',
      intro: '60대 이상 회원 수업을 오래 맡았습니다. 균형 잡기와 낙상 예방 동작부터 '
          '시작해 천천히 강도를 올립니다.',
      certifications: <String>['건강운동관리사', '노인스포츠지도사'],
    ),
    // 카카오 Local 에서 온 주변 헬스장의 소속 트레이너(#329). gymId 가 카카오
    // place id 라서 데모 픽스처와 실 API 응답 양쪽에 그대로 붙는다.
    // **시연용 가상 인물이다** — 실재 업체의 실제 트레이너가 아니다.
    Trainer(
      id: 'trainer-demo-jung',
      gymId: '11621774', // 휘트니스에이든
      name: '정트레이너',
      role: '퍼스널 트레이너',
      reason: '감량 정체기를 넘기는 방법을 같이 찾아요',
      career: '6년',
      intro: '체중이 멈춘 시점에 식사량과 운동량을 다시 맞추는 일을 자주 합니다. '
          '몸무게보다 둘레와 체성분 변화를 기준으로 봅니다.',
      certifications: <String>['생활스포츠지도사 2급'],
    ),
    Trainer(
      id: 'trainer-demo-ha',
      gymId: '11621774',
      name: '하트레이너',
      role: '체형 교정 트레이너',
      reason: '앉아서 굳은 목과 어깨를 풀어드려요',
      career: '4년',
      intro: '오래 앉아 생긴 목·어깨 불편을 주로 다룹니다. 스트레칭과 가벼운 근력 '
          '운동을 섞어 한 시간을 채웁니다.',
      certifications: <String>['필라테스 지도자', '생활스포츠지도사 2급'],
    ),
    Trainer(
      id: 'trainer-demo-han',
      gymId: '1558845892', // 하이핏
      name: '한트레이너',
      role: '퍼스널 트레이너',
      reason: '기구가 처음인 분께 눈높이를 맞춰요',
      career: '3년',
      intro: '기구 사용법부터 하나씩 익히는 수업입니다. 무게를 올리기 전에 자세가 '
          '자리를 잡을 때까지 시간을 씁니다.',
      certifications: <String>['퍼스널트레이닝 CPT'],
    ),
    Trainer(
      id: 'trainer-demo-oh',
      gymId: '1558845892',
      name: '오트레이너',
      role: '그룹 PT 트레이너',
      reason: '여럿이 하면 빠지는 날이 줄어요',
      career: '5년',
      intro: '3~5인 그룹 수업을 맡습니다. 서로 속도를 맞추다 보면 혼자 할 때보다 '
          '빠지는 날이 줄어듭니다.',
      certifications: <String>['생활스포츠지도사 2급'],
    ),
    Trainer(
      id: 'trainer-demo-seo',
      gymId: '328969863', // 빌드업짐 PT 신촌점
      name: '서트레이너',
      role: '재활 전문 트레이너',
      reason: '병원 재활 이후 복귀 단계를 봐드려요',
      career: '10년',
      intro: '병원 재활이 끝난 뒤 일상 운동으로 넘어가는 구간을 맡습니다. 통증 기록을 '
          '함께 남기며 주 단위로 강도를 조절합니다.',
      certifications: <String>['물리치료사', '건강운동관리사'],
    ),
    Trainer(
      id: 'trainer-demo-nam',
      gymId: '328969863',
      name: '남트레이너',
      role: '퍼스널 트레이너',
      reason: '스쿼트·데드리프트 자세를 영상으로 잡아드려요',
      career: '7년',
      intro: '스쿼트와 데드리프트 자세 교정을 주로 합니다. 영상으로 찍어 함께 보면서 '
          '바뀐 점을 확인합니다.',
      certifications: <String>['퍼스널트레이닝 CPT'],
    ),
    Trainer(
      id: 'trainer-demo-moon',
      gymId: '696444256', // 신인규피티스튜디오
      name: '문트레이너',
      role: '퍼스널 트레이너',
      reason: '식단 기록을 매주 같이 점검해요',
      career: '7년',
      intro: '1:1 수업만 진행합니다. 매주 식사 기록을 함께 보고 다음 주에 바꿀 것을 '
          '한 가지씩 정합니다.',
      certifications: <String>['스포츠 영양사', '생활스포츠지도사 2급'],
    ),
    Trainer(
      id: 'trainer-demo-bae',
      gymId: '696444256',
      name: '배트레이너',
      role: '러닝 코치',
      reason: '무릎이 편한 달리기 자세를 찾아드려요',
      career: '5년',
      intro: '달리기 자세와 호흡을 봐드립니다. 무릎에 부담이 덜 가는 보폭을 찾는 데 '
          '수업 시간을 많이 씁니다.',
      certifications: <String>['생활스포츠지도사 2급'],
    ),
  ];

  @override
  Future<Gym?> fetchMyGym() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (_myGymId == null) return null;
    return _gyms.where((Gym gym) => gym.id == _myGymId).firstOrNull;
  }

  @override
  Future<List<Gym>> fetchNearby() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _gyms;
  }

  @override
  Future<void> disconnectMyGym() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    // 헬스장을 떠나면 그곳 소속 트레이너 연결도 함께 사라진다.
    _myGymId = null;
    _myTrainerId = null;
  }

  @override
  Future<Trainer?> fetchMyTrainer() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (_myTrainerId == null) return null;
    return _trainers
        .where((Trainer trainer) => trainer.id == _myTrainerId)
        .firstOrNull;
  }

  @override
  Future<List<Trainer>> fetchTrainersByGym(String gymId) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return _trainers
        .where((Trainer trainer) => trainer.gymId == gymId)
        .toList(growable: false);
  }

  @override
  Future<List<Trainer>> fetchAllTrainers() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _trainers;
  }

  @override
  Future<Trainer?> fetchTrainer(String trainerId) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return _trainers
        .where((Trainer trainer) => trainer.id == trainerId)
        .firstOrNull;
  }

  @override
  Future<List<Trainer>> fetchRecommendedTrainers() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    // 추천 사유가 붙은 트레이너만 레일에 올린다.
    return _trainers
        .where((Trainer trainer) => trainer.reason?.isNotEmpty ?? false)
        .toList(growable: false);
  }

  @override
  Future<void> disconnectMyTrainer() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    // 헬스장 연결은 그대로 두고 담당 트레이너만 뗀다.
    _myTrainerId = null;
  }
}
