import 'dart:async';

import 'package:flutter/material.dart';

import 'package:oncare_trainer/design_system/tokens/spacing.dart';
import 'package:oncare_trainer/design_system/tokens/toast.dart';

/// 토스트가 전하는 소식의 종류.
///
/// 아이콘과 머무는 시간만 달라진다 — 바탕색까지 갈라 놓으면 성공 토스트와
/// 실패 토스트가 같은 앱의 같은 부품으로 보이지 않는다.
enum AppToastKind { info, success, error }

/// 토스트에 붙는 동작 버튼. 눌리면 [onTap]을 부르고 토스트를 닫는다.
class AppToastAction {
  const AppToastAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

/// 화면 위쪽에 잠깐 뜨는 알림을 띄운다. (#1378)
///
/// 사용자 앱의 `showAppToast`(#1259)와 같은 자리다. **`SnackBar`가 아니라
/// 루트 오버레이에 얹는다** — 스낵바는 `Scaffold` 안에 그려지므로 대화상자
/// 위에서 결과를 알려야 하는 자리(리포트 전송 완료)에서는 가려질 수 있다.
void showAppToast(
  BuildContext context,
  String message, {
  AppToastKind kind = AppToastKind.info,
  AppToastAction? action,
  Duration? duration,
}) {
  AppToastHost.of(context).show(message, kind: kind, action: action, duration: duration);
}

/// 토스트를 띄우는 손잡이. 화면이 사라진 뒤에도 쓸 수 있도록 오버레이를 미리
/// 잡아 둔다.
class AppToastHost {
  const AppToastHost._(this._overlay);

  final OverlayState _overlay;

  /// 지금 떠 있는 토스트. 한 번에 하나만 둔다 — 사용자가 빠르게 두 번 저장하면
  /// 뒤늦게 뜨는 첫 토스트는 이미 지난 소식이다.
  static _AppToastHandle? _visible;

  static AppToastHost of(BuildContext context) =>
      AppToastHost._(Overlay.of(context, rootOverlay: true));

  void show(
    String message, {
    AppToastKind kind = AppToastKind.info,
    AppToastAction? action,
    Duration? duration,
  }) {
    _visible?.dismiss();
    late final _AppToastHandle handle;
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) => _AppToast(
        message: message,
        kind: kind,
        action: action,
        duration:
            duration ??
            (action != null
                ? AppToastStyle.actionDuration
                : (kind == AppToastKind.error
                      ? AppToastStyle.errorDuration
                      : AppToastStyle.duration)),
        onDismissed: () => handle.dismiss(),
      ),
    );
    handle = _AppToastHandle(entry);
    _visible = handle;
    _overlay.insert(entry);
  }
}

class _AppToastHandle {
  _AppToastHandle(this._entry);

  final OverlayEntry _entry;
  bool _removed = false;

  void dismiss() {
    if (_removed) return;
    _removed = true;
    if (AppToastHost._visible == this) AppToastHost._visible = null;
    // 오버레이가 이미 사라진 뒤(앱 종료·테스트 정리)라면 걷을 것도 없다.
    if (_entry.mounted) _entry.remove();
  }
}

class _AppToast extends StatefulWidget {
  const _AppToast({
    required this.message,
    required this.kind,
    required this.duration,
    required this.onDismissed,
    this.action,
  });

  final String message;
  final AppToastKind kind;
  final AppToastAction? action;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppToastStyle.enterDuration,
    reverseDuration: AppToastStyle.exitDuration,
  );
  Timer? _dwell;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dwell = Timer(widget.duration, _hide);
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _hide() {
    _dwell?.cancel();
    if (!mounted) {
      widget.onDismissed();
      return;
    }
    _controller.reverse().whenComplete(widget.onDismissed);
  }

  void _runAction() {
    widget.action?.onTap();
    _hide();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Positioned(
      top: MediaQuery.paddingOf(context).top + AppToastStyle.topGap,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.6),
          end: Offset.zero,
        ).animate(curve),
        child: FadeTransition(
          opacity: curve,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppToastStyle.maxWidth,
                ),
                child: _pill(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: GestureDetector(
        // 먼저 읽고 치울 수 있게 한다 — 눌러도, 위로 밀어도 사라진다.
        onTap: widget.action == null ? _hide : null,
        onVerticalDragEnd: (DragEndDetails details) {
          if ((details.primaryVelocity ?? 0) < 0) _hide();
        },
        child: Material(
          color: AppToastStyle.background,
          elevation: 6,
          borderRadius: AppToastStyle.borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(_icon(widget.kind), size: 20, color: _iconColor(widget.kind)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    widget.message,
                    style: AppToastStyle.contentTextStyle,
                  ),
                ),
                if (widget.action case final action?) ...[
                  const SizedBox(width: AppSpacing.md),
                  GestureDetector(
                    key: const ValueKey<String>('app-toast-action'),
                    onTap: _runAction,
                    child: Text(action.label, style: AppToastStyle.actionTextStyle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _icon(AppToastKind kind) {
  switch (kind) {
    case AppToastKind.success:
      return Icons.check_circle_rounded;
    case AppToastKind.error:
      return Icons.error_rounded;
    case AppToastKind.info:
      return Icons.info_rounded;
  }
}

Color _iconColor(AppToastKind kind) {
  switch (kind) {
    case AppToastKind.success:
      return AppToastStyle.successIcon;
    case AppToastKind.error:
      return AppToastStyle.errorIcon;
    case AppToastKind.info:
      return AppToastStyle.infoIcon;
  }
}
