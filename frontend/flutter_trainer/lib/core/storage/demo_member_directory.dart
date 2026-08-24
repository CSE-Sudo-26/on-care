/// 아직 트레이너와 연결되지 않은 데모 회원 한 명 — 회원 앱 마이페이지에 이미
/// 등록해 둔 프로필이라고 가정한다. "신규 고객 등록"(회원 ID로 연결) 데모
/// 시나리오가 이 명부에서 찾아 연결한다.
///
/// 성별·생년월일이 여기 있는 이유는 트레이너가 연결 시점에 입력하는 값이
/// 아니라는 것을 데모에서도 보여주기 위해서다 — 연결되면
/// [DemoProspectiveMember] 가 들고 있는 값 그대로가 로컬 고객 행에 들어간다.
class DemoProspectiveMember {
  const DemoProspectiveMember({
    required this.id,
    required this.name,
    required this.gender,
    required this.birthDate,
    required this.goal,
  });

  /// 회원이 자기 앱 MY 탭에서 확인해 트레이너에게 알려주는 회원 ID이자,
  /// 연결 뒤 고객 행의 id가 되는 값 — 실 서비스의 `User.id` 형식
  /// (`user-<12자리 hex>`)을 그대로 흉내낸다. `DEMO-1`처럼 짧고 추측하기
  /// 쉬운 값이면 회원 ID가 실제로는 복잡한 식별자라는 감이 오지 않는다.
  final String id;
  final String name;

  /// `male`/`female`/`other` — 회원이 이미 등록해 둔 값.
  final String gender;
  final DateTime birthDate;
  final String goal;

  /// [today] 기준 만 나이. 생일이 지났는지까지 본다 — 연도 차만 빼면 생일
  /// 전 몇 달은 실제보다 한 살 많게 나온다.
  int ageOn(DateTime today) {
    int age = today.year - birthDate.year;
    final bool birthdayPassed =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!birthdayPassed) age -= 1;
    return age;
  }
}

/// 데모에서 "아직 연결되지 않은 회원"을 시연하기 위한 고정 명부.
///
/// 실서비스에서는 회원이 자기 앱에 등록한 실제 계정이 이 자리를 하고, 회원
/// ID는 `User.id`(회원 앱 MY 탭의 "내 회원 ID", `user-{uuid4 hex 12자리}`
/// 형식)다. 데모에는 그 회원 계정 백엔드가 없어 같은 모양의 명부를 로컬에
/// 고정해 둔다.
final List<DemoProspectiveMember> demoProspectiveMembers =
    <DemoProspectiveMember>[
      DemoProspectiveMember(
        id: 'user-8f2a41c9d6e3',
        name: '이수아',
        gender: 'female',
        birthDate: DateTime(1996, 4, 12),
        goal: '체지방 감량',
      ),
      DemoProspectiveMember(
        id: 'user-1c7b93f04a58',
        name: '박준서',
        gender: 'male',
        birthDate: DateTime(1990, 11, 3),
        goal: '근력 향상',
      ),
    ];

/// [id] 로 찾는다 — 앞뒤 공백·대소문자는 같은 회원 ID로 본다(실 서비스의
/// `func.lower(User.id)` 비교와 같은 규칙). 이미 정규화해 넘겨도 안전하도록
/// 여기서도 한 번 더 정규화한다.
DemoProspectiveMember? findDemoProspectiveMemberById(String id) {
  final String normalized = id.trim().toLowerCase();
  for (final DemoProspectiveMember member in demoProspectiveMembers) {
    if (member.id == normalized) return member;
  }
  return null;
}

/// "이미 연결된 회원" 데모 시나리오 — 새 픽스처를 또 만들지 않고 트레이너의
/// 대표 고객 김민수(`seed-client-1`)를 그대로 쓴다. 실제로 로스터에 있는
/// 행이라야 "이미 연결됨" 이라는 응답이 거짓 없이 나온다.
///
/// 회원 앱 MY 탭이 데모 모드에서 보여주는 "내 회원 ID"([MockMyHealthRepository]
/// 의 `id`)와 **일부러 맞춰 뒀다** — 회원이 자기 ID를 보여주고 트레이너가
/// 그걸 그대로 입력해 연결하는 이 기능은 두 데모를 오가며 같은 ID가 통해야
/// 시연이 앞뒤가 맞는다.
///
/// 진짜 `user-demo`(실서버·양쪽 앱 시드·다수 테스트에 박혀 있는 김민수의
/// 실제 계정 id)를 그대로 쓰지 않고 복잡한 형태로 새로 지은 이유: 그 값은
/// 이 신규 고객 등록 기능과 무관한 채팅·라우팅·운동 픽스처 등 수십 곳이
/// 공유하는 식별자라, 여기서 값을 바꾸려면 그 전부를 함께 바꿔야 한다.
/// 지금은 이 기능이 노출하는 두 데모(트레이너웹·회원 앱 MY 탭)에서만
/// 새 값을 쓰고, 실 계정 id 자체를 복잡한 형태로 바꾸는 일은 서버 배포
/// 시점의 후속 작업으로 미룬다.
const String demoAlreadyLinkedMemberId = 'user-7d4e9a2c5f18';
const String demoAlreadyLinkedClientId = 'seed-client-1';
