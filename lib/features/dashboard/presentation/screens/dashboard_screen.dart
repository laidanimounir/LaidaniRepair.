import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);
const Color _neonAmber = Color(0xFFFFB74D);

final _dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = Supabase.instance.client;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  final allTickets = await client.from('repair_tickets').select('status, created_at, estimated_completion_date');
  final activeRepairs = allTickets.where((t) => ['En attente', 'En cours'].contains(t['status'])).length;
  final todayDelivered = allTickets.where((t) => t['status'] == 'Livré').where((t) {
    final d = DateTime.tryParse(t['created_at'] as String);
    return d != null && !d.isBefore(todayStart) && d.isBefore(todayEnd);
  }).length;
  final overdueCount = allTickets.where((t) {
    if (['Terminé', 'Livré'].contains(t['status'])) return false;
    final d = DateTime.tryParse(t['estimated_completion_date'] as String? ?? '');
    return d != null && d.isBefore(DateTime.now());
  }).length;

  final warrantyClaims = await client.from('warranty_claims').select('claim_status');
  final warrantyPending = warrantyClaims.where((w) => w['claim_status'] == 'En attente').length;

  final todayInvoices = await client.from('sales_invoices')
      .select('final_amount')
      .gte('invoice_date', todayStart.toIso8601String())
      .lt('invoice_date', todayEnd.toIso8601String());
  double todayRevenue = 0;
  for (final inv in todayInvoices) {
    todayRevenue += (inv['final_amount'] as num?)?.toDouble() ?? 0;
  }

  final newRepairsToday = allTickets.where((t) {
    final d = DateTime.tryParse(t['created_at'] as String);
    return d != null && !d.isBefore(todayStart) && d.isBefore(todayEnd);
  }).length;

  final todayExpenses = await client.from('expenses')
      .select('amount')
      .gte('expense_date', todayStart.toIso8601String())
      .lt('expense_date', todayEnd.toIso8601String());
  double expensesToday = 0;
  for (final e in todayExpenses) {
    expensesToday += (e['amount'] as num?)?.toDouble() ?? 0;
  }

  final netRevenue = todayRevenue - expensesToday;

  final stockItems = await client.from('products').select('stock_quantity');
  final lowStock = stockItems.where((s) => ((s['stock_quantity'] as num?)?.toInt() ?? 0) <= 5).length;

  final clients = await client.from('customers').select('id');
  final totalClients = clients.length;

  final purchaseInvoices = await client.from('purchase_invoices')
      .select('total_amount, paid_amount');
  double pendingAmount = 0;
  for (final inv in purchaseInvoices) {
    final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
    pendingAmount += (total - paid).clamp(0.0, double.infinity);
  }

  return {
    'activeRepairs': activeRepairs,
    'todayDelivered': todayDelivered,
    'todayRevenue': todayRevenue,
    'lowStock': lowStock,
    'totalClients': totalClients,
    'pendingSupplierAmount': pendingAmount,
    'warrantyPending': warrantyPending,
    'overdueCount': overdueCount,
    'newRepairsToday': newRepairsToday,
    'expensesToday': expensesToday,
    'netRevenue': netRevenue,
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_dashboardStatsProvider);

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_dashboardStatsProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              if ((stats['lowStock'] as int) > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 12),
                      Text('${stats['lowStock']} produit(s) en rupture de stock', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _buildStatRow([
                _StatCard(
                  icon: Icons.build_circle_outlined,
                  label: 'Réparations actives',
                  value: '${stats['activeRepairs']}',
                  color: _neonCyan,
                ),
                _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Livrées aujourd\'hui',
                  value: '${stats['todayDelivered']}',
                  color: _neonEmerald,
                ),
              ]),
              if ((stats['overdueCount'] as int) > 0) ...[
                const SizedBox(height: 12),
                _StatCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Tickets en retard',
                  value: '${stats['overdueCount']}',
                  color: Colors.redAccent,
                ),
              ],
              const SizedBox(height: 12),
              _buildStatRow([
                _StatCard(
                  icon: Icons.payments_outlined,
                  label: 'CA aujourd\'hui',
                  value: '${(stats['todayRevenue'] as double).toStringAsFixed(0)} DA',
                  color: _neonAmber,
                ),
                _StatCard(
                  icon: Icons.people_outline,
                  label: 'Clients',
                  value: '${stats['totalClients']}',
                  color: const Color(0xFF9D97FF),
                ),
              ]),
              const SizedBox(height: 12),
              _buildStatRow([
                _StatCard(
                  icon: Icons.inventory_outlined,
                  label: 'Stock < 5',
                  value: '${stats['lowStock']}',
                  color: (stats['lowStock'] as int) > 0 ? Colors.redAccent : _neonEmerald,
                ),
                _StatCard(
                  icon: Icons.verified_outlined,
                  label: 'Garantie en attente',
                  value: '${stats['warrantyPending']}',
                  color: _neonAmber,
                ),
              ]),
              const SizedBox(height: 12),
              _buildStatRow([
                _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Dettes fournisseurs',
                  value: '${(stats['pendingSupplierAmount'] as double).toStringAsFixed(0)} DA',
                  color: (stats['pendingSupplierAmount'] as double) > 0 ? Colors.orangeAccent : _neonEmerald,
                ),
              ]),
              const SizedBox(height: 16),
              _buildDailySummary(stats),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailySummary(Map<String, dynamic> stats) {
    final revenue = stats['todayRevenue'] as double;
    final expenses = stats['expensesToday'] as double;
    final net = stats['netRevenue'] as double;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonCyan.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RÉSUMÉ DU JOUR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
          const SizedBox(height: 12),
          _summaryRow('Ventes', '${revenue.toStringAsFixed(0)} DA', _neonAmber),
          _summaryRow('Nouvelles réparations', '${stats['newRepairsToday']}', _neonCyan),
          _summaryRow('Livrées', '${stats['todayDelivered']}', _neonEmerald),
          _summaryRow('Dépenses', '${expenses.toStringAsFixed(0)} DA', Colors.redAccent),
          const Divider(color: _glassBorder, height: 24),
          _summaryRow('REVENU NET', '${net.toStringAsFixed(0)} DA', net >= 0 ? Colors.greenAccent : Colors.redAccent),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _textMuted, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.dashboard_customize_outlined, color: _neonCyan, size: 28),
            const SizedBox(width: 12),
            const Text('TABLEAU DE BORD', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Aperçu de l\'activité', style: TextStyle(color: _textMuted, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatRow(List<_StatCard> cards) {
    return Row(
      children: cards.map((c) => Expanded(child: c)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
