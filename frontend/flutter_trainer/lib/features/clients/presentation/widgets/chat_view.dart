import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/config/app_config.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/data/repositories/chat_pdf_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/trainer_memo.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/chat_image_attachment.dart';
import 'package:oncare_trainer/features/messages/domain/chat_context_insight.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/client_chat_message.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/trainer_memo_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/app_toast.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/icon_label.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:printing/printing.dart';

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

  final ImagePicker _picker = ImagePicker();

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
    final AppLocalizations l = AppLocalizations.of(context);
    if (text.trim().length > _maxMessageLength) {
      showAppToast(context, l.chatTooLong);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendTrainerMessage(clientId: widget.clientId, text: text);
    } catch (_) {
      // Guard the failure path too: a slow send that fails after the
      // user left would otherwise touch a disposed context.
      if (!mounted) return;
      // Keep the draft in the input and tell the user it didn't go out.
      showAppToast(context, l.chatSendFailed, kind: AppToastKind.error);
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

  /// 사진 한 장을 고르고 그대로 보낸다. (#921)
  ///
  /// 고른 뒤 미리보기를 한 번 더 거치지 않는 이유는, 자세 사진은 대화 흐름
  /// 안에서 즉시 오가는 것이라서다 — 확인 단계를 넣으면 말 한마디 붙이는 것보다
  /// 사진 한 장 보내는 쪽이 번거로워진다. 잘못 보낸 사진은 대화에서 바로 보인다.
  ///
  /// 데모에는 사진을 받을 백엔드가 없어 진입점 자체를 그리지 않는다.
  Future<void> _sendImage() async {
    if (_sending) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      // 원본 그대로는 상한(6MiB)에 쉽게 닿는다. 자세를 보는 데 필요한 해상도는
      // 남기면서 전송이 실패하지 않을 정도로 줄인다.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    // 함께 붙이는 한마디도 본문과 같은 상한을 지킨다 — 서버가 422 로 거절하면
    // 사진까지 다시 골라야 한다.
    final caption = _input.text.trim();
    if (caption.length > _maxMessageLength) {
      if (!mounted) return;
      showAppToast(context, l.chatTooLong);
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(trainerChatImageRepositoryProvider)
          .send(
            clientId: widget.clientId,
            bytes: bytes,
            fileName: picked.name,
            message: caption,
          );
    } on AppError catch (error) {
      if (!mounted) return;
      // 용량·형식 거절은 서버가 이유를 문장으로 준다. 그 문장이 트레이너가
      // 다음에 할 일(줄여서 다시 보낼지)을 정한다.
      showAppToast(
        context,
        serverDetailOr(l, error.message, l.chatImageSendFailed),
        kind: AppToastKind.error,
      );
      return;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (!mounted) return;
    _input.clear();
    ref.invalidate(chatThreadProvider(widget.clientId));
    ref.invalidate(unreadCountsProvider);
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
    // 닫는 배너가 붙을 자리 — **마지막 시드 메시지** 다음이다. 목록 맨 끝에
    // 무조건 붙이면 방금 보낸 답장이 배너 앞으로 들어가, 화면에서는 "내가
    // 보낸 말이 루틴 전송보다 먼저 있었던 일" 로 읽힌다. 배너는 그날의
    // 분석 → 대화 → 루틴 전송이라는 하루의 **끝**을 표시하는 것이다(#543).
    final int lastSeeded = showDemoBanners
        ? list.lastIndexWhere((m) => m.id.startsWith('seed-'))
        : -1;
    for (int i = 0; i < list.length; i++) {
      final ClientChatMessage m = list[i];
      final bool newDay =
          i == 0 || !_sameDay(list[i - 1].createdAt, m.createdAt);
      if (newDay) {
        if (showDemoBanners && m.id.startsWith('seed-') && i > 0) {
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
          ..add(_DateDivider(date: m.createdAt))
          ..add(const SizedBox(height: AppSpacing.md));
        if (showDemoBanners && m.id.startsWith('seed-')) {
          out
            ..add(
              _SystemBanner(
                key: ValueKey<String>('analyzed-before-${m.id}'),
                clientName: widget.clientName,
              ),
            )
            ..add(const SizedBox(height: AppSpacing.md));
        }
      }
      // 리포트 전송은 말풍선이 아니라 **가운데 안내**다. 누가 무슨 말을 했는가가
      // 아니라 스레드에 무슨 일이 있었는가를 적는 자리라, 같은 흐름의 다른
      // 안내("개인 추천운동이 …")와 같은 모양으로 가운데에 둔다(#1600).
      final DateTime? reportWeek = m.reportWeekStart;
      out
        ..add(
          reportWeek == null
              ? _Bubble(message: m, avatar: widget.clientAvatar)
              : ReportRegisteredCard(
                  key: ValueKey<String>('trainer-message-bubble-${m.id}'),
                  weekStart: reportWeek,
                  onOpen: () => context.go(
                    AppRoutes.reportFor(
                      widget.clientId,
                      weekStart: reportWeek,
                    ),
                  ),
                ),
        )
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
      // 시드 대화가 여기서 끝난다. 그 뒤에 오는 메시지(방금 보낸 답장)는
      // 배너 **아래**에 쌓인다. 시드가 하루짜리인 고객 대부분에게는 이
      // 자리가 곧 목록의 끝이라, 보내기 전 화면은 예전과 똑같다.
      if (i == lastSeeded) {
        out.add(_SentBanner(clientName: widget.clientName));
        if (i != list.length - 1) {
          out.add(const SizedBox(height: AppSpacing.md));
        }
      }
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
    // 원문이 아니라 감지 요약을 남긴다 — 프로그램 탭이 이 메모를 그대로
    // 읽으므로([chatInsightMemoSummary]), 그날의 말투가 아니라 조치할 내용이
    // 남아야 한다 (#1655).
    final String body = chatInsightMemoSummary(
      AppLocalizations.of(context),
      insight,
    );
    try {
      await ref
          .read(trainerMemoRepositoryProvider)
          .create(
            widget.clientId,
            body: body,
            source: TrainerMemoSource.chatInsight,
            insightId: insight.id,
            insightKind: insight.kind.name,
          );
      ref.invalidate(trainerMemosProvider(widget.clientId));
      if (!mounted) return;
      showAppToast(
        context,
        AppLocalizations.of(context).chatInsightMemoSaved,
        kind: AppToastKind.success,
      );
    } on Object {
      // The button stays in its unsaved state so the trainer can try again —
      // the list is only invalidated on a write that actually landed.
      if (!mounted) return;
      showAppToast(
        context,
        AppLocalizations.of(context).chatInsightMemoSaveFailed,
        kind: AppToastKind.error,
      );
    } finally {
      _savingInsights.remove(insight.id);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

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
        _InputBar(
          controller: _input,
          sending: _sending,
          onSend: _send,
          // 데모에는 사진을 받을 백엔드가 없다 — 진입점을 그리지 않는다. (#921)
          onAttachImage: ref.watch(appConfigProvider).useMockApi
              ? null
              : _sendImage,
        ),
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
        // 메모로 남기고 나면 **바탕만** 하얗게 비운다. 붉은 바탕은 "여기
        // 아직 볼 것이 있다" 는 신호인데, 옮겨 적은 뒤에도 그대로 두면
        // 스레드를 다시 열 때마다 처리한 것과 안 한 것이 똑같이 붉다.
        //
        // 윤곽선과 버튼의 붉은색은 남긴다 — 무슨 일이 있었는지(부정적
        // 피드백)는 바뀌지 않았고, 그 사실까지 회색으로 지우면 나중에
        // 훑을 때 이 자리가 무엇이었는지 알아볼 수 없다.
        color: saved
            ? AppColors.card
            : AppColors.warning.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
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
          // 버튼은 저장 뒤에도 붉은색이다. 초록으로 뒤집었더니 빨간 배너
          // 한가운데서 가장 밝은 것이 "메모 추가됨" 이 되어, 정작 읽어야 할
          // 감지 내용보다 눈에 먼저 들어왔다. 상태 차이는 색이 아니라
          // 아이콘(＋ → ✓)과 문구가 말한다.
          Material(
            color: AppColors.warning.withValues(alpha: 0.13),
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
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      saved ? l.chatInsightMemoAdded : l.chatInsightAddMemo,
                      style: const TextStyle(
                        color: AppColors.warning,
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
              style: const TextStyle(
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
/// the centered notice under the last message). Same navy tone as
/// [_SystemBanner] — not green (#1379): green read as a different kind of
/// "완료" than this routine-sent notice means.
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
          color: AppColors.accentSurface,
          borderRadius: const BorderRadius.all(AppRadius.card),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Column(
          children: <Widget>[
            IconLabel(
              icon: Icons.check_circle_outline,
              label: l.chatDemoRoutineSent(clientName),
              color: AppColors.accent,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              l.chatDemoNotified,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
          'trainer-chat-date-${localDate.year}-${localDate.month}-${localDate.day}',
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
  const _Bubble({required this.message, required this.avatar});

  /// 말풍선이 차지할 수 있는 대화 폭의 최대 비율.
  ///
  /// 상한이 없으면 긴 메시지가 대화 창을 가로로 다 채운다. 그러면 말풍선이
  /// 말풍선으로 읽히지 않는다 — 누가 한 말인지는 색과 **어느 쪽으로 붙어
  /// 있는가**가 말하는데, 양쪽 끝에 닿아 버리면 그 신호가 사라진다.
  ///
  /// 절대값 상한은 두지 않는다. 대화 패널이 가장 넓어지는 경우
  /// (`wideMaxWidth` 1440 에서 `splitListWidth` 380 을 뺀 ~1000)에도 이
  /// 비율이면 720 안쪽이라, 읽기 좋은 줄 길이의 기준으로 이미 쓰고 있는
  /// `contentMaxWidth`(760) 를 넘지 않는다.
  static const double _maxWidthFraction = 0.72;

  final ClientChatMessage message;
  final String avatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromTrainer = message.fromTrainer;
    final Widget bubble = Container(
      key: ValueKey<String>('trainer-message-bubble-${message.id}'),
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
            // 사진은 대화 안에서 그리고, PDF 는 내려받는 카드로 둔다. 사진을
            // 카드로 두면 자세를 확인하려고 매번 파일을 열어야 하고, 그건
            // 채팅에 사진을 붙이는 이유 자체를 없앤다. (#921)
            if (attachment.isImage)
              ChatImageAttachment(attachment: attachment)
            else
              _ChatPdfCard(
                attachment: attachment,
                onOpen: () => _openPdf(context, ref, attachment),
              ),
          ],
        ],
      ),
    );
    final time = Text(
      _clockOnly(message.timeLabel),
      key: ValueKey<String>('trainer-message-time-${message.id}'),
      style: const TextStyle(fontSize: 10, color: AppColors.subtleForeground),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Row(
        mainAxisAlignment: fromTrainer
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!fromTrainer) ...<Widget>[
            ClientAvatar(label: avatar, size: 28),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (fromTrainer) ...<Widget>[
            time,
            const SizedBox(width: AppSpacing.xs),
          ],
          // `Flexible` 도 함께 둔다. 아주 좁은 폭에서는 아바타와 여백이
          // 먼저 자리를 가져가 비율로 계산한 상한보다도 남는 폭이 적을 수
          // 있는데, 그때는 상한이 아니라 남은 폭을 따라야 넘치지 않는다.
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * _maxWidthFraction,
              ),
              child: bubble,
            ),
          ),
          if (!fromTrainer) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            time,
          ],
        ],
      ),
    );
  }

  static String _clockOnly(String label) =>
      RegExp(r'\d{1,2}:\d{2}').firstMatch(label)?.group(0) ?? label;

  /// 채팅에 붙은 PDF 한 부를 미리보기로 연다.
  ///
  /// `build` 는 **부를 때마다 복사본**을 준다. 웹에서 미리보기는 pdf.js 로 그리는데,
  /// pdf.js 는 받은 바이트의 버퍼를 워커로 넘기면서(transfer) 원본을 비워 버린다.
  /// 같은 바이트를 그대로 다시 주면 두 번째 렌더가 `ArrayBuffer ... is already
  /// detached` 로 죽고, 그리다 만 미리보기가 스피너만 도는 채로 남는다. 미리보기는
  /// 화면 크기·용지 설정이 바뀔 때마다 다시 그리므로 두 번째 호출은 반드시 온다.
  Future<void> _openPdf(
    BuildContext context,
    WidgetRef ref,
    ChatAttachment attachment,
  ) async {
    final l = AppLocalizations.of(context);
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
              build: (_) async => Uint8List.fromList(bytes),
              pdfFileName: attachment.fileName,
              allowSharing: false,
              // 미리보기가 실패했을 때 스피너를 계속 돌리면 느린 것과 안 되는
              // 것을 구별할 수 없다.
              onError: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    l.chatPdfOpenFailed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.mutedForeground),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      showAppToast(context, l.chatPdfOpenFailed, kind: AppToastKind.error);
    }
  }
}

/// 리포트 등록 안내. (#1378, #1421, #1600)
///
/// 회원 앱과 **같은 정보 구조**로 그린다 — 아이콘, `리포트가 등록되었어요`,
/// 대상 주, 그리고 다음 행동 한 줄. 같은 사건을 두 앱이 다른 모양으로 보여
/// 주면 회원과 트레이너가 같은 화면을 두고 이야기할 수 없다.
///
/// 자리는 말풍선이 아니라 **대화 가운데**다. 누가 무슨 말을 했는가가 아니라
/// 스레드에 무슨 일이 있었는가를 적는 자리라, 같은 흐름의 다른 안내(분석했어요·
/// 개인 추천운동이 전송됐어요)와 같은 모양을 쓴다.
///
/// 바탕은 흰색이고 테두리만 각 앱의 메인 색이다. 구조와 바탕이 같으면 같은
/// 안내로 읽히고, 테두리 색은 어느 앱을 보고 있는지를 말해 준다.
///
/// 다음 행동은 역할마다 다르다. 트레이너 쪽에는 열 PDF 가 없다 — 데모·드리프트
/// 는 파일을 저장하지 못하므로(#1378), 있지도 않은 파일을 여는 시늉 대신 그
/// 리포트가 있는 화면으로 보낸다.
class ReportRegisteredCard extends StatelessWidget {
  /// Creates the card. [onOpen] 은 리포트 탭으로 보내는 동작이다.
  const ReportRegisteredCard({
    required this.weekStart,
    required this.onOpen,
    super.key,
  });

  /// 카드가 가리키는 주의 월요일.
  final DateTime weekStart;

  /// 리포트 탭으로 가기 를 눌렀을 때.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final range = l.dateRange(
      l.dateMonthDay(weekStart.month, weekStart.day),
      l.dateMonthDay(weekEnd.month, weekEnd.day),
    );
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.all(AppRadius.card),
          border: Border.all(color: AppColors.primary),
        ),
        // 글자 배율을 키우면 제목·기간·다음 행동이 차례로 길어진다. 셋을 한
        // 줄에 이어 붙이지 않고 세로로 쌓아 두면, 배율이 커져도 잘리는 대신
        // 상자가 아래로 자란다.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconLabel(
              icon: Icons.description_outlined,
              label: l.chatReportRegistered,
              color: AppColors.primary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              range,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
            // 테두리 없는 글자 버튼. 안내 상자 안에서 두 번째 테두리를 그리면
            // 상자가 둘로 보인다 — 여기서 눌릴 것은 하나뿐이라 글자로 충분하다.
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l.chatReportOpenInReports),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPdfCard extends StatelessWidget {
  const _ChatPdfCard({required this.attachment, required this.onOpen});

  final ChatAttachment attachment;
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
    this.onAttachImage,
  });

  final TextEditingController controller;

  /// Disables the field and the send button while an insert is in flight.
  final bool sending;

  final Future<void> Function() onSend;

  /// 사진 첨부. 데모처럼 받을 백엔드가 없는 빌드에서는 null 이라 버튼 자체가
  /// 그려지지 않는다 — 눌러도 아무 데도 닿지 않는 버튼을 두지 않는다. (#921)
  final Future<void> Function()? onAttachImage;

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
          if (onAttachImage != null) ...<Widget>[
            IconButton(
              key: const ValueKey<String>('client-chat-attach-image'),
              onPressed: sending ? null : onAttachImage,
              icon: const Icon(Icons.image_outlined),
              color: AppColors.mutedForeground,
              tooltip: l.chatAttachImage,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
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
              child: Tooltip(
                message: AppLocalizations.of(context).a11ySendMessage,
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
          ),
        ],
      ),
    );
  }
}
