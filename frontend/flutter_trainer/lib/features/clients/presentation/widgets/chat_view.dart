import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/entities/trainer_memo.dart';
import 'package:oncare_trainer/features/clients/data/repositories/chat_pdf_repository.dart';
import 'package:oncare_trainer/features/messages/domain/chat_context_insight.dart';
import 'package:oncare_trainer/shared/services/trainer_memo_repository.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

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

  /// Mirrors the backend's `ChatSendRequest.text` cap (`max_length=2000`)
  /// so an over-long message is rejected here, with a clear message,
  /// instead of round-tripping to the server for a 422 (review).
  static const int _maxMessageLength = 2000;

  /// A send is in flight — blocks re-entry (button mash / IME send)
  /// from inserting the same message twice.
  bool _sending = false;

  /// Insight ids whose memo save is in flight. A memo write is a network
  /// round trip in API mode, so a second tap before it lands would fire a
  /// duplicate request.
  final Set<String> _savingInsights = <String>{};

  /// Message count at the last auto-scroll, so the thread only scrolls
  /// when a message actually arrives (not on every rebuild).
  int _lastCount = -1;

  static const ChatContextInsightDetector _insightDetector =
      ChatContextInsightDetector();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _input.text;
    if (text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    // messenger 와 같은 이유로 await 전에 잡아 둔다 — 뒤에서 context 를 다시
    // 만지면 async gap 을 건너 쓰게 된다.
    final AppLocalizations l = AppLocalizations.of(context);
    if (text.trim().length > _maxMessageLength) {
      messenger.showSnackBar(SnackBar(content: Text(l.chatTooLong)));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendTrainerMessage(clientId: widget.clientId, text: text);
    } catch (_) {
      // Guard the failure path too: a slow send that fails after the
      // user left would otherwise touch a disposed messenger.
      if (!mounted) return;
      // Keep the draft in the input and tell the user it didn't go out.
      messenger.showSnackBar(SnackBar(content: Text(l.chatSendFailed)));
      return;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    // The insert may outlive this widget (user navigated away while
    // awaiting) — don't touch disposed controllers.
    if (!mounted) return;
    // Clear only after the insert succeeds so the text isn't lost on error.
    _input.clear();
    // Drift streams re-emit on write; the Dio source is a single fetch, so
    // refetch the thread + unread badges after a real-API send. NOTE: don't
    // scroll here — `ref.invalidate` only *starts* an async refetch, so the
    // list the user is looking at right now is still the pre-send one; the
    // `data:` branch below already scrolls to bottom once the new message
    // actually renders (it fires on every list-length change, which covers
    // both the reactive Drift path and this refetch) (review).
    if (!ref.read(appConfigProvider).useMockApi) {
      ref.invalidate(chatThreadProvider(widget.clientId));
      ref.invalidate(unreadCountsProvider);
    }
  }

  /// 데모 안내 배너를 **하루 단위로** 끼워 넣은 목록을 만든다.
  ///
  /// 배너가 스레드 맨 앞·맨 뒤에 하나씩만 있으면, 여러 날에 걸친 스레드에서
  /// "분석은 이 대화가 시작되기 전에 딱 한 번 있었다"로 읽힌다. 실제로는 매일
  /// 그날 데이터를 분석해 그 대화가 시작되고, 조정한 루틴을 보내며 끝난다 —
  /// 그래서 날이 바뀌는 자리마다 앞뒤로 붙인다. (#543)
  ///
  /// 하루짜리 스레드(시드 고객 대부분)에서는 위 하나·아래 하나가 되어 이전과
  /// 똑같이 보인다.
  ///
  /// 날짜 판정은 `createdAt` 으로 한다. `timeLabel` 은 화면에 보일 문자열일
  /// 뿐이라 거기서 날짜를 파내면 표시 문구가 곧 로직이 된다. 시드 메시지에
  /// 대해서만 자르는 이유도 같다 — 방금 보낸 답장은 오늘 날짜라, 그대로 두면
  /// 내 말풍선 앞에 "분석했어요" 가 끼어든다.
  List<Widget> _threadChildren(
    List<ClientChatMessage> list, {
    required bool showDemoBanners,
    required Set<String> savedInsightIds,
  }) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < list.length; i++) {
      final ClientChatMessage m = list[i];
      final bool newDay =
          showDemoBanners &&
          m.id.startsWith('seed-') &&
          (i == 0 || !_sameDay(list[i - 1].createdAt, m.createdAt));
      if (newDay) {
        if (i > 0) {
          out
            ..add(
              _SentBanner(
                key: ValueKey<String>('sent-before-${m.id}'),
                clientName: widget.clientName,
              ),
            )
            ..add(const SizedBox(height: AppSpacing.md));
        }
        out
          ..add(
            _SystemBanner(
              key: ValueKey<String>('analyzed-before-${m.id}'),
              clientName: widget.clientName,
            ),
          )
          ..add(const SizedBox(height: AppSpacing.md));
      }
      out
        ..add(_Bubble(message: m, avatar: widget.clientAvatar))
        ..add(const SizedBox(height: AppSpacing.md));
      final insight = _insightDetector.detect(m);
      if (insight != null) {
        out
          ..add(
            _ChatInsightBanner(
              key: ValueKey<String>('chat-insight-${insight.id}'),
              insight: insight,
              saved: savedInsightIds.contains(insight.id),
              onAddMemo: () => _addInsightMemo(insight),
            ),
          )
          ..add(const SizedBox(height: AppSpacing.md));
      }
    }
    // 대화가 없으면 배너만 남는다 — 분석한 것도 보낸 것도 없으므로 그리지 않는다.
    if (showDemoBanners && list.isNotEmpty) {
      out.add(_SentBanner(clientName: widget.clientName));
    }
    return out;
  }

  /// Saves a detected signal as a trainer memo on this client.
  ///
  /// The memo lands in the same list the client detail screen shows, and the
  /// insight id makes the write idempotent — a double tap or a retry after a
  /// dropped response does not add a second memo.
  Future<void> _addInsightMemo(ChatContextInsight insight) async {
    if (!_savingInsights.add(insight.id)) return;
    try {
      await ref
          .read(trainerMemoRepositoryProvider)
          .create(
            widget.clientId,
            body: insight.evidence,
            source: TrainerMemoSource.chatInsight,
            insightId: insight.id,
            insightKind: insight.kind.name,
          );
      ref.invalidate(trainerMemosProvider(widget.clientId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).chatInsightMemoSaved),
        ),
      );
    } on Object {
      // The button stays in its unsaved state so the trainer can try again —
      // the list is only invalidated on a write that actually landed.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).chatInsightMemoSaveFailed),
        ),
      );
    } finally {
      _savingInsights.remove(insight.id);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final messages = ref.watch(chatThreadProvider(widget.clientId));
    final showDemoBanners = ref.watch(appConfigProvider).useMockApi;
    final savedInsightIds =
        ref
            .watch(trainerMemosProvider(widget.clientId))
            .valueOrNull
            ?.map((memo) => memo.insightId)
            .whereType<String>()
            .toSet() ??
        const <String>{};

    return Column(
      children: <Widget>[
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyHint(
              message: l.chatLoadFailed,
              icon: Icons.error_outline,
              action: ActionButton(
                key: ValueKey<String>('chat-retry-${widget.clientId}'),
                label: l.actionRetry,
                onPressed: messages.isLoading
                    ? null
                    : () => ref.invalidate(chatThreadProvider(widget.clientId)),
              ),
            ),
            data: (list) {
              // Auto-scroll only when a message arrived, not every build.
              if (list.length != _lastCount) {
                _lastCount = list.length;
                _scrollToBottom();
                // Viewing the thread clears its unread badge — also for
                // messages that arrive while it stays open. Deferred so
                // the write never runs inside build.
                final repo = ref.read(chatRepositoryProvider);
                final realApi = !ref.read(appConfigProvider).useMockApi;
                Future<void>.microtask(() async {
                  try {
                    await repo.markThreadRead(widget.clientId);
                    // Drift updates unread via its stream; the Dio source
                    // needs an explicit refetch of the badge counts.
                    if (realApi && mounted) {
                      ref.invalidate(unreadCountsProvider);
                    }
                  } catch (_) {
                    // Reading the thread still succeeded. A transient read
                    // receipt failure may leave the badge visible, but must
                    // not escape as an unhandled async error.
                  }
                });
              }
              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: _threadChildren(
                  list,
                  showDemoBanners: showDemoBanners,
                  savedInsightIds: savedInsightIds,
                ),
              );
            },
          ),
        ),
        _InputBar(controller: _input, sending: _sending, onSend: _send),
      ],
    );
  }
}

class _ChatInsightBanner extends StatelessWidget {
  const _ChatInsightBanner({
    required this.insight,
    required this.saved,
    required this.onAddMemo,
    super.key,
  });

  final ChatContextInsight insight;
  final bool saved;
  final Future<void> Function() onAddMemo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDiscomfort = insight.kind == ChatInsightKind.discomfort;
    final title = isDiscomfort
        ? l.chatInsightDiscomfortTitle(
            insight.bodyPart ?? l.chatInsightBodyPartGeneral,
          )
        : l.chatInsightNegativeTitle;
    final description = isDiscomfort
        ? l.chatInsightDiscomfortDescription
        : l.chatInsightNegativeDescription;

    return Container(
      key: ValueKey<String>('chat-insight-banner-${insight.messageId}'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: saved
                ? AppColors.success.withValues(alpha: 0.10)
                : AppColors.warning.withValues(alpha: 0.13),
            borderRadius: const BorderRadius.all(AppRadius.pill),
            child: InkWell(
              key: ValueKey<String>('chat-insight-add-${insight.id}'),
              onTap: saved ? null : onAddMemo,
              borderRadius: const BorderRadius.all(AppRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      saved ? Icons.check_rounded : Icons.add_rounded,
                      size: 15,
                      color: saved ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      saved ? l.chatInsightMemoAdded : l.chatInsightAddMemo,
                      style: TextStyle(
                        color: saved ? AppColors.success : AppColors.warning,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemBanner extends StatelessWidget {
  const _SystemBanner({required this.clientName, super.key});

  final String clientName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
            IconLabel(
              icon: Icons.auto_awesome,
              label: l.chatDemoAnalyzed(clientName),
              color: AppColors.accent,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              l.chatDemoReportSent,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
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
  const _SentBanner({required this.clientName, super.key});

  final String clientName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
            IconLabel(
              icon: Icons.check_circle_outline,
              label: l.chatDemoRoutineSent(clientName),
              color: AppColors.success,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              l.chatDemoNotified,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
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

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.avatar});

  final ClientChatMessage message;
  final String avatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message.body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: fromTrainer
                      ? AppColors.accentForeground
                      : AppColors.foreground,
                ),
              ),
              if (message.attachment case final attachment?) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _ChatPdfCard(
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
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.subtleForeground,
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

  Future<void> _openPdf(
    BuildContext context,
    WidgetRef ref,
    ChatPdfAttachment attachment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref
          .read(trainerChatPdfRepositoryProvider)
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
      messenger.showSnackBar(const SnackBar(content: Text('PDF를 열지 못했습니다.')));
    }
  }
}

class _ChatPdfCard extends StatelessWidget {
  const _ChatPdfCard({required this.attachment, required this.onOpen});

  final ChatPdfAttachment attachment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card.withValues(alpha: 0.92),
    borderRadius: const BorderRadius.all(AppRadius.sm),
    child: InkWell(
      key: ValueKey<String>('trainer-chat-pdf-${attachment.fileId}'),
      onTap: onOpen,
      borderRadius: const BorderRadius.all(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.picture_as_pdf, color: AppColors.destructive),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(attachment.fileName, overflow: TextOverflow.ellipsis),
                  Text(_fileSize(attachment.fileSize)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
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

  /// Disables the field and the send button while an insert is in flight.
  final bool sending;

  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
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
              // The console header carries a 고객 검색 field too, so the
              // composer is addressable by key rather than by being the
              // page's only input.
              key: const ValueKey<String>('client-chat-input'),
              controller: controller,
              enabled: !sending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: l.chatInputHint,
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
            color: sending ? AppColors.disabledForeground : AppColors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              key: const ValueKey<String>('client-chat-send'),
              customBorder: const CircleBorder(),
              onTap: sending ? null : onSend,
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
