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
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/alert_badge.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

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
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
      scrollable: false,
      contentPadding: const EdgeInsets.fromLTRB(
        AppLayout.pagePadding,
        AppLayout.pagePadding,
        AppLayout.pagePadding,
        AppLayout.pagePadding,
      ),
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
            if (_query.isNotEmpty &&
                !client.name.toLowerCase().contains(_query.toLowerCase()) &&
                !client.lastMessage.toLowerCase().contains(
                  _query.toLowerCase(),
                )) {
              return false;
            }
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
                    controller: _search,
                    onQueryChanged: _setQuery,
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
                    width: 340,
                    child: _ConversationList(
                      clients: filtered,
                      selectedId: selected?.id,
                      unread: unread,
                      filter: filter,
                      controller: _search,
                      onQueryChanged: _setQuery,
                      onFilterChanged: _setFilter,
                      onSelected: _selectClient,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
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

  void _setQuery(String value) => setState(() => _query = value.trim());

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
    required this.controller,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onSelected,
  });

  final List<TrainerClient> clients;
  final String? selectedId;
  final Map<String, int> unread;
  final _ConversationFilter filter;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_ConversationFilter> onFilterChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              l.messagesConversations,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: l.messagesSearchHint,
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.borderStrong),
          Expanded(
            child: clients.isEmpty
                ? EmptyHint(
                    message: l.messagesEmpty,
                    icon: Icons.forum_outlined,
                  )
                : ListView.separated(
                    itemCount: clients.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 76,
                      color: AppColors.borderStrong,
                    ),
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
      ),
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
    final alerts = healthAlertsFor(client);
    return Material(
      color: selected ? AppColors.accentSurface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    left: BorderSide(color: AppColors.primary, width: 3),
                  )
                : null,
          ),
          child: Row(
            children: <Widget>[
              ClientAvatar(label: client.avatar, active: client.active),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            client.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            client.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 12.5,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: AppSpacing.xs),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.all(AppRadius.pill),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (alerts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      AlertBadge(alert: alerts.first),
                    ],
                  ],
                ),
              ),
            ],
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
                      Text(
                        client.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
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
                  label: l.messagesProgram,
                  onPressed: () => context.go(AppRoutes.coachingFor(client.id)),
                ),
                const SizedBox(width: AppSpacing.xs),
                ActionButton(
                  label: l.messagesSchedule,
                  onPressed: () => context.go(AppRoutes.scheduleView('week')),
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(width: AppSpacing.md),
                TextButton(
                  onPressed: () =>
                      context.go(AppRoutes.clientDetail(client.id)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l.messagesClientDetail),
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
