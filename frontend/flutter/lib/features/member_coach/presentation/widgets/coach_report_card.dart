import 'package:flutter/material.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// 리포트 등록 안내. (#1421, #1600)
///
/// 트레이너 앱의 `ReportRegisteredCard` 와 **같은 정보 구조**다 — 아이콘,
/// `리포트가 등록되었어요`, 대상 주, 그리고 다음 행동 한 줄. 같은 사건이
/// 한쪽에서는 파일 카드로, 다른 쪽에서는 안내 카드로 보이면 두 사람이 같은
/// 리포트를 두고 다른 것을 본 채로 이야기하게 된다.
///
/// 자리는 말풍선이 아니라 **대화 가운데**다. 누가 무슨 말을 했는가가 아니라
/// 스레드에 무슨 일이 있었는가를 적는 자리라, 같은 흐름의 다른 안내(`분석했어요`·
/// `개인 추천운동을 받았어요`)와 같은 모양을 쓴다.
///
/// 바탕은 흰색이고 테두리만 각 앱의 메인 색이다. 구조와 바탕이 같으면 같은
/// 안내로 읽히고, 테두리 색이 어느 앱을 보고 있는지를 말해 준다.
///
/// 다음 행동은 역할마다 다르다. 회원은 리포트를 열어 보고([onOpenPdf]),
/// 트레이너는 리포트 탭으로 간다.
class CoachReportCard extends StatelessWidget {
  /// Creates the card.
  const CoachReportCard({
    required this.weekStart,
    required this.onOpenPdf,
    super.key,
  });

  /// 카드가 가리키는 주의 월요일.
  final DateTime weekStart;

  /// `PDF 미리보기` 를 눌렀을 때.
  ///
  /// 첨부가 있으면 그 파일을, 없으면 같은 주를 회원 기록으로 정리한 문서를
  /// 연다 — 어느 쪽이든 열 것이 있으므로 버튼을 감추지 않는다(#1600).
  final VoidCallback onOpenPdf;

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
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FigmaColors.primary),
        ),
        // 글자 배율을 키우면 제목·기간·다음 행동이 차례로 길어진다. 셋을 한
        // 줄에 이어 붙이지 않고 세로로 쌓아 두면, 배율이 커져도 잘리는 대신
        // 상자가 아래로 자란다.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: FigmaColors.primary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    l.coachChatReportRegistered,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              range,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
            // 테두리 없는 글자 버튼. 안내 상자 안에서 두 번째 테두리를 그리면
            // 상자가 둘로 보인다 — 여기서 눌릴 것은 하나뿐이라 글자로 충분하다.
            TextButton(
              onPressed: onOpenPdf,
              style: TextButton.styleFrom(
                foregroundColor: FigmaColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l.coachChatReportPreviewPdf),
            ),
          ],
        ),
      ),
    );
  }
}
