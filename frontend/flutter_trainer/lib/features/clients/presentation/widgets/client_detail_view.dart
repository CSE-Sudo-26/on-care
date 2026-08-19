import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/domain/repositories/client_data_refresher.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_follow_up_dialog.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/client_memo_dialog.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/diet_view.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/member_health_profile_dialog.dart';
import 'package:oncare_trainer/features/clients/presentation/widgets/workout_view.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/client_alerts.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/services/chat_repository.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/alert_badge.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';
import 'package:oncare_trainer/shared/widgets/client_identity.dart';
import 'package:oncare_trainer/shared/widgets/status_dot_label.dart';

/// Labels for [AppRoutes.clientTabSections], in the same order.
///
/// 함수인 이유: const 리스트로 두면 생성 시점에 로케일을 알 수 없다. 개수는
/// 라우트 개수와 맞아야 하므로 [clientSectionCount] 로 따로 센다. (#501)
List<String> clientSectionLabels(AppLocalizations l) => <String>[
  l.clientTabDiet,
  l.clientTabWorkout,
];

/// 탭 개수 — 라우트(`AppRoutes.clientTabSections`)와 맞물리는 값이라
/// 로케일과 무관하다.
const int clientSectionCount = 2;

/// The trainer-only client detail: identity and actions stay above the diet and
/// workout tabs. The selected tab mirrors the route so deep links, refreshes,
/// and browser navigation restore the same section.
class ClientDetailView extends ConsumerStatefulWidget {
  /// Creates the detail body for [clientId].
  const ClientDetailView({
    super.key,
    required this.clientId,
    required this.section,
    required this.onSectionChange,
    this.showBack = true,
    this.onClose,
  });

  /// Id of the client being viewed.
  final String clientId;

  /// Active sub-section; unknown values fall back to the default.
  final String? section;

  /// Asks the host to navigate to another section.
  final ValueChanged<String> onSectionChange;

  /// Whether to render the back button (narrow, detail-only layout).
  final bool showBack;

  /// Closes the panel and returns to the plain list.
  final VoidCallback? onClose;

  /// The section actually being shown; unknown values fall back to the
  /// default so a stale link renders something rather than nothing.
  String get resolvedSection {
    final s = section ?? '';
    return AppRoutes.clientTabSections.contains(s)
        ? s
        : AppRoutes.defaultClientSection;
  }

  @override
  ConsumerState<ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends ConsumerState<ClientDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late int _reportedIndex;

  /// A 활성/휴면 write is in flight. The badge is a one-tap control, so
  /// without this a second tap fires a second request and the two answers
  /// land in whatever order the network decides.
  bool _statusSaving = false;

  int get _routeIndex =>
      AppRoutes.clientTabSections.indexOf(widget.resolvedSection);

  @override
  void initState() {
    super.initState();
    _reportedIndex = _routeIndex;
    _tabController = TabController(
      length: clientSectionCount,
      initialIndex: _reportedIndex,
      vsync: this,
    )..addListener(_handleTabChange);
  }

  @override
  void didUpdateWidget(covariant ClientDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _routeIndex;
    if (nextIndex != _tabController.index) {
      _reportedIndex = nextIndex;
      _tabController.animateTo(nextIndex);
    }
  }

  void _handleTabChange() {
    if (_tabController.index == _reportedIndex) return;
    _reportedIndex = _tabController.index;
    widget.onSectionChange(AppRoutes.clientTabSections[_reportedIndex]);
  }

  /// Moves the client between 활성 and 휴면. (#707)
  ///
  /// Nothing is written to the badge here — it renders the roster, and the
  /// roster only changes once the source confirms. A failed call therefore
  /// leaves the previous state on screen instead of a value the server
  /// never accepted, and the trainer can tap again.
  Future<void> _setActive(String clientId, bool active) async {
    if (_statusSaving) return;
    setState(() => _statusSaving = true);
    try {
      await ref
          .read(clientRepositoryProvider)
          .setClientActive(clientId, active);
      if (!mounted) return;
      setState(() => _statusSaving = false);
    } on AppError catch (error) {
      if (!mounted) return;
      setState(() => _statusSaving = false);
      final AppLocalizations l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serverDetailOr(l, error.message, l.clientStatusChangeFailed),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _statusSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).clientStatusChangeFailed),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // Distinguish loading / error / loaded instead of flattening them
    // into an empty list (an unknown id used to render a nameless
    // "고객" chat and never-ending 식단/운동 spinners — codex review).
    final clientsAsync = ref.watch(clientsProvider);
    // The unread count has to come along: without it `alertsFor` always
    // sees 0 and 답장 대기 could never appear here — so a client the
    // dashboard flagged in red would lose its reason on arrival.
    final unread =
        ref.watch(unreadCountsProvider).valueOrNull ?? const <String, int>{};

    return clientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _StatusView(
        message: l.clientsLoadFailed,
        showBack: widget.showBack,
        // Re-subscribes the stream for a fresh attempt.
        onRetry: () => ref.invalidate(clientsProvider),
      ),
      data: (clients) {
        final match = clients.where((c) => c.id == widget.clientId);
        if (match.isEmpty) {
          // Stale deep link / removed client.
          return _StatusView(
            message: l.clientNotFound,
            showBack: widget.showBack,
            onRetry: null,
          );
        }
        final client = match.first;

        final diet = DietView(
          key: ValueKey<String>('diet-${widget.clientId}'),
          client: client,
        );
        final workout = WorkoutView(
          key: ValueKey<String>('workout-${widget.clientId}'),
          client: client,
        );

        return Column(
          children: <Widget>[
            _Header(
              client: client,
              alerts: alertsFor(client, unread: unread[client.id] ?? 0),
              showBack: widget.showBack,
              onClose: widget.onClose,
              onRefresh: () {
                final ClientRepository repository = ref.read(
                  clientRepositoryProvider,
                );
                if (repository case final ClientDataRefresher refresher) {
                  refresher.refreshClientData(client.id);
                }
              },
              onToggleActive: _statusSaving
                  ? null
                  : () => _setActive(client.id, !client.active),
            ),
            Material(
              color: AppColors.card,
              child: TabBar(
                key: const ValueKey<String>('client-detail-sub-tabs'),
                controller: _tabController,
                tabs: <Widget>[
                  Tab(text: l.clientTabDiet),
                  Tab(text: l.clientTabWorkout),
                ],
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.mutedForeground,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: AppColors.borderStrong,
              ),
            ),
            Expanded(
              child: TabBarView(
                key: ValueKey<String>('client-detail-tabs-${widget.clientId}'),
                controller: _tabController,
                children: <Widget>[diet, workout],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fallback body for the error and not-found states: a message, an
/// optional 다시 시도 button, and a way back to the 고객 list.
class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.message,
    required this.showBack,
    required this.onRetry,
  });

  final String message;
  final bool showBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(l.actionRetry)),
          if (showBack)
            TextButton(
              onPressed: () => context.go(AppRoutes.clients),
              child: Text(l.clientBackToList),
            ),
        ],
      ),
    );
  }
}

/// Identity, why this client is flagged, and the two things the trainer most
/// often does next — above the tabs, so actionable context stays visible no
/// matter which tab is open without duplicating the tab-specific summaries.
class _Header extends ConsumerWidget {
  const _Header({
    required this.client,
    required this.alerts,
    required this.showBack,
    required this.onClose,
    required this.onRefresh,
    required this.onToggleActive,
  });

  final TrainerClient client;

  /// Why this client is flagged; empty when they're fine today.
  final List<ClientAlert> alerts;

  final bool showBack;
  final VoidCallback? onClose;
  final VoidCallback onRefresh;

  /// Flips the client between 활성 and 휴면.
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 주의사항 배지는 프로필 줄로 올라갔다(#926) — 활성/휴면 배지와 같이
          // **이 사람이 어떤 상태인가**를 말하는 값이라, 혼자 한 줄을 쓸 이유가
          // 없었다. 배지가 하나뿐인 경우가 대부분이라 그 줄은 거의 언제나
          // 배지 한 개와 빈 여백이었고, 그만큼 아래 식단·운동이 밀렸다. 경고가
          // 없는 회원은 줄이 통째로 사라져 회원을 옮길 때마다 빠른 버튼 줄의
          // 세로 위치까지 달라졌다.
          _identityRow(context),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            key: const ValueKey<String>('client-detail-quick-actions'),
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            // 파랑·하양이 번갈아 선다 — 메시지 · 프로그램 · 신체·목표 · 후속 관리 ·
            // 메모. 같은 무게로만 서면 어느 것이 이 화면의 주된 동작인지 읽히지
            // 않는다.
            children: <Widget>[
              // 이 회원을 보다가 바로 이어지는 두 자리. 예전에는 식단·운동을
              // 다 읽고도 메시지 탭·프로그램 탭으로 건너가 같은 사람을 목록에서
              // 다시 찾아야 했다(#823).
              ActionButton(
                key: const ValueKey<String>('client-detail-open-messages'),
                label: l.clientQuickMessages,
                icon: Icons.chat_bubble_outline,
                primary: true,
                onPressed: () => context.go(AppRoutes.messagesFor(client.id)),
              ),
              ActionButton(
                key: const ValueKey<String>('client-detail-open-program'),
                label: l.clientQuickProgram,
                icon: Icons.auto_awesome_outlined,
                onPressed: () => context.go(AppRoutes.coachingFor(client.id)),
              ),
              ActionButton(
                label: l.clientHealthGoals,
                icon: Icons.badge_outlined,
                primary: true,
                onPressed: () => showMemberHealthProfileDialog(
                  context,
                  memberId: client.id,
                  repository: ref.read(clientRepositoryProvider),
                  // 서버에 성별이 없으면 로스터가 보여 주는 값으로 연다 —
                  // 헤더와 대화상자가 다른 말을 하지 않도록(#960).
                  fallbackGender: client.rosterGender,
                ),
              ),
              // 메모 바로 앞이다 — 끝의 두 자리는 둘 다 내가 이 고객에 대해 남기는
              // 기록이고, 다른 점은 "언제까지 무엇을 할 것인가"가 붙느냐뿐이다
              // (#869). 메모는 줄의 오른쪽 끝을 계속 지킨다(#729).
              ActionButton(
                key: const ValueKey<String>('client-detail-follow-up'),
                label: l.followUp,
                icon: Icons.event_available_outlined,
                onPressed: () => showClientFollowUpDialog(
                  context,
                  clientId: client.id,
                  clientName: client.name,
                ),
              ),
              ActionButton(
                label: l.clientTrainerMemo,
                icon: Icons.edit_note_outlined,
                primary: true,
                onPressed: () => showClientMemoDialog(
                  context,
                  clientId: client.id,
                  clientName: client.name,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identityRow(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      // 주의사항 줄이 사라졌는지를 테스트가 재려면 프로필 줄의 끝을 지목할 수
      // 있어야 한다(#926).
      key: const ValueKey<String>('client-detail-identity'),
      children: <Widget>[
        if (showBack)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: AppColors.accent,
            tooltip: l.clientList,
            onPressed: () => context.go(AppRoutes.clients),
          ),
        ClientAvatar(label: client.avatar, size: 36),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Status sits with the name — it describes the person, so
              // it belongs to their identity line rather than to the
              // corner the actions live in. 주의사항 배지도 같은 이유로 이
              // 줄에 있다(#926).
              //
              // `Row` 가 아니라 `Wrap` 이다. 셋을 한 줄에 억지로 세우면 영어 ·
              // 배율 1.3 · 폭 1024 에서 줄이 넘쳤다 — 알약과 배지는 글자 길이만큼
              // 자리를 요구할 뿐 줄어들 수 없기 때문이다. `Wrap` 은 자리가
              // 모자라면 다음 줄로 내린다.
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) => Wrap(
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    // The backend roster has no status mutation endpoint
                    // yet. Keep the status visible in real mode, but only
                    // make it interactive when the selected repository
                    // supports roster mutations.
                    Material(
                      color:
                          (client.active
                                  ? AppColors.success
                                  : AppColors.disabledForeground)
                              .withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                      child: InkWell(
                        key: const ValueKey<String>('client-status-toggle'),
                        onTap: onToggleActive,
                        borderRadius: const BorderRadius.all(AppRadius.pill),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          child: StatusDotLabel(
                            label: client.active
                                ? l.clientActive
                                : l.clientDormant,
                            filled: client.active,
                            color: client.active
                                ? AppColors.success
                                : AppColors.disabledForeground,
                          ),
                        ),
                      ),
                    ),
                    // 배지는 하나씩 `Wrap` 의 자식이다. 묶어서 넣으면 그 묶음이
                    // 통째로 다음 줄로 내려가고, 묶음 안에서는 다시 접히지 않는다.
                    for (final alert in alerts)
                      KeyedSubtree(
                        key: ValueKey<String>(
                          'client-detail-alert-${alert.name}',
                        ),
                        child: AlertBadge(alert: alert),
                      ),
                  ],
                ),
              ),
              Text(
                client.goal,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.subtleForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey<String>('client-data-refresh'),
          icon: const Icon(Icons.refresh, size: 18),
          color: AppColors.subtleForeground,
          tooltip: l.actionRefresh,
          onPressed: onRefresh,
        ),
        if (onClose != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.subtleForeground,
            tooltip: l.clientClosePanel,
            onPressed: onClose,
          ),
      ],
    );
  }
}
