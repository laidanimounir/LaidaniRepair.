import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final activeRepairs = allTickets.where((t) => ['En attente'].contains(t['status'])).length;
  final todayDelivered = allTickets.where((t) {
    if (t['status'] != 'Livré') return false;
    final deliveredRaw = t['delivered_at'];
    if (deliveredRaw == null) return false;
    final d = DateTime.tryParse(deliveredRaw as String);
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

final _forecastProvider = FutureProvider<List<double>>((ref) async {
  final client = Supabase.instance.client;
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final invoices = await client
      .from('sales_invoices')
      .select('final_amount, invoice_date')
      .gte('invoice_date', thirtyDaysAgo.toIso8601String())
      .lte('invoice_date', now.toIso8601String());

  final dailyRevenue = <int, double>{};
  for (final inv in invoices) {
    final date = DateTime.tryParse(inv['invoice_date'] as String);
    if (date == null) continue;
    final dayKey = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + ((inv['final_amount'] as num?)?.toDouble() ?? 0);
  }

  final totalDays = dailyRevenue.isNotEmpty ? dailyRevenue.length : 1;
  final totalRevenue = dailyRevenue.values.fold<double>(0, (a, b) => a + b);
  final avgDaily = totalRevenue / totalDays;

  return List.generate(7, (i) => avgDaily);
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _editMode = false;
  Set<String> _hiddenWidgets = {};

  static const _prefsKey = 'dashboard_hidden_widgets';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) {
      setState(() {
        _hiddenWidgets = hidden.toSet();
      });
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _hiddenWidgets.toList());
  }

  void _toggleWidget(String id) {
    setState(() {
      if (_hiddenWidgets.contains(id)) {
        _hiddenWidgets.remove(id);
      } else {
        _hiddenWidgets.add(id);
      }
    });
    _savePrefs();
  }

  bool _isVisible(String id) => !_hiddenWidgets.contains(id);

  @override
  Widget build(BuildContext context) {
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
              if (_editMode) _buildEditPanel(),
              if ((stats['lowStock'] as int) > 0 && _isVisible('low_stock_alert'))
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
              if (_isVisible('active_repairs')) ...[
                const SizedBox(height: 20),
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
              ],
              if ((stats['overdueCount'] as int) > 0 && _isVisible('overdue')) ...[
                const SizedBox(height: 12),
                _StatCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Tickets en retard',
                  value: '${stats['overdueCount']}',
                  color: Colors.redAccent,
                ),
              ],
              if (_isVisible('revenue_clients')) ...[
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
              ],
              if (_isVisible('stock_warranty')) ...[
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
              ],
              if (_isVisible('supplier_debt')) ...[
                const SizedBox(height: 12),
                _buildStatRow([
                  _StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Dettes fournisseurs',
                    value: '${(stats['pendingSupplierAmount'] as double).toStringAsFixed(0)} DA',
                    color: (stats['pendingSupplierAmount'] as double) > 0 ? Colors.orangeAccent : _neonEmerald,
                  ),
                ]),
              ],
              if (_isVisible('daily_summary')) ...[
                const SizedBox(height: 16),
                _buildDailySummary(stats),
              ],
              if (_isVisible('forecast')) ...[
                const SizedBox(height: 16),
                _buildForecastCard(ref),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditPanel() {
    final widgets = [
      _WidgetToggle(id: 'low_stock_alert', label: 'Alerte Stock Bas', icon: Icons.warning_amber_rounded, visible: _isVisible('low_stock_alert')),
      _WidgetToggle(id: 'active_repairs', label: 'Réparations Actives/Livrées', icon: Icons.build_circle_outlined, visible: _isVisible('active_repairs')),
      _WidgetToggle(id: 'overdue', label: 'Tickets en Retard', icon: Icons.warning_amber_rounded, visible: _isVisible('overdue')),
      _WidgetToggle(id: 'revenue_clients', label: 'CA & Clients', icon: Icons.payments_outlined, visible: _isVisible('revenue_clients')),
      _WidgetToggle(id: 'stock_warranty', label: 'Stock & Garantie', icon: Icons.inventory_outlined, visible: _isVisible('stock_warranty')),
      _WidgetToggle(id: 'supplier_debt', label: 'Dettes Fournisseurs', icon: Icons.account_balance_wallet_outlined, visible: _isVisible('supplier_debt')),
      _WidgetToggle(id: 'daily_summary', label: 'Résumé du Jour', icon: Icons.today, visible: _isVisible('daily_summary')),
      _WidgetToggle(id: 'forecast', label: 'Prévision 7 Jours', icon: Icons.trending_up, visible: _isVisible('forecast')),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _neonCyan.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PERSONNALISER LE TABLEAU DE BORD', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          const Text('Affichez ou masquez les widgets selon vos besoins.', style: TextStyle(color: _textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widgets.map((w) => FilterChip(
              label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(w.icon, size: 14, color: w.visible ? _neonCyan : _textMuted), const SizedBox(width: 6), Text(w.label)]),
              selected: w.visible,
              onSelected: (_) => _toggleWidget(w.id),
              selectedColor: _neonCyan.withOpacity(0.2),
              backgroundColor: _bgCarbon,
              side: BorderSide(color: w.visible ? _neonCyan : _glassBorder),
              showCheckmark: false,
              labelStyle: TextStyle(color: w.visible ? _neonCyan : _textMuted, fontSize: 12),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(WidgetRef ref) {
    final forecastAsync = ref.watch(_forecastProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonCyan.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: _neonCyan, size: 18),
              const SizedBox(width: 8),
              const Text('PRÉVISION 7 JOURS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
              const Spacer(),
              Text('Basé sur 30j', style: TextStyle(color: _textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),
          forecastAsync.when(
            loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: _neonCyan))),
            error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent)),
            data: (values) => SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b) / 4, getDrawingHorizontalLine: (value) => FlLine(color: _glassBorder, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text('${value.toInt()} DA', style: const TextStyle(color: _textMuted, fontSize: 10)), reservedSize: 50)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                      final labels = ['J+1', 'J+2', 'J+3', 'J+4', 'J+5', 'J+6', 'J+7'];
                      final idx = value.toInt();
                      return idx >= 0 && idx < labels.length ? Text(labels[idx], style: const TextStyle(color: _textMuted, fontSize: 10)) : const Text('');
                    })),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      color: _neonCyan,
                      barWidth: 3,
                      dotData: FlDotData(show: true, getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 4, color: _bgCarbon, strokeWidth: 2, strokeColor: _neonCyan)),
                      belowBarData: BarAreaData(show: true, color: _neonCyan.withOpacity(0.08)),
                    ),
                  ],
                  lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.toStringAsFixed(0)} DA', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList())),
                ),
              ),
            ),
          ),
        ],
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
            const Spacer(),
            IconButton(
              icon: Icon(_editMode ? Icons.check : Icons.edit, color: _editMode ? _neonEmerald : _textMuted),
              tooltip: _editMode ? 'Terminer l\'édition' : 'Personnaliser le tableau de bord',
              onPressed: () => setState(() => _editMode = !_editMode),
            ),
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

class _WidgetToggle {
  final String id;
  final String label;
  final IconData icon;
  final bool visible;

  const _WidgetToggle({required this.id, required this.label, required this.icon, required this.visible});
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
