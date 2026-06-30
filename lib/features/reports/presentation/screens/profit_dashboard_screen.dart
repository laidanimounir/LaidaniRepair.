import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

class ProfitDashboardScreen extends ConsumerStatefulWidget {
  const ProfitDashboardScreen({super.key});

  @override
  ConsumerState<ProfitDashboardScreen> createState() => _ProfitDashboardScreenState();
}

class _ProfitDashboardScreenState extends ConsumerState<ProfitDashboardScreen> {
  String _selectedFilter = 'Cette semaine';
  DateTime _startDate = _weekStart();
  DateTime _endDate = DateTime.now();
  bool _loading = false;
  String? _error;

  double _totalRevenue = 0;
  double _totalPartsCost = 0;
  double _totalLaborCost = 0;
  double _totalNetProfit = 0;
  int _ticketCount = 0;
  double _avgProfitPerTicket = 0;
  double _posRevenue = 0;
  double _posCost = 0;
  int _posCount = 0;
  List<Map<String, dynamic>> _byTechnician = [];
  List<Map<String, dynamic>> _byDevice = [];
  bool _showTechnician = true;
  bool _showDevice = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfitData());
  }

  static DateTime _weekStart() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  void _setFilter(String filter) {
    setState(() { _selectedFilter = filter; _error = null; });
    final now = DateTime.now();
    switch (filter) {
      case "Aujourd'hui":
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = _startDate.add(const Duration(days: 1));
        break;
      case 'Cette semaine':
        _startDate = _weekStart();
        _endDate = now;
        break;
      case 'Ce mois':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      default:
        break;
    }
    _loadProfitData();
  }

  Future<void> _loadProfitData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ref.read(supabaseClientProvider);

      final ticketsResp = await client
          .from('repair_tickets')
          .select('id, final_cost, labor_cost, device_brand, device_name, created_at, profiles!repair_tickets_worker_id_fkey(full_name)')
          .gte('created_at', _startDate.toIso8601String())
          .lte('created_at', _endDate.toIso8601String())
          .neq('status', 'Annulé')
          .neq('payment_status', 'Remboursé');

      final ticketIds = (ticketsResp as List).map((t) => (t as Map<String, dynamic>)['id'] as String).toList();
      List<Map<String, dynamic>> allParts = [];
      if (ticketIds.isNotEmpty) {
        final partsResp = await client
            .from('repair_parts')
            .select('ticket_id, shop_cost_price, quantity, charged_price')
            .inFilter('ticket_id', ticketIds);
        allParts = List<Map<String, dynamic>>.from(partsResp);
      }

      double totalRevenue = 0;
      double totalPartsCost = 0;
      double totalLaborCost = 0;
      int ticketCount = 0;
      final techMap = <String, Map<String, double>>{};
      final deviceMap = <String, Map<String, dynamic>>{};

      // --- POS sales ---
      double posRevenue = 0;
      double posCost = 0;
      int posCount = 0;
      final salesResp = await client
          .from('sales_invoices')
          .select('id, final_amount, worker_id, profiles!sales_invoices_worker_id_fkey(full_name)')
          .gte('invoice_date', _startDate.toIso8601String())
          .lte('invoice_date', _endDate.toIso8601String());
      final salesData = (salesResp as List).cast<Map<String, dynamic>>();

      final salesInvoiceIds = salesData.map((s) => s['id'] as String).toList();
      Map<String, Map<String, double>> salesItemsByInvoice = {};
      if (salesInvoiceIds.isNotEmpty) {
        final itemsResp = await client
            .from('sales_items')
            .select('invoice_id, quantity, sell_price, products!sales_items_product_id_fkey(purchase_price)')
            .inFilter('invoice_id', salesInvoiceIds);
        for (final item in (itemsResp as List)) {
          final m = Map<String, dynamic>.from(item as Map<String, dynamic>);
          final invId = m['invoice_id'] as String;
          final qty = (m['quantity'] as num?)?.toDouble() ?? 0;
          final purchase = ((m['products'] as Map?)?.let((p) => p['purchase_price'] as num?)?.toDouble()) ?? 0;
          salesItemsByInvoice.putIfAbsent(invId, () => {'cost': 0, 'qty': 0});
          salesItemsByInvoice[invId]!['cost'] = salesItemsByInvoice[invId]!['cost']! + (purchase * qty);
          salesItemsByInvoice[invId]!['qty'] = salesItemsByInvoice[invId]!['qty']! + qty;
        }
      }

      for (final s in salesData) {
        final invId = s['id'] as String;
        final revenue = (s['final_amount'] as num?)?.toDouble() ?? 0;
        final cost = salesItemsByInvoice[invId]?['cost'] ?? 0;
        final profit = revenue - cost;
        final techName = (s['profiles'] as Map?)?.let((p) => p['full_name'] as String?) ?? 'Non assigné';

        posRevenue += revenue;
        posCost += cost;
        posCount++;

        techMap.putIfAbsent(techName, () => {'tickets': 0, 'revenue': 0, 'parts': 0, 'labor': 0, 'profit': 0});
        techMap[techName]!['tickets'] = techMap[techName]!['tickets']! + 1;
        techMap[techName]!['revenue'] = techMap[techName]!['revenue']! + revenue;
        techMap[techName]!['parts'] = techMap[techName]!['parts']! + cost;
        techMap[techName]!['profit'] = techMap[techName]!['profit']! + profit;
      }

      for (final t in ticketsResp) {
        final tMap = Map<String, dynamic>.from(t as Map<String, dynamic>);
        final ticketId = tMap['id'] as String;
        final revenue = (tMap['final_cost'] as num?)?.toDouble() ?? 0;
        final labor = (tMap['labor_cost'] as num?)?.toDouble() ?? 0;
        final techName = (tMap['profiles'] as Map?)?.let((p) => p['full_name'] as String?) ?? 'Non assigné';

        final partsForTicket = allParts.where((p) => p['ticket_id'] == ticketId).toList();
        double partsCost = 0;
        double chargedSum = 0;
        for (final p in partsForTicket) {
          partsCost += ((p['shop_cost_price'] as num?)?.toDouble() ?? 0) * ((p['quantity'] as num?)?.toInt() ?? 1);
          chargedSum += ((p['charged_price'] as num?)?.toDouble() ?? 0) * ((p['quantity'] as num?)?.toInt() ?? 1);
        }

        totalRevenue += revenue;
        totalPartsCost += partsCost;
        totalLaborCost += labor;
        ticketCount++;

        techMap.putIfAbsent(techName, () => {'tickets': 0, 'revenue': 0, 'parts': 0, 'labor': 0, 'profit': 0});
        techMap[techName]!['tickets'] = techMap[techName]!['tickets']! + 1;
        techMap[techName]!['revenue'] = techMap[techName]!['revenue']! + revenue;
        techMap[techName]!['parts'] = techMap[techName]!['parts']! + partsCost;
        techMap[techName]!['labor'] = techMap[techName]!['labor']! + labor;
        techMap[techName]!['profit'] = techMap[techName]!['profit']! + revenue - partsCost;

        final deviceName = '${tMap['device_brand'] ?? ''} ${tMap['device_name'] ?? ''}'.trim();
        final deviceKey = deviceName.isNotEmpty ? deviceName : 'Non spécifié';
        deviceMap.putIfAbsent(deviceKey, () => {'tickets': 0, 'revenue': 0, 'profit': 0});
        deviceMap[deviceKey]!['tickets'] = deviceMap[deviceKey]!['tickets'] + 1;
        deviceMap[deviceKey]!['revenue'] = deviceMap[deviceKey]!['revenue'] + revenue;
        deviceMap[deviceKey]!['profit'] = deviceMap[deviceKey]!['profit'] + revenue - partsCost;
      }

      final totalNetProfit = totalRevenue + posRevenue - totalPartsCost - posCost;

      final byTech = techMap.entries.map((e) => {
        'name': e.key,
        'tickets': e.value['tickets']!.toInt(),
        'revenue': e.value['revenue']!,
        'parts': e.value['parts']!,
        'labor': e.value['labor']!,
        'profit': e.value['profit']!,
        'margin': e.value['revenue']! > 0 ? (e.value['profit']! / e.value['revenue']! * 100) : 0,
      }).toList()
        ..sort((a, b) => (b['profit'] as double).compareTo(a['profit'] as double));

      final byDevice = deviceMap.entries.map((e) => {
        'name': e.key,
        'tickets': e.value['tickets']!.toInt(),
        'avgRevenue': e.value['tickets']! > 0 ? e.value['revenue']! / e.value['tickets']! : 0,
        'avgProfit': e.value['tickets']! > 0 ? e.value['profit']! / e.value['tickets']! : 0,
      }).toList()
        ..sort((a, b) => (b['avgProfit'] as double).compareTo(a['avgProfit'] as double));

      if (mounted) {
        setState(() {
          _totalRevenue = totalRevenue + posRevenue;
          _totalPartsCost = totalPartsCost + posCost;
          _totalLaborCost = totalLaborCost;
          _totalNetProfit = totalNetProfit;
          _ticketCount = ticketCount;
          _posRevenue = posRevenue;
          _posCost = posCost;
          _posCount = posCount;
          _avgProfitPerTicket = (ticketCount + posCount) > 0 ? totalNetProfit / (ticketCount + posCount) : 0;
          _byTechnician = byTech;
          _byDevice = byDevice;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Widget _buildFilterChips() {
    final filters = ["Aujourd'hui", 'Cette semaine', 'Ce mois'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f, style: TextStyle(color: selected ? _bgCarbon : Colors.white, fontSize: 13)),
              selected: selected,
              backgroundColor: _panelDark,
              selectedColor: _neonCyan,
              side: BorderSide(color: selected ? _neonCyan : _glassBorder),
              onSelected: (_) => _setFilter(f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 500;
        final crossCount = wide ? 4 : 2;
        final items = [
          {'label': "Chiffre d'affaires", 'value': '${_totalRevenue.toStringAsFixed(0)} DA', 'sub': _posRevenue > 0 ? 'Réparations: ${(_totalRevenue - _posRevenue).toStringAsFixed(0)} DA + Ventes: ${_posRevenue.toStringAsFixed(0)} DA' : null, 'color': _neonCyan},
          {'label': 'Coût total', 'value': '${(_totalPartsCost).toStringAsFixed(0)} DA', 'sub': _posCost > 0 ? 'Réparations: ${(_totalPartsCost - _posCost).toStringAsFixed(0)} DA + POS: ${_posCost.toStringAsFixed(0)} DA' : null, 'color': Colors.orangeAccent},
          {'label': 'Bénéfice net', 'value': '${_totalNetProfit.toStringAsFixed(0)} DA', 'color': _totalNetProfit >= 0 ? _neonEmerald : Colors.redAccent},
          {'label': 'Marge moyenne', 'value': '${_avgProfitPerTicket.toStringAsFixed(0)} DA/ticket', 'color': Colors.purpleAccent},
        ];
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossCount, mainAxisExtent: 90, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: (item['color'] as Color).withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item['label'] as String, style: const TextStyle(color: _textMuted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(item['value'] as String, style: TextStyle(color: item['color'] as Color, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (item['sub'] != null)
                    Padding(padding: const EdgeInsets.only(top: 2), child: Text(item['sub'] as String, style: const TextStyle(color: _textMuted, fontSize: 9))),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTechnicianTable() {
    if (_byTechnician.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showTechnician = !_showTechnician),
            child: Row(
              children: [
                Icon(_showTechnician ? Icons.expand_less : Icons.expand_more, color: _neonCyan, size: 20),
                const SizedBox(width: 8),
                const Text('Par technicien', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          if (_showTechnician) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_bgCarbon),
                dataRowColor: WidgetStateProperty.all(Colors.transparent),
                headingTextStyle: const TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                dividerThickness: 0.5,
                columns: const [
                  DataColumn(label: Text('Technicien')),
                  DataColumn(label: Text('Tickets')),
                  DataColumn(label: Text('CA')),
                  DataColumn(label: Text('Coût')),
                  DataColumn(label: Text('Bénéfice')),
                  DataColumn(label: Text('Marge %')),
                ],
                rows: _byTechnician.map((t) => DataRow(cells: [
                  DataCell(Text(t['name'] as String)),
                  DataCell(Text('${t['tickets']}')),
                  DataCell(Text('${(t['revenue'] as double).toStringAsFixed(0)} DA')),
                  DataCell(Text('${((t['parts'] as double) + (t['labor'] as double)).toStringAsFixed(0)} DA')),
                  DataCell(Text('${(t['profit'] as double).toStringAsFixed(0)} DA', style: TextStyle(color: (t['profit'] as double) >= 0 ? _neonEmerald : Colors.redAccent))),
                  DataCell(Text('${(t['margin'] as double).toStringAsFixed(1)}%')),
                ])).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceTable() {
    if (_byDevice.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showDevice = !_showDevice),
            child: Row(
              children: [
                Icon(_showDevice ? Icons.expand_less : Icons.expand_more, color: _neonCyan, size: 20),
                const SizedBox(width: 8),
                const Text('Par appareil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          if (_showDevice) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_bgCarbon),
                dataRowColor: WidgetStateProperty.all(Colors.transparent),
                headingTextStyle: const TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                dividerThickness: 0.5,
                columns: const [
                  DataColumn(label: Text('Appareil')),
                  DataColumn(label: Text('Tickets')),
                  DataColumn(label: Text('CA moyen')),
                  DataColumn(label: Text('Bénéfice moyen')),
                ],
                rows: _byDevice.map((d) => DataRow(cells: [
                  DataCell(Text(d['name'] as String)),
                  DataCell(Text('${d['tickets']}')),
                  DataCell(Text('${(d['avgRevenue'] as double).toStringAsFixed(0)} DA')),
                  DataCell(Text('${(d['avgProfit'] as double).toStringAsFixed(0)} DA', style: TextStyle(color: (d['avgProfit'] as double) >= 0 ? _neonEmerald : Colors.redAccent))),
                ])).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);
    if (!isOwner) {
      return Scaffold(
        backgroundColor: _bgCarbon,
        body: const Center(child: Text('Accès refusé', style: TextStyle(color: Colors.redAccent, fontSize: 18))),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _bgCarbon,
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Erreur: $_error', style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center))),
      );
    }

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 850;
          final content = Padding(
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: _neonCyan, size: 24),
                    const SizedBox(width: 12),
                    const Text('Rentabilité', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('$_ticketCount réparations${_posCount > 0 ? " + $_posCount ventes" : ""}', style: const TextStyle(color: _textMuted, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _neonCyan)))
                else ...[
                  _buildSummaryCards(),
                  const SizedBox(height: 20),
                  _buildTechnicianTable(),
                  const SizedBox(height: 16),
                  _buildDeviceTable(),
                ],
              ],
            ),
          );
          if (isDesktop) {
            return Center(child: SizedBox(width: 960, child: SingleChildScrollView(child: content)));
          }
          return SingleChildScrollView(child: content);
        },
      ),
    );
  }
}

extension _MapExt on Map? {
  R? let<R>(R Function(Map map) block) {
    if (this == null) return null;
    return block(this!);
  }
}
