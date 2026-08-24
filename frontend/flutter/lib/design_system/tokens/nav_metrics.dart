/// 하단 내비게이션 바의 치수.
///
/// 셸이 바를 그릴 때 쓰는 숫자와, 그 위에 뜨는 것들(토스트)이 비켜야 할
/// 숫자는 **같은 값이어야 한다.** 예전에는 두 값이 따로 있었고 `+` 버튼이
/// 바 위로 솟은 만큼을 토스트가 모르는 바람에, 토스트 아래에 투명한 띠가
/// 남고 `+` 원이 그 경계에 걸쳤다.
class AppNavMetrics {
  AppNavMetrics._();

  /// 목적지 아이콘과 라벨이 들어가는 바 본체의 높이.
  static const double barHeight = 58;

  /// `+` 버튼이 바 위로 솟은 만큼. 바 위젯은 이 여백까지 자기 높이로
  /// 들고 있어서(투명), 바 위에 놓이는 것은 자동으로 `+` 를 비킨다.
  static const double addButtonLift = 24;

  /// `+` 버튼의 지름.
  static const double addButtonSize = 56;

  /// 바 아래 안전영역을 이만큼까지만 따른다. 그보다 깊은 기기에서도
  /// 바가 지나치게 두꺼워지지 않는다.
  static const double maxBottomInset = 22;
}
