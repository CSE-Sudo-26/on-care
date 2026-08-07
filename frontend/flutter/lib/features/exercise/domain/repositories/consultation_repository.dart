import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';

/// 상담 신청 접수·조회. (#327)
abstract class ConsultationRepository {
  /// 접수된 상담 id. 같은 대상에 이미 대기 중이면 [DuplicatePendingConsultation].
  Future<String> create(ConsultationDraft draft);
}

/// 서버가 409 로 거절한 경우 — 같은 헬스장/트레이너에 대기 중인 신청이 이미 있다.
/// 화면은 이미 `hasPending` 으로 버튼을 막지만, 다른 기기에서 넣었을 수 있어
/// 서버 판정을 최종으로 삼는다.
class DuplicatePendingConsultation implements Exception {
  const DuplicatePendingConsultation();
}
