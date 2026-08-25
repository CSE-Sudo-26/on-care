import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// One past workout in a client's history (운동기록 sub-tab). Decoded
/// from the drift `ClientRoutineHistory` row (`exercisesJson` becomes
/// the [exercises] list).
class RoutineHistoryEntry {
  /// Creates a history entry.
  const RoutineHistoryEntry({
    this.id = '',
    required this.dateLabel,
    required this.label,
    required this.completionRate,
    required this.exercises,
    required this.clientFeedback,
    required this.trainerNote,
    this.assignedRoutineId,
    this.completedAt,
  });

  /// Stable history id used when editing feedback.
  final String id;

  /// Display date (e.g. "7/12 (오늘)").
  final String dateLabel;

  /// Session kind (e.g. "PT 세션 · 트레이너 지도").
  final String label;

  /// 0–100 completion.
  final int completionRate;

  /// Exercise lines; a "✗" marks a skipped one (rendered struck-through).
  final List<String> exercises;

  /// Client's feedback (may be empty).
  final String clientFeedback;

  /// Trainer's note (may be empty — the note box is hidden then).
  final String trainerNote;

  /// Present only when this history row came from an assigned routine.
  final String? assignedRoutineId;

  /// 운동을 마친 시각. 실 API 는 `completed_at` 으로 늘 채워 주고, 데모는
  /// 시드가 오늘 위에 얹은 날짜를 준다. [dateLabel] 은 화면에 그릴 문자열일
  /// 뿐이라 기간을 판단하는 데 쓸 수 없다 — 거르는 쪽은 언제나 이 값이다.
  final DateTime? completedAt;
}

/// [range] 안에 있는 기록만. 시작·끝 모두 **포함**이고 시각은 버린다 —
/// 서버가 주는 완료 시각은 하루 중 아무 때나이므로, 마지막 날 0시와 견주면
/// 그날 저녁 운동이 통째로 빠진다.
///
/// [RoutineHistoryEntry.completedAt] 이 없는 기록은 **늘 남긴다**. 날짜를 모르는
/// 것과 그 기간이 아닌 것은 다른 말이고, 모른다고 숨기면 트레이너 눈에는
/// 기록이 사라진 것으로 보인다(#1114).
List<RoutineHistoryEntry> historyInRange(
  Iterable<RoutineHistoryEntry> entries,
  ClientDateRange range,
) {
  final DateTime from = DateTime(
    range.from.year,
    range.from.month,
    range.from.day,
  );
  final DateTime to = DateTime(range.to.year, range.to.month, range.to.day);
  return entries
      .where((RoutineHistoryEntry entry) {
        final DateTime? at = entry.completedAt;
        if (at == null) return true;
        final DateTime day = DateTime(at.year, at.month, at.day);
        return !day.isBefore(from) && !day.isAfter(to);
      })
      .toList(growable: false);
}

/// 화면에 그리는 기록 종류 이름. (#1453)
///
/// 옛 시드·픽스처가 `AI 루틴 · 자율 운동` 이라는 이름으로 저장돼 있다. 지금
/// 두 앱이 같은 대상을 부르는 이름은 `AI 개인운동` 이다. 저장된 문자열을
/// 고치는 마이그레이션 대신 **그릴 때 정규화**한다 — 이미 깔린 데모 DB 와
/// 실서버의 옛 행까지 한 번에 같은 이름으로 보이고, 새 시드는 애초에 새
/// 이름으로 저장한다.
String routineKindLabel(AppLocalizations l, String raw) {
  const String legacyAiRoutine = 'AI 루틴 · 자율 운동';
  return raw.trim() == legacyAiRoutine ? l.workoutKindAiPersonal : raw;
}

/// 고객 피드백 상자의 제목. 무엇에 달린 말인지까지 적는다. (#1453)
///
/// 배정된 개인 운동 기록이고 운동이 하나면 그 운동 이름을 넣는다. 여러 개가
/// 묶인 기록(PT·프로그램)은 세션 전체에 달린 말이므로 운동 하나에 억지로
/// 붙이지 않는다.
String clientFeedbackTitle(AppLocalizations l, RoutineHistoryEntry entry) {
  if (entry.assignedRoutineId == null) return l.clientFeedbackSession;
  if (entry.exercises.length != 1) return l.clientFeedbackPersonal;
  final String name = _exerciseName(entry.exercises.single);
  return name.isEmpty ? l.clientFeedbackPersonal : l.clientFeedbackOn(name);
}

/// `런닝 25분 ✓` 처럼 분량·표시가 붙은 줄에서 운동 이름만 떼어 낸다.
String _exerciseName(String line) {
  final String cleaned = line.replaceAll('✓', '').replaceAll('✗', '').trim();
  final RegExp trailing = RegExp(
    r'\s+(\d+[^\s]*|\(.*\))$',
  );
  String name = cleaned;
  while (trailing.hasMatch(name)) {
    name = name.replaceFirst(trailing, '').trim();
  }
  return name;
}
