import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/data/repositories/chat_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_chat_message.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';

/// The 채팅 sub-tab: an AI-received system banner, the message thread
/// (trainer right / client left), and an input bar that appends a
/// trainer message to the local DB.
class ChatView extends ConsumerStatefulWidget {
  /// Creates the chat view for [clientId].
  const ChatView({
    super.key,
    required this.clientId,
    required this.clientAvatar,
    required this.clientName,
  });

  /// Client whose thread is shown.
  final String clientId;

  /// Single-char avatar label for client bubbles.
  final String clientAvatar;

  /// Client display name (used in the system banner).
  final String clientName;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendTrainerMessage(clientId: widget.clientId, text: text);
    } catch (_) {
      // Keep the draft in the input and tell the user it didn't go out.
      messenger.showSnackBar(
        const SnackBar(content: Text('메시지 전송에 실패했어요. 다시 시도해 주세요')),
      );
      return;
    }
    // Clear only after the insert succeeds so the text isn't lost on error.
    _input.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatThreadProvider(widget.clientId));

    return Column(
      children: <Widget>[
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(
              child: Text(
                '대화를 불러오지 못했어요',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ),
            data: (list) {
              _scrollToBottom();
              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  _SystemBanner(clientName: widget.clientName),
                  const SizedBox(height: AppSpacing.md),
                  for (final m in list) ...<Widget>[
                    _Bubble(message: m, avatar: widget.clientAvatar),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _SentBanner(clientName: widget.clientName),
                ],
              );
            },
          ),
        ),
        _InputBar(controller: _input, onSend: _send),
      ],
    );
  }
}

class _SystemBanner extends StatelessWidget {
  const _SystemBanner({required this.clientName});

  final String clientName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.accentSurface,
          borderRadius: const BorderRadius.all(AppRadius.card),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Column(
          children: <Widget>[
            Text(
              '✦ AI가 $clientName님의 식단·운동 데이터를 분석했어요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '트레이너님께 요약 리포트가 전송됐어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "루틴 전송됨" system banner at the end of the seeded thread (mock:
/// the green centered notice under the last message).
class _SentBanner extends StatelessWidget {
  const _SentBanner({required this.clientName});

  final String clientName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(AppRadius.card),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: <Widget>[
            Text(
              '✓ AI 분석 기반 루틴이 $clientName님에게 전송됐어요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '고객 앱에 알림이 전달됐어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.avatar});

  final ClientChatMessage message;
  final String avatar;

  @override
  Widget build(BuildContext context) {
    final fromTrainer = message.fromTrainer;
    final bubble = Column(
      crossAxisAlignment: fromTrainer
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: fromTrainer ? AppColors.accent : AppColors.card,
            border: fromTrainer
                ? null
                : Border.all(color: AppColors.borderStrong),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(fromTrainer ? 16 : 4),
              bottomRight: Radius.circular(fromTrainer ? 4 : 16),
            ),
          ),
          child: Text(
            message.body,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: fromTrainer
                  ? AppColors.accentForeground
                  : AppColors.foreground,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          message.timeLabel,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.disabledForeground,
          ),
        ),
      ],
    );

    return Row(
      mainAxisAlignment: fromTrainer
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (!fromTrainer) ...<Widget>[
          ClientAvatar(label: avatar, size: 28),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: bubble),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final Future<void> Function() onSend;

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
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '메시지 입력...',
                filled: true,
                fillColor: AppColors.accentSurface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(AppRadius.card),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSend,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Icon(
                  Icons.send,
                  size: 18,
                  color: AppColors.accentForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
