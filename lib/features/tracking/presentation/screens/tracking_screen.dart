import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

const _timelineSteps = [
  _TimelineStep('Reçu', Icons.inbox_rounded),
  _TimelineStep('Diagnostic', Icons.search_rounded),
  _TimelineStep('Devis', Icons.description_rounded),
  _TimelineStep('En réparation', Icons.build_rounded),
  _TimelineStep('Contrôle qualité', Icons.verified_rounded),
  _TimelineStep('Prêt', Icons.check_circle_rounded),
  _TimelineStep('Livré', Icons.local_shipping_rounded),
];

class _TimelineStep {
  final String label;
  final IconData icon;
  const _TimelineStep(this.label, this.icon);
}

class TrackingScreen extends StatefulWidget {
  final String qrCodeHash;
  const TrackingScreen({super.key, required this.qrCodeHash});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _events = [];
  String? _error;
  bool _loading = true;

  int _currentStepIndex(String status) {
    if (status == 'Livré') return 6;
    if (status == 'Terminé') return 5;
    if (status == 'En réparation') return 3;
    if (status == 'En attente') return 0;
    return 0;
  }

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
          .select('*, customers(full_name, phone_number), assigned_technician:profiles!repair_tickets_assigned_technician_id_fkey(full_name)')
          .eq('qr_code_hash', widget.qrCodeHash)
          .maybeSingle();

      List<Map<String, dynamic>> events = [];
      if (data != null) {
        events = List<Map<String, dynamic>>.from(
          await client
              .from('repair_ticket_events')
              .select('*')
              .eq('ticket_id', data['id'])
              .order('created_at', ascending: true),
        );
      }

      setState(() {
        _ticket = data;
        _events = events;
        _loading = false;
      });
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
    final technician = t['assigned_technician']?['full_name'] ?? 'Non assigné';
    final estimatedDate = t['estimated_completion_date'] as String?;
    final qrHash = t['qr_code_hash'] ?? '';
    final currentIdx = _currentStepIndex(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(24), border: Border.all(color: _glassBorder)),
            child: Column(
              children: [
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
                const SizedBox(height: 12),
                Text('Réf: $qrHash', style: const TextStyle(color: _textMuted, fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(24), border: Border.all(color: _glassBorder)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PROGRESSION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                const SizedBox(height: 24),
                ...List.generate(_timelineSteps.length, (i) {
                  final step = _timelineSteps[i];
                  final isCompleted = i <= currentIdx;
                  final isCurrent = i == currentIdx;

                  Color stepColor;
                  if (isCurrent) {
                    stepColor = _neonCyan;
                  } else if (isCompleted) {
                    stepColor = _neonEmerald;
                  } else {
                    stepColor = _textMuted.withOpacity(0.4);
                  }

                  final eventDate = _getEventDateForStep(i);

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Column(
                            children: [
                              Container(
                                width: isCurrent ? 28 : 22,
                                height: isCurrent ? 28 : 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted ? stepColor : Colors.transparent,
                                  border: Border.all(color: stepColor, width: isCurrent ? 3 : 2),
                                  boxShadow: isCurrent
                                      ? [BoxShadow(color: _neonCyan.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
                                      : null,
                                ),
                                child: Icon(step.icon, size: isCurrent ? 16 : 12, color: isCompleted ? _bgCarbon : stepColor),
                              ),
                              if (i < _timelineSteps.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: i < currentIdx ? _neonEmerald : _textMuted.withOpacity(0.2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: i < _timelineSteps.length - 1 ? 32 : 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.label,
                                  style: TextStyle(
                                    color: isCurrent ? _neonCyan : (isCompleted ? _neonEmerald : _textMuted),
                                    fontWeight: isCurrent ? FontWeight.w900 : (isCompleted ? FontWeight.w600 : FontWeight.w400),
                                    fontSize: isCurrent ? 15 : 13,
                                  ),
                                ),
                                if (eventDate != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      eventDate,
                                      style: TextStyle(color: stepColor.withOpacity(0.7), fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getEventDateForStep(int stepIndex) {
    final stepEventTypes = [
      null,
      null,
      'quote_generated',
      null,
      'qc_result',
      'status_change',
      'handover_confirmed',
    ];

    if (stepIndex == 0) {
      final createdAt = _ticket?['created_at'] as String?;
      if (createdAt != null) {
        final d = DateTime.tryParse(createdAt);
        if (d != null) return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
      return null;
    }

    final eventType = stepEventTypes[stepIndex];
    if (eventType == null) return null;

    final matchingEvents = _events.where((e) => e['event_type'] == eventType).toList();
    if (matchingEvents.isEmpty) return null;

    final event = matchingEvents.last;
    final dateStr = event['created_at'] as String?;
    if (dateStr == null) return null;

    final d = DateTime.tryParse(dateStr);
    if (d == null) return null;
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
}
