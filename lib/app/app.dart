import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../theme/app_theme.dart';
import 'routes.dart';

class RunStrictApp extends ConsumerWidget {
  const RunStrictApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'RUN',
      theme: AppTheme.themeData,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
