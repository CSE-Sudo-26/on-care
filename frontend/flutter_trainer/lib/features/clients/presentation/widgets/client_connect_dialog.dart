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
import 'package:oncare_trainer/features/clients/presentation/widgets/pairing_code_input.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/app_toast.dart';
import 'package:oncare_trainer/shared/widgets/client_avatar.dart';

/// 회원이 자기 앱에 띄운 6자리 동기화 코드로 연결하는 신규 고객 등록 창.
/// (#919·#1634)
///
/// 예전에는 회원 ID(`User.id`)를 완전 일치로 받았다. `user-<12자리 hex>` 는
/// 마주 앉아 불러 주거나 받아 적을 수 있는 형태가 아니었다.
///
/// **한 번에 연결된다.** 코드를 발급해 불러 준 것이 회원 본인이고 그 화면이
/// 공유 범위를 말한다 — 이미 받은 동의를 한 번 더 받을 이유가 없다. 여섯
/// 자리를 잘못 눌러도 100만분의 1 로 남에게 닿을 뿐이고, 연결된 뒤 결과
/// 카드의 이름·성별·나이·목표로 곧바로 알아볼 수 있다.
///
/// 성별·나이·신체 정보는 여기서 입력받지 않는다 — 연결되면 회원이 이미 자기
/// 앱에 등록해 둔 값을 그대로 쓴다.
///
/// 창 아래쪽의 **답을 기다리는 요청**은 옛 담당 요청 경로가 남긴 것이다. 보낸
/// 요청은 고객 목록에 나타나지 않으므로, 여기가 아니면 트레이너는 자기가
/// 무엇을 보냈는지 볼 곳이 없다. 데모에는 기다릴 답이 없어 그 목록이 없다
/// ([connectsImmediately]).
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
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  /// 연결이 끝난 회원. 결과 카드가 이 값을 보여 준다.
  PairedMember? _paired;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 창이 열리면 바로 칠 수 있어야 한다 — 회원이 코드를 불러 주고 있는 자리다.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _codeFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  /// 여섯 자리가 다 차면 곧바로 보낸다 — 따로 누를 버튼을 두지 않는다.
  void _onCodeChanged(String value) {
    if (_error != null) setState(() => _error = null);
    if (value.length == PairingCodeInput.length) _connect();
  }

  Future<void> _connect() async {
    if (_busy) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final String code = _code.text.trim();
    if (code.length != PairingCodeInput.length) {
      setState(() => _error = l.clientConnectCodeRequired);
      return;
    }
    final repository = ref.read(clientInviteRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final paired = await repository.redeemPairingCode(code);
      ref.invalidate(pendingClientInvitesProvider);
      // 데모(즉시 연결)와 실 API 모두 고객 탭과 고객 관리가 같은 목록을 보므로
      // 두 provider 를 함께 새로고침한다.
      ref.invalidate(clientsProvider);
      ref.invalidate(managedClientsProvider);
      // 미등록 동안 걸러졌던 오늘 일정·안읽음 배지도 다시 보인다(#1623).
      invalidateClientVisibilityDependentViews(ref);
      if (!mounted) return;
      // 창을 곧바로 닫지 않는다 — 여섯 자리를 잘못 눌렀다면 여기서
      // 이름·성별·나이·목표로 알아봐야 한다. 닫는 것은 트레이너가 정한다.
      setState(() => _paired = paired);
    } on NotFoundError {
      if (!mounted) return;
      setState(() => _error = l.clientConnectCodeInvalid);
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

  /// 결과를 확인했다 — 창을 닫는다.
  void _done(PairedMember paired) {
    final AppLocalizations l = AppLocalizations.of(context);
    Navigator.of(context).pop();
    showAppToast(
      context,
      l.clientInviteConnected(paired.name),
      kind: AppToastKind.success,
    );
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
                  l.clientConnectCodeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PairingCodeInput(
                  controller: _code,
                  focusNode: _codeFocus,
                  enabled: !_busy && _paired == null,
                  onChanged: _onCodeChanged,
                ),
                if (_error case final String error) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.destructive,
                    ),
                  ),
                ],
                if (_busy) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
                if (_paired case final PairedMember paired) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _PairedMemberCard(paired: paired),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      key: const ValueKey<String>('client-connect-done'),
                      onPressed: () => _done(paired),
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(AppRadius.md),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(l.clientConnectDone),
                    ),
                  ),
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

/// 방금 연결된 회원 — 아바타·이름·성별/나이·목표. (#1634)
///
/// 코드를 발급해 불러 준 것이 회원 본인이라 신원 확인은 이미 끝났다. 그래도
/// 이름만 보여 주지 않는 것은, 트레이너가 여섯 자리를 잘못 눌렀을 때 **연결된
/// 뒤에라도** 그 사실을 알아볼 수 있어야 하기 때문이다.
///
/// 여기 있는 값은 모두 회원이 자기 앱에 등록해 둔 것이다 — 트레이너가 지금
/// 입력하는 값이 아니다. 키·몸무게·질환은 고객 상세의 건강 프로필에서 본다.
class _PairedMemberCard extends StatelessWidget {
  const _PairedMemberCard({required this.paired});

  final PairedMember paired;

  @override
  Widget build(BuildContext context) {
    final bool korean = Localizations.localeOf(context).languageCode == 'ko';
    String? demographics;
    if (paired.gender.isNotEmpty && paired.age != null) {
      final String genderLabel = switch (paired.gender) {
        'female' => korean ? '여성' : 'Female',
        'male' => korean ? '남성' : 'Male',
        _ => korean ? '기타' : 'Other',
      };
      demographics = korean
          ? '$genderLabel · ${paired.age}세'
          : '$genderLabel · Age ${paired.age}';
    }
    final String initial = paired.name.isEmpty
        ? '?'
        : String.fromCharCode(paired.name.runes.first);

    return Container(
      key: const ValueKey<String>('client-connect-result'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.primary),
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
                        paired.name,
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
                if (paired.goal.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    paired.goal,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.subtleForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: AppColors.primary,
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
