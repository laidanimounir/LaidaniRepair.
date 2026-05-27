import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonPurple = Color(0xFFB000FF);
const Color _dangerNeon = Colors.redAccent;
const Color _successNeon = Colors.greenAccent;

final _auditLogsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('audit_logs')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(500)
      .map((data) => List<Map<String, dynamic>>.from(data));
});

final _profilesProvider = FutureProvider<Map<String, String>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client.from('profiles').select('id, full_name');
  final map = <String, String>{};
  for (var row in res) {
    map[row['id'].toString()] = row['full_name']?.toString() ?? 'Inconnu';
  }
  return map;
});

final _logFilterProvider = StateProvider<String>((ref) => 'All');
final _actionFilterProvider = StateProvider<String>((ref) => 'All');
final _userFilterProvider = StateProvider<String?>((ref) => null);

final _mappedAuditLogsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final streamAsync = ref.watch(_auditLogsStreamProvider);
  final profilesAsync = ref.watch(_profilesProvider);
  final tableFilter = ref.watch(_logFilterProvider);
  final actionFilter = ref.watch(_actionFilterProvider);
  final userFilter = ref.watch(_userFilterProvider);

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
    final workerId = (log['user_id'] ?? log['worker_id'])?.toString() ?? '';

    bool keep = true;
    if (tableFilter != 'All') {
      if (tableFilter == 'Repairs' && !(table.contains('repair') || table.contains('ticket'))) keep = false;
      else if (tableFilter == 'Sales' && !table.contains('sale')) keep = false;
      else if (tableFilter == 'Purchases' && !(table.contains('purchase') || table.contains('supplier'))) keep = false;
      else if (tableFilter == 'Deletes' && action != 'DELETE') keep = false;
    }
    if (actionFilter != 'All' && action != actionFilter) keep = false;
    if (userFilter != null && workerId != userFilter) keep = false;

    if (keep) {
      final newLog = Map<String, dynamic>.from(log);
      newLog['worker_name'] = profilesMap[workerId] ?? 'Système / Trigger';
      filteredLogs.add(newLog);
    }
  }

  return AsyncValue.data(filteredLogs);
});

String _translateAction(String action) {
  switch (action.toUpperCase()) {
    case 'INSERT': return 'Création';
    case 'UPDATE': return 'Modification';
    case 'DELETE': return 'Suppression';
    default: return action;
  }
}

String _translateTable(String table) {
  switch (table.toLowerCase()) {
    case 'repair_tickets': return 'Ticket Réparation';
    case 'repair_parts': return 'Pièce Réparation';
    case 'sales': return 'Vente';
    case 'sale_items': return 'Article Vendu';
    case 'purchase_invoices': return 'Achat Fournisseur';
    case 'purchase_items': return 'Article Acheté';
    case 'products': return 'Stock';
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
    case 'total_due': return 'Dette';
    case 'total_amount': return 'Montant Total';
    case 'paid_amount': return 'Montant Payé';
    case 'part_name': return 'Pièce';
    case 'part_cost': return 'Coût Pièce';
    case 'part_status': return 'Statut Pièce';
    case 'category_id': return 'Catégorie';
    case 'barcode': return 'Code Barres';
    case 'min_stock': return 'Seuil Min';
    case 'advance_payment': return 'Avance';
    case 'client_name_temp': return 'Nom Client';
    case 'client_phone_temp': return 'Tél Client';
    case 'qr_code_hash': return 'Code QR';
    case 'issue_description': return 'Panne';
    default: return key.replaceAll('_', ' ');
  }
}

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_mappedAuditLogsProvider);
    final currentFilter = ref.watch(_logFilterProvider);
    final currentActionFilter = ref.watch(_actionFilterProvider);
    final profilesAsync = ref.watch(_profilesProvider);

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Column(
        children: [
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
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.file_download, color: _neonPurple),
                      tooltip: 'Exporter CSV',
                      onPressed: () => _exportCsv(context, logsAsync.valueOrNull ?? []),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...['All', 'Repairs', 'Sales', 'Purchases', 'Deletes'].map((filter) {
                        final isSelected = currentFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter == 'All' ? 'Tout' : (filter == 'Deletes' ? 'Suppressions' : filter), style: TextStyle(color: isSelected ? Colors.white : _textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                            selected: isSelected,
                            selectedColor: filter == 'Deletes' ? _dangerNeon.withOpacity(0.2) : _neonPurple.withOpacity(0.2),
                            backgroundColor: _bgCarbon,
                            side: BorderSide(color: isSelected ? (filter == 'Deletes' ? _dangerNeon : _neonPurple) : _glassBorder),
                            onSelected: (_) => ref.read(_logFilterProvider.notifier).state = filter,
                          ),
                        );
                      }),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 28, color: _glassBorder),
                      const SizedBox(width: 12),
                      ...['All', 'INSERT', 'UPDATE', 'DELETE'].map((action) {
                        final isSelected = currentActionFilter == action;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(action == 'All' ? 'Actions' : _translateAction(action), style: TextStyle(color: isSelected ? Colors.white : _textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                            selected: isSelected,
                            selectedColor: action == 'DELETE' ? _dangerNeon.withOpacity(0.2) : _neonPurple.withOpacity(0.2),
                            backgroundColor: _bgCarbon,
                            side: BorderSide(color: isSelected ? _neonPurple : _glassBorder),
                            onSelected: (_) => ref.read(_actionFilterProvider.notifier).state = action,
                          ),
                        );
                      }),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 28, color: _glassBorder),
                      const SizedBox(width: 12),
                      profilesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (profiles) {
                          final items = profiles.entries.toList();
                          final currentUser = ref.watch(_userFilterProvider);
                          return DropdownButton<String?>(
                            value: currentUser,
                            dropdownColor: _panelDark,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            underline: const SizedBox(),
                            hint: const Text('Filtrer par employé', style: TextStyle(color: _textMuted, fontSize: 12)),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Tous les employés', style: TextStyle(color: _textMuted, fontSize: 12))),
                              ...items.map((e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 12)))),
                            ],
                            onChanged: (v) => ref.read(_userFilterProvider.notifier).state = v,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

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

    final diff = DateTime.now().difference(rawDate);
    String timeAgo;
    if (diff.inMinutes < 1) timeAgo = "À l'instant";
    else if (diff.inHours < 1) timeAgo = "Il y a ${diff.inMinutes} min";
    else if (diff.inDays < 1) timeAgo = "Il y a ${diff.inHours} h";
    else timeAgo = "Il y a ${diff.inDays} jours";

    final fullDate = "${rawDate.day.toString().padLeft(2, '0')}/${rawDate.month.toString().padLeft(2, '0')}/${rawDate.year} ${rawDate.hour.toString().padLeft(2, '0')}:${rawDate.minute.toString().padLeft(2, '0')}";

    final isDelete = action == 'DELETE';
    final isInsert = action == 'INSERT';
    final accentColor = isDelete ? _dangerNeon : (isInsert ? _successNeon : Colors.orangeAccent);
    IconData iconData = isDelete ? Icons.delete_forever : (isInsert ? Icons.add_circle_outline : Icons.edit_note);
    if (table.contains('repair')) iconData = Icons.build_circle_outlined;
    else if (table.contains('sale') || table.contains('purchase')) iconData = Icons.shopping_cart_outlined;
    else if (table.contains('product')) iconData = Icons.inventory_2_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _panelDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDelete ? accentColor.withOpacity(0.5) : _glassBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAuditDetails(context, log, action, accentColor),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(iconData, color: accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_getHumanTitle(action, table),
                                style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 13)),
                          ),
                          Text('$timeAgo', style: const TextStyle(color: _textMuted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 12, color: _textMuted),
                          const SizedBox(width: 4),
                          Text(workerName, style: const TextStyle(color: _textMuted, fontSize: 11)),
                          const SizedBox(width: 16),
                          const Icon(Icons.calendar_today, size: 10, color: _textMuted),
                          const SizedBox(width: 4),
                          Text(fullDate, style: const TextStyle(color: _textMuted, fontSize: 10)),
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
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.manage_search, color: accentColor),
                  const SizedBox(width: 12),
                  Text(action == 'UPDATE' ? 'CHANGEMENTS DÉTECTÉS' : 'DÉTAILS DU JOURNAL', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: _glassBorder, height: 24),

              if (changedKeys.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Aucune modification détectée sur les champs visibles.', style: TextStyle(color: _textMuted))))
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: changedKeys.map((key) {
                        final humanKey = _translateKey(key).toUpperCase();
                        final oldVal = oldData[key]?.toString() ?? '';
                        final newVal = newData[key]?.toString() ?? '';

                        Color diffColor;
                        if (action == 'INSERT') {
                          diffColor = _successNeon;
                        } else if (action == 'DELETE') {
                          diffColor = _dangerNeon;
                        } else {
                          diffColor = Colors.orangeAccent;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bgCarbon.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(left: BorderSide(color: diffColor, width: 3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(humanKey, style: const TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: diffColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: diffColor.withOpacity(0.3))),
                                    child: Text(action == 'INSERT' ? 'AJOUTÉ' : (action == 'DELETE' ? 'SUPPRIMÉ' : 'MODIFIÉ'), style: TextStyle(color: diffColor, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (action == 'UPDATE') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('ANCIEN', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(oldVal.isNotEmpty ? oldVal : '(vide)', style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 12, decoration: TextDecoration.lineThrough)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, color: _textMuted, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: _successNeon.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('NOUVEAU', style: TextStyle(color: _successNeon, fontSize: 9, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(newVal.isNotEmpty ? newVal : '(vide)', style: const TextStyle(color: _successNeon, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: diffColor.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    action == 'DELETE' ? (oldVal.isNotEmpty ? oldVal : newVal) : (newVal.isNotEmpty ? newVal : oldVal),
                                    style: TextStyle(color: diffColor, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
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

Future<void> _exportCsv(BuildContext context, List<Map<String, dynamic>> logs) async {
  if (logs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune donnée à exporter'), backgroundColor: Colors.redAccent));
    return;
  }

  try {
    final rows = <List<String>>[];
    rows.add(['Date', 'Action', 'Table', 'Utilisateur', 'Anciennes Données', 'Nouvelles Données', 'Notes']);

    for (var log in logs) {
      rows.add([
        log['created_at']?.toString() ?? '',
        _translateAction(log['action_type']?.toString() ?? ''),
        _translateTable(log['table_name']?.toString() ?? ''),
        log['worker_name']?.toString() ?? 'Système',
        log['old_data']?.toString() ?? '',
        log['new_data']?.toString() ?? '',
        log['notes']?.toString() ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/audit_logs_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData, encoding: utf8);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Exporté: ${file.path}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur export: $e'), backgroundColor: Colors.redAccent));
    }
  }
}
