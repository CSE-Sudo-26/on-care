import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 상담 요청 인박스로 가는 헤더 액션. (#858, #882, #987)
///
/// 처음에는 화면 폭 전체를 쓰는 남색 그라디언트 카드였다. 면적은 제일 큰데
/// 정작 몇 건 밀렸는지가 눈에 꽂히지 않았고 — 알림이 아니라 배너로 읽혔다 —
/// 타임라인에서 세로 공간까지 빼앗았다.
///
/// 지금은 아이콘 위에 **빨간 배지**를 얹은 헤더 액션이다. 알림을 알림으로
/// 읽히게 하는 가장 익숙한 표현이고, 헤더 액션 줄에서 가장 적은 폭을 쓴다.
/// 라벨을 함께 두면 영어 로케일·큰 글자 배율에서 줄 전체가 넘친다 — #849
/// 관문이 폭 1024·en·배율 1.3 에서 그것을 잡았다. 이름은 툴팁과 시맨틱스로
/// 남는다.
///
/// 배지가 감싸는 것은 **아이콘이 아니라 아이콘을 담은 네모**다(#987). 배지는
/// 자식의 오른쪽 위 모서리에 붙는데, 17px 아이콘을 감싸면 지름 16px 짜리 빨간
/// 원이 아이콘의 절반 가까이를 덮어 무슨 버튼인지 형태로 알아볼 수 없었다.
/// 네모를 감싸면 같은 규약(오른쪽 위 모서리)을 지키면서 아이콘이 온전히 남는다.
/// 모서리 밖으로 나가는 만큼은 바깥 여백으로 미리 자리를 비워 둔다 — 헤더
/// 액션 줄에서 옆 버튼을 침범하지 않기 위해서다.
///
/// 빨강은 처리할 것이 있을 때만 뜬다: 0건이거나 아직 못 읽었으면([pending] 이
/// null) 배지 없이 조용한 버튼으로 남는다.
class ConsultationInboxAction extends StatelessWidget {
  const ConsultationInboxAction({
    super.key,
    required this.pending,
    required this.onTap,
  });

  /// 대기 중인 상담 요청 수. 아직 불러오지 못했으면 null.
  final int? pending;

  final VoidCallback onTap;

  /// 배지가 네모 밖으로 나가는 양.
  ///
  /// 자리를 미리 비워 두었더니(#987) 이 버튼만 옆의 `예약 슬롯`·`새 일정` 보다
  /// 6px 아래에 서서, 한 줄에 선 세 버튼이 서로 다른 격자를 썼다(#1013).
  /// `Badge` 는 `Clip.none` 으로 그리므로 자리를 비우지 않아도 잘리지 않는다 —
  /// 옆 버튼과 같은 36 높이를 지키는 편이 낫다.
  static const double _badgeOverflowTop = 6;
  static const double _badgeOverflowRight = 5;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int count = pending ?? 0;
    final bool waiting = count > 0;

    return Tooltip(
      message: l.consultTitle,
      child: Semantics(
        // 키는 액션 전체에 둔다 — 배지가 탭 대상(InkWell)의 바깥이라, 키가
        // 안쪽에 있으면 배지를 이 액션의 자손으로 찾을 수 없다.
        key: const Key('consult-inbox-entry'),
        button: true,
        label: l.consultTitle,
        child: Badge(
          isLabelVisible: waiting,
          alignment: Alignment.topRight,
          offset: const Offset(_badgeOverflowRight, -_badgeOverflowTop),
          backgroundColor: AppColors.destructive,
          textColor: AppColors.destructiveForeground,
          label: Text('$count'),
          child: Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.all(AppRadius.md),
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.all(AppRadius.md),
              child: Container(
                // 옆의 `예약 슬롯`·`새 일정`(`ActionButton`)과 같은 높이·모서리다.
                height: 36,
                width: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(AppRadius.md),
                  // 옆의 `예약 슬롯` 과 같은 남색 윤곽선이다. 대기 건이 있다고
                  // 테두리까지 빨갛게 물들이면 헤더에서 이 버튼만 튄다 —
                  // 알리는 일은 배지 하나로 충분하다(#1013).
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
