import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/ai_coach/domain/entities/chat_message.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/chat_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';

/// The AI 코치 chat screen, rebuilt to the On-Care Figma design. Opened from the
/// coaching sheet's "AI와 대화하기" CTA. Replies are served by
/// [chatControllerProvider] (the real coach repository, mock-RAG in demo mode),
/// so questions get grounded answers with source chips instead of a canned line.
class AICoachPage extends ConsumerStatefulWidget {
  const AICoachPage({super.key});

  @override
  ConsumerState<AICoachPage> createState() => _AICoachPageState();
}

List<String> _quickReplies(AppLocalizations l) => <String>[
  l.aicQuickReply1,
  l.aicQuickReply2,
  l.aicQuickReply3,
];

class _AICoachPageState extends ConsumerState<AICoachPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send([String? preset]) {
    final String text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ChatState chat = ref.watch(chatControllerProvider);
    // Auto-scroll whenever the conversation grows / the typing bubble toggles.
    ref.listen<ChatState>(chatControllerProvider, (_, _) => _scrollToBottom());

    // The starter prompts only make sense before the user has said anything.
    final bool showQuickReplies =
        !chat.messages.any((ChatMessage m) => m.isUser) && !chat.sending;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: <Widget>[
                _header(context),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    children: <Widget>[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EEF4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l.aicDatePillToday,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 의료 조언 면책 — 코치는 식단·운동 코칭이지 진료가 아니다.
                      // 시스템 프롬프트에도 진단 금지 지시가 있지만, 사용자가
                      // 그걸 볼 수는 없으므로 화면에도 한 줄 남긴다.
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            l.aicMedicalDisclaimer,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final ChatMessage m in chat.messages) ...<Widget>[
                        _bubble(context, m),
                        const SizedBox(height: 16),
                      ],
                      if (showQuickReplies) _quickReplySection(),
                    ],
                  ),
                ),
                _inputBar(sending: chat.sending),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          _circle(
            Icons.chevron_left,
            MaterialLocalizations.of(context).backButtonTooltip,
            () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.dashboard),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    const OniAvatar(size: 38),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          // `지금 연결됨` 은 트레이너 온라인 점과 같은 초록이다(#1239).
                          color: FigmaColors.statusGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l.pageAiCoachTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.ink,
                      ),
                    ),
                    Text(
                      l.aicHeaderSubtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: FigmaColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 뒤로 버튼과 같은 폭의 빈 자리. 오른쪽에 놓을 동작이 아직 없어서
          // 두는 것이지, 누를 것이 있는 자리가 아니다 — 예전에는 여기 '⋯'
          // 버튼이 있었는데 콜백이 비어 있어 눌러도 아무 일이 없었다(#783).
          // 대화 초기화 같은 메뉴를 붙이려면 서버에 저장된 대화를 지우는
          // 경로(`GET /ai-coach/messages` 의 짝)가 먼저 필요하다.
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _circle(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: FigmaColors.softBlue,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // 아이콘만 있는 버튼이라 무엇을 하는지 말할 데가 툴팁뿐이다(#972).
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: FigmaColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessage m) {
    // 앱이 스스로 띄운 말풍선(인사·실패 안내)은 문구가 비어 있다. 로케일에 맞춰
    // 여기서 그린다 — 컨트롤러는 어떤 말풍선인지만 정한다(#847).
    final AppLocalizations l = AppLocalizations.of(context);
    final String text = switch (m.notice) {
      ChatNotice.welcome => l.aiCoachWelcome,
      ChatNotice.failure => l.aiCoachFailure,
      null => m.content,
    };
    if (m.isUser) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: FigmaColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        const OniAvatar(size: 34),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                constraints: const BoxConstraints(maxWidth: 255),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: FigmaColors.hairline),
                  boxShadow: kCardShadow,
                ),
                child: m.pending
                    // 점 세 개만 깜빡이면 무엇을 기다리는지 알 수 없다. 답이
                    // 그 사람의 기록을 읽고 만들어지는 중이라는 것을 한 줄로
                    // 말해 준다(#1180).
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const _TypingDots(),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l.aicGeneratingReply,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: FigmaColors.textSub,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: FigmaColors.ink,
                        ),
                      ),
              ),
              if (!m.pending && m.sources.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: _sourceChips(m.sources),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sourceChips(List<String> sources) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final String s in sources)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: FigmaColors.softBlue,
              borderRadius: BorderRadius.circular(999),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 12,
                    color: FigmaColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      s,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: FigmaColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _quickReplySection() {
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            l.aicQuickRepliesLabel,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        for (final String q in _quickReplies(l)) ...<Widget>[
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _send(q),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FigmaColors.primaryA(0.3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  q,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _inputBar({required bool sending}) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: FigmaColors.softBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FigmaColors.primaryA(0.22), width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            // 예전에는 여기 '+' 원형이 있었다. 제스처 위젯이 없는 순수
            // Container 라서 첨부 버튼처럼 보이기만 하고 눌리지 않았다(#783).
            // 붙일 동작(사진·기록 첨부)이 생기면 그때 실제 버튼으로 되살린다.
            // 원형이 빠진 만큼 글자가 테두리에 붙어서, 최소한의 여백만 남긴다.
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: sending ? null : (_) => _send(),
                style: const TextStyle(fontSize: 15, color: FigmaColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l.aicInputHint,
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: AppLocalizations.of(context).a11ySendMessage,
              child: GestureDetector(
                onTap: sending ? null : () => _send(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: FigmaColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: kCardShadow,
                  ),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward,
                          size: 16,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three-dot "typing…" indicator shown inside the coach bubble while a reply
/// is in flight (mirrors the pending [ChatMessage] placeholder).
class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
            child:
                Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: FigmaColors.textFaint,
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(
                      onPlay: (AnimationController c) =>
                          c.repeat(reverse: true),
                    )
                    .fade(
                      begin: 0.35,
                      end: 1,
                      duration: 500.ms,
                      delay: (i * 150).ms,
                      curve: Curves.easeInOut,
                    )
                    .scaleXY(begin: 0.8, end: 1),
          ),
      ],
    );
  }
}
