import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

class TechnicianReportScreen extends ConsumerStatefulWidget {
  const TechnicianReportScreen({super.key});
  @override
  ConsumerState<TechnicianReportScreen> createState() => _TechnicianReportScreenState();
}

class _TechnicianReportScreenState extends ConsumerState<TechnicianReportScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = ref.read(supabaseClientProvider);

    final results = await Future.wait([
      client.from('profiles').select('id, full_name, role_id').filter('role_id', 'not.is', null),
      client.from('repair_tickets').select('id, assigned_technician_id, status, created_at, completed_at, final_cost').not('assigned_technician_id', 'is', null),
      client.from('warranty_claims').select('id, created_by'),
      client.from('customer_feedback').select('ticket_id, rating'),
    ]);

    final techs = results[0] as List<dynamic>;
    final allTickets = results[1] as List<dynamic>;
    final allWarranty = results[2] as List<dynamic>;
    final allFeedback = results[3] as List<dynamic>;

    final result = <Map<String, dynamic>>[];
    for (final t in techs) {
      final techId = t['id'] as String;
      final repairs = allTickets.where((r) => r['assigned_technician_id'] == techId).toList();
      final completed = repairs.where((r) => r['completed_at'] != null).toList();

      double totalMin = 0; int count = 0;
      for (final r in completed) {
        final a = DateTime.tryParse(r['created_at']?.toString() ?? '');
        final b = DateTime.tryParse(r['completed_at']?.toString() ?? '');
        if (a != null && b != null) { totalMin += b.difference(a).inMinutes; count++; }
      }
      final avgMin = count > 0 ? (totalMin / count).round() : 0;

      double totalRev = 0;
      for (final r in repairs) totalRev += (r['final_cost'] as num?)?.toDouble() ?? 0;

      final wc = allWarranty.where((w) => w['created_by'] == techId).toList();
      final warrantyRate = repairs.isNotEmpty ? (wc.length / repairs.length * 100).toStringAsFixed(1) : '0.0';

      final ids = repairs.map((r) => r['id'] as String).toSet();
      double avgRating = 0;
      if (ids.isNotEmpty) {
        final fb = allFeedback.where((f) => ids.contains(f['ticket_id'] as String)).toList();
        if (fb.isNotEmpty) avgRating = fb.fold(0.0, (s, f) => s + ((f['rating'] as num?)?.toInt() ?? 0)) / fb.length;
      }

      result.add({
        'name': t['full_name'] ?? 'Inconnu',
        'total': repairs.length,
        'completed': completed.length,
        'avgTime': avgMin,
        'revenue': totalRev,
        'warrantyRate': warrantyRate,
        'avgRating': avgRating,
      });
    }
    if (mounted) setState(() { _items = result; _loading = false; });
  }

  Widget _stat(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      appBar: AppBar(backgroundColor: const Color(0xFF0A0F1A), title: const Text('PERFORMANCE TECHNICIENS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))) : _items.isEmpty ? const Center(child: Text('Aucune donnee.', style: TextStyle(color: Colors.white54))) : ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: _items.length,
        itemBuilder: (_, i) {
          final t = _items[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF0A0F1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x1AFFFFFF))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(spacing: 16, runSpacing: 8, children: [
                _stat('Reparations', '${t['total']}', const Color(0xFF00E5FF)),
                _stat('Terminees', '${t['completed']}', const Color(0xFF10B981)),
                _stat('Tps moyen', '${t['avgTime']}min', Colors.orangeAccent),
                _stat('CA', '${(t['revenue'] as double).toStringAsFixed(0)} DA', Colors.amber),
                _stat('Retour garantie', '${t['warrantyRate']}%', Colors.redAccent),
                _stat('Note', (t['avgRating'] as double).toStringAsFixed(1), Colors.purpleAccent),
              ]),
            ]),
          );
        },
      ),
    );
  }
}
