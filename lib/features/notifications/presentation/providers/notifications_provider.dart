import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'low_stock', 'overdue_repair', 'pending_reminder'
  final DateTime createdAt;
  final bool isRead;
  final String? route;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.route,
  });
}

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final client = Supabase.instance.client;
  final notifications = <AppNotification>[];

  final lowStock = await client
      .from('products')
      .select('product_name, stock_quantity, min_stock')
      .limit(50);
  for (final p in lowStock) {
    final stock = (p['stock_quantity'] as num?)?.toInt() ?? 0;
    final minStock = (p['min_stock'] as num?)?.toInt() ?? 5;
    if (minStock > 0 && stock <= minStock) {
      notifications.add(AppNotification(
        id: 'stock_${p['product_name']}',
        title: 'Stock bas',
        message: '${p['product_name']}: $stock unités (min: $minStock)',
        type: 'low_stock',
        createdAt: DateTime.now(),
        route: '/shell/inventory',
      ));
    }
  }

  final overdueRepairs = await client
      .from('repair_tickets')
      .select('device_name, estimated_completion_date, status, client_name_temp')
      .filter('status', 'in', '("En attente")')
      .limit(10);
  for (final r in overdueRepairs) {
    final estimated = r['estimated_completion_date'] as String?;
    if (estimated != null) {
      final estDate = DateTime.tryParse(estimated);
      if (estDate != null && estDate.isBefore(DateTime.now())) {
        notifications.add(AppNotification(
          id: 'overdue_${r.hashCode}',
          title: 'Réparation en retard',
          message: '${r['device_name'] ?? 'Appareil'} - Dépassé depuis ${DateTime.now().difference(estDate).inDays} jours',
          type: 'overdue_repair',
          createdAt: DateTime.now(),
          route: '/shell/repairs',
        ));
      }
    }
  }

  final pendingReminders = await client
      .from('maintenance_reminders')
      .select('message, remind_at, customers(full_name)')
      .filter('remind_at', 'lte', DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10))
      .limit(10);
  for (final r in pendingReminders) {
    notifications.add(AppNotification(
      id: 'reminder_${r.hashCode}',
      title: 'Rappel maintenance',
      message: r['message']?.toString() ?? 'Maintenance à prévoir',
      type: 'pending_reminder',
      createdAt: DateTime.now(),
      route: '/shell/reminders',
    ));
  }

  return notifications;
});