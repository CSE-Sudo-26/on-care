import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/member_coach/data/repositories/chat_pdf_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/domain/entities/member_weekly_report.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_report_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_image_attachment.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_report_card.dart';
import 'package:oncare/features/member_coach/services/member_report_pdf_generator.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:oncare/shared/widgets/app_toast.dart';
import 'package:printing/printing.dart';

/// 루트 화면 위에 채팅 페이지를 열어 하단 내비게이션과 플로팅 버튼을 가린다.
Future<void> openTrainerChatPage(
  BuildContext context, {
  required String trainerName,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => TrainerChatPage(trainerName: trainerName),
    ),
  );
}

/// 담당 트레이너와의 대화 목록과 메시지 입력창을 보여주는 전체 화면이다.
class TrainerChatPage extends ConsumerStatefulWidget {
  const TrainerChatPage({required this.trainerName, super.key});

  final String trainerName;

  @override
  ConsumerState<TrainerChatPage> createState() => _TrainerChatPageState();
}

class _TrainerChatPageState extends ConsumerState<TrainerChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// 마지막으로 그린 메시지 수. 길이가 바뀐 프레임에서만 스크롤한다.
  int _lastCount = -1;
  bool _sending = false;

  /// 데모 안내 배너를 **하루 단위로** 끼워 넣은 목록을 만든다.
  ///
  /// 배너가 스레드 맨 앞·맨 뒤에 하나씩만 있으면, 사흘치 대화에서 "분석은 이
  /// 대화가 시작되기 전에 딱 한 번 있었다"로 읽힌다. 실제로는 매일 그날 데이터를
  /// 분석해 그 대화가 시작되고, 트레이너가 조정한 루틴을 보내며 끝난다 — 그래서
  /// 날이 바뀌는 자리마다 앞뒤로 붙인다. (#543)
  ///
  /// 날짜 판정은 `createdAt` 으로 한다. `timeLabel` 은 화면에 보일 문자열일
  /// 뿐이라 거기서 날짜를 파내면 표시 문구가 곧 로직이 된다.
  ///
  /// 시드 메시지에 대해서만 자른다. 데모 중에 내가 보낸 답장은 오늘 날짜라
  /// 그대로 두면 내 말풍선 앞에 "분석했어요" 가 끼어든다.
  List<Widget> _withDemoBanners(List<CoachMessage> messages) {
    final List<Widget> out = <Widget>[];
    final int lastSeeded = messages.lastIndexWhere(
      (message) => message.id.startsWith('seed-'),
    );
    for (int i = 0; i < messages.length; i++) {
      final CoachMessage m = messages[i];
      final bool seeded = m.id.startsWith('seed-');
      final bool newDay =
          i == 0 || !_sameDay(messages[i - 1].createdAt, m.createdAt);
      if (newDay) {
        if (seeded && i > 0) {
          out.add(
            _ReceivedBanner(key: ValueKey<String>('received-before-${m.id}')),
          );
          out.add(const SizedBox(height: 16));
        }
        out.add(_DateDivider(date: m.createdAt));
        out.add(const SizedBox(height: 16));
        if (seeded) {
          out.add(_AnalyzedBanner(trainerName: widget.trainerName));
          out.add(const SizedBox(height: 16));
        }
      }
      out.add(_threadEntry(m));
      if (i == lastSeeded) {
        out.add(const _ReceivedBanner());
        if (i != messages.length - 1) out.add(const SizedBox(height: 16));
      }
    }
    return out;
  }

  List<Widget> _withoutDemoBanners(List<CoachMessage> messages) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (i == 0 || !_sameDay(messages[i - 1].createdAt, message.createdAt)) {
        out
          ..add(_DateDivider(date: message.createdAt))
          ..add(const SizedBox(height: 16));
      }
      out.add(_threadEntry(message));
    }
    return out;
  }

  /// 스레드 한 줄 — 말풍선이거나, 가운데 안내다.
  ///
  /// 리포트 전송은 누가 무슨 말을 했는가가 아니라 스레드에 무슨 일이 있었는가를
  /// 적는 자리다. 트레이너 앱도 같은 사건을 가운데 안내로 그린다(#1600).
  Widget _threadEntry(CoachMessage message) {
    final DateTime? reportWeek = message.reportWeekStart;
    if (reportWeek == null) return _Bubble(message: message);
    return _ReportNotice(
      key: ValueKey<String>('coach-message-bubble-${message.id}'),
      message: message,
      weekStart: reportWeek,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  /// 대화를 열거나 메시지가 늘면 맨 아래를 보여 준다.
  ///
  /// 없을 때는 스레드가 가장 오래된 메시지부터 보였다. 한 개짜리 데모에서는
  /// 티가 안 났지만 기록이 3일치로 늘자, 채팅을 열면 며칠 전 첫 인사가 뜨고
  /// 최근 대화는 직접 내려야 보였다. 트레이너 앱은 이미 같은 동작을 한다.
  void _scrollToBottom({double? previousMax, int attemptsLeft = 12}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final double max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(max);

      // ListView는 긴 목록의 아직 만들지 않은 자식 높이를 추정한다. 첫 jump로
      // 새 자식이 만들어지면 maxScrollExtent가 다음 프레임에 다시 늘 수 있다.
      // 그 상태에서 멈추면 서버에서 최신 메시지를 받았어도 화면에는 이전 끝이
      // 남는다. 범위가 한 프레임 동안 안정될 때까지 다시 끝을 맞춘다.
      final bool stable =
          previousMax != null && (max - previousMax).abs() < 0.5;
      if (!stable && attemptsLeft > 1) {
        _scrollToBottom(previousMax: max, attemptsLeft: attemptsLeft - 1);
      }
    });
  }

  Future<void> _markRead() async {
    try {
      await ref.read(memberCoachRepositoryProvider).markRead();
    } catch (_) {
      // 읽음 처리 실패는 이미 불러오는 대화 표시를 막지 않는다.
      return;
    }
    if (mounted) ref.invalidate(coachUnreadProvider);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    // 문구와 같이 await 전에 잡아 둔다.
    final AppToastHost toast = AppToastHost.of(context);
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(memberCoachRepositoryProvider).sendMessage(text);
    } catch (_) {
      if (!mounted) return;
      toast.show(l.coachChatSendFailed,
        kind: AppToastKind.error,
      );
      return;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (!mounted) return;
    _input.clear();
    ref.invalidate(coachChatProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final chat = ref.watch(coachChatProvider);
    final bool showDemoBanners = ref.watch(appConfigProvider).useMockApi;
    return Scaffold(
      backgroundColor: FigmaColors.statBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: l.coachChatBack,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 19,
                      color: FigmaColors.ink,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: FigmaColors.iconTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: FigmaColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.trainerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: FigmaColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.coachChatSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: FigmaColors.hairline),
            Expanded(
              child: ColoredBox(
                color: FigmaColors.statBg,
                child: chat.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Text(
                      l.coachChatLoadFailed,
                      style: const TextStyle(color: AppColors.foreground),
                    ),
                  ),
                  data: (messages) {
                    // 길이가 바뀐 프레임에서만 — 매 빌드마다 부르면 사용자가
                    // 위로 올려 읽는 중에도 아래로 끌어내린다.
                    if (messages.length != _lastCount) {
                      _lastCount = messages.length;
                      _scrollToBottom();
                      // Mark newly polled trainer messages read while this
                      // full-screen route is visible, then refresh its badge.
                      Future<void>.microtask(_markRead);
                    }
                    return ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                      children: showDemoBanners
                          ? _withDemoBanners(messages)
                          : _withoutDemoBanners(messages),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: _InputBar(
                controller: _input,
                sending: _sending,
                onSend: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 데모 전용 안내 배너 — 트레이너 앱의 같은 배너를 회원 시점으로 옮긴 것.
///
/// 트레이너 화면은 "AI가 김민수님의 … 분석했어요 / 루틴이 김민수님에게
/// 전송됐어요" 라고 말한다. 같은 사건을 받는 쪽에서 보면 "내 데이터를
/// 분석했어요 / 루틴을 받았어요" 가 된다 — 내용은 같고 시점만 다르다. (#543)
///
/// 실 모드에서는 그리지 않는다. 서버가 실제로 그 순간을 알려주는 것이 아니라
/// 데모 대화의 맥락을 설명하는 장치이기 때문이다.
class _AnalyzedBanner extends StatelessWidget {
  const _AnalyzedBanner({required this.trainerName});

  final String trainerName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _BannerFrame(
      background: FigmaColors.iconTint,
      border: FigmaColors.primary.withValues(alpha: 0.25),
      icon: Icons.auto_awesome,
      iconColor: FigmaColors.primary,
      title: l.coachChatDemoAnalyzed,
      subtitle: l.coachChatDemoReportSent(trainerName),
    );
  }
}

class _ReceivedBanner extends StatelessWidget {
  const _ReceivedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _BannerFrame(
      // #1239 이후로는 "완료" 배너를 두 앱이 함께 쓰는 완료 초록으로
      // 칠했는데, 이 배너는 상태 완료가 아니라 "개인 추천운동을 받았다"는
      // 안내다 — 위 [_AnalyzedBanner]와 같은 흐름의 다음 단계라, 초록이
      // 아니라 그 배너와 같은 하양+파랑으로 맞춘다(#1379).
      background: FigmaColors.iconTint,
      border: FigmaColors.primary.withValues(alpha: 0.25),
      icon: Icons.check_circle_outline,
      iconColor: FigmaColors.primary,
      title: l.coachChatDemoRoutineReceived,
      subtitle: l.coachChatDemoNotified,
    );
  }
}

class _BannerFrame extends StatelessWidget {
  const _BannerFrame({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  static const List<String> _weekdays = <String>[
    '월요일',
    '화요일',
    '수요일',
    '목요일',
    '금요일',
    '토요일',
    '일요일',
  ];

  @override
  Widget build(BuildContext context) {
    final localDate = date.toLocal();
    return Center(
      child: Text(
        '${localDate.year}년 ${localDate.month}월 ${localDate.day}일 ${_weekdays[localDate.weekday - 1]}',
        key: ValueKey<String>(
          'coach-chat-date-${localDate.year}-${localDate.month}-${localDate.day}',
        ),
        style: const TextStyle(
          color: AppColors.mutedForeground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromMe = message.fromMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: fromMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!fromMe) ...<Widget>[
            Container(
              key: ValueKey<String>('coach-message-avatar-${message.id}'),
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: FigmaColors.iconTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 17,
                color: FigmaColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (fromMe) ...<Widget>[
            _MessageTime(message: message),
            const SizedBox(width: 5),
          ],
          Flexible(child: _bubble(context, ref)),
          if (!fromMe) ...<Widget>[
            const SizedBox(width: 5),
            _MessageTime(message: message),
          ],
        ],
      ),
    );
  }

  /// 말풍선 하나. 리포트 등록 안내는 여기로 오지 않는다 — 그것은 말풍선이
  /// 아니라 대화 가운데 안내라, 스레드를 세울 때 갈라진다(#1600).
  Widget _bubble(BuildContext context, WidgetRef ref) {
    final bool fromMe = message.fromMe;
    return Container(
      key: ValueKey<String>('coach-message-bubble-${message.id}'),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.70,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: fromMe ? FigmaColors.primary : Colors.white,
        border: fromMe ? null : Border.all(color: FigmaColors.hairline),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(fromMe ? 14 : 4),
          bottomRight: Radius.circular(fromMe ? 4 : 14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: fromMe ? Colors.white : FigmaColors.ink,
            ),
          ),
          if (message.attachment case final attachment?) ...<Widget>[
            const SizedBox(height: 8),
            // 사진은 대화 안에서 그리고, 리포트 PDF 는 내려받는
            // 카드로 둔다. 사진을 카드로 두면 볼 때마다 파일을
            // 열어야 한다. (#921)
            if (attachment.isImage)
              CoachImageAttachment(attachment: attachment)
            else
              _PdfCard(
                attachment: attachment,
                onOpen: () => _openPdf(context, ref, attachment),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPdf(
    BuildContext context,
    WidgetRef ref,
    CoachAttachment attachment,
  ) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppToastHost toast = AppToastHost.of(context);
    try {
      final bytes = await ref
          .read(chatPdfRepositoryProvider)
          .download(attachment.downloadPath);
      if (!context.mounted) return;
      await showPdfPreviewDialog(context, bytes, attachment.fileName);
    } catch (_) {
      toast.show(l.coachChatPdfOpenFailed, kind: AppToastKind.error);
    }
  }
}

/// PDF 한 부를 미리보기로 연다. 첨부 파일과 회원 기록으로 만든 문서가 같은
/// 화면으로 열려야, 회원이 무엇을 보고 있는지 헷갈리지 않는다. (#1600)
///
/// `build` 는 **부를 때마다 복사본**을 준다. 웹에서 미리보기는 pdf.js 로 그리는데,
/// pdf.js 는 받은 바이트의 버퍼를 워커로 넘기면서(transfer) 원본을 비워 버린다.
/// 같은 바이트를 그대로 다시 주면 두 번째 렌더가 `ArrayBuffer ... is already
/// detached` 로 죽고, 그리다 만 미리보기가 스피너만 도는 채로 남는다. 미리보기는
/// 화면 크기·용지 설정이 바뀔 때마다 다시 그리므로 두 번째 호출은 반드시 온다.
Future<void> showPdfPreviewDialog(
  BuildContext context,
  Uint8List bytes,
  String fileName,
) {
  final AppLocalizations l = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: SizedBox(
        width: 760,
        height: 720,
        child: PdfPreview(
          build: (_) async => Uint8List.fromList(bytes),
          pdfFileName: fileName,
          allowSharing: false,
          // 미리보기가 실패했을 때 스피너를 계속 돌리면 회원은 느린 것과
          // 안 되는 것을 구별할 수 없다.
          onError: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l.coachChatPdfOpenFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 리포트 등록 안내 — 대화 가운데 상자와 `PDF 미리보기`. (#1600)
///
/// 누르면 트레이너가 보낸 파일을 연다. 열 파일이 없으면(데모, 그리고 본문만
/// 보낸 리포트) 같은 주를 회원 기록으로 정리한 문서를 만들어 같은 미리보기로
/// 연다 — 리포트 화면이 보여 주는 통계를 회원도 그 자리에서 볼 수 있어야 한다.
class _ReportNotice extends ConsumerStatefulWidget {
  const _ReportNotice({
    required this.message,
    required this.weekStart,
    super.key,
  });

  final CoachMessage message;
  final DateTime weekStart;

  @override
  ConsumerState<_ReportNotice> createState() => _ReportNoticeState();
}

class _ReportNoticeState extends ConsumerState<_ReportNotice> {
  /// 문서를 만드는 동안 다시 누르지 못하게 한다 — 같은 문서를 두 번 그리면
  /// 미리보기가 두 겹으로 열린다.
  bool _opening = false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: CoachReportCard(
      weekStart: widget.weekStart,
      onOpenPdf: _opening ? () {} : _open,
    ),
  );

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final AppLocalizations l = AppLocalizations.of(context);
    final AppToastHost toast = AppToastHost.of(context);
    try {
      final CoachAttachment? attachment = widget.message.attachment;
      final Uint8List bytes;
      final String fileName;
      if (attachment != null) {
        bytes = await ref
            .read(chatPdfRepositoryProvider)
            .download(attachment.downloadPath);
        fileName = attachment.fileName;
      } else {
        final MemberWeeklyReport report = await ref.read(
          memberWeeklyReportProvider(widget.weekStart).future,
        );
        bytes = await ref
            .read(memberReportPdfGeneratorProvider)
            .generate(l: l, report: report);
        fileName = l.coachReportPdfFileName(_ymd(widget.weekStart));
      }
      if (!mounted) return;
      await showPdfPreviewDialog(context, bytes, fileName);
    } catch (_) {
      toast.show(l.coachChatPdfOpenFailed, kind: AppToastKind.error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  static String _ymd(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _PdfCard extends StatelessWidget {
  const _PdfCard({required this.attachment, required this.onOpen});

  final CoachAttachment attachment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      key: ValueKey<String>('coach-pdf-${attachment.fileId}'),
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.picture_as_pdf, color: Color(0xffb3261e)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(attachment.fileName, overflow: TextOverflow.ellipsis),
                  Text(_fileSize(attachment.fileSize)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    ),
  );

  static String _fileSize(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(1)} KB';
}

class _MessageTime extends StatelessWidget {
  const _MessageTime({required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) => Text(
    _clockOnly(message.timeLabel),
    key: ValueKey<String>('coach-message-time-${message.id}'),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.mutedForeground,
    ),
  );

  static String _clockOnly(String label) =>
      RegExp(r'\d{1,2}:\d{2}').firstMatch(label)?.group(0) ?? label;
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: FigmaColors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              key: const ValueKey<String>('member-chat-input'),
              controller: controller,
              enabled: !sending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).coachChatInputHint,
                filled: true,
                fillColor: FigmaColors.statBg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: FigmaColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: FigmaColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: FigmaColors.primaryA(0.45)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: sending ? FigmaColors.textFaint : FigmaColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              key: const ValueKey<String>('member-chat-send'),
              customBorder: const CircleBorder(),
              onTap: sending ? null : onSend,
              child: Tooltip(
                message: AppLocalizations.of(context).a11ySendMessage,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.send, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
