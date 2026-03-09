import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _expensesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('expenses')
      .select('*, profiles(full_name)')
      .order('expense_date', ascending: false)
      .limit(100);
});

// ─── Expenses Screen ──────────────────────────────────────────────────────────

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(_expensesProvider);

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
                const Icon(Icons.account_balance_wallet, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Dépenses', style: TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w700, fontSize: 18)),
                const Spacer(),
                // Total badge
                expensesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) {
                    final total = list.fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Total: ${total.toStringAsFixed(0)} DA',
                          style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.onSurfaceMuted, size: 18),
                  onPressed: () => ref.invalidate(_expensesProvider),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error))),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(child: Text('Aucune dépense enregistrée', style: TextStyle(color: AppTheme.onSurfaceMuted)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final e = expenses[i];
                    final date = DateTime.tryParse(e['expense_date'] ?? '')?.toString().substring(0, 16) ?? '';
                    final worker = e['profiles']?['full_name'] ?? '';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A50)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long, size: 20, color: AppTheme.error),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e['expense_type'] ?? '', style: const TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('$date • $worker', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                                if ((e['notes'] ?? '').isNotEmpty)
                                  Text(e['notes'], style: const TextStyle(color: AppTheme.onSurface, fontSize: 11),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Text('${(e['amount'] as num?)?.toStringAsFixed(0) ?? '0'} DA',
                              style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 14)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpense(context, ref),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─── Add Expense Dialog ───────────────────────────────────────────────────────

void _showAddExpense(BuildContext context, WidgetRef ref) {
  final typeCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nouvelle dépense'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type de dépense (ex: Loyer, Électricité)')),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: const InputDecoration(labelText: 'Montant (DA)', suffixText: 'DA')),
            const SizedBox(height: 12),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optionnel)'), maxLines: 2),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            final type = typeCtrl.text.trim();
            final amountText = amountCtrl.text.trim();
            final amount = double.tryParse(amountText) ?? 0;
            
            if (type.isEmpty || amount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Veuillez entrer un type de dépense et un montant valide'), backgroundColor: Colors.redAccent),
              );
              return;
            }

            final messenger = ScaffoldMessenger.of(context);
            final container = ProviderScope.containerOf(context);
            Navigator.pop(ctx);
            
            try {
              final client = container.read(supabaseClientProvider);
              final user = Supabase.instance.client.auth.currentUser;
              await client.from('expenses').insert({
                'worker_id': user?.id,
                'expense_type': type,
                'amount': amount,
                'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              });
              container.invalidate(_expensesProvider);
              messenger.showSnackBar(
                const SnackBar(content: Text('Dépense enregistrée avec succès'), backgroundColor: Colors.green),
              );
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Erreur lors de l\'enregistrement de la dépense.'), backgroundColor: Colors.redAccent),
              );
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}
