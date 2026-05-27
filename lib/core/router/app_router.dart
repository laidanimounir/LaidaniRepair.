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
import 'package:laidani_repair/features/repairs/presentation/screens/technician_board_screen.dart';
import 'package:laidani_repair/features/clients/presentation/screens/clients_screen.dart';
import 'package:laidani_repair/features/stock/presentation/screens/inventory_screen.dart';
import 'package:laidani_repair/features/stock/presentation/screens/purchases_screen.dart';
import 'package:laidani_repair/features/employees/presentation/screens/employees_screen.dart';
import 'package:laidani_repair/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:laidani_repair/features/audit/presentation/screens/audit_screen.dart';
import 'package:laidani_repair/features/reports/presentation/screens/sales_reports_screen.dart';
import 'package:laidani_repair/features/reports/presentation/screens/repairs_report_screen.dart';
import 'package:laidani_repair/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:laidani_repair/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:laidani_repair/features/tracking/presentation/screens/tracking_screen.dart';
import 'package:laidani_repair/core/constants/app_constants.dart';
// تأكد من وجود هذا السطر تحديداً
import 'package:laidani_repair/features/repairs/presentation/screens/ticket_details_screen.dart';

class _GoRouterRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;
  bool _isAnimating = false;
  void lockForAnimation() => _isAnimating = true;

  void unlockAndNotify() {
    _isAnimating = false;
    notifyListeners();
  }

  _GoRouterRefreshNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.initialSession) {
        Future.delayed(const Duration(milliseconds: 2000), notifyListeners);
        return;
      }
      if (event.event == AuthChangeEvent.signedIn) {
        if (_isAnimating) return; 
        notifyListeners();
        return;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerRefreshProvider = Provider<_GoRouterRefreshNotifier>((ref) {
  final n = _GoRouterRefreshNotifier();
  ref.onDispose(n.dispose);
  return n;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: AppConstants.routeSplash,
    refreshListenable: refreshNotifier,
    debugLogDiagnostics: false,

    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null;
      final location = state.matchedLocation;

      if (location == AppConstants.routeSplash) return null;

      // Public tracking page - no auth required
      if (location.startsWith('/track/')) return null;

      if (!isLoggedIn) {
        return location == AppConstants.routeLogin
            ? null
            : AppConstants.routeLogin;
      }

      if (location == AppConstants.routeLogin ||
          location == AppConstants.routeSplash) {
        return AppConstants.routePos;
      }

      if (AppConstants.ownerOnlyRoutes.contains(location)) {
        final profile = ref.read(profileProvider).valueOrNull;
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
      GoRoute(
        path: '/track/:qr_code_hash',
        builder: (context, state) {
          final hash = state.pathParameters['qr_code_hash']!;
          return TrackingScreen(qrCodeHash: hash);
        },
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
            path: AppConstants.routeTechnicianBoard,
            builder: (_, __) => const TechnicianBoardScreen(),
          ),
          GoRoute(
            path: AppConstants.routeAttendance,
            builder: (_, __) => const AttendanceScreen(),
          ),
          GoRoute(
            path: AppConstants.routeEmployees,
            builder: (_, __) => const EmployeesScreen(),
          ),
          GoRoute(
            path: AppConstants.routeClients,
            builder: (_, __) => const ClientsScreen(),
          ),
          GoRoute(
            path: AppConstants.routeInventory,
            builder: (_, __) => const InventoryScreen(),
          ),
          GoRoute(
            path: AppConstants.routePurchases,
            builder: (_, __) => const PurchasesScreen(),
          ),
          GoRoute(
            path: AppConstants.routeExpenses,
            builder: (_, __) => const ExpensesScreen(),
          ),
          GoRoute(
            path: AppConstants.routeAudit,
            builder: (_, __) => const AuditScreen(),
          ),
          GoRoute(
            path: '/shell/reports',
            builder: (_, __) => const SalesReportsScreen(),
          ),
          GoRoute(
            path: '/shell/repairs-report',
            builder: (_, __) => const RepairsReportScreen(),
          ),
          GoRoute(
            path: AppConstants.routeDashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          // المسار الجديد مضاف هنا بشكل صحيح
          GoRoute(
            path: '/repair-details/:id', 
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return TicketDetailsScreen(ticketId: id);
            },
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