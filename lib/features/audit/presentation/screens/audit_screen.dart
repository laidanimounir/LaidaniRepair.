import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _auditLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('audit_logs')
      .select('*, profiles(full_name)')
      .order('created_at', ascending: false)
      .limit(200);
});

// ─── Audit Screen ─────────────────────────────────────────────────────────────

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_auditLogsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainer,
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A50))),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_edu, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text("Journal d'audit", style: TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w700, fontSize: 18)),
                const Spacer(),
                logsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => Text('${list.length} entrées',
                      style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.onSurfaceMuted, size: 18),
                  onPressed: () => ref.invalidate(_auditLogsProvider),
                ),
              ],
            ),
          ),
          // Logs list
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error))),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_edu_outlined, size: 48, color: AppTheme.onSurfaceMuted),
                        SizedBox(height: 12),
                        Text("Aucune entrée dans le journal", style: TextStyle(color: AppTheme.onSurfaceMuted)),
                        SizedBox(height: 4),
                        Text("Les actions seront enregistrées automatiquement par les triggers.",
                            style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    final action = log['action_type'] ?? '';
                    final table = log['table_name'] ?? '';
                    final worker = log['profiles']?['full_name'] ?? 'Système';
                    final date = DateTime.tryParse(log['created_at'] ?? '')?.toString().substring(0, 19) ?? '';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2A2A50)),
                      ),
                      child: Row(
                        children: [
                          // Action icon
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _actionColor(action).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_actionIcon(action), size: 16, color: _actionColor(action)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _actionColor(action).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(action.toUpperCase(),
                                          style: TextStyle(color: _actionColor(action), fontSize: 10, fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(table, style: const TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('$worker • $date',
                                    style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          // View details
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.onSurfaceMuted),
                            onPressed: () => _showLogDetail(context, log),
                          ),
                        ],
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

Color _actionColor(String action) {
  switch (action.toLowerCase()) {
    case 'insert': return Colors.greenAccent;
    case 'update': return Colors.blueAccent;
    case 'delete': return AppTheme.error;
    default: return AppTheme.onSurfaceMuted;
  }
}

IconData _actionIcon(String action) {
  switch (action.toLowerCase()) {
    case 'insert': return Icons.add_circle_outline;
    case 'update': return Icons.edit_outlined;
    case 'delete': return Icons.delete_outline;
    default: return Icons.info_outline;
  }
}

void _showLogDetail(BuildContext context, Map<String, dynamic> log) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(_actionIcon(log['action_type'] ?? ''), color: _actionColor(log['action_type'] ?? ''), size: 20),
          const SizedBox(width: 8),
          Text('${(log['action_type'] ?? '').toUpperCase()} — ${log['table_name'] ?? ''}'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (log['old_data'] != null) ...[
                const Text('Anciennes données:', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                  child: Text(log['old_data'].toString(), style: const TextStyle(color: AppTheme.onSurface, fontSize: 11, fontFamily: 'monospace')),
                ),
                const SizedBox(height: 12),
              ],
              if (log['new_data'] != null) ...[
                const Text('Nouvelles données:', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                  child: Text(log['new_data'].toString(), style: const TextStyle(color: AppTheme.onSurface, fontSize: 11, fontFamily: 'monospace')),
                ),
              ],
              if (log['old_data'] == null && log['new_data'] == null)
                const Text('Aucune donnée détaillée disponible.', style: TextStyle(color: AppTheme.onSurfaceMuted)),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
}
