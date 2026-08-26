import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 리포트 등록 안내. (#1421)
///
/// 트레이너 앱의 `ReportRegisteredCard` 와 **같은 정보 구조**다 — 아이콘,
/// `리포트가 등록되었어요`, 대상 주, 그리고 다음 행동 한 줄. 같은 사건이
/// 한쪽에서는 파일 카드로, 다른 쪽에서는 안내 카드로 보이면 두 사람이 같은
/// 리포트를 두고 다른 것을 본 채로 이야기하게 된다.
///
/// 색만 각 앱의 메인 색을 쓴다. 구조가 같으면 같은 카드로 읽히고, 색은 어느
/// 앱을 보고 있는지를 말해 준다.
///
/// 다음 행동은 역할마다 다르다. 회원은 파일을 열고([onOpenPdf]), 트레이너는
/// 리포트 탭으로 간다.
class CoachReportCard extends StatelessWidget {
  /// Creates the card.
  const CoachReportCard({
    required this.weekStart,
    this.onOpenPdf,
    super.key,
  });

  /// 카드가 가리키는 주의 월요일.
  final DateTime weekStart;

  /// 열 수 있는 PDF 가 딸려 있을 때의 동작.
  ///
  /// `null` 이면 `PDF 열기` 를 아예 그리지 않는다 — 데모처럼 파일이 없는
  /// 자리에서 눌러 봐야 실패하는 버튼을 두지 않기 위해서다.
  final VoidCallback? onOpenPdf;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));
    final String range = l.coachChatReportWeek(
      weekStart.month,
      weekStart.day,
      weekEnd.month,
      weekEnd.day,
    );
    final VoidCallback? onOpen = onOpenPdf;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.70,
      ),
      child: Material(
        color: FigmaColors.primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                // 글자 배율을 키우면 제목·기간·다음 행동이 차례로 길어진다.
                // 셋을 한 줄에 이어 붙이지 않고 세로로 쌓아 두면, 배율이
                // 커져도 잘리는 대신 카드가 아래로 자란다.
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l.coachChatReportRegistered,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        range,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      if (onOpen != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                l.coachChatReportOpenPdf,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
