import 'package:flutter/material.dart';

import 'package:oncare/features/exercise/domain/entities/consultation_draft.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// [PreferredTime] → 현지화 문구. "시간 협의"거나 로케일에 맞는 "오후 7:00" 형태.
///
/// 엔티티는 라벨이 아니라 값(계약)을 들고 있으므로 화면이 렌더 시점에 만든다 — 그래야
/// 서버에서 복원한 신청도 같은 문구로 보인다(#327 의 연장, #1256).
String preferredTimeLabel(
  BuildContext context,
  AppLocalizations l,
  PreferredTime time,
) {
  final TimeOfDay? at = time.timeOfDay;
  if (at == null) return l.exTimeFlexible;
  return MaterialLocalizations.of(context).formatTimeOfDay(at);
}
