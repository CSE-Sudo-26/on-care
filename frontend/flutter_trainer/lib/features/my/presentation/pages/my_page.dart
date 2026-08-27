import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare_trainer/app/router/routes.dart';
// Session은 앱 전역 상태라 예외적으로 auth feature 의 provider 를 직접
// 사용한다 (라우터의 인증 게이트와 동일한 소비자). TODO: 실 백엔드
// 도입 시 세션 계층을 core/session 으로 승격해 이 의존을 정리한다.
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/core/utils/server_message.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/design_system/tokens/toast.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare_trainer/features/my/data/trainer_account_repository.dart';
import 'package:oncare_trainer/features/my/data/trainer_profile_repository.dart';
import 'package:oncare_trainer/features/my/data/trainer_settings.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';
import 'package:oncare_trainer/shared/models/trainer_client.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/app_toast.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/shared/widgets/status_dot_label.dart';

/// 내 정보 / 설정 — reached from the sidebar footer, not the nav list.
///
/// It is not a navigation destination on purpose: a trainer opens this
/// a few times a month, and giving it a nav row would put it beside the
/// five surfaces they use every day. Two sections behind one switch:
///
///  * **내 정보** — profile, certifications, this month's stats, gym.
///    Edits persist through `PUT /v1/trainer/me` and the gym affiliation
///    endpoints; mock mode follows the same repository contract (#477, #452).
///    이름·이메일 입력은 비활성이다 — 값이 없어서가 아니라 **계정 소관**이라
///    여기서 바꾸지 않는다.
///  * **설정** — 알림 수신 설정은 `GET/PUT /v1/trainer/me/settings`(#379),
///    비밀번호 변경은 `POST /v1/trainer/me/password` 로 서버에 저장된다.
///    비밀번호 변경만 **데모에서 비활성**이고(바꿀 계정이 없다) 그 사유를 함께
///    보여 준다 — 미구현이 아니라 그 빌드에서만 막히는 것이다.
///    앱 정보(서비스·버전·문의)는 표시 전용이다.
///
/// The Figma mock's "역할 전환" section is intentionally omitted — the
/// trainer and member apps use fully separate accounts (CLAUDE.local.md).
class MyPage extends ConsumerStatefulWidget {
  /// Creates the page. [tab] is `profile` (default) or `settings`.
  const MyPage({super.key, this.tab});

  /// Active section, from the `t` query parameter.
  final String? tab;

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  /// 0 = 내 정보, 1 = 설정.
  late int _tab = widget.tab == 'settings' ? 1 : 0;

  bool _editing = false;
  bool _saving = false;
  bool _saveFlash = false;
  final Set<String> _removingClients = <String>{};
  Timer? _flashTimer;

  // The "saved" profile (in-memory mock; starts from the seed/session).
  late TrainerProfile _profile;
  late TrainerGym _gym;
  late List<String> _certs;

  // Edit drafts.
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};
  final TextEditingController _newCert = TextEditingController();
  late List<String> _draftCerts;
  late String _draftGymId;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionControllerProvider);
    _profile = session.profile ?? seedTrainerProfile;
    _gym = _profile.gym;
    _certs = List<String>.of(_profile.certifications);
    _draftCerts = List<String>.of(_certs);
    _draftGymId = _gym.id ?? '';
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    for (final c in _fields.values) {
      c.dispose();
    }
    _newCert.dispose();
    super.dispose();
  }

  TextEditingController _field(String key, String initial) {
    return _fields.putIfAbsent(key, () => TextEditingController(text: initial));
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _draftCerts = List<String>.of(_certs);
      _draftGymId = _gym.id ?? '';
      _field('name', _profile.name).text = _profile.name;
      _field('email', _profile.email).text = _profile.email;
      _field('phone', _profile.phone).text = _profile.phone;
      _field('specialty', _profile.specialty).text = _profile.specialty;
      _field('career', _profile.career).text = _profile.career;
      _field('intro', _profile.intro).text = _profile.intro;
      _field('gymName', _gym.name).text = _gym.name;
      _field('gymAddress', _gym.address).text = _gym.address;
      _field('gymHours', _gym.hours).text = _gym.hours;
      _field('gymPhone', _gym.phone).text = _gym.phone;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    // 숫자만 읽는다. 전에는 한국어 '년' 접미사를 정규식에 박아 뒀는데, 영어
    // 로케일에서 "7 years" 를 입력하면 매칭에 실패했다. (#501)
    final careerMatch = RegExp(
      r'^\s*(\d+)\s*\S*\s*$',
    ).firstMatch(_fields['career']!.text);
    final careerYears = int.tryParse(careerMatch?.group(1) ?? '');
    if (careerYears == null || careerYears < 0 || careerYears > 80) {
      final AppLocalizations l = AppLocalizations.of(context);
      showAppToast(context, l.myCareerInvalid);
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(trainerProfileRepositoryProvider);
    var profileSaved = false;
    try {
      final draftGymId = _draftGymId.trim();
      final currentGymId = _gym.id ?? '';
      var saved = await repository.update(
        TrainerProfileUpdate(
          phone: _fields['phone']!.text.trim(),
          specialty: _fields['specialty']!.text.trim(),
          careerYears: careerYears,
          intro: _fields['intro']!.text.trim(),
          certifications: List<String>.of(_draftCerts),
          // Affiliated gym text is derived by the server. Legacy profiles
          // without a place id retain the original editable text contract.
          gymName: currentGymId.isEmpty && draftGymId.isEmpty
              ? _fields['gymName']!.text.trim()
              : null,
          gymAddress: currentGymId.isEmpty && draftGymId.isEmpty
              ? _fields['gymAddress']!.text.trim()
              : null,
          gymHours: currentGymId.isEmpty && draftGymId.isEmpty
              ? _fields['gymHours']!.text.trim()
              : null,
          gymPhone: currentGymId.isEmpty && draftGymId.isEmpty
              ? _fields['gymPhone']!.text.trim()
              : null,
        ),
      );
      profileSaved = true;
      if (draftGymId != currentGymId) {
        saved = draftGymId.isEmpty
            ? await repository.clearGym()
            : await repository.setGym(draftGymId);
      }
      if (!mounted) return;
      _applySavedProfile(saved);
    } catch (error) {
      TrainerProfile? restored;
      try {
        restored = await repository.fetch();
      } catch (_) {
        restored = ref.read(sessionControllerProvider).profile;
      }
      if (!mounted) return;
      if (restored != null) _applyRestoredProfile(restored);
      setState(() => _saving = false);
      final message = _saveFailureMessage(error, profileSaved: profileSaved);
      showAppToast(context, message, kind: AppToastKind.error);
      return;
    }

    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saveFlash = false);
    });
  }

  String _saveFailureMessage(Object error, {required bool profileSaved}) {
    final AppLocalizations l = AppLocalizations.of(context);
    final detail = error is AppError ? error.message : null;
    if (profileSaved) {
      final localizedDetail = serverDetailOr(l, detail, '');
      return localizedDetail.isEmpty
          ? l.myGymChangeFailed
          : '${l.myGymChangeFailed} $localizedDetail';
    }
    return serverDetailOr(l, detail, l.myProfileSaveFailed);
  }

  void _applySavedProfile(TrainerProfile saved) {
    ref.read(sessionControllerProvider.notifier).replaceProfile(saved);
    setState(() {
      _profile = saved;
      _gym = saved.gym;
      _certs = List<String>.of(saved.certifications);
      _draftCerts = List<String>.of(_certs);
      _draftGymId = saved.gym.id ?? '';
      _editing = false;
      _saving = false;
      _saveFlash = true;
      _newCert.clear();
    });
  }

  void _applyRestoredProfile(TrainerProfile restored) {
    ref.read(sessionControllerProvider.notifier).replaceProfile(restored);
    setState(() {
      _profile = restored;
      _gym = restored.gym;
      _certs = List<String>.of(restored.certifications);
      _draftCerts = List<String>.of(_certs);
      _draftGymId = restored.gym.id ?? '';
      _editing = false;
    });
  }

  Future<void> _signOut() async {
    // The router's auth gate redirects to the login screen.
    await ref.read(sessionControllerProvider.notifier).signOut();
  }

  Future<void> _removeClient(TrainerClient client) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.myClientRemoveTitle(client.name)),
        content: Text(l.myClientRemoveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.myClientRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removingClients.add(client.id));
    try {
      await ref.read(clientRepositoryProvider).removeClient(client.id);
      ref.invalidate(clientsProvider);
      ref.invalidate(managedClientsProvider);
      if (!mounted) return;
      showAppToast(context, l.myClientRemoveSuccess);
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, l.myClientRemoveFailed, kind: AppToastKind.error);
    } finally {
      if (mounted) setState(() => _removingClients.remove(client.id));
    }
  }

  Future<void> _restoreClient(TrainerClient client) async {
    final l = AppLocalizations.of(context);
    setState(() => _removingClients.add(client.id));
    try {
      await ref.read(clientRepositoryProvider).restoreClient(client.id);
      ref.invalidate(clientsProvider);
      ref.invalidate(managedClientsProvider);
      if (!mounted) return;
      showAppToast(context, l.myClientRestoreSuccess);
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, l.myClientRestoreFailed, kind: AppToastKind.error);
    } finally {
      if (mounted) setState(() => _removingClients.remove(client.id));
    }
  }

  /// 계정 탈퇴. 이름 확인을 받은 뒤에만 나가고, 성공하면 로그아웃과 같은 경로로
  /// 로그인 화면에 도달한다(라우터의 인증 게이트). (#505)
  Future<void> _deleteAccount() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(name: _profile.name),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(trainerAccountRepositoryProvider).deleteAccount();
    } on AppError catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        serverDetailOr(l, e.message, l.myDeleteFailed),
        kind: AppToastKind.error,
      );
      return;
    }
    // 계정이 사라졌으므로 남은 토큰은 무효다 — 세션을 비워 인증 게이트가
    // 로그인 화면으로 돌려보내게 한다.
    await ref.read(sessionControllerProvider.notifier).signOut();
  }

  @override
  void didUpdateWidget(MyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab) {
      setState(() => _tab = widget.tab == 'settings' ? 1 : 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final managingClients = widget.tab == 'clients';
    return PageScaffold(
      title: managingClients
          ? l.myClientManagement
          : _tab == 0
          ? l.myTabProfile
          : l.myTabSettings,
      subtitle: _profile.name,
      maxWidth: AppLayout.contentMaxWidth,
      actions: <Widget>[
        if (managingClients)
          ActionButton(
            label: l.clientBackToList,
            icon: Icons.arrow_back,
            onPressed: () => context.go(AppRoutes.mySection('profile')),
          )
        else
          SegmentedSwitch(
            labels: <String>[l.myTabProfile, l.myTabSettings],
            selected: _tab,
            onChanged: (i) {
              setState(() => _tab = i);
              context.go(AppRoutes.mySection(i == 0 ? 'profile' : 'settings'));
            },
          ),
        if (!managingClients && _tab == 0)
          if (_editing)
            ActionButton(
              label: _saving ? l.mySaving : l.actionSave,
              icon: _saving ? Icons.hourglass_top : Icons.check,
              primary: true,
              onPressed: _saving ? null : _save,
            )
          else
            ActionButton(
              label: l.myEditProfile,
              icon: Icons.edit_outlined,
              onPressed: _saving ? null : _startEdit,
            ),
      ],
      child: managingClients
          ? _buildClientManagement()
          : _tab == 0
          ? _buildProfile()
          : _buildSettings(),
    );
  }

  Widget _buildProfile() {
    final AppLocalizations l = AppLocalizations.of(context);
    final clientCount = ref.watch(clientsProvider).valueOrNull?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_editing) ...<Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: _ChipButton(
              label: l.actionCancel,
              background: AppColors.inputBackground,
              foreground: AppColors.subtleForeground,
              onTap: _saving
                  ? null
                  : () => setState(() {
                      _editing = false;
                      // Drop the un-added cert draft too — otherwise it
                      // reappears on the next edit (PR review).
                      _newCert.clear();
                    }),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (_saveFlash) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(AppRadius.card),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              l.mySaved,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _ProfileCard(profile: _profile, editing: _editing, field: _field),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel(l.myCertifications),
        const SizedBox(height: AppSpacing.sm),
        _CertsCard(
          certs: _editing ? _draftCerts : _certs,
          editing: _editing,
          newCert: _newCert,
          onAdd: () {
            final v = _newCert.text.trim();
            if (v.isEmpty) return;
            setState(() {
              _draftCerts.add(v);
              _newCert.clear();
            });
          },
          onRemove: (i) => setState(() => _draftCerts.removeAt(i)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel(l.myMonthStats),
        const SizedBox(height: AppSpacing.sm),
        _StatsCard(clientCount: clientCount),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel(l.myGym),
        const SizedBox(height: AppSpacing.sm),
        _GymCard(
          gym: _gym,
          editing: _editing,
          field: _field,
          choices: ref.watch(trainerGymChoicesProvider),
          selectedGymId: _draftGymId,
          onGymChanged: (value) => setState(() => _draftGymId = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ClientManagementEntry(
          onTap: () => context.go(AppRoutes.mySection('clients')),
        ),
      ],
    );
  }

  Widget _buildClientManagement() => _ClientManagementCard(
    clients: ref.watch(managedClientsProvider),
    removing: _removingClients,
    onRemove: _removeClient,
    onRestore: _restoreClient,
  );

  /// Applies a settings change and tells the trainer if it didn't stick.
  ///
  /// The switch flips immediately (waiting on a round trip feels broken),
  /// so a failed write has to be visible — otherwise the screen shows a
  /// value the server never accepted.
  Future<void> _applySetting(Future<void> Function() change) async {
    await change();
    if (!mounted) return;
    final controller = ref.read(trainerSettingsProvider.notifier);
    if (controller.lastError) {
      controller.clearError();
      showAppToast(
        context,
        AppLocalizations.of(context).mySettingsSaveFailed,
        kind: AppToastKind.error,
      );
    }
  }

  Widget _buildSettings() {
    final AppLocalizations l = AppLocalizations.of(context);
    final settings = ref.watch(trainerSettingsProvider);
    final controller = ref.read(trainerSettingsProvider.notifier);
    final account = ref.watch(trainerAccountRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: l.myNotifications,
          icon: Icons.notifications_none,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SwitchRow(
                label: l.myNotifNewMessage,
                hint: l.myNotifNewMessageHint,
                value: settings.newMessageAlerts,
                onChanged: (v) =>
                    _applySetting(() => controller.setNewMessageAlerts(v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 약관은 계정 카드보다 위에 둔다 — 로그아웃·탈퇴 옆에 붙이면 읽는
        // 문서가 되돌릴 수 없는 동작과 같은 무게로 보인다. (#968)
        SectionCard(
          title: l.myLegal,
          icon: Icons.gavel_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _LegalRow(
                icon: Icons.description_outlined,
                label: l.myLegalTermsTitle,
                hint: l.myLegalTermsHint,
                document: AppRoutes.legalTerms,
              ),
              const Divider(height: 1, color: AppColors.borderStrong),
              _LegalRow(
                icon: Icons.privacy_tip_outlined,
                label: l.myLegalPrivacyTitle,
                hint: l.myLegalPrivacyHint,
                document: AppRoutes.legalPrivacy,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l.myAccount,
          icon: Icons.lock_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l.myChangePassword,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        Text(
                          account.supportsPasswordChange
                              ? l.myChangePasswordHint
                              : l.myChangePasswordDemo,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.disabledForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ActionButton(
                    label: l.actionChange,
                    icon: Icons.key_outlined,
                    onPressed: account.supportsPasswordChange
                        ? _openPasswordSheet
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.borderStrong),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(label: l.myLoginAccount, value: _profile.email),
              const SizedBox(height: AppSpacing.md),
              // 역할 전환 대신 로그아웃만 둔다 (계정 기반 분리).
              _LogoutButton(onTap: _signOut),
              const SizedBox(height: AppSpacing.md),
              // 탈퇴는 로그아웃 아래, 더 조용한 문구로 둔다 — 매일 쓰는 동작
              // 옆에 같은 무게로 놓으면 잘못 누르기 쉽다. (#505)
              _DeleteAccountRow(
                enabled: account.supportsDeletion,
                onTap: _deleteAccount,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l.myAppInfo,
          icon: Icons.info_outline,
          child: Column(
            children: <Widget>[
              _InfoRow(label: l.myService, value: l.appTitle),
              _InfoRow(label: l.myVersion, value: '0.1.0'),
              _InfoRow(label: l.myContact, value: seedTrainerProfile.email),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.subtleForeground,
      ),
    );
  }

  Future<void> _openPasswordSheet() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.card),
      ),
      // 상단 토스트가 이 시트 위로 겹쳐 뜰 수 있다 — 화면 꼭대기까지
      // 올라오지 않게 남길 최소 높이를 [AppToastStyle.dialogTopClearance]
      // 로 잡는다.
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height -
            AppToastStyle.dialogTopClearance,
      ),
      builder: (context) => const _PasswordSheet(),
    );
    if (changed == true && mounted) {
      final AppLocalizations l = AppLocalizations.of(context);
      showAppToast(context, l.myPasswordChanged, kind: AppToastKind.success);
    }
  }
}

/// 약관·개인정보 처리방침 한 줄. 문서는 셸 밖의 `/legal/<문서>` 라우트가
/// 그리므로 push 로 열고, 뒤로 누르면 이 화면으로 돌아온다. (#968)
class _LegalRow extends StatelessWidget {
  const _LegalRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.document,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String document;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.legalDocument(document)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.mutedForeground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.disabledForeground,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.disabledForeground,
            ),
          ],
        ),
      ),
    );
  }
}

/// 계정 탈퇴 진입점. 되돌릴 수 없는 동작이라 이름을 그대로 입력받는다.
///
/// 확인 다이얼로그의 예/아니오만으로는 실수를 거르지 못한다 — 담당 회원 링크와
/// 예약이 함께 사라지고, 회원에게는 알림이 간다. (#505)
class _DeleteAccountRow extends StatelessWidget {
  const _DeleteAccountRow({required this.enabled, required this.onTap});

  final bool enabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l.myDeleteAccount,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
              Text(
                enabled ? l.myDeleteHint : l.myDeleteDemo,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.disabledForeground,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          key: const ValueKey<String>('delete-account'),
          onPressed: enabled ? onTap : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
          child: Text(
            l.myDeleteAction,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// 탈퇴 확인 — 트레이너 이름을 그대로 입력해야 진행된다.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.name});

  final String name;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _input = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final next = _input.text.trim() == widget.name.trim();
      if (next != _matches) setState(() => _matches = next);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.myDeleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.myDeleteBody, style: const TextStyle(fontSize: 13.5)),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.myDeleteConfirmPrompt(widget.name),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            key: const ValueKey<String>('delete-account-confirm'),
            controller: _input,
            autofocus: true,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          key: const ValueKey<String>('delete-account-submit'),
          // 이름이 맞아야 눌린다 — 확인 절차가 형식만 남지 않도록.
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            l.myDeleteAction,
            style: const TextStyle(color: AppColors.destructive),
          ),
        ),
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: const BorderRadius.all(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.editing,
    required this.field,
  });

  final TrainerProfile profile;
  final bool editing;
  final TextEditingController Function(String, String) field;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(
          color: editing
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              // 사용자 앱 MY 프로필과 동일한 이니셜 원형 아바타(블루 그라데이션).
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[AppColors.primary, AppColors.secondary],
                  ),
                  border: Border.all(color: AppColors.primary, width: 2.5),
                ),
                child: Text(
                  profile.name.isNotEmpty ? profile.name.substring(0, 1) : '·',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      profile.email,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtleForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        _Tag(text: profile.specialty, color: AppColors.primary),
                        _Tag(
                          text: l.myCareerYears(profile.career),
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (editing) ...<Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1, color: AppColors.borderStrong),
            ),
            _EditField(
              label: l.myFieldName,
              controller: field('name', profile.name),
              enabled: false,
            ),
            _EditField(
              label: l.myFieldEmail,
              controller: field('email', profile.email),
              enabled: false,
            ),
            _EditField(
              label: l.myFieldPhone,
              controller: field('phone', profile.phone),
              inputKey: const ValueKey<String>('profile-phone'),
            ),
            _EditField(
              label: l.myFieldSpecialty,
              controller: field('specialty', profile.specialty),
            ),
            _EditField(
              label: l.myFieldCareer,
              controller: field('career', profile.career),
              inputKey: const ValueKey<String>('profile-career'),
            ),
            _EditField(
              label: l.myFieldIntro,
              controller: field('intro', profile.intro),
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.enabled = true,
    this.inputKey,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final bool enabled;
  final Key? inputKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: 3),
          TextField(
            key: inputKey,
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
            decoration: const InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertsCard extends StatelessWidget {
  const _CertsCard({
    required this.certs,
    required this.editing,
    required this.newCert,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> certs;
  final bool editing;
  final TextEditingController newCert;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < certs.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i < certs.length - 1 || editing ? AppSpacing.sm : 0,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.accentSurface,
                      borderRadius: BorderRadius.all(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      certs[i],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  if (editing)
                    // `GestureDetector` 는 버튼으로 인식되지 않고, 안에 있는
                    // 것은 X 아이콘 하나뿐이라 무엇을 지우는지 말할 데가
                    // 없다(#972).
                    Semantics(
                      button: true,
                      label: l.a11yRemoveCertification,
                      child: GestureDetector(
                        onTap: () => onRemove(i),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.subtleForeground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (editing)
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: newCert,
                    decoration: InputDecoration(
                      hintText: l.myAddCertification,
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ChipButton(
                  label: l.myAdd,
                  background: AppColors.primary,
                  foreground: AppColors.primaryForeground,
                  onTap: onAdd,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ClientManagementEntry extends StatelessWidget {
  const _ClientManagementEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: const BorderRadius.all(AppRadius.card),
        onTap: onTap,
        child: SectionCard(
          title: l.myClientManagement,
          icon: Icons.manage_accounts_outlined,
          trailing: const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.disabledForeground,
          ),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ClientManagementCard extends StatelessWidget {
  const _ClientManagementCard({
    required this.clients,
    required this.removing,
    required this.onRemove,
    required this.onRestore,
  });

  final AsyncValue<List<TrainerClient>> clients;
  final Set<String> removing;
  final ValueChanged<TrainerClient> onRemove;
  final ValueChanged<TrainerClient> onRestore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SectionCard(
      title: l.myStatClients,
      icon: Icons.manage_accounts_outlined,
      child: clients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Text(l.clientsLoadFailed),
        data: (allItems) {
          final items = allItems;
          if (items.isEmpty) return Text(l.myClientManagementEmpty);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < items.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(height: 1, color: AppColors.borderStrong),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(items[i].avatar)),
                  title: Text(items[i].name),
                  subtitle: Text(
                    '${items[i].registered ? l.myClientRegistered : l.myClientUnregistered} · ${items[i].goal}',
                  ),
                  trailing: Tooltip(
                    message: items[i].registered
                        ? l.myClientRemove
                        : l.myClientRestore,
                    child: TextButton(
                      onPressed: removing.contains(items[i].id)
                          ? null
                          : () => items[i].registered
                                ? onRemove(items[i])
                                : onRestore(items[i]),
                      child: removing.contains(items[i].id)
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              items[i].registered
                                  ? l.myClientRemove
                                  : l.myClientRestore,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// "이번 달 통계" — 남색 그라데이션 블록. 담당 고객(live count) /
/// 완료 세션 / 루틴 전송 (mock figures from the Figma).
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.clientCount});

  final int clientCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.bannerStart, AppColors.bannerEnd],
        ),
        borderRadius: const BorderRadius.all(AppRadius.card),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: <Widget>[
          _Stat(
            icon: Icons.people_alt_outlined,
            value: '$clientCount',
            unit: l.dashUnitPeople,
            label: l.myStatClients,
          ),
          _Stat(
            icon: Icons.check_circle_outline_rounded,
            value: '24',
            unit: l.unitTimes,
            label: l.myStatSessionsDone,
          ),
          _Stat(
            icon: Icons.send_rounded,
            value: '18',
            unit: l.dashUnitCount,
            label: l.myStatRoutinesSent,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.secondary,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({
    required this.gym,
    required this.editing,
    required this.field,
    required this.choices,
    required this.selectedGymId,
    required this.onGymChanged,
  });

  final TrainerGym gym;
  final bool editing;
  final TextEditingController Function(String, String) field;
  final AsyncValue<List<TrainerGymChoice>> choices;
  final String selectedGymId;
  final ValueChanged<String> onGymChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(AppRadius.card),
        boxShadow: kCardShadow,
        border: Border.all(
          color: editing
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: editing
          ? Column(
              children: <Widget>[
                _GymChoiceField(
                  currentGym: gym,
                  choices: choices,
                  selectedGymId: selectedGymId,
                  onChanged: onGymChanged,
                ),
                _EditField(
                  label: l.myGymName,
                  controller: field('gymName', gym.name),
                  enabled: selectedGymId.isEmpty,
                ),
                _EditField(
                  label: l.myGymAddress,
                  controller: field('gymAddress', gym.address),
                  enabled: selectedGymId.isEmpty,
                ),
                _EditField(
                  label: l.myGymHours,
                  controller: field('gymHours', gym.hours),
                  enabled: selectedGymId.isEmpty,
                ),
                _EditField(
                  label: l.myFieldPhone,
                  controller: field('gymPhone', gym.phone),
                  enabled: selectedGymId.isEmpty,
                ),
              ],
            )
          : Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.accentSurface,
                        borderRadius: BorderRadius.all(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.home_outlined,
                        size: 17,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            gym.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                          Text(
                            gym.address,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.subtleForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusDotLabel(
                      label: l.myGymOpen,
                      color: AppColors.success,
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Divider(height: 1, color: AppColors.borderStrong),
                ),
                Row(
                  children: <Widget>[
                    _GymDetail(label: l.myGymHours, value: gym.hours),
                    _GymDetail(label: l.myFieldPhone, value: gym.phone),
                  ],
                ),
              ],
            ),
    );
  }
}

class _GymChoiceField extends StatelessWidget {
  const _GymChoiceField({
    required this.currentGym,
    required this.choices,
    required this.selectedGymId,
    required this.onChanged,
  });

  final TrainerGym currentGym;
  final AsyncValue<List<TrainerGymChoice>> choices;
  final String selectedGymId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.myGym,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: 3),
          choices.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => Text(
              l.myGymListFailed,
              style: const TextStyle(
                color: AppColors.destructive,
                fontSize: 12,
              ),
            ),
            data: (items) {
              final currentId = selectedGymId;
              final hasCurrent =
                  currentId.isEmpty ||
                  items.any((choice) => choice.id == currentId);
              return DropdownButtonFormField<String>(
                key: ValueKey<String>(currentId),
                initialValue: currentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: '', child: Text(l.myNoGym)),
                  if (!hasCurrent)
                    DropdownMenuItem<String>(
                      value: currentId,
                      child: Text(currentGym.name),
                    ),
                  for (final choice in items)
                    DropdownMenuItem<String>(
                      value: choice.id,
                      child: Text(
                        choice.address.isEmpty
                            ? choice.name
                            : '${choice.name} · ${choice.address}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => onChanged(value ?? ''),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GymDetail extends StatelessWidget {
  const _GymDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Material(
      color: AppColors.card,
      borderRadius: const BorderRadius.all(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(AppRadius.card),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.logout, size: 16, color: AppColors.destructive),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l.mySignOut,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.destructive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One notification preference. The switch writes through immediately —
/// there is no save button, because a settings screen with unsaved state
/// is a settings screen people leave half-applied.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.disabledForeground,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Which box a password-sheet validation message belongs under.
enum _PasswordField {
  /// 현재 비밀번호.
  current,

  /// 새 비밀번호.
  next,

  /// 새 비밀번호 확인.
  confirm,
}

/// Bottom sheet for changing the password.
///
/// Asks for the current password as well: a stolen token should not be
/// enough to take the account over.
class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  /// Which field [_error] belongs to. Showing every message under 현재
  /// 비밀번호 sent people to fix the wrong box.
  _PasswordField? _errorField;

  /// Matches the server's `TrainerPasswordChange.new_password` minimum —
  /// checking here too saves a round trip and a confusing 400.
  static const int _minLength = 8;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final current = _current.text;
    final next = _next.text;
    if (current.isEmpty) {
      final AppLocalizations l = AppLocalizations.of(context);
      _fail(_PasswordField.current, l.myPwCurrentRequired);
      return;
    }
    if (next.length < _minLength) {
      final AppLocalizations l = AppLocalizations.of(context);
      _fail(_PasswordField.next, l.myPwTooShort(_minLength));
      return;
    }
    if (next != _confirm.text) {
      final AppLocalizations l = AppLocalizations.of(context);
      _fail(_PasswordField.confirm, l.myPwMismatch);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _errorField = null;
    });
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(trainerAccountRepositoryProvider)
          .changePassword(currentPassword: current, newPassword: next);
    } on ValidationError catch (e) {
      // The server's own wording (현재 비밀번호가 일치하지 않습니다 …) is
      // more useful than anything generic we could substitute, and it is
      // always about the current password — that is the only value it
      // verifies. 다만 그 문장은 한국어뿐이라 영어 화면에서는 기본 문구로
      // 물러난다. (#501)
      if (mounted) {
        final AppLocalizations l = AppLocalizations.of(context);
        _fail(
          _PasswordField.current,
          serverDetailOr(l, e.message, l.myPwChangeFailed),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        final AppLocalizations l = AppLocalizations.of(context);
        _fail(_PasswordField.current, l.myPwChangeRetry);
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    navigator.pop(true);
  }

  void _clearError() {
    if (_error == null) return;
    setState(() {
      _error = null;
      _errorField = null;
    });
  }

  void _fail(_PasswordField field, String message) {
    setState(() {
      _error = message;
      _errorField = field;
    });
  }

  String? _errorFor(_PasswordField field) =>
      _errorField == field ? _error : null;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.myChangePassword,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PasswordInput(
            controller: _current,
            hint: l.myPwCurrent,
            errorText: _errorFor(_PasswordField.current),
            onChanged: _clearError,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PasswordInput(
            controller: _next,
            hint: l.myPwNew(_minLength),
            errorText: _errorFor(_PasswordField.next),
            onChanged: _clearError,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PasswordInput(
            controller: _confirm,
            hint: l.myPwConfirm,
            errorText: _errorFor(_PasswordField.confirm),
            onChanged: _clearError,
          ),
          const SizedBox(height: AppSpacing.lg),
          Material(
            color: _saving ? AppColors.disabledForeground : AppColors.primary,
            borderRadius: const BorderRadius.all(AppRadius.lg),
            child: InkWell(
              onTap: _saving ? null : _submit,
              borderRadius: const BorderRadius.all(AppRadius.lg),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(
                  _saving ? l.myPwChanging : l.myPwChangeAction,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryForeground,
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

class _PasswordInput extends StatelessWidget {
  const _PasswordInput({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(AppRadius.lg),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      obscureText: true,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.subtleForeground),
        isDense: true,
        filled: true,
        fillColor: AppColors.inputBackground,
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.subtleForeground,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
