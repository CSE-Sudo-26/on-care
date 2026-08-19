/// 화면에 적는 수치의 표기 규칙 — 소수 첫째 자리까지만 남기고, 정수는 천 단위
/// 콤마만 붙인다.
///
/// 영양 요약 카드와 기간 추이 카드가 **같은 화면에 나란히** 놓인다. 두 곳이
/// 각자 서식을 들고 있으면 당류 17.8 이 한쪽에서 `17.8`, 다른 쪽에서 `18` 로
/// 찍히는 일이 생기고, 그건 회원이 바로 알아챈다. 한 함수로 모아 둔다.
String formatNumber(num value) {
  if (value != value.roundToDouble()) return value.toStringAsFixed(1);
  return value.toInt().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (Match _) => ',',
  );
}
