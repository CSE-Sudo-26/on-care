/// 일정 상태·종류의 **계약값**과 그 표시 문구를 갈라 두는 곳. (#501)
///
/// `TrainerSchedule.status`(`예정`|`완료`|`공백`)와 `type`(`1:1 PT`|`상담`)은 화면
/// 문구처럼 보이지만 실제로는 **DB 에 저장되고 서버로 나가는 값**이다. 백엔드가
/// `status == '예정'` 인 행만 완료 처리하고(`trainer_service.complete_session`)
/// drift 쿼리도 이 문자열로 거른다.
///
/// 다국어를 넣으면서 가장 쉽게 저지를 수 있는 사고가 이 값을 화면 문구로 착각해
/// 번역하는 것이다. 영어 로케일에서 `status: 'Completed'` 가 저장되는 순간 그 행은
/// 어느 쿼리에도 걸리지 않고, 되돌리려면 데이터를 고쳐야 한다.
///
/// 그래서 **계약값은 여기 상수로 못 박고**, 화면에 보일 문구는 `AppLocalizations`
/// 에서 따로 가져온다. 코드에 흩어진 리터럴을 지우면 어느 쪽 용도인지 읽는 사람이
/// 헷갈릴 일도 없다.
library;

import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// `TrainerSchedule.status` 에 저장되는 값. **번역하지 않는다.**
abstract final class ScheduleStatus {
  static const String upcoming = '예정';
  static const String done = '완료';
  static const String gap = '공백';
}

/// `TrainerSchedule.type` 에 저장되는 값. **번역하지 않는다.**
abstract final class SessionType {
  static const String personalTraining = '1:1 PT';
  static const String consultation = '상담';

  /// 일정 생성·수정 화면의 선택지 순서.
  static const List<String> all = <String>[personalTraining, consultation];
}

/// 저장된 상태값 → 화면 문구.
String scheduleStatusLabel(AppLocalizations l, String status) => switch (status) {
  ScheduleStatus.upcoming => l.scheduleStatusUpcoming,
  ScheduleStatus.done => l.scheduleStatusDone,
  ScheduleStatus.gap => l.scheduleStatusGap,
  // 서버가 새 상태를 추가했는데 앱이 모르는 경우. 빈칸을 보여 주느니 원문을 그대로
  // 내보낸다 — 무엇이 들어왔는지 화면에서 확인할 수 있다.
  _ => status,
};

/// 저장된 종류값 → 화면 문구.
String sessionTypeLabel(AppLocalizations l, String type) => switch (type) {
  SessionType.personalTraining => l.sessionTypePersonalTraining,
  SessionType.consultation => l.sessionTypeConsultation,
  _ => type,
};
