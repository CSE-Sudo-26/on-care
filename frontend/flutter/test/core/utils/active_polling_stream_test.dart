import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oncare/core/utils/active_polling_stream.dart';

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resume discards the in-flight response and immediately reloads',
    () async {
      final Completer<String> staleRequest = Completer<String>();
      final Completer<String> freshRequest = Completer<String>();
      final Completer<void> firstStarted = Completer<void>();
      final Completer<void> secondStarted = Completer<void>();
      final Completer<void> freshEmitted = Completer<void>();
      final List<String> emitted = <String>[];
      var calls = 0;

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final StreamSubscription<String> subscription =
          activePollingStream<String>(
            load: () {
              calls += 1;
              if (calls == 1) {
                firstStarted.complete();
                return staleRequest.future;
              }
              secondStarted.complete();
              return freshRequest.future;
            },
            interval: const Duration(days: 1),
          ).listen((String value) {
            emitted.add(value);
            if (value == 'fresh' && !freshEmitted.isCompleted) {
              freshEmitted.complete();
            }
          });

      try {
        await firstStarted.future;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

        expect(calls, 1);
        staleRequest.complete('stale');
        await secondStarted.future.timeout(const Duration(seconds: 1));

        expect(calls, 2);
        expect(emitted, isEmpty);

        freshRequest.complete('fresh');
        await freshEmitted.future.timeout(const Duration(seconds: 1));
        expect(emitted, <String>['fresh']);
      } finally {
        if (!staleRequest.isCompleted) staleRequest.complete('cleanup');
        if (!freshRequest.isCompleted) freshRequest.complete('cleanup');
        await subscription.cancel();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
    },
  );
}
