import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/design_system/tokens/radius.dart';
import 'package:oncare/design_system/tokens/spacing.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';

// ---------------------------------------------------------------------------
// Shared scaffold
// ---------------------------------------------------------------------------

/// Wraps each settings modal in a consistent Dialog → header (title + X) →
/// scrollable body → primary footer button layout, matching the prototype.
class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({
    required this.title,
    required this.body,
    required this.footerLabel,
    this.onFooter,
    this.saving = false,
  });

  final String title;
  final Widget body;
  final String footerLabel;
  final VoidCallback? onFooter;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _RoundCloseButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              body,
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(AppRadius.lg),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : (onFooter ?? () => Navigator.of(context).pop()),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(footerLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundCloseButton extends StatelessWidget {
  const _RoundCloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.muted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.close, size: 18, color: AppColors.mutedForeground),
        ),
      ),
    );
  }
}

/// Field-label + TextField pair used by the my-profile form.
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputBackground,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            suffixIcon: suffixIcon == null
                ? null
                : Icon(suffixIcon, color: AppColors.mutedForeground, size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 내 프로필 modal
// ---------------------------------------------------------------------------

Future<void> showMyProfileModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _MyProfileDialog(),
  );
}

class _MyProfileDialog extends ConsumerWidget {
  const _MyProfileDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileProvider);
    return async.when(
      data: (UserProfile p) => _MyProfileForm(initial: p),
      loading: () => const _LoadingDialog(title: '내 프로필'),
      error: (_, _) => const _MyProfileForm(
        initial: UserProfile(id: '', name: '', email: ''),
      ),
    );
  }
}

class _MyProfileForm extends ConsumerStatefulWidget {
  const _MyProfileForm({required this.initial});
  final UserProfile initial;

  @override
  ConsumerState<_MyProfileForm> createState() => _MyProfileFormState();
}

class _MyProfileFormState extends ConsumerState<_MyProfileForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial.name);
  late final TextEditingController _email =
      TextEditingController(text: widget.initial.email);
  late final TextEditingController _phone =
      TextEditingController(text: widget.initial.phone);
  late final TextEditingController _birth =
      TextEditingController(text: widget.initial.birthDate);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _birth.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(accountRepositoryProvider).updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        birthDate: _birth.text.trim(),
      );
      ref.invalidate(profileProvider);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('내 프로필이 저장되었어요')));
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('저장에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDialog(
      title: '내 프로필',
      footerLabel: '저장하기',
      onFooter: _save,
      saving: _saving,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _LabeledField(label: '이름', controller: _name),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            label: '이메일',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            label: '전화번호',
            controller: _phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            label: '생년월일',
            controller: _birth,
            suffixIcon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }
}

/// Minimal spinner dialog shown while the profile loads.
class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return _SettingsDialog(
      title: title,
      footerLabel: '저장하기',
      saving: true,
      body: const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 알림 설정 modal
// ---------------------------------------------------------------------------

Future<void> showNotificationSettingsModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _NotificationSettingsDialog(),
  );
}

class _NotificationSettingsDialog extends StatefulWidget {
  const _NotificationSettingsDialog();
  @override
  State<_NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<_NotificationSettingsDialog> {
  bool _diet = true;
  bool _exercise = true;
  bool _vitals = true;
  bool _goal = true;
  bool _marketing = false;

  @override
  Widget build(BuildContext context) {
    return _SettingsDialog(
      title: '알림 설정',
      footerLabel: '닫기',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ToggleRow(
            label: '식단 기록 알림',
            value: _diet,
            onChanged: (v) => setState(() => _diet = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ToggleRow(
            label: '운동 기록 알림',
            value: _exercise,
            onChanged: (v) => setState(() => _exercise = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ToggleRow(
            label: '건강 데이터 입력 알림',
            value: _vitals,
            onChanged: (v) => setState(() => _vitals = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ToggleRow(
            label: '목표 달성 알림',
            value: _goal,
            onChanged: (v) => setState(() => _goal = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ToggleRow(
            label: '마케팅 알림',
            value: _marketing,
            onChanged: (v) => setState(() => _marketing = v),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 고객 지원 modal
// ---------------------------------------------------------------------------

Future<void> showCustomerSupportModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _CustomerSupportDialog(),
  );
}

class _CustomerSupportDialog extends StatelessWidget {
  const _CustomerSupportDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsDialog(
      title: '고객 지원',
      footerLabel: '닫기',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SupportInfoCard(
            title: '고객센터 운영시간',
            lines: <String>['평일 09:00 - 18:00', '(주말 및 공휴일 제외)'],
          ),
          const SizedBox(height: AppSpacing.sm),
          const _SupportInfoCard(
            title: '전화 상담',
            lines: <String>['1588-1234'],
            icon: Icons.call_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _SupportInfoCard(
            title: '이메일 문의',
            lines: <String>['support@oncare.com'],
            icon: Icons.mail_outline,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _SupportInfoCard(
            title: '카카오톡 상담',
            lines: <String>['@온케어'],
            icon: Icons.chat_bubble_outline,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '자주 묻는 질문',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FaqRow(text: '식단 분석은 어떻게 하나요?'),
          const SizedBox(height: AppSpacing.xs),
          const _FaqRow(text: '건강 데이터를 수정하려면?'),
          const SizedBox(height: AppSpacing.xs),
          const _FaqRow(text: '포인트는 어떻게 쌓이나요?'),
        ],
      ),
    );
  }
}

class _SupportInfoCard extends StatelessWidget {
  const _SupportInfoCard({
    required this.title,
    required this.lines,
    this.icon,
  });

  final String title;
  final List<String> lines;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                for (final line in lines)
                  Text(
                    line,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: lines.length == 1
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (icon != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Icon(icon, color: AppColors.mutedForeground, size: 20),
          ],
        ],
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Text('• $text', style: theme.textTheme.bodyMedium),
    );
  }
}
