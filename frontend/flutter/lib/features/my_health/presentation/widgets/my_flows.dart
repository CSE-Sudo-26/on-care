import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncare/core/storage/prefs_store.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/features/account/domain/entities/user_profile.dart';
import 'package:oncare/features/account/presentation/controllers/account_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _shell(
  BuildContext context,
  String title,
  List<Widget> children, {
  bool saving = false,
}) {
  final Widget sheet = SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        // Match the main content width so the sheet scales with the viewport
        // like the tab pages. The theme lifts the modal route cap to this
        // width too (see AppTheme._bottomSheetTheme); this centres the child.
        maxWidth: AppBreakpoints.contentMaxWidth,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3EA),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: FigmaColors.ink,
                      ),
                    ),
                  ),
                  Material(
                    color: const Color(0xFFF4F6F8),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      // Disabled while a save is in flight (blocks dismiss).
                      onTap: saving ? null : () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: FigmaColors.textSub,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return PopScope(canPop: !saving, child: sheet);
}

Future<void> _open(BuildContext context, String title, List<Widget> body) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => _shell(ctx, title, body),
  );
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

/// Figma-styled label + editable text field used by the profile and goal
/// sheets. White fill on the `statBg` card, brand-blue focus ring.
class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.suffix,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffix;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: FigmaColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: FigmaColors.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textFaint,
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FigmaColors.textMuted,
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
              borderSide: const BorderSide(color: FigmaColors.primary, width: 1.4),
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
      child: Center(child: CircularProgressIndicator(color: FigmaColors.primary)),
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
            foregroundColor: FigmaColors.textSub,
            side: const BorderSide(color: FigmaColors.hairline),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            l.myCancel,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    ],
  );
}

// ───────────────────────────────────────────────────────── 내 프로필 ──

/// Profile editor — pre-fills from `profileProvider` and persists via
/// `AccountRepository.updateProfile`.
Future<void> showProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => const _ProfileSheet(),
  );
}

class _ProfileSheet extends ConsumerWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);
    return profile.when(
      data: (UserProfile p) => _ProfileForm(initial: p),
      loading: () => _shell(context, l.myProfileTitle, const <Widget>[_SheetLoader()]),
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
      await ref.read(accountRepositoryProvider).updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        birthDate: _birth.text.trim(),
      );
      // Sheet dismissed mid-save → don't touch ref/pop the page below.
      if (!mounted) return;
      ref.invalidate(profileProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l.myProfileSaved)),
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l.mySaveFailed)),
      );
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

/// Health goals editor — pre-fills from `profileProvider` and persists via
/// `AccountRepository.updateHealthGoals`.
Future<void> showGoalsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => const _GoalsSheet(),
  );
}

class _GoalsSheet extends ConsumerWidget {
  const _GoalsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);
    return profile.when(
      data: (UserProfile p) => _GoalsForm(initial: p),
      loading: () => _shell(context, l.myGoalsTitle, const <Widget>[_SheetLoader()]),
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
  late final TextEditingController _weight = TextEditingController(
    text: '${(widget.initial.goalWeightKg ?? 70).round()}',
  );
  late final TextEditingController _bp = TextEditingController(
    text: '${widget.initial.goalBpSystolic ?? 120}',
  );
  late final TextEditingController _sugar = TextEditingController(
    text: '${widget.initial.goalBloodSugar ?? 100}',
  );
  late final TextEditingController _kcal = TextEditingController(
    text: '${widget.initial.dailyCalories ?? 2000}',
  );
  late final TextEditingController _sodium = TextEditingController(
    text: '${widget.initial.dailySodiumMg ?? 2000}',
  );
  bool _saving = false;

  @override
  void dispose() {
    _weight.dispose();
    _bp.dispose();
    _sugar.dispose();
    _kcal.dispose();
    _sodium.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(accountRepositoryProvider).updateHealthGoals(
        goalWeightKg: int.tryParse(_weight.text.trim()),
        goalBpSystolic: int.tryParse(_bp.text.trim()),
        goalBloodSugar: int.tryParse(_sugar.text.trim()),
        dailyCalories: int.tryParse(_kcal.text.trim()),
        dailySodiumMg: int.tryParse(_sodium.text.trim()),
      );
      // Sheet dismissed mid-save → don't touch ref/pop the page below.
      if (!mounted) return;
      ref.invalidate(profileProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l.myGoalsSaved)),
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l.mySaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final List<TextInputFormatter> digitsOnly = <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
    ];
    return _shell(context, l.myGoalsTitle, <Widget>[
      Text(
        l.myGoalsDesc,
        style: const TextStyle(fontSize: 12, color: FigmaColors.textMuted),
      ),
      const SizedBox(height: 12),
      _card(<Widget>[
        _SheetField(
          label: l.myGoalWeight,
          controller: _weight,
          suffix: l.unitKg,
          keyboardType: TextInputType.number,
          inputFormatters: digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myGoalBp,
          controller: _bp,
          suffix: 'mmHg',
          keyboardType: TextInputType.number,
          inputFormatters: digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myGoalBloodSugar,
          controller: _sugar,
          suffix: 'mg/dL',
          keyboardType: TextInputType.number,
          inputFormatters: digitsOnly,
        ),
      ]),
      const SizedBox(height: 12),
      _card(<Widget>[
        _SheetField(
          label: l.myGoalCalories,
          controller: _kcal,
          suffix: l.unitKcal,
          keyboardType: TextInputType.number,
          inputFormatters: digitsOnly,
        ),
        const SizedBox(height: 12),
        _SheetField(
          label: l.myGoalSodium,
          controller: _sodium,
          suffix: 'mg',
          keyboardType: TextInputType.number,
          inputFormatters: digitsOnly,
        ),
      ]),
      const SizedBox(height: 16),
      _saveRow(context: context, saving: _saving, onSave: _save),
    ], saving: _saving);
  }
}

// ───────────────────────────────────────────────────────── 알림 설정 ──

/// One notification toggle: SharedPreferences key and the default used before
/// the user has ever changed it. The display label is resolved from
/// [_notifLabel] so it is never carried as a hardcoded string.
class _NotifItem {
  const _NotifItem(this.prefKey, this.fallback);
  final String prefKey;
  final bool fallback;
}

const List<_NotifItem> _notifItems = <_NotifItem>[
  _NotifItem('notif_diet_log', true),
  _NotifItem('notif_exercise_reminder', true),
  _NotifItem('notif_trainer_message', true),
  _NotifItem('notif_ai_coaching', true),
  _NotifItem('notif_weekly_report', false),
];

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

/// Notification preferences — toggles load from and persist to
/// SharedPreferences so they survive a reload.
Future<void> showNotifSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => const _NotifSheet(),
  );
}

class _NotifSheet extends ConsumerStatefulWidget {
  const _NotifSheet();

  @override
  ConsumerState<_NotifSheet> createState() => _NotifSheetState();
}

class _NotifSheetState extends ConsumerState<_NotifSheet> {
  late final SharedPreferences _prefs;
  final Map<String, bool> _on = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _prefs = ref.read(sharedPreferencesProvider);
    for (final _NotifItem item in _notifItems) {
      _on[item.prefKey] = _prefs.getBool(item.prefKey) ?? item.fallback;
    }
  }

  void _persist(String key, bool value) {
    setState(() => _on[key] = value);
    _prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _shell(context, l.myNotifTitle, <Widget>[
      _card(<Widget>[
        for (int i = 0; i < _notifItems.length; i++) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _notifLabel(l, _notifItems[i].prefKey),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.ink,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _on[_notifItems[i].prefKey] ?? _notifItems[i].fallback,
                activeThumbColor: FigmaColors.primary,
                onChanged: (bool v) => _persist(_notifItems[i].prefKey, v),
              ),
            ],
          ),
          if (i < _notifItems.length - 1)
            const Divider(height: 1, color: FigmaColors.hairline),
        ],
      ]),
    ]);
  }
}

// ───────────────────────────────────────────────────────── 고객 지원 ──

/// Customer support entries.
Future<void> showSupportSheet(BuildContext context) {
  final AppLocalizations l = AppLocalizations.of(context);
  return _open(context, l.mySupportTitle, <Widget>[
    _supportRow(
      Icons.help_outline,
      l.mySupportFaq,
      () => _comingSoon(context, l.mySupportFaq),
    ),
    _supportRow(
      Icons.chat_bubble_outline,
      l.mySupportInquiry,
      () => _comingSoon(context, l.mySupportInquiry),
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
        style: const TextStyle(fontSize: 12, color: FigmaColors.textFaint),
      ),
    ),
  ]);
}

void _comingSoon(BuildContext context, String label) {
  final AppLocalizations l = AppLocalizations.of(context);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l.myComingSoon(label))));
}

void _openLegal(BuildContext context, _LegalDoc doc) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => _LegalDocSheet(doc: doc),
  );
}

Widget _supportRow(IconData icon, String label, VoidCallback onTap) {
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
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
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

class _LegalDocSheet extends StatelessWidget {
  const _LegalDocSheet({required this.doc});
  final _LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String title =
        doc == _LegalDoc.terms ? l.myLegalTermsTitle : l.myLegalPrivacyTitle;
    final String body =
        doc == _LegalDoc.terms ? l.myLegalTermsBody : l.myLegalPrivacyBody;
    return _shell(context, title, <Widget>[
      _card(<Widget>[
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            height: 1.7,
            fontWeight: FontWeight.w500,
            color: FigmaColors.textBody,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Center(
        child: Text(
          l.myLegalEffectiveDate,
          style: const TextStyle(fontSize: 11, color: FigmaColors.textFaint),
        ),
      ),
    ]);
  }
}
