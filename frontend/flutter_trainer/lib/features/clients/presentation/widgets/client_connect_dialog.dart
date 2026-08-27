import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/design_system/tokens/toast.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_invite_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_invite.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/app_toast.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';

/// 회원 ID로 기존 회원을 찾아 연결하는 신규 고객 등록 창. (#919)
///
/// 두 단계다 — 회원 ID로 **찾고**, 찾은 사람과 **연결한다**. 한 번에 연결하지
/// 않는 이유는 오타 한 글자가 다른 사람에게 가는 요청이 되기 때문이다. 이름을
/// 눈으로 확인하고 나서 누르게 한다. 성별·나이·신체 정보는 여기서 입력받지
/// 않는다 — 연결되면 회원이 이미 자기 앱에 등록해 둔 값을 그대로 쓴다.
///
/// 회원 ID 완전 일치만 되는 것도 의도다. 이름으로 훑을 수 있으면 담당도 아닌
/// 사람들의 존재가 트레이너에게 드러난다.
///
/// 실 API 는 연결이 회원의 수락을 기다리는 **요청**이라(담당 관계가 상대의
/// 식단·건강 기록을 여는 권한이라 한쪽이 일방적으로 만들 수 없다), 창
/// 아래쪽에 **답을 기다리는 요청**을 함께 둔다 — 보낸 요청은 고객 목록에
/// 나타나지 않으므로, 여기가 아니면 트레이너는 자기가 무엇을 보냈는지 볼 곳이
/// 없다. 데모는 회원 ID가 확인되면 그 자리에서 연결되므로([connectsImmediately])
/// 이 목록도 메시지 칸도 없다 — 기다릴 답이 없다.
///
/// 가운데 뜨는 작은 창이다 — 상담 요청 인박스(`showConsultationsDialog`)와
/// 같은 자리(다른 작업으로 잠깐 넘어갔다 돌아오는 자리)에서 열리는 창이라
/// 같은 형식을 쓴다. 바닥에서 올라오는 시트로 두면 같은 성격의 두 진입점이
/// 서로 다른 화면처럼 읽힌다.
class ClientConnectDialog extends ConsumerStatefulWidget {
  const ClientConnectDialog({super.key});

  @override
  ConsumerState<ClientConnectDialog> createState() =>
      _ClientConnectDialogState();
}

class _ClientConnectDialogState extends ConsumerState<ClientConnectDialog> {
  final TextEditingController _memberId = TextEditingController();
  final TextEditingController _message = TextEditingController();

  MemberLookup? _found;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _memberId.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (_busy) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final memberId = _memberId.text.trim();
    if (memberId.isEmpty) {
      setState(() {
        _error = l.clientInviteMemberIdRequired;
        _found = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
    });
    try {
      final found = await ref
          .read(clientInviteRepositoryProvider)
          .lookup(memberId);
      if (!mounted || _memberId.text.trim() != memberId) return;
      setState(() => _found = found);
    } on NotFoundError {
      if (!mounted) return;
      setState(() => _error = l.clientInviteNotFound);
    } on AppError catch (error) {
      if (!mounted) return;
      // 서버가 이유를 문장으로 준 경우에는 그 문장이 다음에 할 일을 정한다.
      // (한국어 로케일에서만 — 영어 화면에 한국어가 새지 않게 한다.)
      setState(
        () => _error = serverDetailOr(l, error.message, l.clientInviteFailed),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final found = _found;
    if (_busy || found == null) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final repository = ref.read(clientInviteRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.invite(found.memberId, message: _message.text);
      ref.invalidate(pendingClientInvitesProvider);
      // 데모(즉시 연결)와 미등록 고객을 되살리는 경로 모두, 고객 탭과
      // 고객 관리가 같은 목록을 보므로 두 provider 를 함께 새로고침한다.
      ref.invalidate(clientsProvider);
      ref.invalidate(managedClientsProvider);
      if (!mounted) return;
      navigator.pop();
      showAppToast(
        context,
        repository.connectsImmediately
            ? l.clientInviteConnected(found.name)
            : l.clientInviteSent(found.name),
        kind: AppToastKind.success,
      );
    } on AppError catch (error) {
      if (!mounted) return;
      setState(
        () => _error = serverDetailOr(l, error.message, l.clientInviteFailed),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(ClientInvite invite) async {
    if (_busy) return;
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(clientInviteRepositoryProvider).cancel(invite.id);
      ref.invalidate(pendingClientInvitesProvider);
      if (!mounted) return;
      showAppToast(
        context,
        l.clientInviteCancelled,
        kind: AppToastKind.success,
      );
    } on AppError catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        serverDetailOr(l, error.message, l.clientInviteCancelFailed),
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool connectsImmediately = ref.watch(
      clientInviteRepositoryProvider.select((r) => r.connectsImmediately),
    );

    return Dialog(
      key: const ValueKey<String>('client-connect-dialog'),
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      // 위쪽만 [AppToastStyle.dialogTopClearance] — 상단 토스트가 이
      // 대화상자 위로 겹쳐 뜰 수 있다.
      insetPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppToastStyle.dialogTopClearance,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l.clientInviteTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // 수락해야 고객이 된다는 것(실 API)을, 또는 바로 연결된다는 것
                // (데모)을 창이 먼저 말한다 — 연결한 뒤 명단을 새로고침하며
                // 기다리는 일이 없도록.
                Text(
                  connectsImmediately
                      ? l.clientInviteIntroImmediate
                      : l.clientInviteIntro,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.clientInviteMemberIdLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  key: const ValueKey<String>('client-connect-member-id'),
                  controller: _memberId,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.search,
                  cursorHeight: 15,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedForeground,
                  ),
                  onChanged: (_) {
                    if (_found != null) {
                      setState(() => _found = null);
                    }
                  },
                  onSubmitted: (_) => _lookup(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l.clientInviteMemberIdRequired,
                    errorText: _error,
                    contentPadding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      top: 10,
                      bottom: 10,
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 40,
                    ),
                    suffixIcon: IconButton(
                      key: const ValueKey<String>('client-connect-lookup'),
                      tooltip: l.clientInviteLookupAction,
                      onPressed: _busy ? null : _lookup,
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      color: AppColors.primary,
                      icon: const Icon(Icons.search_rounded),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_found case final MemberLookup found) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _FoundMemberCard(found: found),
                  if (found.canInvite) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    // 바로 등록하지 않고 한 번 더 확인시킨다 — 회원 ID 한 글자가
                    // 틀리면 다른 사람과 연결되므로, 이름·정보를 눈으로 보고
                    // 누르게 한다.
                    Text(
                      l.clientInviteConfirmPrompt,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (!connectsImmediately)
                      TextField(
                        key: const ValueKey<String>('client-invite-message'),
                        controller: _message,
                        maxLines: 2,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: l.clientInviteMessageLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    if (connectsImmediately)
                      SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          key: const ValueKey<String>(
                            'client-connect-register',
                          ),
                          onPressed: _busy ? null : _send,
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                          ),
                          label: Text(l.clientInviteConnectAction),
                          style: FilledButton.styleFrom(
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(AppRadius.md),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      ActionButton(
                        label: l.clientInviteSendAction,
                        icon: Icons.send,
                        primary: true,
                        onPressed: _busy ? null : _send,
                      ),
                  ],
                ],
                if (!connectsImmediately) ...<Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l.clientInvitePendingTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PendingInvitesList(busy: _busy, onCancel: _cancel),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 창 우상단의 닫기 버튼 — 바닥 시트와 달리 가운데 뜨는 창은 아래로 끌어
/// 내려 닫을 수 없으므로, 배경을 눌러 닫는 것과 별개로 명시적인 닫기
/// 동작을 둔다(상담 요청 인박스의 닫기 버튼과 같은 이유).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: MaterialLocalizations.of(context).closeButtonTooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.close,
              size: 18,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// 답을 기다리는 요청 목록 — 실 API 전용([ClientInviteRepository.connectsImmediately]
/// 가 `false`)이라 별도 위젯으로 뺀다. 데모는 이 provider 를 구독조차 하지
/// 않는다.
class _PendingInvitesList extends ConsumerWidget {
  const _PendingInvitesList({required this.busy, required this.onCancel});

  final bool busy;
  final ValueChanged<ClientInvite> onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final pending = ref.watch(pendingClientInvitesProvider);
    return pending.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(
        l.clientInviteFailed,
        style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
      ),
      data: (rows) => rows.isEmpty
          ? Text(
              l.clientInvitePendingEmpty,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            )
          : Column(
              children: <Widget>[
                for (final invite in rows)
                  _PendingInviteRow(
                    invite: invite,
                    onCancel: busy ? null : () => onCancel(invite),
                  ),
              ],
            ),
    );
  }
}

/// 찾은 회원 한 명. 연결할 수 없는 상태면 그 이유가 이름 아래에 남는다.
///
/// 실 API 는 이름 이외의 인적 사항(이메일 등)을 주지 않는다 — 담당이 성립하기
/// 전에는 최소 식별 정보만으로 충분하다. 데모는 [MemberLookup.gender]·
/// [MemberLookup.age]·[MemberLookup.goal] 을 함께 주므로, 있으면 여기서
/// 보여준다 — "이 고객이 맞나요?" 확인이 이름 하나로는 부족하다.
class _FoundMemberCard extends StatelessWidget {
  const _FoundMemberCard({required this.found});

  final MemberLookup found;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String? blocked = switch (found) {
      MemberLookup(coachedByMe: true) => l.clientInviteAlreadyCoached,
      MemberLookup(hasTrainer: true) => l.clientInviteHasTrainer,
      MemberLookup(invitePending: true) => l.clientInvitePendingHint,
      _ => null,
    };
    final bool korean = Localizations.localeOf(context).languageCode == 'ko';
    String? demographics;
    if (found.gender case final String gender when found.age != null) {
      final String genderLabel = switch (gender) {
        'female' => korean ? '여성' : 'Female',
        'male' => korean ? '남성' : 'Male',
        _ => korean ? '기타' : 'Other',
      };
      demographics = korean
          ? '$genderLabel · ${found.age}세'
          : '$genderLabel · Age ${found.age}';
    }
    final String initial = found.name.isEmpty
        ? '?'
        : String.fromCharCode(found.name.runes.first);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClientAvatar(label: initial, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        found.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    if (demographics != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          demographics,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subtleForeground,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (found.goal case final String goal
                    when goal.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    goal,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.subtleForeground,
                    ),
                  ),
                ],
                if (blocked != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    blocked,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 답을 기다리는 요청 한 줄.
class _PendingInviteRow extends StatelessWidget {
  const _PendingInviteRow({required this.invite, this.onCancel});

  final ClientInvite invite;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              invite.memberName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: Text(l.clientInviteCancelAction),
          ),
        ],
      ),
    );
  }
}
