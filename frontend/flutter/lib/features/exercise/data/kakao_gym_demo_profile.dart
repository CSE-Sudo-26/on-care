/// 카카오 Local 이 주지 않는 항목을 채우는 **시연용** 보강 데이터.
///
/// 카카오 Local 장소검색이 주는 것: 이름·주소·거리·좌표·전화 (실데이터)
/// 카카오가 주지 않는 것: 평점·전문분야·영업시간·소속 트레이너
///
/// 아래 값 중 [phone] 만 카카오 응답에서 가져온 실제 값이고, **평점·전문분야·
/// 영업시간은 데모를 위해 지어낸 값이다.** 실재하는 업체명에 붙는 정보이므로
/// 시연 외 용도로 쓰거나 사실처럼 표기하지 말 것. 제휴 헬스장(`/gyms/*`, #324)이
/// 들어오면 이 파일은 삭제한다.
///
/// 소속 트레이너는 `Gym` 이 아니라 `Trainer` 엔티티에 있으므로 여기 두지 않고
/// `MockGymRepository` 가 `gymId`(= 카카오 place id)로 들고 있다.
///
/// 키는 카카오 place id 라서 데모 픽스처(`local_api_interceptor`)와 실 API 응답
/// 양쪽에 동일하게 매칭된다.
class KakaoGymDemoProfile {
  const KakaoGymDemoProfile({
    required this.rating,
    required this.tags,
    this.phone,
    this.weekdayHours,
    this.weekendHours,
  });

  final double rating;
  final List<String> tags;
  final String? phone;
  final String? weekdayHours;
  final String? weekendHours;
}

/// 신촌 권역 실제 헬스장 4곳 — 이름·주소·거리·전화는 카카오 실데이터,
/// 나머지는 시연용 값이다.
const Map<String, KakaoGymDemoProfile> kKakaoGymDemoProfiles =
    <String, KakaoGymDemoProfile>{
      // 휘트니스에이든
      '11621774': KakaoGymDemoProfile(
        rating: 4.6,
        tags: <String>['다이어트', '체형 교정'],
        phone: '02-332-1720',
        weekdayHours: '06:00 - 23:00',
        weekendHours: '09:00 - 18:00',
      ),
      // 하이핏
      '1558845892': KakaoGymDemoProfile(
        rating: 4.4,
        tags: <String>['근력운동', '그룹 PT'],
        phone: '02-362-7822',
        weekdayHours: '05:30 - 24:00',
        weekendHours: '08:00 - 20:00',
      ),
      // 빌드업짐 PT 신촌점
      '328969863': KakaoGymDemoProfile(
        rating: 4.9,
        tags: <String>['PT 전문', '재활운동'],
        phone: '0502-5552-4212',
        weekdayHours: '07:00 - 23:00',
        weekendHours: '10:00 - 17:00',
      ),
      // 신인규피티스튜디오
      '696444256': KakaoGymDemoProfile(
        rating: 4.7,
        tags: <String>['1:1 PT', '식단 관리'],
        phone: '010-7616-9819',
        weekdayHours: '08:00 - 22:00',
        weekendHours: '10:00 - 16:00',
      ),
    };
