import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/features/ai_coach/domain/entities/chat_message.dart';
import 'package:oncare/features/ai_coach/domain/repositories/ai_coach_repository.dart';
import 'package:oncare/features/ai_coach/presentation/controllers/ai_coach_controller.dart';

/// Suggested starter prompts shown on the home card and empty chat.
const List<String> kCoachPrompts = <String>[
  '나트륨 줄이는 법',
  '오늘 뭐 먹을까?',
  '운동 추천해줘',
  '혈당 관리 팁',
];

const ChatMessage _welcome = ChatMessage(
  role: ChatRole.coach,
  content: '안녕하세요, AI 건강 코치 온이예요 🙂\n'
      '고혈압·당뇨 관리를 위한 식단·운동·혈압·혈당 무엇이든 편하게 물어보세요.',
);

class ChatState {
  const ChatState({this.messages = const <ChatMessage>[_welcome], this.sending = false});

  final List<ChatMessage> messages;
  final bool sending;

  ChatState copyWith({List<ChatMessage>? messages, bool? sending}) => ChatState(
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
  );
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repo) : super(const ChatState()) {
    _restore();
  }

  final AiCoachRepository _repo;

  /// 서버에 저장된 이전 대화를 불러온다(재접속·다른 기기에서 대화 잇기).
  ///
  /// 실패해도 조용히 넘어간다. 히스토리를 못 불러온 것 때문에 채팅을 못 쓰게
  /// 만들 이유가 없고, 화면은 welcome 메시지로 정상 동작한다. 목업 모드는 항상
  /// 빈 목록이라 지금과 똑같이 welcome 하나로 시작한다.
  Future<void> _restore() async {
    try {
      final stored = await _repo.fetchHistory();
      if (stored.isEmpty || !mounted) return;
      // 복원한 대화가 있으면 welcome 대신 그것을 보여준다 — 이어 하는 대화에
      // 매번 인사가 끼어들면 맥락이 끊긴다.
      state = state.copyWith(messages: stored);
    } catch (_) {
      // 무시: welcome 메시지 상태 유지
    }
  }

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.sending) return;

    // 현재까지의 대화(진행 중 placeholder 제외)를 history 로 전달.
    final history = state.messages.where((ChatMessage m) => !m.pending).toList();

    state = state.copyWith(
      messages: <ChatMessage>[
        ...history,
        ChatMessage(role: ChatRole.user, content: message),
        const ChatMessage(role: ChatRole.coach, content: '', pending: true),
      ],
      sending: true,
    );

    try {
      final reply = await _repo.sendMessage(message: message, history: history);
      state = state.copyWith(messages: _replacePending(reply), sending: false);
    } catch (_) {
      state = state.copyWith(
        messages: _replacePending(
          const ChatMessage(
            role: ChatRole.coach,
            content: '앗, 잠시 문제가 생겼어요. 잠시 후 다시 시도해 주세요.',
          ),
        ),
        sending: false,
      );
    }
  }

  List<ChatMessage> _replacePending(ChatMessage reply) => <ChatMessage>[
    ...state.messages.where((ChatMessage m) => !m.pending),
    reply,
  ];
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>(
      (ref) => ChatController(ref.watch(aiCoachRepositoryProvider)),
      name: 'chatController',
    );
