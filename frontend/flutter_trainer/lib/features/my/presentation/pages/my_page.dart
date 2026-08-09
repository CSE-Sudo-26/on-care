import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:oncare_trainer/app/router/routes.dart';
import 'package:oncare_trainer/design_system/tokens/colors.dart';
import 'package:oncare_trainer/design_system/tokens/elevation.dart';
import 'package:oncare_trainer/design_system/tokens/layout.dart';
import 'package:oncare_trainer/design_system/tokens/radius.dart';
import 'package:oncare_trainer/design_system/tokens/spacing.dart';
// Session은 앱 전역 상태라 예외적으로 auth feature 의 provider 를 직접
// 사용한다 (라우터의 인증 게이트와 동일한 소비자). TODO: 실 백엔드
// 도입 시 세션 계층을 core/session 으로 승격해 이 의존을 정리한다.
import 'package:oncare_trainer/core/errors/app_error.dart';
import 'package:oncare_trainer/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare_trainer/features/my/data/trainer_account_repository.dart';
import 'package:oncare_trainer/features/my/data/trainer_profile_repository.dart';
import 'package:oncare_trainer/features/my/data/trainer_settings.dart';
import 'package:oncare_trainer/shared/widgets/status_dot_label.dart';
import 'package:oncare_trainer/shared/models/trainer_profile.dart';
import 'package:oncare_trainer/shared/services/client_repository.dart';
import 'package:oncare_trainer/shared/widgets/action_button.dart';
import 'package:oncare_trainer/shared/widgets/page_scaffold.dart';
import 'package:oncare_trainer/shared/widgets/section_card.dart';
import 'package:oncare_trainer/gen/l10n/app_localizations.dart';

/// 내 정보 / 설정 — reached from the sidebar footer, not the nav list.
///
/// It is not a navigation destination on purpose: a trainer opens this
/// a few times a month, and giving it a nav row would put it beside the
/// five surfaces they use every day. Two sections behind one switch:
///
///  * **내 정보** — profile, certifications, this month's stats, gym.
///    Edits persist through `PUT /v1/trainer/me` and the gym affiliation
///    endpoints; mock mode follows the same repository contract.
///  * **설정** — notifications, account, app info, 로그아웃. Most rows
///    are placeholders today; they are shown (disabled, with a reason)
///    rather than hidden so the shape of the screen doesn't change when
///    the endpoints arrive.
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.myCareerInvalid)),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    if (!profileSaved) return detail ?? l.myProfileSaveFailed;
    final partial = l.myGymChangeFailed;
    return detail == null ? partial : '$partial $detail';
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
    return PageScaffold(
      title: _tab == 0 ? l.myTabProfile : l.myTabSettings,
      subtitle: _profile.name,
      maxWidth: AppLayout.contentMaxWidth,
      actions: <Widget>[
        SegmentedSwitch(
          labels: <String>[l.myTabProfile, l.myTabSettings],
          selected: _tab,
          onChanged: (i) {
            setState(() => _tab = i);
            context.go(AppRoutes.mySection(i == 0 ? 'profile' : 'settings'));
          },
        ),
        if (_tab == 0)
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
      child: _tab == 0 ? _buildProfile() : _buildSettings(),
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
              style: TextStyle(
                fontSize: 11,
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
      ],
    );
  }

  /// Applies a settings change and tells the trainer if it didn't stick.
  ///
  /// The switch flips immediately (waiting on a round trip feels broken),
  /// so a failed write has to be visible — otherwise the screen shows a
  /// value the server never accepted.
  Future<void> _applySetting(Future<void> Function() change) async {
    final messenger = ScaffoldMessenger.of(context);
    await change();
    if (!mounted) return;
    final controller = ref.read(trainerSettingsProvider.notifier);
    final error = controller.lastError;
    if (error != null) {
      controller.clearError();
      messenger.showSnackBar(SnackBar(content: Text(error)));
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
              const Divider(height: 1, color: AppColors.borderStrong),
              _SwitchRow(
                label: l.myNotifSessionReminder,
                hint: l.myNotifSessionReminderHint,
                value: settings.sessionReminders,
                onChanged: (v) =>
                    _applySetting(() => controller.setSessionReminders(v)),
              ),
              if (settings.sessionReminders) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l.myReminderLead,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    SegmentedSwitch(
                      labels: <String>[
                        for (final m in reminderLeadOptions) l.myMinutesBefore(m),
                      ],
                      selected: reminderLeadOptions.indexOf(
                        settings.reminderLeadMinutes,
                      ),
                      onChanged: (i) => _applySetting(
                        () =>
                            controller.setReminderLead(reminderLeadOptions[i]),
                      ),
                    ),
                  ],
                ),
              ],
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
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        Text(
                          account.supportsPasswordChange
                              ? l.myChangePasswordHint
                              : l.myChangePasswordDemo,
                          style: const TextStyle(
                            fontSize: 10.5,
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
        fontSize: 11.5,
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
      builder: (context) => const _PasswordSheet(),
    );
    if (changed == true && mounted) {
      final AppLocalizations l = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.myPasswordChanged)));
    }
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
              fontSize: 11.5,
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
                    fontSize: 18,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      profile.email,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtleForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        _Tag(text: profile.specialty, color: AppColors.success),
                        const SizedBox(width: AppSpacing.xs),
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
          fontSize: 9.5,
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
              fontSize: 9.5,
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
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
            decoration: InputDecoration(
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  if (editing)
                    GestureDetector(
                      onTap: () => onRemove(i),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.subtleForeground,
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

/// "이번 달 통계" — warm gradient block with 담당 고객(live count) /
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
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                          Text(
                            gym.address,
                            style: const TextStyle(
                              fontSize: 10.5,
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
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: 3),
          choices.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => Text(
              l.myGymListFailed,
              style: TextStyle(color: AppColors.destructive, fontSize: 11),
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
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text(l.myNoGym),
                  ),
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
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
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
              Icon(Icons.logout, size: 16, color: AppColors.destructive),
              SizedBox(width: AppSpacing.sm),
              Text(
                l.mySignOut,
                style: TextStyle(
                  fontSize: 12.5,
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 10.5,
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
      // verifies.
      if (mounted) {
        final AppLocalizations l = AppLocalizations.of(context);
        _fail(_PasswordField.current, e.message ?? l.myPwChangeFailed);
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
            style: TextStyle(
              fontSize: 15,
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
                    fontSize: 13,
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
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.subtleForeground,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
