import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';
import 'package:laidani_repair/features/auth/presentation/screens/login_screen.dart';
import 'package:laidani_repair/features/auth/presentation/screens/splash_screen.dart';
import 'package:laidani_repair/features/shell/presentation/screens/app_shell.dart';
import 'package:laidani_repair/features/pos/presentation/screens/pos_screen.dart';
import 'package:laidani_repair/features/repairs/presentation/screens/repairs_screen.dart';
import 'package:laidani_repair/features/clients/presentation/screens/clients_screen.dart';
import 'package:laidani_repair/features/stock/presentation/screens/stock_screen.dart';
import 'package:laidani_repair/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:laidani_repair/features/audit/presentation/screens/audit_screen.dart';
import 'package:laidani_repair/core/constants/app_constants.dart';

// ─── Router Refresh Notifier ───────────────────────────────────────────────

/// Bridges Supabase auth stream → GoRouter refresh mechanism.
class _GoRouterRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  _GoRouterRefreshNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _routerRefreshProvider = Provider<_GoRouterRefreshNotifier>((ref) {
  final n = _GoRouterRefreshNotifier();
  ref.onDispose(n.dispose);
  return n;
});

// ─── App Router ────────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: AppConstants.routeSplash,
    refreshListenable: refreshNotifier,
    debugLogDiagnostics: false,

    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null;
      final location = state.matchedLocation;

      // Always allow splash to load first
      if (location == AppConstants.routeSplash) return null;

      // Not logged in → go to login
      if (!isLoggedIn) {
        return location == AppConstants.routeLogin
            ? null
            : AppConstants.routeLogin;
      }

      // Logged in but on login/splash → go to POS
      if (location == AppConstants.routeLogin ||
          location == AppConstants.routeSplash) {
        return AppConstants.routePos;
      }

      // RBAC: owner-only routes
      if (AppConstants.ownerOnlyRoutes.contains(location)) {
        final profile = ref.read(profileProvider).valueOrNull;
        // If profile is still loading, let it through (shell will guard visually)
        if (profile != null && !profile.isOwner) {
          return AppConstants.routePos;
        }
      }

      return null;
    },

    routes: [
      GoRoute(
        path: AppConstants.routeSplash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.routeLogin,
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppConstants.routePos,
            builder: (_, __) => const PosScreen(),
          ),
          GoRoute(
            path: AppConstants.routeRepairs,
            builder: (_, __) => const RepairsScreen(),
          ),
          GoRoute(
            path: AppConstants.routeClients,
            builder: (_, __) => const ClientsScreen(),
          ),
          GoRoute(
            path: AppConstants.routeStock,
            builder: (_, __) => const StockScreen(),
          ),
          GoRoute(
            path: AppConstants.routeExpenses,
            builder: (_, __) => const ExpensesScreen(),
          ),
          GoRoute(
            path: AppConstants.routeAudit,
            builder: (_, __) => const AuditScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page introuvable : ${state.error}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
});
