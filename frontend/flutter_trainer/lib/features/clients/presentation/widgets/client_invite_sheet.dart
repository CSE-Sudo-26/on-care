import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/features/clients/data/repositories/client_invite_repository.dart';
import 'package:oncare_trainer/features/clients/domain/entities/client_invite.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';

/// 회원에게 담당 요청을 보내는 시트. (#919)
///
/// 두 단계다 — 이메일로 **찾고**, 찾은 사람에게 **보낸다**. 한 번에 보내지 않는
/// 이유는 오타 한 글자가 다른 사람에게 가는 요청이 되기 때문이다. 이름을 눈으로
/// 확인하고 나서 누르게 한다.
///
/// 이메일 완전 일치만 되는 것도 의도다. 이름으로 훑을 수 있으면 담당도 아닌
/// 사람들의 존재가 트레이너에게 드러난다.
///
/// 시트 아래쪽에는 **답을 기다리는 요청**을 함께 둔다. 보낸 요청은 고객 목록에
/// 나타나지 않으므로(수락 전이라 담당이 아니다), 여기가 아니면 트레이너는 자기가
/// 무엇을 보냈는지 볼 곳이 없다.
class ClientInviteSheet extends ConsumerStatefulWidget {
  const ClientInviteSheet({super.key});

  @override
  ConsumerState<ClientInviteSheet> createState() => _ClientInviteSheetState();
}

class _ClientInviteSheetState extends ConsumerState<ClientInviteSheet> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _message = TextEditingController();

  MemberLookup? _found;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (_busy) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = l.clientInviteEmailRequired;
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
          .lookup(email);
      if (!mounted) return;
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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(clientInviteRepositoryProvider)
          .invite(found.memberId, message: _message.text);
      ref.invalidate(pendingClientInvitesProvider);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l.clientInviteSent(found.name))),
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
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(clientInviteRepositoryProvider).cancel(invite.id);
      ref.invalidate(pendingClientInvitesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.clientInviteCancelled)));
    } on AppError catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            serverDetailOr(l, error.message, l.clientInviteCancelFailed),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final pending = ref.watch(pendingClientInvitesProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l.clientInviteTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // 수락해야 고객이 된다는 것을 시트가 먼저 말한다 — 보낸 뒤 명단을
            // 새로고침하며 기다리는 일이 없도록.
            Text(
              l.clientInviteIntro,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('client-invite-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onSubmitted: (_) => _lookup(),
                    decoration: InputDecoration(
                      labelText: l.clientInviteEmailLabel,
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: ActionButton(
                    label: l.clientInviteLookupAction,
                    icon: Icons.search,
                    onPressed: _busy ? null : _lookup,
                  ),
                ),
              ],
            ),
            if (_found case final MemberLookup found) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _FoundMemberCard(found: found),
              if (found.canInvite) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
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
                ActionButton(
                  label: l.clientInviteSendAction,
                  icon: Icons.send,
                  primary: true,
                  onPressed: _busy ? null : _send,
                ),
              ],
            ],
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
            pending.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(
                l.clientInviteFailed,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
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
                            onCancel: _busy ? null : () => _cancel(invite),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 찾은 회원 한 명. 보낼 수 없는 상태면 그 이유가 이름 아래에 남는다.
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            found.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          Text(
            found.email,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          if (blocked != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              blocked,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  invite.memberName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  invite.memberEmail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
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
