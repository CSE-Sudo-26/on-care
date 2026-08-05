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
  ];

  final List<CoachMessage> _chat = <CoachMessage>[
    const CoachMessage(
      id: 'seed-m1',
      sender: CoachSender.trainer,
      body: '오늘 점심 등록 잘 확인했어요. 나트륨만 조금 신경 써 주세요!',
      timeLabel: '13:20',
    ),
  ];

  bool _read = false;

  @override
  Future<MemberCoach?> fetchCoach() async => _coach;

  @override
  Future<List<CoachRoutine>> fetchRoutines() async =>
      List<CoachRoutine>.unmodifiable(_routines);

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
      ),
    );
  }

  @override
  Future<void> markRead() async => _read = true;

  @override
  Future<int> unreadCount() async =>
      _read ? 0 : _chat.where((m) => m.sender == CoachSender.trainer).length;
}
