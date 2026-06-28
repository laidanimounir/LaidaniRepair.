import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  // Supabase
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw StateError(
        'SUPABASE_URL is not set. Make sure the .env file exists at the '
        'project root and contains SUPABASE_URL=<your-project-url>',
      );
    }
    return url;
  }

  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY is not set. Make sure the .env file exists at the '
        'project root and contains SUPABASE_ANON_KEY=<your-anon-key>',
      );
    }
    return key;
  }

  // App
  static String get appName => dotenv.env['APP_NAME'] ?? 'LaidaniRepair';
  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  // Roles
  static const String roleOwner = 'owner';
  static const String roleWorker = 'worker';

  // Routes
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routePos = '/shell/pos';
  static const String routeRepairs = '/shell/repairs';
  static const String routeClients = '/shell/clients';
  static const String routeInventory = '/shell/inventory';
  static const String routePurchases = '/shell/purchases';
  static const String routeExpenses = '/shell/expenses';
  static const String routeAudit = '/shell/audit';
  static const String routeDashboard = '/shell/dashboard';
  static const String routeTechnicianBoard = '/shell/technician-board';
  static const String routeAttendance = '/shell/attendance';
  static const String routeEmployees = '/shell/employees';
  static const String routePromotions = '/shell/promotions';
  static const String routeReminders = '/shell/reminders';
  static const String routeBackup = '/shell/backup';
  static const String routeBranches = '/shell/branches';
  static const String routeSettings = '/shell/settings';
  static const String routeImport = '/shell/import';
  static const String routeWarranty = '/shell/warranty';

  /// Routes accessible only by 'owner' role
  static const List<String> ownerOnlyRoutes = [
    routeInventory,
    routePurchases,
    routeExpenses,
    routeAudit,
    routeEmployees,
    routePromotions,
    routeBranches,
    routeSettings,
  ];
}
