import 'package:oncare/core/demo/demo_ai_advice.dart';
import 'package:oncare/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 홈 '오늘의 AI 통합 조언' 본문을 고른다.
///
/// 우선순위:
///
/// 1. [DashboardSummary.aiAdviceKey] — 데모가 싣는 로케일 독립 식별자.
///    여기서 ARB 문장으로 풀어야 영어 로케일에서 영어가 나온다(#435).
/// 2. [DashboardSummary.sodiumWarning] / [DashboardSummary.exerciseFeedback] —
///    서버가 만든 문장. 번역본이 없어 받은 그대로 쓴다.
/// 3. ARB 기본 문구.
String aiAdviceBody(AppLocalizations l, DashboardSummary summary) {
  final String? fromKey = _localized(l, summary.aiAdviceKey);
  return fromKey ??
      summary.sodiumWarning ??
      summary.exerciseFeedback ??
      l.homeAiAdviceBody;
}

/// 모르는 키는 null 을 돌려 서버 문장·ARB 기본값으로 넘긴다 — 서버가 새 키를
/// 먼저 내려도 화면이 비지 않게.
String? _localized(AppLocalizations l, String? key) => switch (key) {
  kDailyCombinedAdviceKey => l.homeAiAdviceBody,
  _ => null,
};
