/// '주의' 는 회원 앱과 같은 빨강이다. (#690)
///
/// 색이 되돌아가면 화면에서는 조용히 주황으로 보일 뿐이라 리뷰에서 놓치기 쉽다.
/// 회원이 자기 폰에서 빨갛게 보는 것을 트레이너가 주황으로 보는 상태로 돌아가지
/// 않도록 여기서 못을 박는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/widgets/alert_badge.dart';

void main() {
  group('주의 색', () {
    test('주의와 목표 초과가 같은 빨강이다', () {
      // 회원 앱 `FigmaColors.dangerRed` 와 같은 값.
      expect(AppColors.warning, const Color(0xFFF04438));
      expect(AppColors.warning, AppColors.overTarget);
    });

    test('완료율 저조도 목표 초과와 같은 색으로 알린다', () {
      // 예전에는 이쪽만 주황이라 같은 '주의' 가 두 세기로 보였다.
      expect(
        alertColor(ClientAlert.lowCompletion),
        alertColor(ClientAlert.sodiumOver),
      );
      expect(alertColor(ClientAlert.lowCompletion), AppColors.warning);
    });

    test('처리 필요는 여전히 남색이다', () {
      // 답장 대기는 주의가 아니다. 전부 빨갛게 만들면 목록에서 무엇이 급한지
      // 색으로는 구분되지 않는다.
      expect(alertColor(ClientAlert.unanswered), AppColors.primary);
      expect(alertColor(ClientAlert.unanswered), isNot(AppColors.warning));
    });

    test('브랜드 주황은 주의와 다른 색으로 남는다', () {
      // 메모·안내·진행 척도의 '부분' 이 쓰는 색. 주의와 같아지면 그 자리들이
      // 없는 위험을 있다고 말하게 된다.
      expect(AppColors.brandOrange, const Color(0xFFFF953C));
      expect(AppColors.brandOrange, isNot(AppColors.warning));
    });
  });
}
