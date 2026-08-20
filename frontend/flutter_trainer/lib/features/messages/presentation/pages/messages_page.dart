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
    final completion = recordedCompletionMean(client)?.round();
    final alerts = healthAlertsFor(client);
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
                ClientAvatar(label: client.avatar, active: client.active),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ClientIdentity(
                        client: client,
                        nameStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        client.goal,
                        style: const TextStyle(
                          color: AppColors.subtleForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ActionButton(
                  key: const ValueKey<String>('messages-client-detail-button'),
                  label: l.messagesClientDetail,
                  onPressed: () =>
                      context.go(AppRoutes.clientDetail(client.id)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            color: AppColors.accentSurface.withValues(alpha: 0.55),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          l.messagesRecentWorkout(client.lastRoutine),
                          style: _signalStyle,
                        ),
                        const _SignalDivider(),
                        Text(
                          completion == null
                              ? l.messagesNoCompletion
                              : l.messagesCompletion(completion),
                          style: _signalStyle,
                        ),
                        if (alerts.isNotEmpty) ...<Widget>[
                          const _SignalDivider(),
                          AlertBadge(alert: alerts.first),
                        ],
                      ],
                    ),
                  ),
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

  static const TextStyle _signalStyle = TextStyle(
    fontSize: 12,
    color: AppColors.mutedForeground,
    fontWeight: FontWeight.w600,
  );
}

class _SignalDivider extends StatelessWidget {
  const _SignalDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Container(width: 1, height: 12, color: AppColors.borderStrong),
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
