import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';

final _remindersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('maintenance_reminders')
      .select('*, customers(full_name, phone_number), repair_tickets(device_name)')
      .order('remind_at', ascending: true)
      .limit(200);
});

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(_remindersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainer,
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A50))),
            ),
            child: Row(
              children: [
                const Icon(Icons.notification_important, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Rappels de Maintenance',
                    style: TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w700, fontSize: 18)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.onSurfaceMuted, size: 18),
                  onPressed: () => ref.invalidate(_remindersProvider),
                ),
              ],
            ),
          ),
          Expanded(
            child: remindersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error))),
              data: (reminders) {
                if (reminders.isEmpty) {
                  return const Center(child: Text('Aucun rappel programmé', style: TextStyle(color: AppTheme.onSurfaceMuted)));
                }
                final now = DateTime.now();
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: reminders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = reminders[i];
                    final customerName = r['customers']?['full_name'] ?? 'Client';
                    final deviceName = r['repair_tickets']?['device_name'] ?? 'Appareil';
                    final remindAt = DateTime.tryParse(r['remind_at']?.toString() ?? '');
                    final sent = r['sent'] as bool? ?? false;
                    final message = r['message'] as String? ?? '';
                    final isOverdue = remindAt != null && remindAt.isBefore(now);

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: sent ? Colors.greenAccent.withOpacity(0.15) : (isOverdue ? Colors.redAccent.withOpacity(0.15) : Colors.orangeAccent.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          sent ? Icons.check_circle : (isOverdue ? Icons.warning_amber : Icons.notifications_active),
                          color: sent ? Colors.greenAccent : (isOverdue ? Colors.redAccent : Colors.orangeAccent),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(customerName,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.onBackground)),
                          ),
                          if (remindAt != null)
                            Text(
                              DateFormat('dd/MM/yyyy').format(remindAt),
                              style: TextStyle(color: isOverdue ? Colors.redAccent : AppTheme.onSurfaceMuted, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      subtitle: Text('$deviceName — $message',
                          style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                      trailing: sent
                          ? const Icon(Icons.done_all, color: Colors.greenAccent, size: 18)
                          : IconButton(
                              icon: const Icon(Icons.mark_email_read, color: AppTheme.primary, size: 18),
                              tooltip: 'Marquer envoyé',
                              onPressed: () async {
                                final client = ref.read(supabaseClientProvider);
                                await client.from('maintenance_reminders').update({'sent': true}).eq('id', r['id']);
                                ref.invalidate(_remindersProvider);
                              },
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
