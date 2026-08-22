import 'package:oncare_trainer/features/clients/domain/entities/client_period.dart';

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
