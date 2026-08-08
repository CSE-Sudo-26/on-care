import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/ai_coach/domain/entities/chat_message.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/chat_controller.dart';

const LinearGradient _coachGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[AppColors.primary, AppColors.secondary],
);

/// Full-screen interactive chat with the AI coach "온이".
/// Opened from the home coach card; optionally pre-sends [initialMessage].
class CoachChatPage extends ConsumerStatefulWidget {
  const CoachChatPage({this.initialMessage, super.key});

  final String? initialMessage;

  @override
  ConsumerState<CoachChatPage> createState() => _CoachChatPageState();
}

class _CoachChatPageState extends ConsumerState<CoachChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initialMessage;
    if (initial != null && initial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatControllerProvider.notifier).send(initial);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final ChatState state = ref.watch(chatControllerProvider);
    // Auto-scroll whenever the conversation grows / typing toggles.
    ref.listen<ChatState>(chatControllerProvider, (_, _) => _scrollToBottom());

    final bool showPrompts = state.messages.length <= 1 && !state.sending;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const _ChatHeader(),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                children: <Widget>[
                  for (final ChatMessage m in state.messages)
                    _MessageBubble(message: m),
                  if (showPrompts) _PromptSuggestions(onTap: _send),
                ],
              ),
            ),
            _ChatInputBar(
              controller: _input,
              focusNode: _focus,
              sending: state.sending,
              onSend: () => _send(_input.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.foreground),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const _CoachAvatar(size: 40),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '온이',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: <Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'AI 건강 코치',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar({this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: _coachGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.smart_toy_rounded,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUser = message.isUser;
    final double maxWidth = MediaQuery.of(context).size.width * 0.76;

    final Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        gradient: isUser ? _coachGradient : null,
        color: isUser ? null : AppColors.accent,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
      child: message.pending
          ? const _TypingDots()
          : Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser ? Colors.white : AppColors.foreground,
                height: 1.45,
              ),
            ),
    );

    final Widget column = Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        bubble,
        if (!isUser && message.sources.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: _SourceChips(sources: message.sources),
          ),
      ],
    );

    final Widget row = Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!isUser) ...<Widget>[
          const _CoachAvatar(),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: column),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: row
          .animate()
          .fadeIn(duration: 220.ms)
          .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

class _SourceChips extends StatelessWidget {
  const _SourceChips({required this.sources});
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final String s in sources)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.all(AppRadius.pill),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 12,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      s,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
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
}

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
                      decoration: BoxDecoration(
                        color: AppColors.mutedForeground.withValues(alpha: 0.6),
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

class _PromptSuggestions extends StatelessWidget {
  const _PromptSuggestions({required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 38, top: 2),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final String p in kCoachPrompts)
            Material(
              color: AppColors.background,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(AppRadius.pill),
                side: BorderSide(color: AppColors.primary),
              ),
              child: InkWell(
                borderRadius: const BorderRadius.all(AppRadius.pill),
                onTap: () => onTap(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    p,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.all(AppRadius.pill),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '온이에게 물어보세요…',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _SendButton(sending: sending, onTap: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onTap});
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: sending ? null : onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: sending ? null : _coachGradient,
            color: sending ? AppColors.muted : null,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              : const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      ),
    );
  }
}
