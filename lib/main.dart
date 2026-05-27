import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:laidani_repair/core/constants/app_constants.dart';
import 'package:laidani_repair/core/router/app_router.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(400, 600),
    center: true,
    fullScreen: false,
    backgroundColor: Color(0xFF050914),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'LaidaniRepair ERP',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: _LaidaniRepairApp(),
    ),
  );
}

class _LaidaniRepairApp extends ConsumerWidget {
  const _LaidaniRepairApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'LaidaniRepair ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}