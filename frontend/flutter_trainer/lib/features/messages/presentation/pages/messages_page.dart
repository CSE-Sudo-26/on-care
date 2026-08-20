import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/chat_view.dart';
import 'package:oncare_trainer/features/search/presentation/widgets/client_search_bar.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/alert_badge.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/shared/widgets/status_dot_label.dart';

enum _ConversationFilter {
  all('all'),
  unread('unread'),
  attention('attention');

  const _ConversationFilter(this.value);

  final String value;

  String label(AppLocalizations l) => switch (this) {
    _ConversationFilter.all => l.messagesFilterAll,
    _ConversationFilter.unread => l.messagesFilterUnread,
    _ConversationFilter.attention => l.messagesFilterAttention,
  };

  static _ConversationFilter parse(String? value) => values.firstWhere(
    (item) => item.value == value,
    orElse: () => _ConversationFilter.all,
  );
}

/// Figma의 독립 메시지 작업 공간. 기존 회원 상세 채팅과 같은
/// [chatThreadProvider]/[chatRepositoryProvider]를 사용하므로 회원 앱과의
/// 메시지 흐름, 읽음 처리, polling semantics는 그대로 유지된다.
class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key, this.clientId, this.filter});

  final String? clientId;
  final String? filter;

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final clientsAsync = ref.watch(prioritizedClientsProvider);
    final unread =
        ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};
    final filter = _ConversationFilter.parse(widget.filter);

    return PageScaffold(
      title: l.navMessages,
      subtitle: l.messagesSubtitle,
      headerCenter: const ClientSearchBar(),
      scrollable: false,
      child: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyHint(
          message: l.messagesLoadFailed,
          icon: Icons.error_outline,
          action: ActionButton(
            label: l.actionRetry,
            onPressed: () => ref.invalidate(clientsProvider),
          ),
        ),
        data: (clients) {
          final filtered = clients.where((client) {
            return switch (filter) {
              _ConversationFilter.all => true,
              _ConversationFilter.unread => (unread[client.id] ?? 0) > 0,
              _ConversationFilter.attention => healthAlertsFor(
                client,
              ).isNotEmpty,
            };
          }).toList();
          final selected = widget.clientId == null
              ? null
              : clients.cast<TrainerClient?>().firstWhere(
                  (client) => client?.id == widget.clientId,
                  orElse: () => null,
                );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < AppLayout.splitBreakpoint) {
                if (selected == null) {
                  return _ConversationList(
                    clients: filtered,
                    selectedId: null,
                    unread: unread,
                    filter: filter,
                    onFilterChanged: _setFilter,
                    onSelected: _selectClient,
                  );
                }
                return _ThreadPanel(
                  client: selected,
                  onBack: () => context.go(
                    AppRoutes.messagesFor(null, filter: widget.filter),
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: AppLayout.splitListWidth,
                    child: _ConversationList(
                      clients: filtered,
                      selectedId: selected?.id,
                      unread: unread,
                      filter: filter,
                      onFilterChanged: _setFilter,
                      onSelected: _selectClient,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: selected == null
                        ? const _EmptyThread()
                        : _ThreadPanel(client: selected),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _setFilter(_ConversationFilter filter) {
    context.go(AppRoutes.messagesFor(widget.clientId, filter: filter.value));
  }

  void _selectClient(String id) {
    context.go(AppRoutes.messagesFor(id, filter: widget.filter));
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.clients,
    required this.selectedId,
    required this.unread,
    required this.filter,
    required this.onFilterChanged,
    required this.onSelected,
  });

  final List<TrainerClient> clients;
  final String? selectedId;
  final Map<String, int> unread;
  final _ConversationFilter filter;
  final ValueChanged<_ConversationFilter> onFilterChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l.messagesConversations,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final item in _ConversationFilter.values) ...<Widget>[
                _FilterChip(
                  label: item == _ConversationFilter.unread
                      ? l.messagesFilterUnreadCount(
                          unread.values.where((n) => n > 0).length,
                        )
                      : item.label(l),
                  selected: filter == item,
                  onTap: () => onFilterChanged(item),
                ),
                if (item != _ConversationFilter.values.last)
                  const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: clients.isEmpty
              ? EmptyHint(message: l.messagesEmpty, icon: Icons.forum_outlined)
              : ListView.separated(
                  padding: const EdgeInsets.only(
                    right: AppSpacing.sm,
                    bottom: AppLayout.pagePadding,
                  ),
                  itemCount: clients.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return _ConversationTile(
                      key: ValueKey<String>(
                        'messages-conversation-${client.id}',
                      ),
                      client: client,
                      selected: client.id == selectedId,
                      unread: unread[client.id] ?? 0,
                      onTap: () => onSelected(client.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSurface : AppColors.inputBackground,
      borderRadius: const BorderRadius.all(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    super.key,
    required this.client,
    required this.selected,
    required this.unread,
    required this.onTap,
  });

  final TrainerClient client;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // 로스터의 미리보기는 대화가 없는 고객에게 빈 문자열이다(실 API의
    // `last_message=… if last_msg else ""`). 빈 `Text` 는 아무것도 그리지
    // 않아 그 줄이 통째로 사라졌고, 옆 고객만 한 줄 높은 타일을 가졌다 —
    // 화면은 "미리보기가 없다"가 아니라 "아직 대화가 없다"를 말해야 한다.
    final hasPreview = client.lastMessage.trim().isNotEmpty;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
      ),
      child: Material(
        color: selected ? AppColors.accentSurface : AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(AppRadius.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(AppRadius.card),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.5)
                    : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                ClientAvatar(
                  label: client.avatar,
                  size: 36,
                  showStatus: true,
                  active: client.active,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ClientIdentity(
                              client: client,
                              nameStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                          Text(
                            client.lastTime,
                            style: const TextStyle(
                              color: AppColors.subtleForeground,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      // 오른쪽 대화 패널 머리에는 목표가 있는데 정작 고객을
                      // 고르는 목록에는 없었다(#898).
                      const SizedBox(height: 2),
                      ClientGoalLabel(client: client),
                      // 활성/주의 배지는 여기 없다. 목록은 **어느 대화를 열까**
                      // 를 정하는 자리라 이름 · 목표 · 마지막 말 · 안읽음이면
                      // 충분하고, 상태의 자세한 내막은 대화를 연 뒤 헤더가
                      // 말한다(#991). 같은 사실을 두 번 세우면 목록이 길어질
                      // 뿐 고르는 데 도움이 되지 않는다. 활성/휴면만은 아바타
                      // 모서리의 점으로 남는다 — 훑는 자리의 표시다.
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              hasPreview
                                  ? client.lastMessage
                                  : l.messagesNoPreview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hasPreview
                                    ? AppColors.mutedForeground
                                    : AppColors.subtleForeground,
                                fontSize: 11.5,
                                fontStyle: hasPreview
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              key: ValueKey<String>(
                                'messages-unread-${client.id}',
                              ),
                              margin: const EdgeInsets.only(
                                left: AppSpacing.xs,
                              ),
                              constraints: const BoxConstraints(minWidth: 20),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.all(AppRadius.pill),
                              ),
                              child: Text(
                                '$unread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadPanel extends StatelessWidget {
  const _ThreadPanel({required this.client, this.onBack});

  final TrainerClient client;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                if (onBack != null) ...<Widget>[
                  IconButton(
                    tooltip: l.messagesBackToList,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                // 활성/휴면은 옆의 알약이 글자로 말한다 — 여기 점까지 찍으면
                // 같은 사실이 한 뼘 안에 두 번 선다. 목록의 아바타는 반대다:
                // 그쪽엔 알약이 없어 점이 유일한 표시다.
                ClientAvatar(label: client.avatar),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _Identity(client: client)),
                // 식단·운동은 고객 탭이 훨씬 자세히 보여 준다. 이 화면은
                // 대화를 하는 곳이므로, 그 데이터를 여기로 옮겨 오는 대신
                // **가는 길**만 둔다.
                _ClientDetailLink(
                  key: const ValueKey<String>('messages-client-detail-button'),
                  label: l.messagesClientDetail,
                  onPressed: () =>
                      context.go(AppRoutes.clientDetail(client.id)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderStrong),
          Expanded(
            child: ChatView(
              key: ValueKey<String>('messages-thread-${client.id}'),
              clientId: client.id,
              clientAvatar: client.avatar,
              clientName: client.name,
            ),
          ),
        ],
      ),
    );
  }
}

/// 대화 헤더가 말하는 이 사람 — 이름 · 성별·나이 · 활성/휴면 · 주의사항,
/// 그 아래 목표.
///
/// 고객 탭 상세(`client_detail_view.dart` 의 `_identityRow`)와 같은 구성이다.
/// 같은 사실을 두 탭이 다른 모양으로 말하지 않도록 색·문구·모양을 맞춘다(#926).
///
/// 여기가 목록보다 **자세한** 자리다. 목록은 어느 대화를 열까만 정하고,
/// 연 뒤에 이 사람이 어떤 상태인지는 여기서 읽는다.
///
/// `Row` 가 아니라 `Wrap` 인 이유: 알약과 배지는 글자 길이만큼 자리를 요구할
/// 뿐 줄어들 수 없어서, 좁은 폭에서는 다음 줄로 내려야 한다.
///
/// 알약은 **읽기 전용**이다. 활성/휴면을 바꾸는 자리는 고객 탭이고, 대화
/// 중에 눌러서 바뀌면 되돌릴 곳이 이 화면에 없다.
class _Identity extends StatelessWidget {
  const _Identity({required this.client});

  final TrainerClient client;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final alerts = healthAlertsFor(client);
    final statusColor = client.active
        ? AppColors.success
        : AppColors.disabledForeground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) => Wrap(
            key: const ValueKey<String>('messages-thread-identity'),
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: 4,
            children: <Widget>[
              // 이름만은 줄 폭 안에서 말줄임한다 — `Wrap` 의 자식은 폭이
              // 무제한이라 기대는 곳이 없으면 긴 이름이 그대로 뻗는다.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth),
                child: ClientIdentity(
                  client: client,
                  nameStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Container(
                key: const ValueKey<String>('messages-thread-status'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(AppRadius.pill),
                ),
                child: StatusDotLabel(
                  label: client.active ? l.clientActive : l.clientDormant,
                  filled: client.active,
                  color: statusColor,
                ),
              ),
              // 배지는 하나씩 `Wrap` 의 자식이다. 묶어서 넣으면 그 묶음이
              // 통째로 다음 줄로 내려가고, 묶음 안에서는 다시 접히지 않는다.
              //
              // 목록과 달리 **전부** 세운다 — 자세한 쪽이 여기다.
              for (final alert in alerts)
                KeyedSubtree(
                  key: ValueKey<String>('messages-thread-alert-${alert.name}'),
                  child: AlertBadge(alert: alert),
                ),
            ],
          ),
        ),
        Text(
          client.goal,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.subtleForeground,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 고객 탭으로 가는 길 — 화살표 앞에 목적지 이름을 세운다.
///
/// 화살표만 두면 "여기서 어디로 가는가" 를 아이콘 모양으로 짐작해야 한다.
/// 그렇다고 채워진 버튼으로 세우면 이 화면의 주된 동작인 메시지 보내기보다
/// 강하게 읽힌다 — 글자를 화살표와 **같은 색·같은 크기**로 두어, 길잡이는
/// 되되 눈길은 끌지 않게 한다.
class _ClientDetailLink extends StatelessWidget {
  const _ClientDetailLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(AppRadius.pill),
        child: InkWell(
          onTap: onPressed,
          borderRadius: const BorderRadius.all(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    // 화살표(20)와 같은 크기·같은 색. 둘이 한 덩어리로 읽힌다.
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.disabledForeground,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.disabledForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Panel(
      child: EmptyHint(
        message: l.messagesSelectPrompt,
        icon: Icons.chat_bubble_outline,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}
