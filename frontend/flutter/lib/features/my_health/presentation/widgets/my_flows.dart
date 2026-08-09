import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:oncare/features/my_health/domain/support_links.dart';
import 'package:oncare/features/notification/data/repositories/notification_settings_repository.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// 숫자 전용 입력 필터 — 붙여넣기/외부 키보드로 문자가 들어와 저장 시 int
/// 파싱이 null 로 날아가는 것을 막는다.
final List<TextInputFormatter> _digitsOnly = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

void _showTopNotification(
  ScaffoldMessengerState messenger,
  String message, {
  required bool isError,
}) {
  messenger.hideCurrentMaterialBanner();
  late final ScaffoldFeatureController<
    MaterialBanner,
    MaterialBannerClosedReason
  >
  controller;
  controller = messenger.showMaterialBanner(
    MaterialBanner(
      elevation: 3,
      margin: const EdgeInsets.all(12),
      leading: Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        color: isError ? FigmaColors.dangerRed : FigmaColors.primary,
      ),
      content: Text(message),
      actions: <Widget>[
        IconButton(
          tooltip: '닫기',
          onPressed: () => controller.close(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
  final dismissTimer = Timer(const Duration(seconds: 3), controller.close);
  unawaited(controller.closed.whenComplete(dismissTimer.cancel));
}

Widget _shell(
  BuildContext context,
  String title,
  List<Widget> children, {
  bool saving = false,
}) {
  final Widget page = Scaffold(
    key: const Key('mySettingsPage'),
    backgroundColor: Colors.white,
    appBar: AppBar(
      centerTitle: true,
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: FigmaColors.ink,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.contentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: children,
          ),
        ),
      ),
    ),
  );
  return PopScope(canPop: !saving, child: page);
}

Widget _card(List<Widget> children) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: FigmaColors.statBg,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  ),
);

/// Figma-styled label + editable text field used by the profile sheet.
/// White fill on the `statBg` card, brand-blue focus ring.
class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.hintText,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? hintText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: FigmaColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: FigmaColors.primary,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The gradient profile disc with the member's initial.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[FigmaColors.primary, FigmaColors.primaryDeep],
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Spinner shown inside a sheet while `profileProvider` is loading.
class _SheetLoader extends StatelessWidget {
  const _SheetLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(color: FigmaColors.primary),
      ),
    );
  }
}

/// The 취소 · 저장 footer shared by the profile and goal sheets. The primary
/// button shows a spinner and both buttons disable while [saving].
Widget _saveRow({
  required BuildContext context,
  required bool saving,
  required VoidCallback onSave,
}) {
  final AppLocalizations l = AppLocalizations.of(context);
  return Row(
    children: <Widget>[
      Expanded(
        child: OutlinedButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mutedForeground,
            side: const BorderSide(color: FigmaColors.hairline),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            l.myCancel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: saving ? null : onSave,
          style: FilledButton.styleFrom(
            backgroundColor: FigmaColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  l.mySave,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    ],
  );
}

// ───────────────────────────────────────────────────────── 내 프로필 ──

/// Profile editor — pre-fills from `profileProvider` and persists via
/// `AccountRepository.updateProfile`.
Future<void> openProfilePage(BuildContext context) {
  return context.push<void>(AppRoutes.mySettingsPath('profile'));
}

class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);
    return profile.when(
      data: (UserProfile p) => _ProfileForm(initial: p),
      loading: () =>
          _shell(context, l.myProfileTitle, const <Widget>[_SheetLoader()]),
      error: (_, _) => const _ProfileForm(
        initial: UserProfile(id: '', name: '', email: ''),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.initial});
  final UserProfile initial;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.initial.email,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initial.phone,
  );
  late final TextEditingController _birth = TextEditingController(
    text: widget.initial.birthDate,
  );
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
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            birthDate: _birth.text.trim(),
          );
      // Sheet dismissed mid-save → don't touch ref/pop the page below.
      if (!mounted) return;
      ref.invalidate(profileProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l.myProfileSaved)));
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.mySaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String name = widget.initial.name.trim();
    final String initial = name.isNotEmpty ? name.substring(0, 1) : '·';
    return _shell(context, l.myProfileTitle, <Widget>[
      Center(child: _Avatar(initial: initial)),
      const SizedBox(height: 16),
      _card(<Widget>[
        _SheetField(label: l.myFieldName, controller: _name),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myFieldEmail,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myFieldPhone,
          controller: _phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myFieldBirth,
          controller: _birth,
          hintText: '1996-03-21',
        ),
      ]),
      const SizedBox(height: 16),
      _saveRow(context: context, saving: _saving, onSave: _save),
    ], saving: _saving);
  }
}

// ───────────────────────────────────────────────────────── 건강 목표 ──

/// 건강 목표 시트 — 식단 일일 목표(6종) + 주간 운동 목표(3종)를 수정한다.
/// 체중/혈압/혈당(vitals) 목표는 다루지 않는다.
Future<void> openGoalsPage(BuildContext context) {
  return context.push<void>(AppRoutes.mySettingsPath('goals'));
}

class HealthGoalsPage extends ConsumerWidget {
  const HealthGoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);
    return profile.when(
      data: (UserProfile p) => _GoalsForm(initial: p),
      loading: () => _shell(context, '건강 목표', const <Widget>[_SheetLoader()]),
      error: (_, _) => const _GoalsForm(
        initial: UserProfile(id: '', name: '', email: ''),
      ),
    );
  }
}

class _GoalsForm extends ConsumerStatefulWidget {
  const _GoalsForm({required this.initial});
  final UserProfile initial;

  @override
  ConsumerState<_GoalsForm> createState() => _GoalsFormState();
}

class _GoalsFormState extends ConsumerState<_GoalsForm> {
  late final TextEditingController _kcal = _ctl(
    widget.initial.dailyCalories,
    UserProfile.defaultDailyCalories,
  );
  late final TextEditingController _sodium = _ctl(
    widget.initial.dailySodiumMg,
    UserProfile.defaultDailySodiumMg,
  );
  late final TextEditingController _sugar = _ctl(
    widget.initial.dailySugarG,
    UserProfile.defaultDailySugarG,
  );
  late final TextEditingController _carbs = _ctl(
    widget.initial.dailyCarbsG,
    UserProfile.defaultDailyCarbsG,
  );
  late final TextEditingController _protein = _ctl(
    widget.initial.dailyProteinG,
    UserProfile.defaultDailyProteinG,
  );
  late final TextEditingController _fat = _ctl(
    widget.initial.dailyFatG,
    UserProfile.defaultDailyFatG,
  );
  late final TextEditingController _workouts = _ctl(
    widget.initial.weeklyWorkoutGoal,
    7,
  );
  late final TextEditingController _minutes = _ctl(
    widget.initial.weeklyExerciseMinutesGoal,
    150,
  );
  late final TextEditingController _burn = _ctl(
    widget.initial.weeklyBurnGoal,
    1500,
  );
  bool _saving = false;

  static TextEditingController _ctl(int? value, int fallback) =>
      TextEditingController(text: '${value ?? fallback}');

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _kcal,
      _sodium,
      _sugar,
      _carbs,
      _protein,
      _fat,
      _workouts,
      _minutes,
      _burn,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _val(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateHealthGoals(
            dailyCalories: _val(_kcal),
            dailySodiumMg: _val(_sodium),
            dailySugarG: _val(_sugar),
            dailyCarbsG: _val(_carbs),
            dailyProteinG: _val(_protein),
            dailyFatG: _val(_fat),
            weeklyWorkoutGoal: _val(_workouts),
            weeklyExerciseMinutesGoal: _val(_minutes),
            weeklyBurnGoal: _val(_burn),
          );
      if (!mounted) return;
      ref.invalidate(profileProvider);
      ref.invalidate(dashboardSummaryProvider);
      navigator.pop();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!messenger.mounted) return;
      _showTopNotification(messenger, '건강 목표가 저장되었어요', isError: false);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      _showTopNotification(messenger, l.mySaveFailed, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _shell(context, '건강 목표', <Widget>[
      const _GoalsSectionLabel('식단 일일 목표'),
      const SizedBox(height: 8),
      _card(<Widget>[
        _SheetField(
          label: '일일 칼로리 제한 (kcal)',
          controller: _kcal,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: '일일 나트륨 제한 (mg)',
          controller: _sodium,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: '일일 당류 제한 (g)',
          controller: _sugar,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: '일일 탄수화물 제한 (g)',
          controller: _carbs,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: '일일 단백질 제한 (g)',
          controller: _protein,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: '일일 지방 제한 (g)',
          controller: _fat,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
        ),
      ]),
      const SizedBox(height: 20),
      const _GoalsSectionLabel('주간 운동 목표'),
      const SizedBox(height: 8),
      _card(<Widget>[
        _SheetField(
          label: '주간 운동 횟수 목표 (회)',
          controller: _workouts,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: '주간 운동 시간 목표 (분)',
          controller: _minutes,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: '주간 소모 칼로리 목표 (kcal)',
          controller: _burn,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
        ),
      ]),
      const SizedBox(height: 16),
      _saveRow(context: context, saving: _saving, onSave: _save),
    ], saving: _saving);
  }
}

/// Small section heading between the two goal groups.
class _GoalsSectionLabel extends StatelessWidget {
  const _GoalsSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: FigmaColors.ink,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── 알림 설정 ──

/// 토글 목록은 저장소 계약(`kNotificationSettingItems`)이 갖는다 — 키를 서버와
/// 공유하므로 화면이 따로 들고 있으면 어긋난다(#489). 표시 라벨은 [_notifLabel]
/// 이 ARB 에서 찾는다.

/// Localized label for a notification toggle, keyed off its stable prefKey.
String _notifLabel(AppLocalizations l, String prefKey) {
  switch (prefKey) {
    case 'notif_diet_log':
      return l.myNotifDietLog;
    case 'notif_exercise_reminder':
      return l.myNotifExercise;
    case 'notif_trainer_message':
      return l.myNotifTrainer;
    case 'notif_ai_coaching':
      return l.myNotifAiCoaching;
    case 'notif_weekly_report':
      return l.myNotifWeeklyReport;
    default:
      return prefKey;
  }
}

/// 알림 수신 설정.
///
/// 실모드는 계정 단위로 서버에 저장한다 — 기기를 바꿔도 유지되고, 무엇보다
/// 서버가 설정을 알아야 알림을 만들 때 끌 수 있다(#489). 데모/목은 기존대로
/// SharedPreferences 라 화면과 동작이 지금과 같다.
Future<void> openNotificationSettingsPage(BuildContext context) {
  return context.push<void>(AppRoutes.mySettingsPath('notifications'));
}

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  /// 이 화면에서 바꾼 값. 서버 응답을 기다리는 동안에도 스위치가 즉시 움직여야
  /// 한다 — 왕복을 기다리면 눌리지 않는 것처럼 보인다.
  ///
  /// 저장에 **성공한 값도 여기 남는다.** 지우면 최초 조회값으로 돌아가는데,
  /// 서버에는 저장된 값이 남아 있어 화면과 어긋난다.
  final Map<String, bool> _local = <String, bool>{};

  /// 키별 최신 요청 번호. 늦게 도착한 옛 응답이 최신 상태를 덮어쓰는 것을 막는다.
  final Map<String, int> _requestSeq = <String, int>{};

  /// 화면에 그릴 값 — 내가 바꾼 값이 우선, 없으면 서버 값.
  bool _valueOf(String key, Map<String, bool> saved, bool fallback) =>
      _local[key] ?? saved[key] ?? fallback;

  Future<void> _persist(String key, bool value, bool previous) async {
    final int seq = (_requestSeq[key] ?? 0) + 1;
    _requestSeq[key] = seq;
    setState(() => _local[key] = value);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(notificationSettingsRepositoryProvider)
          .setValue(key, value);
    } on Object {
      if (!mounted) return;
      // 이 요청을 기다리는 사이 더 눌렀다면, 옛 실패로 최신 상태를 되돌리지
      // 않는다(리뷰).
      if (_requestSeq[key] != seq) return;
      // 되돌릴 곳은 **직전 값**이지 최초 조회값이 아니다. 한 번 저장에 성공한 뒤
      // 다음 저장이 실패하면 최초값으로 돌아가 서버와 어긋난다(리뷰).
      setState(() => _local[key] = previous);
      messenger.showSnackBar(
        const SnackBar(content: Text('알림 설정을 저장하지 못했어요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final Map<String, bool> saved =
        ref.watch(notificationSettingsProvider).valueOrNull ??
        <String, bool>{
          for (final NotificationSettingItem item in kNotificationSettingItems)
            item.key: item.fallback,
        };
    return _shell(context, l.myNotifTitle, <Widget>[
      _card(<Widget>[
        for (int i = 0; i < kNotificationSettingItems.length; i++) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _notifLabel(l, kNotificationSettingItems[i].key),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.ink,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _valueOf(
                  kNotificationSettingItems[i].key,
                  saved,
                  kNotificationSettingItems[i].fallback,
                ),
                activeThumbColor: FigmaColors.primary,
                onChanged: (bool v) => _persist(
                  kNotificationSettingItems[i].key,
                  v,
                  // 실패했을 때 돌아갈 곳 — 지금 화면에 보이는 값.
                  _valueOf(
                    kNotificationSettingItems[i].key,
                    saved,
                    kNotificationSettingItems[i].fallback,
                  ),
                ),
              ),
            ],
          ),
          if (i < kNotificationSettingItems.length - 1)
            const Divider(height: 1, color: FigmaColors.hairline),
        ],
      ]),
    ]);
  }
}

// ───────────────────────────────────────────────────────── 고객 지원 ──

/// Customer support entries.
Future<void> openSupportPage(BuildContext context) {
  return context.push<void>(AppRoutes.mySettingsPath('support'));
}

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _shell(context, l.mySupportTitle, <Widget>[
      // FAQ·1:1 문의는 앱 안에 화면을 만들지 않고 운영 중인 카카오톡 채널로
      // 보낸다. 문의는 사람이 답해야 하는 일이고 그 창구는 이미 있다. (#507)
      _supportRow(
        Icons.help_outline,
        l.mySupportFaq,
        () => _openExternal(context, kSupportChannelUrl),
        external: true,
        hint: l.mySupportExternalHint,
      ),
      _supportRow(
        Icons.chat_bubble_outline,
        l.mySupportInquiry,
        () => _openExternal(context, kSupportChatUrl),
        external: true,
        hint: l.mySupportExternalHint,
      ),
      _supportRow(
        Icons.description_outlined,
        l.myLegalTermsTitle,
        () => _openLegal(context, _LegalDoc.terms),
      ),
      _supportRow(
        Icons.privacy_tip_outlined,
        l.myLegalPrivacyTitle,
        () => _openLegal(context, _LegalDoc.privacy),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          l.myAppVersion,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    ]);
  }
}

/// 외부 링크를 연다. 실패하면 사유를 알린다.
///
/// 조용히 아무 일도 일어나지 않는 것이 가장 나쁘다 — 카카오톡이 없거나 열 수 있는
/// 앱이 없을 때, 사용자는 앱이 고장 난 것으로 읽는다. (#507)
Future<void> _openExternal(BuildContext context, String url) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  bool opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      // 앱 안 웹뷰가 아니라 브라우저·카카오톡으로 넘긴다 — 로그인된 채널
      // 세션을 그대로 쓸 수 있어야 문의가 이어진다.
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text(l.mySupportOpenFailed)));
  }
}

void _openLegal(BuildContext context, _LegalDoc doc) {
  context.push<void>(AppRoutes.mySettingsPath(doc.name));
}

Widget _supportRow(
  IconData icon,
  String label,
  VoidCallback onTap, {
  bool external = false,
  String? hint,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: FigmaColors.statBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: FigmaColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: FigmaColors.ink,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: FigmaColors.textFaint,
                        ),
                      ),
                  ],
                ),
              ),
              // 앱 밖으로 나가는 행은 화살표 대신 외부 링크 아이콘을 쓴다 —
              // 눌렀을 때 무엇이 일어나는지 미리 보이게.
              Icon(
                external ? Icons.open_in_new : Icons.chevron_right,
                size: 18,
                color: FigmaColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The in-app legal documents surfaced from customer support. Titles and
/// bodies are resolved from localizations via [_LegalDocSheet].
enum _LegalDoc { terms, privacy }

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.document});

  final String document;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool isTerms = document == _LegalDoc.terms.name;
    final String title = isTerms ? l.myLegalTermsTitle : l.myLegalPrivacyTitle;
    final String body = isTerms ? l.myLegalTermsBody : l.myLegalPrivacyBody;
    return _shell(context, title, <Widget>[
      _card(<Widget>[
        Text(
          body,
          style: const TextStyle(
            fontSize: 14,
            height: 1.7,
            fontWeight: FontWeight.w500,
            color: AppColors.foreground,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Center(
        child: Text(
          l.myLegalEffectiveDate,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    ]);
  }
}
