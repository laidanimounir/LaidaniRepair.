import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

class RepairsReportScreen extends ConsumerStatefulWidget {
  const RepairsReportScreen({super.key});

  @override
  ConsumerState<RepairsReportScreen> createState() => _RepairsReportScreenState();
}

class _RepairsReportScreenState extends ConsumerState<RepairsReportScreen> {
  DateTimeRange _dateRange = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());
  String? _technicianFilter;
  String? _statusFilter;
  String? _deviceTypeFilter;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _technicians = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final client = ref.read(supabaseClientProvider);
    final techs = await client.from('profiles').select('id, full_name');
    setState(() => _technicians = List<Map<String, dynamic>>.from(techs));
    await _runReport();
  }

  Future<void> _runReport() async {
    setState(() => _loading = true);
    final client = ref.read(supabaseClientProvider);
    var sel = client.from('repair_tickets')
        .select('*, customers(full_name), profiles!repair_tickets_assigned_technician_id_fkey(full_name)');
    if (_technicianFilter != null) sel = sel.eq('assigned_technician_id', _technicianFilter!);
    if (_statusFilter != null) sel = sel.eq('status', _statusFilter!);
    if (_deviceTypeFilter != null) sel = sel.eq('device_type', _deviceTypeFilter!);
    final data = await sel
        .gte('created_at', _dateRange.start.toIso8601String())
        .lte('created_at', _dateRange.end.toIso8601String())
        .order('created_at', ascending: false);
    setState(() { _tickets = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final totalRepairs = _tickets.length;
    final completed = _tickets.where((t) => t['status'] == 'Terminé' || t['status'] == 'Livré').length;
    final totalRevenue = _tickets.fold<double>(0, (sum, t) => sum + ((t['final_cost'] as num?)?.toDouble() ?? 0));
    final completedTickets = _tickets.where((t) => t['completed_at'] != null && t['created_at'] != null).toList();
    Duration avgTime = Duration.zero;
    if (completedTickets.isNotEmpty) {
      final total = completedTickets.fold<int>(0, (sum, t) {
        final created = DateTime.tryParse(t['created_at'] as String? ?? '');
        final completedAt = DateTime.tryParse(t['completed_at'] as String? ?? '');
        if (created != null && completedAt != null) {
          return sum + completedAt.difference(created).inMinutes;
        }
        return sum;
      });
      avgTime = Duration(minutes: total ~/ completedTickets.length);
    }

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: _panelDark, border: Border(bottom: BorderSide(color: _glassBorder, width: 1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _neonCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _neonCyan.withOpacity(0.3))),
                      child: const Icon(Icons.analytics_outlined, color: _neonCyan, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: Text('RAPPORT RÉPARATIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5))),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(Icons.date_range, '${_dateRange.start.day}/${_dateRange.start.month}/${_dateRange.start.year} - ${_dateRange.end.day}/${_dateRange.end.month}/${_dateRange.end.year}', () async {
                        final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDateRange: _dateRange);
                        if (picked != null) setState(() => _dateRange = picked);
                        await _runReport();
                      }),
                      const SizedBox(width: 8),
                      _filterChip(Icons.person_outline, _technicianName(), () => _showFilterSheet('technician')),
                      const SizedBox(width: 8),
                      _filterChip(Icons.filter_alt_outlined, _statusFilter ?? 'Tous statuts', () => _showFilterSheet('status')),
                      const SizedBox(width: 8),
                      _filterChip(Icons.devices, _deviceTypeFilter ?? 'Tous types', () => _showFilterSheet('device_type')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: _loading
                ? const CircularProgressIndicator(color: _neonCyan)
                : Row(
                    children: [
                      _summaryCard('Total', '$totalRepairs', _neonCyan),
                      _summaryCard('Terminées', '$completed', _neonEmerald),
                      _summaryCard('CA', '${totalRevenue.toStringAsFixed(0)} DA', Colors.amber),
                      _summaryCard('Tps moyen', '${avgTime.inHours}h${avgTime.inMinutes % 60}min', Colors.orangeAccent),
                    ],
                  ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _neonCyan))
                : _tickets.isEmpty
                    ? Center(child: Text('Aucune donnée.', style: const TextStyle(color: _textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _tickets.length,
                        itemBuilder: (context, index) {
                          final t = _tickets[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text(t['device_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13))),
                                Expanded(flex: 2, child: Text(t['customers']?['full_name'] ?? '', style: const TextStyle(color: _textMuted, fontSize: 12))),
                                Expanded(flex: 1, child: Text(t['status'] ?? '', style: TextStyle(color: _statusColor(t['status']), fontSize: 12))),
                                Expanded(flex: 1, child: Text('${(t['final_cost'] as num?)?.toDouble() ?? 0} DA', style: const TextStyle(color: Colors.white, fontSize: 12))),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _neonCyan, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _technicianName() {
    if (_technicianFilter == null) return 'Tous techniciens';
    final t = _technicians.where((e) => e['id'] == _technicianFilter).firstOrNull;
    return t?['full_name'] ?? 'Technicien';
  }

  void _showFilterSheet(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panelDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final items = <Map<String, String?>>[{'label': 'Tous', 'value': null}];
        if (type == 'technician') {
          for (final t in _technicians) items.add({'label': t['full_name'], 'value': t['id']});
        } else if (type == 'status') {
          for (final s in ['En attente', 'En cours', 'Terminé', 'Livré']) items.add({'label': s, 'value': s});
        } else if (type == 'device_type') {
          for (final d in ['Smartphone', 'Tablette', 'PC Portable', 'PC Bureau', 'Console', 'Montre connectée', 'Autre']) items.add({'label': d, 'value': d});
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: items.map((i) => ListTile(
            title: Text(i['label'] ?? '', style: const TextStyle(color: Colors.white)),
            onTap: () {
              if (type == 'technician') _technicianFilter = i['value'];
              else if (type == 'status') _statusFilter = i['value'];
              else if (type == 'device_type') _deviceTypeFilter = i['value'];
              Navigator.pop(ctx);
              _runReport();
            },
          )).toList(),
        );
      },
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'En attente': return Colors.orangeAccent;
      case 'En cours': return Colors.blueAccent;
      case 'Terminé': return Colors.greenAccent;
      case 'Livré': return Colors.purpleAccent;
      default: return _neonCyan;
    }
  }
}
