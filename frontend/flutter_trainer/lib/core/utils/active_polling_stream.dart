import 'dart:async';

import 'package:flutter/widgets.dart';

/// Polls [load] while the stream has a listener and the application is in
/// the foreground.
///
/// The first failure is surfaced so an initial loading error can be shown.
/// Once a value has been emitted, transient failures are kept out of the
/// stream: consumers continue showing the last good value while the next
/// poll retries. Cancelling the subscription or backgrounding the app stops
/// the timer immediately.
Stream<T> activePollingStream<T>({
  required Future<T> Function() load,
  required Duration? interval,
  Stream<void>? refreshes,
}) {
  late final StreamController<T> controller;
  late final _LifecycleObserver lifecycleObserver;
  Timer? timer;
  StreamSubscription<void>? refreshSubscription;
  bool cancelled = false;
  bool loading = false;
  bool refreshPending = false;
  bool hasValue = false;
  int lifecycleGeneration = 0;
  bool foreground = _isForeground(WidgetsBinding.instance.lifecycleState);

  late void Function() scheduleNext;

  Future<void> poll() async {
    if (cancelled || loading || !foreground) return;
    loading = true;
    final int requestGeneration = lifecycleGeneration;
    try {
      final T value = await load();
      if (!cancelled &&
          foreground &&
          requestGeneration == lifecycleGeneration) {
        hasValue = true;
        controller.add(value);
      }
    } catch (error, stackTrace) {
      if (!cancelled &&
          foreground &&
          requestGeneration == lifecycleGeneration &&
          !hasValue) {
        controller.addError(error, stackTrace);
      }
    } finally {
      loading = false;
      if (refreshPending && !cancelled && foreground) {
        refreshPending = false;
        unawaited(poll());
      } else {
        scheduleNext();
      }
    }
  }

  scheduleNext = () {
    timer?.cancel();
    timer = null;
    final Duration? delay = interval;
    if (cancelled || !foreground || delay == null) return;
    timer = Timer(delay, () => unawaited(poll()));
  };

  void handleLifecycle(AppLifecycleState state) {
    final bool nextForeground = _isForeground(state);
    if (foreground == nextForeground) return;
    foreground = nextForeground;
    timer?.cancel();
    timer = null;
    if (!foreground) {
      lifecycleGeneration += 1;
      refreshPending = false;
    } else if (loading) {
      refreshPending = true;
    } else {
      unawaited(poll());
    }
  }

  void refreshNow() {
    if (cancelled || !foreground) return;
    timer?.cancel();
    timer = null;
    if (loading) {
      refreshPending = true;
    } else {
      unawaited(poll());
    }
  }

  lifecycleObserver = _LifecycleObserver(handleLifecycle);
  controller = StreamController<T>(
    onListen: () {
      foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
      WidgetsBinding.instance.addObserver(lifecycleObserver);
      refreshSubscription = refreshes?.listen((_) => refreshNow());
      if (foreground) unawaited(poll());
    },
    onCancel: () {
      cancelled = true;
      timer?.cancel();
      timer = null;
      unawaited(refreshSubscription?.cancel());
      refreshSubscription = null;
      WidgetsBinding.instance.removeObserver(lifecycleObserver);
      unawaited(controller.close());
    },
  );
  return controller.stream;
}

bool _isForeground(AppLifecycleState? state) =>
    state == null || state == AppLifecycleState.resumed;

class _LifecycleObserver with WidgetsBindingObserver {
  _LifecycleObserver(this.onChanged);

  final void Function(AppLifecycleState state) onChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChanged(state);
}
