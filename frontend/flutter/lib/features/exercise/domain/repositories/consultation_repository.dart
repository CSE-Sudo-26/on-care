import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';
import 'package:oncare/features/exercise/domain/entities/consultation_request.dart';

/// 상담 목록 한 쪽의 건수. 서버 기본값과 같다(#980).
const int consultationPageSize = 50;

/// 상담 신청 접수·조회. (#327)
abstract class ConsultationRepository {
  /// 접수된 상담 id. 같은 대상에 이미 대기 중이면 [DuplicatePendingConsultation].
  Future<String> create(ConsultationDraft draft);

  /// 내가 낸 상담 **최근 [limit] 건**(최신순). 앱을 다시 열어도 대기 중 신청이 화면에
  /// 남아야 한다 — 목록이 비면 `hasPending` 이 false 라 같은 대상에 다시 눌러 409 를
  /// 받는다(#327).
  ///
  /// 서버가 한 쪽만 준다(#980). 화면이 쓰는 것은 대기 중인 신청뿐이고 그것은 대개 가장
  /// 최근 건이라 첫 쪽으로 충분하다. 그보다 오래된 대기 신청이 남아 있는 드문 경우는
  /// 접수 시 서버가 409 로 알려 주고, 컨트롤러가 그 응답으로 목록을 채운다.
  Future<List<ConsultationRequest>> fetchMine({int limit});
}

/// 서버가 409 로 거절한 경우 — 같은 헬스장/트레이너에 대기 중인 신청이 이미 있다.
/// 화면은 이미 `hasPending` 으로 버튼을 막지만, 다른 기기에서 넣었을 수 있어
/// 서버 판정을 최종으로 삼는다.
class DuplicatePendingConsultation implements Exception {
  const DuplicatePendingConsultation();
}
