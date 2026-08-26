/// 주로 관리하고 싶은 항목. (#1471)
///
/// 서버는 이 값을 `HealthProfile.conditions` 한 칸에 쉼표로 이어 저장한다 —
/// 온보딩이 처음부터 그렇게 저장해 왔고, 그 값을 MY `건강 목표` 가 그대로
/// 이어받는다. 저장 형식을 바꾸면 이미 저장된 값이 화면에서 사라지므로,
/// 형식은 그대로 두고 읽고 쓰는 규칙만 한곳에 모은다.
///
/// **진단·치료 중인 질환을 단정하는 값이 아니다.** 화면 문구도 어디에 초점을
/// 둘지 묻는 말로만 쓴다.
library;

/// 저장에 쓰는 값. 화면 라벨은 로케일이 따로 들고 있다.
const String kHealthFocusHypertension = '고혈압';
const String kHealthFocusDiabetes = '당뇨';

/// 저장 문자열 → 고른 항목. 모르는 값은 버린다 — 옛 자유 입력이 섞여 있어도
/// 칩이 지어내지 않는다.
Set<String> parseHealthFocus(String raw) {
  const Set<String> known = <String>{
    kHealthFocusHypertension,
    kHealthFocusDiabetes,
  };
  return raw
      .split(',')
      .map((String part) => part.trim())
      .where(known.contains)
      .toSet();
}

/// 고른 항목 → 저장 문자열. 순서를 고정해 같은 선택이 늘 같은 문자열이 된다.
String formatHealthFocus(Set<String> focus) => <String>[
  if (focus.contains(kHealthFocusHypertension)) kHealthFocusHypertension,
  if (focus.contains(kHealthFocusDiabetes)) kHealthFocusDiabetes,
].join(', ');
