class AppConstants {
  AppConstants._();

  // Supabase
  static const String supabaseUrl = 'https://igxpwxfruasfpvfagbaw.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlneHB3eGZydWFzZnB2ZmFnYmF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5MzY5MzEsImV4cCI6MjA4ODUxMjkzMX0.sp6Cx1pzaQuaZxhxTtGZJZa7FUUAmL9z0jGhrTqCq0E';

  // App
  static const String appName = 'LaidaniRepair';

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

  /// Routes accessible only by 'owner' role
  static const List<String> ownerOnlyRoutes = [
    routeInventory,
    routePurchases,
    routeExpenses,
    routeAudit,
  ];
}
