import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/core/config/app_config.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/member_coach/data/repositories/chat_pdf_repository.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';
import 'package:oncare/features/member_coach/presentation/widgets/coach_image_attachment.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
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
    for (int i = 0; i < messages.length; i++) {
      final CoachMessage m = messages[i];
      final bool seeded = m.id.startsWith('seed-');
      final bool newDay =
          seeded &&
          (i == 0 || !_sameDay(messages[i - 1].createdAt, m.createdAt));
      if (newDay) {
        if (i > 0) {
          out.add(
            _ReceivedBanner(key: ValueKey<String>('received-before-${m.id}')),
          );
          out.add(const SizedBox(height: 16));
        }
        out.add(_AnalyzedBanner(trainerName: widget.trainerName));
        out.add(const SizedBox(height: 16));
      }
      out.add(_Bubble(message: m));
    }
    if (messages.isNotEmpty) out.add(const _ReceivedBanner());
    return out;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 대화를 열거나 메시지가 늘면 맨 아래를 보여 준다.
  ///
  /// 없을 때는 스레드가 가장 오래된 메시지부터 보였다. 한 개짜리 데모에서는
  /// 티가 안 났지만 기록이 3일치로 늘자, 채팅을 열면 며칠 전 첫 인사가 뜨고
  /// 최근 대화는 직접 내려야 보였다. 트레이너 앱은 이미 같은 동작을 한다.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
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
    final messenger = ScaffoldMessenger.of(context);
    // messenger 와 같이 await 전에 잡아 둔다.
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(memberCoachRepositoryProvider).sendMessage(text);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.coachChatSendFailed)));
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
                        Row(
                          children: <Widget>[
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                color: FigmaColors.statusGreen,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(width: 7, height: 7),
                            ),
                            const SizedBox(width: 5),
                            // 부제는 로케일마다 길이가 다르다 — 영어가 한국어보다
                            // 훨씬 길어 고정 폭으로 두면 그대로 넘친다(#840).
                            Flexible(
                              child: Text(
                                l.coachChatSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: FigmaColors.textMuted,
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
                          : <Widget>[
                              for (final CoachMessage m in messages)
                                _Bubble(message: m),
                            ],
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
      background: FigmaColors.greenText.withValues(alpha: 0.08),
      border: FigmaColors.greenText.withValues(alpha: 0.25),
      icon: Icons.check_circle_outline,
      iconColor: FigmaColors.greenText,
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
          Flexible(
            child: Column(
              crossAxisAlignment: fromMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  key: ValueKey<String>('coach-message-bubble-${message.id}'),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.70,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: fromMe ? FigmaColors.primary : Colors.white,
                    border: fromMe
                        ? null
                        : Border.all(color: FigmaColors.hairline),
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
                      if (message.attachment
                          case final attachment?) ...<Widget>[
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
                ),
                const SizedBox(height: 3),
                Text(
                  message.timeLabel,
                  key: ValueKey<String>('coach-message-time-${message.id}'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fromMe
                        ? FigmaColors.primary
                        : AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (fromMe) const SizedBox(width: 4),
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref
          .read(chatPdfRepositoryProvider)
          .download(attachment.downloadPath);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 760,
            height: 720,
            child: PdfPreview(
              build: (_) async => bytes,
              pdfFileName: attachment.fileName,
              allowSharing: false,
            ),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.coachChatPdfOpenFailed)));
    }
  }
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
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
