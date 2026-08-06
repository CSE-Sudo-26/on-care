import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/member_coach/domain/entities/member_coach.dart';
import 'package:oncare/features/member_coach/presentation/controllers/member_coach_providers.dart';

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
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Opening the thread clears the unread badge.
    Future<void>.microtask(() async {
      await ref.read(memberCoachRepositoryProvider).markRead();
      if (mounted) ref.invalidate(coachUnreadProvider);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(memberCoachRepositoryProvider).sendMessage(text);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('메시지 전송에 실패했어요. 다시 시도해 주세요')),
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
    final chat = ref.watch(coachChatProvider);
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
                    tooltip: '뒤로가기',
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: FigmaColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Row(
                          children: <Widget>[
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: FigmaColors.statusGreen,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(width: 7, height: 7),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '담당 트레이너 · 상담 가능',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
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
                  error: (_, _) => const Center(
                    child: Text(
                      '대화를 불러오지 못했어요',
                      style: TextStyle(color: AppColors.foreground),
                    ),
                  ),
                  data: (messages) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _Bubble(message: messages[i]),
                  ),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
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
                  child: Text(
                    message.body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: fromMe ? Colors.white : FigmaColors.ink,
                    ),
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
              controller: controller,
              enabled: !sending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '트레이너에게 메시지 보내기...',
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
