import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/repositories/member_coach_repository.dart';

/// In-memory demo coach for `USE_MOCK_API=true`. Mirrors the trainer app's
/// seed identity (김트레이너) so the two demo apps tell one story. Chat is
/// stateful for the session so a sent message appears in the thread.
class MockMemberCoachRepository implements MemberCoachRepository {
  MockMemberCoachRepository();

  static const _coach = MemberCoach(
    trainerId: 'seed-trainer',
    name: '김트레이너',
    specialty: '퍼스널 트레이너',
    career: '7년',
    intro: '혈압 관리와 체중 감량 전문 트레이너입니다.',
    gymName: '온케어짐 신촌점',
    goal: '혈압 관리 · 체중 감량',
  );

  final List<CoachRoutine> _routines = <CoachRoutine>[
    const CoachRoutine(
      id: 'seed-r1',
      name: '저강도 유산소 (걷기)',
      minutes: 20,
      type: '유산소',
      reason: '혈압 안정에 효과적',
      source: 'ai',
    ),
    const CoachRoutine(
      id: 'seed-r2',
      name: '코어 스트레칭',
      minutes: 10,
      type: '스트레칭',
      reason: '허리 부담 완화',
      source: 'trainer',
    ),
    const CoachRoutine(
      id: 'seed-r3',
      name: '어깨 관절 보호 스트레칭',
      minutes: 8,
      type: '스트레칭',
      reason: 'PT 피드백 반영 · 오른쪽 어깨 보호',
      source: 'ai',
    ),
  ];

  /// 시드 메시지 정렬 기준점. 날짜 자체에는 의미가 없다 — 화면에 나오는 것은
  /// `timeLabel` 이고, 이 값은 순서를 고정하는 용도다.
  static final DateTime _seedEpoch = DateTime.utc(2026);

  /// 담당 트레이너와의 대화 — **이미 진행 중인** 코칭의 사흘치 토막.
  ///
  /// 첫 인사로 시작하지 않는다. 이 회원은 PT 12회차를 지난 사람이라(운동 이력·
  /// AI 코치 카드가 그렇게 말한다) 배정 인사가 앞에 붙으면 다른 화면과 어긋난다.
  ///
  /// 데모 사용자는 트레이너 앱의 시드 고객 김민수와 같은 사람이라 **두 앱이
  /// 같은 대화를 보여야 한다.** 전에는 이쪽만 메시지 한 개였고 그 문구는
  /// 저장소 어디에도 짝이 없어서, 같은 사람의 대화가 앱마다 달랐다. (#543)
  ///
  /// 같은 목록이 아래 두 곳에도 있다 — 한 곳만 고치면 그 파일의 테스트가
  /// 깨진다:
  ///  * `frontend/flutter_trainer/lib/core/storage/seed_clients.dart` (트레이너 시점)
  ///  * `backend/app/db/seed_member_data.py::_CHAT` (실서버 시드)
  ///
  /// 오늘 것이 아닌 메시지는 트레이너 앱과 같은 `요일 시각` 형식을 쓴다 — 이
  /// 화면에는 날짜 구분선이 없어서, 라벨이 며칠 전인지까지 말해 주지 않으면
  /// 3일치가 한 덩어리로 읽힌다.
  final List<CoachMessage> _chat = <CoachMessage>[
    // 1일차.
    _seed(
      1,
      CoachSender.trainer,
      '민수님, 지난주 기록 정리해 봤는데 요일마다 이행률이 들쭉날쭉하네요. 바쁜 요일이 정해져 있나요?',
      '화 10:02',
      day: 0,
    ),
    _seed(2, CoachSender.me, '화요일이랑 목요일이 야근이 많아요 😥', '화 10:15', day: 0),
    _seed(
      3,
      CoachSender.trainer,
      '그럼 그 이틀은 15분짜리 짧은 루틴으로 바꿔 둘게요. 안 하는 것보다 훨씬 낫습니다',
      '화 10:21',
      day: 0,
    ),
    _seed(4, CoachSender.me, '그 정도면 퇴근하고도 할 수 있을 것 같아요', '화 10:24', day: 0),
    _seed(
      5,
      CoachSender.trainer,
      '혈압약 드시는 시간은 그대로시죠? 유산소가 그 시간과 겹치지 않게 잡을게요',
      '화 10:26',
      day: 0,
    ),
    _seed(6, CoachSender.me, '네, 아침 8시 그대로예요', '화 10:29', day: 0),
    _seed(
      7,
      CoachSender.trainer,
      '확인했어요. 화·목은 15분 저강도로 바꿔서 보냈습니다 🙂',
      '화 10:34',
      day: 0,
    ),
    // 2일차.
    _seed(
      8,
      CoachSender.trainer,
      '민수님, 요즘 나트륨이 목표(2,000mg) 근처에서 자주 걸리네요. 국·찌개가 잦으신 편인가요?',
      '수 09:30',
      day: 1,
    ),
    _seed(9, CoachSender.me, '회사 구내식당이라 국물이 늘 나와요 😅', '수 12:40', day: 1),
    _seed(
      10,
      CoachSender.trainer,
      '국물만 절반 남기셔도 400~500mg은 빠져요. 그거 하나만 먼저 해보죠',
      '수 12:52',
      day: 1,
    ),
    _seed(11, CoachSender.me, '오늘은 국물 안 마셨어요! 걷기도 25분 했습니다', '수 19:05', day: 1),
    _seed(
      12,
      CoachSender.trainer,
      '좋아요 👏 그 한 가지만 지켜도 추이가 달라져요',
      '수 19:20',
      day: 1,
    ),
    _seed(
      13,
      CoachSender.trainer,
      '내일 루틴은 걷기 20분으로 조금 늘려서 보냈어요. 주말까지 이 페이스로 가봐요',
      '수 19:22',
      day: 1,
    ),
    // 3일차.
    _seed(
      14,
      CoachSender.trainer,
      '민수님, AI 식단 분석 잘 받았어요 👍 오늘 나트륨이 목표치를 좀 넘었는데 어떠셨어요?',
      '18:10',
      day: 2,
    ),
    _seed(15, CoachSender.me, '찌개 먹을 때 국물을 많이 마셨나봐요 😅', '18:13', day: 2),
    _seed(
      16,
      CoachSender.trainer,
      '그렇군요! 오늘 PT 후에 부상이나 불편한 데는 없으셨나요?',
      '18:14',
      day: 2,
    ),
    _seed(17, CoachSender.me, '무릎이 가볍게 당기긴 했는데 괜찮아요', '18:16', day: 2),
    _seed(
      18,
      CoachSender.trainer,
      '확인했어요. AI가 오늘 식단 기반으로 유산소 루틴을 추천했는데, 무릎 상태 감안해서 런닝 대신 걷기로 조정해서 보낼게요. 다음 PT 때 봐요 💪',
      '18:18',
      day: 2,
    ),
  ];

  /// [day] 는 며칠째 대화인가 (0 = 스레드의 첫 날).
  ///
  /// `timeLabel` 은 화면에 보일 문자열일 뿐 날짜가 아니다. 날짜를 실제로
  /// 벌려 두지 않으면, 대화를 날짜로 묶는 쪽(하루치 AI 분석 안내)이 사흘치를
  /// 하루로 본다.
  static CoachMessage _seed(
    int index,
    CoachSender sender,
    String body,
    String timeLabel, {
    required int day,
  }) => CoachMessage(
    id: 'seed-m$index',
    sender: sender,
    body: body,
    timeLabel: timeLabel,
    createdAt: _seedEpoch.add(Duration(days: day, minutes: index)),
  );

  bool _read = false;

  @override
  Future<MemberCoach?> fetchCoach() async => _coach;

  @override
  Future<List<CoachRoutine>> fetchRoutines() async =>
      List<CoachRoutine>.unmodifiable(_routines);

  /// 데모에는 트레이너가 잡은 일정이 없다. (#490)
  ///
  /// 시드로 만들어 넣지 않는 이유: 데모 홈에 없던 카드가 생겨 화면이 지금과
  /// 달라진다. 실모드에서만 나타나는 것이 맞다.
  @override
  Future<List<CoachSession>> fetchSessions() async => const <CoachSession>[];

  @override
  Future<List<CoachMessage>> fetchChat() async =>
      List<CoachMessage>.unmodifiable(_chat);

  @override
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    _chat.add(
      CoachMessage(
        id: 'me-${now.microsecondsSinceEpoch}',
        sender: CoachSender.me,
        body: trimmed,
        timeLabel:
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}',
        createdAt: now,
      ),
    );
  }

  @override
  Future<void> markRead() async => _read = true;

  /// 마지막으로 내가 보낸 메시지 **뒤에** 온 트레이너 메시지만 미읽음이다.
  ///
  /// 스레드 전체의 트레이너 메시지를 세면 3일치 대화에서 배지가 8이 된다 —
  /// 이미 주고받은 대화까지 안 읽은 것으로 치는 셈이라 숫자가 거짓말을 한다.
  @override
  Future<int> unreadCount() async {
    if (_read) return 0;
    final int lastMine = _chat.lastIndexWhere(
      (CoachMessage m) => m.sender == CoachSender.me,
    );
    return _chat.skip(lastMine + 1).length;
  }
}
