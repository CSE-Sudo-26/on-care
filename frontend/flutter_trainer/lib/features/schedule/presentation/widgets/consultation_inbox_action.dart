import 'package:flutter/material.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 상담 요청 인박스로 가는 헤더 액션. (#858, #882)
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int count = pending ?? 0;
    final bool waiting = count > 0;

    return Tooltip(
      message: l.consultTitle,
      child: Semantics(
        button: true,
        label: l.consultTitle,
        child: Material(
          color: Colors.transparent,
          borderRadius: const BorderRadius.all(AppRadius.md),
          child: InkWell(
            key: const Key('consult-inbox-entry'),
            onTap: onTap,
            borderRadius: const BorderRadius.all(AppRadius.md),
            child: Container(
              height: 36,
              width: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(AppRadius.md),
                border: Border.all(
                  color: waiting
                      ? AppColors.destructive.withValues(alpha: 0.45)
                      : AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
              child: Badge(
                isLabelVisible: waiting,
                backgroundColor: AppColors.destructive,
                textColor: AppColors.destructiveForeground,
                label: Text('$count'),
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
