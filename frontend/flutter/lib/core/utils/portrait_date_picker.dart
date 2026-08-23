import 'package:flutter/material.dart';

/// [showDatePicker] 를 항상 세로(portrait) 배치로 띄운다.
///
/// Material 은 다이얼로그를 담는 화면이 가로로 넓으면(landscape) 달력을
/// 헤더·그리드가 좌우로 나뉜 모양으로 바꾼다. 넓은 데스크톱 창에서 열리면
/// 그대로 두는 것만으로 모달마다 매번 좌우로 퍼진 달력이 뜬다 — 세로로
/// 좁고 긴 모양을 원한다면 그때마다 다이얼로그 자신의 화면 판단만
/// 속여야 한다.
///
/// 다이얼로그의 `MediaQuery.size` 만 가로·세로를 뒤바꿔 넘긴다 — 앱
/// 전체가 아니라 이 다이얼로그의 내부 레이아웃 판단(`Orientation`)만
/// 영향을 받는다. 이미 세로인 화면(좁은 창)에서는 그대로 둔다.
Future<DateTime?> showPortraitDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.input,
  TransitionBuilder? builder,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    initialEntryMode: initialEntryMode,
    builder: (context, child) {
      final Widget themed = builder == null ? child! : builder(context, child);
      final MediaQueryData query = MediaQuery.of(context);
      if (query.size.width <= query.size.height) return themed;
      return MediaQuery(
        data: query.copyWith(size: Size(query.size.height, query.size.width)),
        child: themed,
      );
    },
  );
}
