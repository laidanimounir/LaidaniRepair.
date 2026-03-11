import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

// --- Cyber Glass Theme Constants ---
const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonPurple = Color(0xFFB000FF);
const Color _dangerNeon = Colors.redAccent;
const Color _successNeon = Colors.greenAccent;

// ─── Providers ─────────────────────────────────────────────────────────────────

// 1. Raw Stream of Audit Logs
final _auditLogsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('audit_logs')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(300)
      .map((data) => List<Map<String, dynamic>>.from(data));
});

// 2. Profiles Mapping Provider (To grab employee names)
final _profilesProvider = FutureProvider<Map<String, String>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client.from('profiles').select('id, full_name');
  final map = <String, String>{};
  for (var row in res) {
    map[row['id'].toString()] = row['full_name']?.toString() ?? 'Inconnu';
  }
  return map;
});

// 3. Computed Provider (Combines stream + profiles + active filter)
final _logFilterProvider = StateProvider<String>((ref) => 'All');

final _mappedAuditLogsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final streamAsync = ref.watch(_auditLogsStreamProvider);
  final profilesAsync = ref.watch(_profilesProvider);
  final filter = ref.watch(_logFilterProvider);

  if (streamAsync.isLoading || profilesAsync.isLoading && !profilesAsync.hasValue) {
    return const AsyncValue.loading();
  }
  
  if (streamAsync.hasError) return AsyncValue.error(streamAsync.error!, streamAsync.stackTrace!);
  
  final logs = streamAsync.value ?? [];
  final profilesMap = profilesAsync.value ?? {};

  List<Map<String, dynamic>> filteredLogs = [];
  
  for (var log in logs) {
    final action = (log['action_type'] ?? '').toString().toUpperCase();
    final table = (log['table_name'] ?? '').toString().toLowerCase();
    
    // Apply filters
    bool keep = false;
    if (filter == 'All') keep = true;
    else if (filter == 'Repairs' && (table.contains('repair') || table.contains('ticket'))) keep = true;
    else if (filter == 'Sales' && table.contains('sale')) keep = true;
    else if (filter == 'Purchases' && (table.contains('purchase') || table.contains('supplier'))) keep = true;
    else if (filter == 'Deletes' && action == 'DELETE') keep = true;

    if (keep) {
      final newLog = Map<String, dynamic>.from(log);
      // Determine worker_id field (fallback to 'worker_id' or 'user_id' based on generic schema)
      final workerId = (newLog['user_id'] ?? newLog['worker_id'])?.toString() ?? '';
      newLog['worker_name'] = profilesMap[workerId] ?? 'Système / Trigger';
      filteredLogs.add(newLog);
    }
  }

  return AsyncValue.data(filteredLogs);
});

// ─── Translators ─────────────────────────────────────────────────────────────

String _translateAction(String action) {
  switch (action.toUpperCase()) {
    case 'INSERT': return 'Création / Ajout';
    case 'UPDATE': return 'Modification';
    case 'DELETE': return 'Suppression';
    default: return action;
  }
}

String _translateTable(String table) {
  switch (table.toLowerCase()) {
    case 'repair_tickets': return 'Ticket de Réparation';
    case 'repair_parts': return 'Pièce de Réparation';
    case 'sales': return 'Vente (Facture)';
    case 'sale_items': return 'Article Vendu';
    case 'purchase_invoices': return 'Achat Fournisseur';
    case 'purchase_items': return 'Article Acheté';
    case 'products': return 'Article de Stock';
    case 'suppliers': return 'Fournisseur';
    case 'customers': return 'Client';
    case 'customer_payments': return 'Paiement Client';
    default: return table.replaceAll('_', ' ').toUpperCase();
  }
}

String _getHumanTitle(String action, String table) {
  final tableName = _translateTable(table);
  if (action == 'INSERT') return 'Nouveau : $tableName';
  if (action == 'UPDATE') return '$tableName Modifié';
  if (action == 'DELETE') return '$tableName Supprimé';
  return '$action $tableName';
}

String _translateKey(String key) {
  switch (key) {
    case 'device_name': return 'Appareil';
    case 'client_name': return 'Client';
    case 'phone_number': return 'Téléphone';
    case 'problem_description': return 'Problème';
    case 'estimated_cost': return 'Coût Estimé';
    case 'final_cost': return 'Prix Final';
    case 'status': return 'Statut';
    case 'stock_quantity': return 'Quantité';
    case 'product_name': return 'Produit';
    case 'purchase_price': return 'Prix Achat';
    case 'reference_price': return 'Prix Vente';
    case 'supplier_name': return 'Fournisseur';
    case 'total_due': return 'Dette (Dû)';
    case 'total_amount': return 'Montant Total';
    case 'paid_amount': return 'Montant Payé';
    case 'part_name': return 'Pièce';
    case 'part_cost': return 'Coût Pièce';
    case 'part_status': return 'Statut Pièce';
    case 'category_id': return 'Catégorie';
    case 'barcode': return 'Code Barres';
    case 'min_stock': return 'Seuil Min';
    case 'advance_payment': return 'Avance (Dépôt)';
    case 'client_name_temp': return 'Nom Client';
    case 'client_phone_temp': return 'Tél Client';
    case 'qr_code_hash': return 'Code QR';
    case 'issue_description': return 'Description Panne';
    default: return key.replaceAll('_', ' ');
  }
}

// ─── UI Widgets ───────────────────────────────────────────────────────────────

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_mappedAuditLogsProvider);
    final currentFilter = ref.watch(_logFilterProvider);

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Column(
        children: [
          // Header & Filter Bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: _panelDark,
              border: Border(bottom: BorderSide(color: _glassBorder, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _neonPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _neonPurple.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.history_edu, color: _neonPurple, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text('JOURNAL D\'AUDIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                  ],
                ),
                const SizedBox(height: 24),
                // Smart Filters Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Repairs', 'Sales', 'Purchases', 'Deletes'].map((filter) {
                      final isSelected = currentFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ChoiceChip(
                          label: Text(filter == 'All' ? 'Tout' : (filter == 'Deletes' ? 'Suppressions' : filter), style: TextStyle(color: isSelected ? Colors.white : _textMuted, fontWeight: FontWeight.bold)),
                          selected: isSelected,
                          selectedColor: filter == 'Deletes' ? _dangerNeon.withOpacity(0.2) : _neonPurple.withOpacity(0.2),
                          backgroundColor: _bgCarbon,
                          side: BorderSide(color: isSelected ? (filter == 'Deletes' ? _dangerNeon : _neonPurple) : _glassBorder),
                          onSelected: (_) => ref.read(_logFilterProvider.notifier).state = filter,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Timeline List
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _neonPurple)),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_edu_outlined, size: 64, color: _textMuted.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        const Text('Aucune entrée trouvée.', style: TextStyle(color: _textMuted)),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildTimelineCard(context, log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, Map<String, dynamic> log) {
    final action = (log['action_type'] ?? '').toString().toUpperCase();
    final table = (log['table_name'] ?? '').toString();
    final workerName = log['worker_name'] ?? 'Système';
    final rawDate = DateTime.tryParse(log['created_at'] ?? '') ?? DateTime.now();
    
    // Time ago & Full date
    final diff = DateTime.now().difference(rawDate);
    String timeAgo;
    if (diff.inMinutes < 1) timeAgo = "À l'instant";
    else if (diff.inHours < 1) timeAgo = "Il y a ${diff.inMinutes} min";
    else if (diff.inDays < 1) timeAgo = "Il y a ${diff.inHours} h";
    else timeAgo = "Il y a ${diff.inDays} jours";
    
    final fullDate = "${rawDate.day.toString().padLeft(2, '0')}/${rawDate.month.toString().padLeft(2, '0')}/${rawDate.year} ${rawDate.hour.toString().padLeft(2, '0')}:${rawDate.minute.toString().padLeft(2, '0')}";

    final isDelete = action == 'DELETE';
    final isDanger = isDelete;
    
    final accentColor = isDanger ? _dangerNeon : (action == 'UPDATE' ? Colors.orangeAccent : _successNeon);
    IconData iconData = Icons.info_outline;
    if (table.contains('repair')) iconData = Icons.build_circle_outlined;
    else if (table.contains('sale') || table.contains('purchase')) iconData = Icons.shopping_cart_outlined;
    else if (table.contains('product')) iconData = Icons.inventory_2_outlined;
    
    if (isDelete) iconData = Icons.delete_forever;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _panelDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDanger ? accentColor.withOpacity(0.5) : _glassBorder),
        boxShadow: isDanger ? [BoxShadow(color: accentColor.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAuditDetails(context, log, action, accentColor),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: accentColor, size: 20),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getHumanTitle(action, table),
                            style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                          ),
                          Text(
                            '$timeAgo • $fullDate',
                            style: const TextStyle(color: _textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: _textMuted),
                          const SizedBox(width: 4),
                          Text(workerName, style: const TextStyle(color: _textMuted, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAuditDetails(BuildContext context, Map<String, dynamic> log, String action, Color accentColor) {
    // Parse json
    Map<String, dynamic> oldData = {};
    Map<String, dynamic> newData = {};
    
    if (log['old_data'] != null) {
      try {
        oldData = (log['old_data'] is String) ? jsonDecode(log['old_data']) : Map<String, dynamic>.from(log['old_data']);
      } catch (_) {}
    }
    if (log['new_data'] != null) {
      try {
        newData = (log['new_data'] is String) ? jsonDecode(log['new_data']) : Map<String, dynamic>.from(log['new_data']);
      } catch (_) {}
    }

    const ignoredKeys = {'id', 'uuid', 'created_at', 'updated_at', 'worker_id', 'user_id', 'client_id', 'worker_name', 'invoice_id', 'category_id', 'product_id', 'supplier_id'};
    final allKeys = <String>{...oldData.keys, ...newData.keys}
        .where((k) => !ignoredKeys.contains(k))
        .toList()..sort();

    final changedKeys = allKeys.where((k) {
      if (action == 'UPDATE') return oldData[k]?.toString() != newData[k]?.toString();
      return true;
    }).toList();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: _panelDark.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: accentColor.withOpacity(0.5), width: 1.5)),
        child: Container(
          width: 800,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Auto-size to prevent unnecessary scrolling
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.manage_search, color: accentColor),
                  const SizedBox(width: 12),
                  Text(action == 'UPDATE' ? 'CHANGEMENTS DÉTECTÉS' : 'DÉTAILS DU JOURNAL', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: _glassBorder, height: 32),
              
              if (changedKeys.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Aucune modification détectée sur les champs visibles.', style: TextStyle(color: _textMuted))))
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: action == 'UPDATE'
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: changedKeys.map((key) {
                            final humanKey = _translateKey(key).toUpperCase();
                            final oldVal = oldData[key]?.toString() ?? 'Rien';
                            final newVal = newData[key]?.toString() ?? 'Rien';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(humanKey, style: const TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: _bgCarbon.withOpacity(0.4), borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(oldVal, style: const TextStyle(color: Colors.redAccent, decoration: TextDecoration.lineThrough, fontFamily: 'monospace'))),
                                        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_forward_rounded, color: _textMuted, size: 16)),
                                        Expanded(child: Text(newVal, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      : Wrap(
                          spacing: 20,
                          runSpacing: 16,
                          children: changedKeys.map((key) {
                            final humanKey = _translateKey(key).toUpperCase();
                            final val = action == 'DELETE' ? (oldData[key]?.toString() ?? 'Rien') : (newData[key]?.toString() ?? 'Rien');

                            return SizedBox(
                              width: 220,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _bgCarbon.withOpacity(0.4), borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(humanKey, style: const TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(val, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                  ),
                ),
                
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('FERMER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
