import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 서버가 준 사유 문구(`detail`)를 화면에 그대로 쓸지 고른다. (#501)
///
/// 백엔드는 사유를 **한국어로만** 준다 — `"현재 비밀번호가 일치하지 않습니다."`
/// 처럼. 한국어 화면에서는 이 문장이 우리가 대신 붙일 어떤 일반 문구보다 정확해
/// 그대로 보여 준다. 하지만 영어 화면에서는 그 자리만 한국어로 남기 때문에,
/// 로케일이 한국어가 아니면 [fallback](현지화된 기본 문구)으로 물러난다.
///
/// 서버가 안정적인 오류 **코드**를 주게 되면 이 함수는 코드→문구 매핑으로
/// 대체된다. 그때까지는 사유를 잃지 않으면서 영어 화면에 한국어가 새지 않게
/// 하는 최선이다.
String serverDetailOr(AppLocalizations l, String? detail, String fallback) {
  final text = detail?.trim() ?? '';
  if (text.isEmpty) return fallback;
  return l.localeName.startsWith('ko') ? text : fallback;
}
