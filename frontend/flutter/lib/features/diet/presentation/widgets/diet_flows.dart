import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oncare/app/router/routes.dart';
import 'package:oncare/core/utils/clock.dart';
import 'package:oncare/design_system/figma/figma_kit.dart';
import 'package:oncare/design_system/tokens/breakpoints.dart';
import 'package:oncare/design_system/tokens/colors.dart';
import 'package:oncare/features/auth/presentation/controllers/session_controller.dart';
import 'package:oncare/features/diet/domain/entities/diet_analysis.dart';
import 'package:oncare/features/diet/domain/entities/diet_analysis_failure.dart';
import 'package:oncare/features/diet/domain/entities/diet_day.dart';
import 'package:oncare/features/diet/domain/entities/meal_photo.dart';
import 'package:oncare/features/diet/presentation/controllers/diet_controller.dart';
import 'package:oncare/gen/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// A single logged food item, with the per-food nutrition shown on the meal
/// card ([sodiumMg] / [sugarG] default to 0 for draft rows in the edit sheet).
class DietFood {
  const DietFood(this.name, this.kcal, {this.sodiumMg = 0, this.sugarG = 0});
  final String name;
  final int kcal;
  final int sodiumMg;
  final double sugarG;
}

/// A nutrient chip on a meal card (`over` = above the daily target → red).
class DietTag {
  const DietTag(this.label, {this.over = false});
  final String label;
  final bool over;
}

/// One meal in the daily log. [id] is the backend entry id (null for a
/// not-yet-persisted draft) and is required to edit or delete the entry.
class DietMeal {
  const DietMeal({
    required this.mealType,
    required this.time,
    required this.total,
    required this.emoji,
    required this.thumbBg,
    required this.items,
    required this.tags,
    required this.sodium,
    required this.sugar,
    this.aiComment = '',
    this.photoAsset,
    this.photoUrl,
    this.id,
  });

  final MealType mealType;
  final String time;
  final int total;
  final String emoji;
  final Color thumbBg;
  final List<DietFood> items;
  final List<DietTag> tags;
  final int sodium;
  final double sugar;

  /// Short per-meal AI feedback line shown under the food breakdown.
  final String aiComment;

  /// Bundled photo asset for the thumbnail; null falls back to [emoji].
  final String? photoAsset;

  /// API path of the photo the member uploaded (#699). Wins over
  /// [photoAsset] when present.
  final String? photoUrl;
  final String? id;
}

/// Localized meal-type badge label. The API `meal_type` string is always
/// derived from [MealType.name], never from this display label.
String mealBadge(AppLocalizations l, MealType t) => switch (t) {
  MealType.breakfast => l.dietMealBreakfast,
  MealType.lunch => l.dietMealLunch,
  MealType.dinner => l.dietMealDinner,
  MealType.snack => l.dietMealSnack,
};

/// Best-guess meal type for a new entry, based on the current time of day.
String _currentMealType() {
  final int h = nowKst().hour;
  if (h < 11) return 'breakfast';
  if (h < 15) return 'lunch';
  if (h < 21) return 'dinner';
  return 'snack';
}

Widget _sheetShell(BuildContext context, Widget child, {Key? key}) {
  return ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.9,
      // Match the main content width so the sheet scales with the viewport
      // like the tab pages. The theme lifts the modal route cap to this
      // width too (see AppTheme._bottomSheetTheme); this centres the child.
      maxWidth: AppBreakpoints.contentMaxWidth,
    ),
    child: Container(
      key: key,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(top: false, child: child),
    ),
  );
}

Widget _pageShell(Widget child) {
  return Scaffold(
    key: const Key('mealDetailPage'),
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.contentMaxWidth,
          ),
          child: SizedBox.expand(child: child),
        ),
      ),
    ),
  );
}

Widget _sheetHandle() => Container(
  margin: const EdgeInsets.only(top: 12, bottom: 4),
  width: 36,
  height: 4,
  decoration: BoxDecoration(
    color: const Color(0xFFDDE3EA),
    borderRadius: BorderRadius.circular(999),
  ),
);

// ─────────────────────────────────────────────────── 식단 추가하기 ──

/// Opens the short photo-source choice as a content-sized bottom sheet.
Future<void> showDietAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Keep the sheet above the main shell's floating buttons even when it is
    // opened from a tab page that has its own nested Navigator.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) => const _DietAddSheet(),
  );
}

/// Photo-source choice for 식단 추가.
///
/// Owns the picker outcome so a failure can be shown *inside* the sheet: a
/// SnackBar would sit behind this sheet, and the sheet staying open is what
/// lets the user retry (or open Settings) without restarting the flow.
/// Cancelling the camera/gallery is not a failure — nothing is shown.
class _DietAddSheet extends ConsumerStatefulWidget {
  const _DietAddSheet();

  @override
  ConsumerState<_DietAddSheet> createState() => _DietAddSheetState();
}

class _DietAddSheetState extends ConsumerState<_DietAddSheet> {
  MealPhotoFailure? _failure;

  /// Guards a second tap while the OS picker is up — image_picker rejects a
  /// concurrent request with `multiple_request`.
  bool _picking = false;

  Future<void> _pickAndAnalyze(MealPhotoSource source) async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _failure = null;
    });
    final NavigatorState navigator = Navigator.of(context);

    final MealPhoto? photo;
    try {
      photo = await ref.read(mealPhotoPickerProvider).pick(source);
    } on MealPhotoException catch (error) {
      _settle(error.failure);
      return;
    } on Object {
      _settle(MealPhotoFailure.readFailed);
      return;
    }
    // `navigator.mounted` is still true after this sheet is dismissed, so it
    // can't tell us whether the route we're about to pop is ours. Only this
    // State being mounted proves the sheet is still up — without the check a
    // dismiss during the OS picker would pop the page underneath instead.
    if (!mounted) return;
    _settle(null);
    if (photo == null) return; // user cancelled

    navigator.pop();
    await showDietResultSheet(navigator.context, photo, _currentMealType());
  }

  void _settle(MealPhotoFailure? failure) {
    if (!mounted) return;
    setState(() {
      _picking = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final MealPhotoFailure? failure = _failure;
    return _sheetShell(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(child: _sheetHandle()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l.dietAddSheetTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.dietAddSheetSubtitle,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                _CircleClose(onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _PhotoFailureNotice(failure: failure),
            ),
          Padding(
            key: const Key('dietAddOptions'),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: <Widget>[
                _SourceOption(
                  icon: Icons.image_outlined,
                  iconBg: FigmaColors.primaryA(0.12),
                  iconColor: FigmaColors.primary,
                  title: l.dietPickPhoto,
                  subtitle: l.dietPickPhotoSub,
                  onTap: () => _pickAndAnalyze(MealPhotoSource.gallery),
                ),
                const SizedBox(height: 12),
                _SourceOption(
                  icon: Icons.photo_camera_outlined,
                  iconBg: FigmaColors.greenA(0.12),
                  iconColor: FigmaColors.greenText,
                  title: l.dietTakePhoto,
                  subtitle: l.dietTakePhotoSub,
                  onTap: () => _pickAndAnalyze(MealPhotoSource.camera),
                ),
              ],
            ),
          ),
        ],
      ),
      key: const Key('dietAddSheet'),
    );
  }
}

/// In-sheet explanation of why the photo couldn't be used. Only a permanent
/// iOS denial offers Settings; retryable denials and policy restrictions do
/// not send the user somewhere that cannot fix them.
class _PhotoFailureNotice extends StatefulWidget {
  const _PhotoFailureNotice({required this.failure});

  final MealPhotoFailure failure;

  @override
  State<_PhotoFailureNotice> createState() => _PhotoFailureNoticeState();
}

class _PhotoFailureNoticeState extends State<_PhotoFailureNotice> {
  static const Color _warningBg = Color(0xFFFFF1EF);
  static const Color _warningInk = Color(0xFFD1442C);

  /// Settings wouldn't open — fall back to telling the user the manual path.
  /// A tap that silently does nothing reads as a broken app (#507).
  bool _openSettingsFailed = false;

  bool get _isPermanentlyDenied =>
      widget.failure == MealPhotoFailure.cameraPermissionPermanentlyDenied ||
      widget.failure == MealPhotoFailure.photoPermissionPermanentlyDenied;

  /// Only iOS has a URL that lands on this app's permission screen;
  /// elsewhere the message alone has to do.
  bool get _canOpenAppSettings =>
      _isPermanentlyDenied &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;

  String _message(AppLocalizations l) => switch (widget.failure) {
    MealPhotoFailure.cameraPermissionDenied => l.dietCameraPermissionDenied,
    MealPhotoFailure.cameraPermissionPermanentlyDenied =>
      l.dietCameraPermissionPermanentlyDenied,
    MealPhotoFailure.cameraPermissionRestricted =>
      l.dietPhotoPermissionRestricted,
    MealPhotoFailure.photoPermissionDenied => l.dietPhotoPermissionDenied,
    MealPhotoFailure.photoPermissionPermanentlyDenied =>
      l.dietPhotoPermissionPermanentlyDenied,
    MealPhotoFailure.photoPermissionRestricted =>
      l.dietPhotoPermissionRestricted,
    MealPhotoFailure.unsupportedFormat => l.dietPhotoUnsupportedFormat,
    MealPhotoFailure.tooLarge => l.dietPhotoTooLarge,
    MealPhotoFailure.readFailed => l.dietPhotoLoadError,
  };

  Future<void> _openSettings() async {
    bool opened = false;
    try {
      // `app-settings:` is a system scheme, so the platform default mode is
      // what lands on this app's permission screen (no external webview).
      opened = await launchUrl(Uri.parse('app-settings:'));
    } on Object {
      opened = false;
    }
    if (!mounted || opened) return;
    setState(() => _openSettingsFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      key: const Key('dietPhotoFailureNotice'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 18, color: _warningInk),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _message(l),
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: _warningInk,
                  ),
                ),
                if (_canOpenAppSettings)
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: _openSettings,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l.dietOpenSettings,
                          key: const Key('dietOpenSettingsLink'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: FigmaColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_openSettingsFailed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.dietOpenSettingsFailed,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: _warningInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FigmaColors.primaryA(0.15)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
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
    );
  }
}

// ─────────────────────────────────────────────────── 분석 완료 ──

/// AI analysis result sheet shown after picking a photo.
/// Runs the real `POST /diet/analyze` on the picked [photo] and shows the
/// recognised foods + nutrition. The backend persists the entry as part of
/// analysis, so a successful result refreshes [dietTodayProvider].
Future<void> showDietResultSheet(
  BuildContext context,
  MealPhoto photo,
  String mealType,
) {
  return showModalBottomSheet<void>(
    context: context,
    // 하단 바·+ 버튼이 시트 위로 올라오지 않도록 루트에 올린다. 식단 추가 시트와
    // 같은 규칙이다 — 그 시트가 이 시트를 열므로 둘이 같은 층에 있어야 한다(#791).
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FigmaColors.sheetScrim,
    builder: (BuildContext ctx) =>
        _ResultSheet(photo: photo, mealType: mealType),
  );
}

class _ResultSheet extends ConsumerStatefulWidget {
  const _ResultSheet({required this.photo, required this.mealType});
  final MealPhoto photo;
  final String mealType;

  @override
  ConsumerState<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends ConsumerState<_ResultSheet> {
  DietAnalysisResult? _result;
  bool _loading = true;
  DietAnalysisFailure? _failure;

  bool get _failed => _failure != null;

  // One key per capture, reused across retries so a lost response followed by
  // 「다시 시도」 doesn't record the same meal twice (server dedupes on it).
  late final String _idempotencyKey =
      'diet-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final DietAnalysisResult result = await ref
          .read(dietRepositoryProvider)
          .analyze(
            photo: widget.photo,
            mealType: widget.mealType,
            idempotencyKey: _idempotencyKey,
          );
      if (!mounted) return;
      // analyze() already persisted the entry → refresh the day's summary/list.
      ref.invalidate(dietTodayProvider);
      // 기간 뷰(이번 주·이번 달)는 오늘을 dietByDateProvider 로 읽는다.
      // 같이 비우지 않으면 끼니를 바꿔도 기간 막대만 옛 값에 머문다.
      ref.invalidate(dietByDateProvider(nowKst()));
      setState(() {
        _result = result;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failure = DietAnalysisFailure.fromError(error);
      });
    }
  }

  /// Sends the user back to the source picker. The photo they have can't be
  /// analysed, so "다시 시도" would just fail again — the useful next step is
  /// choosing a different one.
  void _pickAnother() {
    final NavigatorState navigator = Navigator.of(context);
    navigator.pop();
    unawaited(showDietAddSheet(navigator.context));
  }

  /// Takes an expired session back to sign-in.
  ///
  /// Signing out *is* the navigation: `appRouterProvider` refreshes the guard
  /// on every session change, and `sessionRedirect` sends a signed-out user
  /// to `/auth/sign-in`. Pushing that route directly would not work — while
  /// the session still reads as authenticated the guard bounces anyone off
  /// the auth routes back to the dashboard. Clearing the dead token is also
  /// the point: it is what made the request fail.
  Future<void> _signInAgain() async {
    // Read before popping; this State is gone right after.
    final NavigatorState navigator = Navigator.of(context);
    final SessionController session = ref.read(
      sessionControllerProvider.notifier,
    );
    navigator.pop();
    await session.signOut();
  }

  String _failureMessage(AppLocalizations l, DietAnalysisFailure failure) =>
      switch (failure) {
        DietAnalysisFailure.unsupportedFormat =>
          l.dietAnalysisUnsupportedFormat,
        DietAnalysisFailure.badRequest => l.dietAnalysisBadRequest,
        DietAnalysisFailure.unauthorized => l.dietAnalysisUnauthorized,
        DietAnalysisFailure.notImplemented => l.dietAnalysisNotImplemented,
        // 502 and transport failures share the "try again shortly" wording —
        // from the user's side both are "it broke, not your photo".
        DietAnalysisFailure.recognitionFailed ||
        DietAnalysisFailure.temporary => l.dietAnalysisFailedBody,
      };

  /// The button only offers a retry when one can actually succeed; otherwise
  /// it moves the user to the step that can (a different photo), or just
  /// closes when nothing in this sheet will help.
  VoidCallback _failureAction(DietAnalysisFailure failure) {
    if (failure.canRetry) return _run;
    return switch (failure) {
      DietAnalysisFailure.unsupportedFormat ||
      DietAnalysisFailure.badRequest => _pickAnother,
      DietAnalysisFailure.unauthorized => () => unawaited(_signInAgain()),
      _ => () => Navigator.of(context).pop(),
    };
  }

  String _failureActionLabel(AppLocalizations l, DietAnalysisFailure failure) {
    if (failure.canRetry) return l.actionRetry;
    return switch (failure) {
      DietAnalysisFailure.unsupportedFormat ||
      DietAnalysisFailure.badRequest => l.dietAnalysisPickAnother,
      DietAnalysisFailure.unauthorized => l.dietAnalysisSignIn,
      _ => l.dietAnalysisClose,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return _sheetShell(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(child: _sheetHandle()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: <Widget>[
                const OniAvatar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _loading
                            ? l.dietAnalyzing
                            : _failed
                            ? l.dietAnalysisFailed
                            : l.dietAnalysisDone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.ink,
                        ),
                      ),
                      Text(
                        l.dietAiNutritionResult,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: FigmaColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _CircleClose(onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: _body(),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final AppLocalizations l = AppLocalizations.of(context);
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: <Widget>[
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
            Text(
              l.dietAnalyzingBody,
              style: const TextStyle(fontSize: 14, color: AppColors.foreground),
            ),
          ],
        ),
      );
    }
    if (_failed || _result == null) {
      // `_result == null` without a classified failure shouldn't happen, but
      // treating it as temporary keeps a retry available instead of a dead end.
      final DietAnalysisFailure failure =
          _failure ?? DietAnalysisFailure.temporary;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: <Widget>[
            Text(
              _failureMessage(l, failure),
              key: const Key('dietAnalysisFailureBody'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('dietAnalysisFailureAction'),
                onPressed: _failureAction(failure),
                style: FilledButton.styleFrom(
                  backgroundColor: FigmaColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _failureActionLabel(l, failure),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final DietAnalysisResult r = _result!;
    final String recognized = r.foods
        .map((RecognizedFood f) => f.name)
        .join(' · ');
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FigmaColors.softBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l.dietRecognizedFood,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                recognized.isEmpty ? l.dietNoRecognizedFood : recognized,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FigmaColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l.dietNutritionResult,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ResultRow(
          label: l.dietCalories,
          value: '${r.totalCalories}',
          unit: l.unitKcal,
        ),
        const SizedBox(height: 8),
        _ResultRow(
          label: l.dietSodium,
          value: '${r.totalSodiumMg}',
          unit: l.dietUnitMg,
        ),
        const SizedBox(height: 8),
        _ResultRow(
          label: l.dietSugar,
          value: '${r.totalSugarG}',
          unit: l.dietUnitG,
        ),
        if (r.coachComment.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FigmaColors.statBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              r.coachComment,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l.dietSaved)));
            },
            style: FilledButton.styleFrom(
              backgroundColor: FigmaColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: Text(
              l.dietDone,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FigmaColors.statBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: FigmaColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────── 식사 수정 ──

/// Opens meal details as a full page above the member tab shell.
Future<void> openMealDetailPage(BuildContext context, DietMeal meal) {
  final String? id = meal.id;
  if (id == null) return Future<void>.value();
  return context.push<void>(AppRoutes.dietEntryDetailPath(id), extra: meal);
}

/// Full-page meal editor. [initialMeal] makes the first transition immediate;
/// when a web URL is refreshed, the same meal is restored from today's data.
class DietMealDetailPage extends ConsumerWidget {
  const DietMealDetailPage({
    super.key,
    required this.entryId,
    this.initialMeal,
  });

  final String entryId;
  final DietMeal? initialMeal;

  DietMeal _fromEntry(DietEntry entry) => DietMeal(
    id: entry.id,
    mealType: entry.mealType,
    time: entry.timeLabel,
    total: entry.totalCalories,
    emoji: '',
    thumbBg: Colors.white,
    photoAsset: entry.photoAsset,
    photoUrl: entry.photoUrl,
    aiComment: entry.aiComment,
    items: <DietFood>[
      for (final FoodItem food in entry.foods)
        DietFood(
          food.name,
          food.calories,
          sodiumMg: food.sodiumMg,
          sugarG: food.sugarG,
        ),
    ],
    tags: const <DietTag>[],
    sodium: entry.sodiumMg,
    sugar: entry.sugarG,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DietMeal? supplied = initialMeal;
    if (supplied != null && supplied.id == entryId) {
      return _MealEditSheet(meal: supplied);
    }

    final AppLocalizations l = AppLocalizations.of(context);
    return ref
        .watch(dietTodayProvider)
        .when(
          data: (DietDay day) {
            for (final DietEntry entry in day.entries) {
              if (entry.id == entryId) {
                return _MealEditSheet(meal: _fromEntry(entry));
              }
            }
            return _MealDetailUnavailable(message: l.dietLoadError);
          },
          loading: () => const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _MealDetailUnavailable(message: l.dietLoadError),
        );
  }
}

class _MealDetailUnavailable extends StatelessWidget {
  const _MealDetailUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: Center(child: Text(message)),
    );
  }
}

class _MealEditSheet extends ConsumerStatefulWidget {
  const _MealEditSheet({required this.meal});
  final DietMeal meal;

  @override
  ConsumerState<_MealEditSheet> createState() => _MealEditSheetState();
}

class _MealEditSheetState extends ConsumerState<_MealEditSheet> {
  static const List<MealType> _types = MealType.values;
  late MealType _type = widget.meal.mealType;
  late List<DietFood> _foods = List<DietFood>.of(widget.meal.items);
  bool _busy = false;

  int get _total => _foods.fold(0, (int a, DietFood f) => a + f.kcal);

  Future<void> _save() async {
    final String? id = widget.meal.id;
    final AppLocalizations l = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (id == null) {
      navigator.pop();
      return;
    }
    setState(() => _busy = true);
    try {
      // Drop empty draft rows (see `dietNewFood` placeholder) so a
      // translation string never lands in stored food names.
      final List<FoodItem> foods = <FoodItem>[
        for (final DietFood f in _foods)
          if (f.name.trim().isNotEmpty)
            FoodItem(name: f.name.trim(), calories: f.kcal),
      ];
      await ref
          .read(dietRepositoryProvider)
          .updateEntry(
            id: id,
            mealType: _type.name,
            foods: foods,
            totalCalories: foods.fold<int>(
              0,
              (int a, FoodItem f) => a + f.calories,
            ),
          );
      // Sheet dismissed mid-save → don't pop the page below.
      if (!mounted) return;
      ref.invalidate(dietTodayProvider);
      // 기간 뷰(이번 주·이번 달)는 오늘을 dietByDateProvider 로 읽는다.
      // 같이 비우지 않으면 끼니를 바꿔도 기간 막대만 옛 값에 머문다.
      ref.invalidate(dietByDateProvider(nowKst()));
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l.dietSaved)));
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l.dietSaveFailed)));
    }
  }

  Future<void> _confirmDelete() async {
    final String? id = widget.meal.id;
    if (id == null) {
      Navigator.of(context).pop();
      return;
    }
    final AppLocalizations l = AppLocalizations.of(context);
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text(l.dietDeleteTitle),
            content: Text(l.dietDeleteConfirm),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l.dietCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                ),
                child: Text(l.dietDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(dietRepositoryProvider).deleteEntry(id);
      // Sheet dismissed mid-delete → don't pop the page below.
      if (!mounted) return;
      ref.invalidate(dietTodayProvider);
      // 기간 뷰(이번 주·이번 달)는 오늘을 dietByDateProvider 로 읽는다.
      // 같이 비우지 않으면 끼니를 바꿔도 기간 막대만 옛 값에 머문다.
      ref.invalidate(dietByDateProvider(nowKst()));
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l.dietDeleted)));
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l.dietDeleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    // Block back/drag dismiss while a save/delete request is in flight.
    final Widget page = _pageShell(
      Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: <Widget>[
                _CircleClose(
                  icon: Icons.arrow_back,
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l.dietMealSheetTitle(mealBadge(l, widget.meal.mealType)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FigmaColors.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    l.dietSave,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.primary,
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
              children: <Widget>[
                _card(<Widget>[
                  _FieldLabel(l.dietMealInfo),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      for (final MealType t in _types) ...<Widget>[
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: _type == t,
                            child: GestureDetector(
                              onTap: () => setState(() => _type = t),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _type == t
                                      ? FigmaColors.primaryA(0.10)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _type == t
                                        ? FigmaColors.primary
                                        : FigmaColors.hairline,
                                  ),
                                ),
                                child: Text(
                                  mealBadge(l, t),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: _type == t
                                        ? FigmaColors.primary
                                        : AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (t != _types.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _FieldLabel(l.dietEatenTime),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FigmaColors.statBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.schedule,
                              size: 14,
                              color: FigmaColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.meal.time,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: FigmaColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),
                _card(<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: _FieldLabel(l.dietEatenFood)),
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _foods = <DietFood>[
                              ..._foods,
                              // Empty draft name; the localized label is shown
                              // only as a placeholder and is validated out on save.
                              const DietFood('', 0),
                            ],
                          ),
                          child: Text(
                            l.dietAddFood,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.dietEditFoodHint,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (int i = 0; i < _foods.length; i++) ...<Widget>[
                    _FoodRow(
                      index: i + 1,
                      food: _foods[i],
                      onDelete: () => setState(
                        () => _foods = <DietFood>[..._foods]..removeAt(i),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Divider(height: 16, color: FigmaColors.hairline),
                  Row(
                    children: <Widget>[
                      Text(
                        l.dietTotalCalories,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_total ${l.unitKcal}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FigmaColors.primary,
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),
                _card(<Widget>[
                  _FieldLabel(l.dietNutritionInfo),
                  const SizedBox(height: 4),
                  Text(
                    l.dietEditNutritionHint,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _NutrientRow(
                    label: l.dietSodium,
                    hint: l.dietSodiumHint,
                    value: '${widget.meal.sodium}',
                    unit: l.dietUnitMg,
                  ),
                  const SizedBox(height: 10),
                  _NutrientRow(
                    label: l.dietSugar,
                    hint: l.dietSugarHint,
                    value: '${widget.meal.sugar}',
                    unit: l.dietUnitG,
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _confirmDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  side: const BorderSide(color: Color(0x33FF3B30)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(
                  l.dietDeleteMeal,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return PopScope(canPop: !_busy, child: page);
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
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: FigmaColors.ink,
    ),
  );
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.index,
    required this.food,
    required this.onDelete,
  });
  final int index;
  final DietFood food;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.hairline),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: FigmaColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              food.name.trim().isEmpty ? l.dietNewFood : food.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FigmaColors.ink,
              ),
            ),
          ),
          Text(
            '${food.kcal}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            l.unitKcal,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: l.a11yRemoveFood,
            child: GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.cancel,
                size: 18,
                color: Color(0xFFFFB4A8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.unit,
  });
  final String label;
  final String hint;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.hairline),
      ),
      child: Row(
        children: <Widget>[
          Container(width: 3, height: 34, color: FigmaColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.ink,
                  ),
                ),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: FigmaColors.ink,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleClose extends StatelessWidget {
  const _CircleClose({required this.onTap, this.icon = Icons.close});
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F6F8),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // 아이콘만 있는 버튼이라 무엇을 닫는지 말할 데가 없다(#972).
        child: Tooltip(
          message: MaterialLocalizations.of(context).closeButtonTooltip,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 16, color: FigmaColors.textSub),
          ),
        ),
      ),
    );
  }
}
