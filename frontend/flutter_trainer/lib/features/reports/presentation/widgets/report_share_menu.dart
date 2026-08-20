import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/reports/data/repositories/report_repository.dart';
import 'package:oncare_trainer/features/reports/domain/weekly_report.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

/// 리포트를 내보내는 두 경로를 한 메뉴로 모은 헤더 액션. (#735)
///
/// 전에는 동작하는 `고객에게 전송` 이 피드백 입력창 아래에, 눌리지 않는
/// `PDF 내보내기` 가 헤더에 따로 있어서 "이 리포트를 어떻게 내보내지"의 답이
/// 화면 두 곳에 나뉘어 있었다.
///
/// 항목에 고객 이름을 함께 적는다 — 헤더는 본문보다 위에 있어 어느 리포트가
/// 열려 있는지 눈으로 잇기 어렵고, 잘못된 고객에게 보내는 실수가 되돌릴 수
/// 없는 종류이기 때문이다.
class ReportShareMenu extends ConsumerWidget {
  /// 메뉴 최소 너비. 두 항목 중 긴 쪽이 한 줄에 들어가는 폭이다.
  static const double _menuMinWidth = 200;

  /// 메뉴 한 줄. Material 기본은 글씨 16 · 높이 48 이라 12~13 으로 짜인 이
  /// 콘솔에서 혼자 커 보였다. 글씨는 여는 버튼(`ActionButton` 라벨)과 같은
  /// 크기·굵기로 맞춘다 — 버튼과 그 메뉴가 다른 크기로 보일 이유가 없다.
  static const ButtonStyle _itemStyle = ButtonStyle(
    textStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    ),
    minimumSize: WidgetStatePropertyAll(Size(0, 36)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.md),
    ),
  );

  const ReportShareMenu({
    super.key,
    required this.client,
    required this.weekStart,
    required this.sent,
    required this.sending,
    required this.feedbackBlank,
    required this.onSend,
    required this.generatingPdf,
    required this.onPdf,
  });

  /// 리포트를 보고 있는 고객. 로스터가 비어 있으면 null.
  final TrainerClient? client;

  /// 화면이 보고 있는 주. 헤더의 주 이동과 같은 값을 써야 다른 주의 리포트를
  /// 보내는 일이 없다.
  final DateTime weekStart;
  final bool sent;
  final bool sending;

  /// 피드백 입력창이 비었는가. 리포트 수치만 덩그러니 보내면 회원은 무슨 뜻인지
  /// 알 수 없어, 전에도 빈 피드백은 보낼 수 없었다.
  final bool feedbackBlank;

  final Future<void> Function(WeeklyReport report) onSend;
  final bool generatingPdf;
  final Future<void> Function(WeeklyReport report) onPdf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final target = client;
    // 메뉴의 **오른쪽 변**을 버튼 오른쪽 변에 맞춘다.
    //
    // 기본(LTR)은 버튼 왼쪽에 붙어 오른쪽으로 자라, 헤더 끝에 있는 이 버튼에서는
    // 창 가장자리에 닿는다. 버튼 너비를 숫자로 추정해 offset 으로 당기는 방법은
    // 라벨·글꼴이 바뀌면 곧바로 어긋나므로, 펼침 방향 자체를 뒤집는다. 안쪽
    // 내용은 다시 LTR 로 돌려 아이콘·글자 순서는 그대로 둔다.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MenuAnchor(
        // 메뉴는 앱의 다른 메뉴와 같은 면으로 그린다 — Material 기본 표면은 이
        // 콘솔의 카드보다 밝고 모서리도 달라 혼자 떠 보였다.
        style: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.card),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(AppRadius.md),
              side: BorderSide(color: AppColors.borderStrong),
            ),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: AppSpacing.xs),
          ),
          minimumSize: WidgetStatePropertyAll(Size(_menuMinWidth, 0)),
        ),
        // 헤더와 한 칸 띄운다. 가로 위치는 아래 Directionality 가 맞춘다.
        alignmentOffset: const Offset(0, AppSpacing.xs),
        menuChildren: <Widget>[
          Directionality(
            textDirection: TextDirection.ltr,
            child: MenuItemButton(
              key: const ValueKey<String>('reports-share-send'),
              style: _itemStyle,
              leadingIcon: Icon(
                sent ? Icons.check : Icons.send_outlined,
                size: 16,
              ),
              onPressed: target == null || sent || sending || feedbackBlank
                  ? null
                  : () => _send(context, ref, target),
              child: Tooltip(
                message: feedbackBlank && target != null && !sent && !sending
                    ? l.reportsShareNeedsFeedback
                    : '',
                child: Text(
                  target == null
                      ? l.reportsShareNoClient
                      : (sent
                            ? l.reportsSendStateSent
                            : (sending
                                  ? l.reportsSendStateSending
                                  : l.reportsShareSendTo(target.name))),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: MenuItemButton(
              key: const ValueKey<String>('reports-share-pdf'),
              style: _itemStyle,
              leadingIcon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
              onPressed: target == null || generatingPdf
                  ? null
                  : () => _pdf(ref, target),
              child: Text(
                generatingPdf ? l.reportsPdfGenerating : l.reportsPdfLabel,
              ),
            ),
          ),
        ],
        builder: (context, controller, _) => Directionality(
          textDirection: TextDirection.ltr,
          child: ActionButton(
            key: const ValueKey<String>('reports-share-action'),
            label: l.reportsShare,
            icon: Icons.ios_share,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
      ),
    );
  }

  /// 화면에 떠 있는 그 주의 리포트를 읽어 전송한다.
  ///
  /// 아직 로딩 중이면 보낼 내용이 없으므로 아무 일도 하지 않는다 — 빈 리포트를
  /// 보내는 것보다 낫다.
  void _send(BuildContext context, WidgetRef ref, TrainerClient target) {
    final report = ref
        .read(weeklyReportProvider((client: target, weekStart: weekStart)))
        .valueOrNull;
    if (report == null) return;
    onSend(report);
  }

  void _pdf(WidgetRef ref, TrainerClient target) {
    final report = ref
        .read(weeklyReportProvider((client: target, weekStart: weekStart)))
        .valueOrNull;
    if (report != null) onPdf(report);
  }
}
