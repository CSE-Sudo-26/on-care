/// 부분 수정에서 **"건드리지 않음"과 "지움"** 을 가르는 값.
///
/// 목표 컬럼은 전부 nullable 이고, `null` 은 *미설정 또는 목표 해제*를 뜻한다.
/// 서버(`HealthGoalsUpdate`)는 `exclude_unset` 으로 이 둘을 이미 구분한다 —
/// 키가 없으면 그대로 두고, 키가 `null` 로 오면 목표를 해제한다.
///
/// 그런데 Dart 쪽 인자가 그냥 `int?` 면 호출부가 그 구분을 표현할 수 없다.
/// `null` 하나로 두 뜻을 다 실어야 해서 어느 한쪽은 반드시 잃는데, 지금까지는
/// "건드리지 않음"으로 읽어 **목표를 지울 방법이 없었다.**
///
/// - 인자를 주지 않으면(`null`) 그 목표는 손대지 않는다.
/// - [GoalUpdate.clear] 또는 `GoalUpdate(null)` 은 목표를 해제한다.
/// - `GoalUpdate(2000)` 은 값을 세운다.
///
/// 확장 타입(`extension type`)이 아니라 진짜 클래스여야 한다 — 확장 타입은
/// 지워지므로 `GoalUpdate?` 가 다시 `int?` 가 되어, 없앴다던 모호함이 그대로
/// 돌아온다.
class GoalUpdate {
  /// 이 목표를 [value] 로 세운다. `null` 이면 해제한다.
  const GoalUpdate(this.value);

  /// 목표를 해제한다 — 서버로 JSON `null` 이 나간다.
  const GoalUpdate.clear() : value = null;

  /// 세울 값. `null` 은 해제다.
  final int? value;

  @override
  bool operator ==(Object other) => other is GoalUpdate && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'GoalUpdate($value)';
}
