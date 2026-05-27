import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      .limit(200);
});

final _budgetProvider = FutureProvider<Map<String, double>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith('budget_'));
  final budgets = <String, double>{};
  for (final k in keys) {
    budgets[k.replaceFirst('budget_', '')] = prefs.getDouble(k) ?? 0;
  }
  return budgets;
});

// ─── Expenses Screen ──────────────────────────────────────────────────────────

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(_expensesProvider);

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
                const Icon(Icons.account_balance_wallet, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Dépenses', style: TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w700, fontSize: 18)),
                const Spacer(),
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
          TabBar(
            controller: _tabCtrl,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.onSurfaceMuted,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(icon: Icon(Icons.receipt_long), text: 'Dépenses'),
              Tab(icon: Icon(Icons.analytics), text: 'Analyse'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildExpensesList(ref, expensesAsync),
                _buildAnalyticsTab(ref, expensesAsync),
              ],
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

  Widget _buildExpensesList(WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> expensesAsync) {
    return expensesAsync.when(
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
              decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A50))),
              child: Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_long, size: 20, color: AppTheme.error)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['expense_type'] ?? '', style: const TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('$date • $worker', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                        if ((e['notes'] ?? '').isNotEmpty)
                          Text(e['notes'], style: const TextStyle(color: AppTheme.onSurface, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text('${(e['amount'] as num?)?.toStringAsFixed(0) ?? '0'} DA', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsTab(WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> expensesAsync) {
    final budgetsAsync = ref.watch(_budgetProvider);

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error))),
      data: (expenses) {
        if (expenses.isEmpty) return const Center(child: Text('Aucune donnée', style: TextStyle(color: AppTheme.onSurfaceMuted)));

        final byCategory = <String, double>{};
        for (final e in expenses) {
          final cat = e['expense_type']?.toString() ?? 'Autre';
          byCategory[cat] = (byCategory[cat] ?? 0) + ((e['amount'] as num?)?.toDouble() ?? 0);
        }

        final byMonth = <String, double>{};
        for (final e in expenses) {
          final date = DateTime.tryParse(e['expense_date'] ?? '');
          if (date != null) {
            final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            byMonth[key] = (byMonth[key] ?? 0) + ((e['amount'] as num?)?.toDouble() ?? 0);
          }
        }
        final months = byMonth.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final last6Months = months.length > 6 ? months.sublist(months.length - 6) : months;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BUDGET PAR CATÉGORIE', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              budgetsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (budgets) {
                  final cats = byCategory.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  return Column(
                    children: cats.map((cat) {
                      final budget = budgets[cat.key] ?? 0;
                      final ratio = (budget > 0 ? (cat.value / budget).clamp(0, 1).toDouble() : 1.0);
                      final color = ratio > 0.9 ? Colors.redAccent : ratio > 0.7 ? Colors.orangeAccent : Colors.greenAccent;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cat.key, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                Text('${cat.value.toStringAsFixed(0)} / ${budget.toStringAsFixed(0)} DA', style: TextStyle(color: color, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: ratio, backgroundColor: Colors.white12, color: color, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _setBudget(context, ref, byCategory.keys.toList()),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Définir les budgets mensuels', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 24),
              const Text('ÉVOLUTION DES DÉPENSES (6 DERNIERS MOIS)', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A50))),
                child: SizedBox(
                  height: 200,
                  child: last6Months.isNotEmpty
                      ? LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(
                                spots: last6Months.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                                isCurved: true,
                                color: AppTheme.primary,
                                barWidth: 3,
                                dotData: FlDotData(show: true),
                                belowBarData: BarAreaData(show: true, color: AppTheme.primary.withOpacity(0.1)),
                              ),
                            ],
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    final idx = v.toInt();
                                    if (idx >= 0 && idx < last6Months.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(last6Months[idx].key, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 10)),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 10)))),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            borderData: FlBorderData(show: false),
                          ),
                        )
                      : const Center(child: Text('Pas assez de données', style: TextStyle(color: AppTheme.onSurfaceMuted))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Set Budget Dialog ────────────────────────────────────────────────────────
void _setBudget(BuildContext context, WidgetRef ref, List<String> categories) {
  final controllers = <String, TextEditingController>{};
  for (final cat in categories) {
    controllers[cat] = TextEditingController();
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Budgets mensuels'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: categories.map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[cat],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: cat, suffixText: 'DA'),
                ),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              for (final cat in categories) {
                final val = double.tryParse(controllers[cat]?.text ?? '') ?? 0;
                await prefs.setDouble('budget_$cat', val);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ref.invalidate(_budgetProvider);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budgets enregistrés'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
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
