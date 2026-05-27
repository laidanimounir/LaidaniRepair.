import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

class TrackingScreen extends StatefulWidget {
  final String qrCodeHash;
  const TrackingScreen({super.key, required this.qrCodeHash});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Map<String, dynamic>? _ticket;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final client = Supabase.instance.client;
      final data = await client
          .from('repair_tickets')
          .select('*, customers(full_name, phone_number), profiles!repair_tickets_assigned_technician_id_fkey(full_name)')
          .eq('qr_code_hash', widget.qrCodeHash)
          .maybeSingle();
      setState(() { _ticket = data; _loading = false; });
    } catch (e) {
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCarbon,
      appBar: AppBar(
        backgroundColor: _panelDark,
        title: const Text('SUIVI DE RÉPARATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : _error != null
              ? Center(child: Text('Erreur: $_error', style: const TextStyle(color: Colors.redAccent)))
              : _ticket == null
                  ? Center(child: Text('Ticket introuvable.', style: const TextStyle(color: _textMuted)))
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final t = _ticket!;
    final status = t['status'] as String? ?? 'En attente';
    final device = t['device_name'] ?? '';
    final issue = t['issue_description'] ?? '';
    final estimated = (t['estimated_cost'] as num?)?.toDouble() ?? 0;
    final paid = (t['paid_amount'] as num?)?.toDouble() ?? 0;
    final balance = estimated - paid;
    final customerName = t['customers']?['full_name'] ?? t['client_name_temp'] ?? 'Client';
    final technician = t['profiles']?['full_name'] ?? 'Non assigné';
    final estimatedDate = t['estimated_completion_date'] as String?;
    final qrHash = t['qr_code_hash'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(24), border: Border.all(color: _glassBorder)),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: _statusColor(status)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 24),
                _infoRow('Client', customerName, Icons.person),
                _infoRow('Appareil', device, Icons.phone_android),
                _infoRow('Problème', issue, Icons.warning_amber_rounded),
                _infoRow('Technicien', technician, Icons.build),
                if (estimatedDate != null) _infoRow('Date fin estimée', estimatedDate, Icons.calendar_today),
                const Divider(color: _glassBorder, height: 32),
                _infoRow('Coût estimé', '${estimated.toStringAsFixed(0)} DA', Icons.calculate),
                _infoRow('Payé', '${paid.toStringAsFixed(0)} DA', Icons.payments_outlined),
                _infoRow('Reste à payer', '${balance.toStringAsFixed(0)} DA', Icons.account_balance_wallet_outlined,
                    color: balance > 0 ? Colors.orangeAccent : _neonEmerald),
                const SizedBox(height: 16),
                Text('Réf: $qrHash', style: const TextStyle(color: _textMuted, fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _textMuted),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text('$label:', style: const TextStyle(color: _textMuted, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'En attente': return Colors.orangeAccent;
      case 'En cours': return Colors.blueAccent;
      case 'Terminé': return Colors.greenAccent;
      case 'Livré': return Colors.purpleAccent;
      default: return _neonCyan;
    }
  }
}
