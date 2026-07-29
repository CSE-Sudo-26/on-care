import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:oncare_trainer/app/router/app_router.dart';
import 'package:oncare_trainer/design_system/theme/app_theme.dart';

/// Root widget for the trainer app. Wires the GoRouter and theme into a
/// [MaterialApp.router].
class OncareTrainerApp extends ConsumerWidget {
  const OncareTrainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'On-Care 트레이너',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
