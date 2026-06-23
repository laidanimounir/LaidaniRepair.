import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:laidani_repair/core/constants/app_constants.dart';
import 'package:laidani_repair/core/router/app_router.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/theme_provider.dart';
import 'package:laidani_repair/core/providers/shortcuts_provider.dart';
import 'package:laidani_repair/core/providers/locale_provider.dart';
import 'package:laidani_repair/core/localization/app_localizations.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';
import 'package:laidani_repair/features/pos/presentation/providers/pos_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env file not available — fallback values in AppConstants will be used
  }

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
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'LaidaniRepair ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        return _ShortcutWrapper(child: child!);
      },
    );
  }
}

class _ShortcutWrapper extends ConsumerWidget {
  final Widget child;
  const _ShortcutWrapper({required this.child});

  void _handleHelp(BuildContext context) {
    showKeyboardHelpDialog(context);
  }

  void _navigateByIndex(BuildContext context, WidgetRef ref, int index) {
    final isOwner = ref.read(isOwnerProvider);
    final visibleItems = _navItemRoutes
        .where((item) => !item.ownerOnly || isOwner)
        .toList();
    if (index >= 0 && index < visibleItems.length) {
      context.go(visibleItems[index].route);
    }
  }

  void _handleCtrlE(BuildContext context, WidgetRef ref) {
    ref.read(exportCsvRequestProvider.notifier).state++;
  }

  void _handleCtrlN(BuildContext context, WidgetRef ref) {
    ref.read(newTicketRequestProvider.notifier).state++;
  }

  void _handleCtrlP(BuildContext context, WidgetRef ref) {
    ref.read(printRequestProvider.notifier).state++;
  }

  void _handleCtrlF(BuildContext context) {
    try {
      showSearch(
        context: context,
        delegate: _GlobalShortcutSearchDelegate(),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f1): () => _handleHelp(context),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _handleCtrlF(context),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () => _handleCtrlE(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _handleCtrlN(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () => _handleCtrlP(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => ref.read(posKioskModeProvider.notifier).state = !ref.read(posKioskModeProvider),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => _navigateByIndex(context, ref, 0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => _navigateByIndex(context, ref, 1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => _navigateByIndex(context, ref, 2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => _navigateByIndex(context, ref, 3),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => _navigateByIndex(context, ref, 4),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true): () => _navigateByIndex(context, ref, 5),
        const SingleActivator(LogicalKeyboardKey.digit7, control: true): () => _navigateByIndex(context, ref, 6),
        const SingleActivator(LogicalKeyboardKey.digit8, control: true): () => _navigateByIndex(context, ref, 7),
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}

class _NavItemRoute {
  final String route;
  final bool ownerOnly;
  const _NavItemRoute({required this.route, this.ownerOnly = false});
}

const _navItemRoutes = <_NavItemRoute>[
  _NavItemRoute(route: AppConstants.routeDashboard),
  _NavItemRoute(route: AppConstants.routePos),
  _NavItemRoute(route: AppConstants.routeRepairs),
  _NavItemRoute(route: AppConstants.routeTechnicianBoard),
  _NavItemRoute(route: AppConstants.routeAttendance),
  _NavItemRoute(route: AppConstants.routeEmployees, ownerOnly: true),
  _NavItemRoute(route: AppConstants.routeClients),
  _NavItemRoute(route: AppConstants.routeInventory, ownerOnly: true),
  _NavItemRoute(route: AppConstants.routePurchases, ownerOnly: true),
  _NavItemRoute(route: AppConstants.routeExpenses, ownerOnly: true),
  _NavItemRoute(route: AppConstants.routeAudit, ownerOnly: true),
  _NavItemRoute(route: '/shell/reports', ownerOnly: true),
  _NavItemRoute(route: '/shell/repairs-report', ownerOnly: true),
  _NavItemRoute(route: AppConstants.routePromotions, ownerOnly: true),
];

class _GlobalShortcutSearchDelegate extends SearchDelegate<String?> {
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear),
      onPressed: () => query = '',
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Tapez pour rechercher...', style: TextStyle(color: Color(0xFF8A9BB4))),
      );
    }
    return Center(
      child: Text('Recherche: $query', style: const TextStyle(color: Color(0xFF8A9BB4))),
    );
  }
}