import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';

// --- Cyber Glass Theme Constants ---
const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

class TicketDetailsScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDetailsScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends ConsumerState<TicketDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _parts = [];
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchFullData());
  }

  // --- جلب البيانات ---
  Future<void> _fetchFullData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final ticketData = await client.from('repair_tickets').select('*, customers(full_name, phone_number)').eq('id', widget.ticketId).maybeSingle();
      final partsData = await client.from('repair_parts').select('*, products(product_name, reference_price)').eq('ticket_id', widget.ticketId);
      final paymentsData = await client.from('repair_payments').select('*').eq('ticket_id', widget.ticketId).order('paid_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _ticket = ticketData;
        _parts = List<Map<String, dynamic>>.from(partsData);
        _payments = List<Map<String, dynamic>>.from(paymentsData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 1. إضافة قطعة (خصم من المخزون) ---
  Future<void> _addPartToTicket(Map<String, dynamic> product) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('repair_parts').insert({
        'ticket_id': widget.ticketId,
        'product_id': product['id'],
        'quantity': 1,
        'charged_price': product['reference_price'],
        'part_status': 'Utilisé'
      });
      _fetchFullData();
      _showToast('Pièce ajoutée et stock mis à jour !', _neonEmerald);
    } catch (e) {
      _showToast('Erreur: $e', Colors.redAccent);
    }
  }

  // --- 2. حذف قطعة (إرجاع للمخزون) ---
  Future<void> _removePart(Map<String, dynamic> part) async {
    final client = ref.read(supabaseClientProvider);
    setState(() => _isLoading = true);
    try {
      // الحذف من الفاتورة (قاعدة البيانات ستعالج المخزون عبر Trigger)
      await client.from('repair_parts').delete().eq('id', part['id']);
      _fetchFullData();
      _showToast('Pièce supprimée et retournée au stock.', Colors.orangeAccent);
    } catch (e) {
      _showToast('Erreur: $e', Colors.redAccent);
      _fetchFullData();
    }
  }

  // --- 3. تغيير حالة القطعة (تالفة) ---
  Future<void> _changePartStatus(Map<String, dynamic> part, String newStatus) async {
    final client = ref.read(supabaseClientProvider);
    setState(() => _isLoading = true);
    try {
      await client.from('repair_parts').update({'part_status': newStatus}).eq('id', part['id']);
      _fetchFullData();
      _showToast('Statut de la pièce mis à jour.', _neonCyan);
    } catch (e) {
      _showToast('Erreur: $e', Colors.redAccent);
      _fetchFullData();
    }
  }

  // --- 4. تعديل المالية (اليد العاملة / التخفيض) ---
  Future<void> _updateFinance(String field, String title, double currentValue) async {
    final ctrl = TextEditingController(text: currentValue.toStringAsFixed(0));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        title: Text('Modifier $title', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'DA', suffixStyle: TextStyle(color: _textMuted)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newValue = double.tryParse(result) ?? 0;
      setState(() => _isLoading = true);
      try {
        await ref.read(supabaseClientProvider).from('repair_tickets').update({field: newValue}).eq('id', widget.ticketId);
        _fetchFullData();
      } catch (e) {
        _showToast('Erreur de mise à jour', Colors.redAccent);
        _fetchFullData();
      }
    }
  }

  // --- Quote Workflow ---
  Future<void> _showQuoteDialog(Color color) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final amountCtrl = TextEditingController(text: (_ticket?['estimated_cost'] as num?)?.toStringAsFixed(0) ?? '0');
        return AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
          title: const Text('Générer le devis', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Montant estimé à facturer', style: TextStyle(color: _textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(suffixText: 'DA', suffixStyle: TextStyle(color: _textMuted)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
              onPressed: () => Navigator.pop(ctx, {'amount': amountCtrl.text}),
              child: const Text('GÉNÉRER LE DEVIS'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    final amount = double.tryParse(result['amount'] ?? '') ?? 0;
    final client = ref.read(supabaseClientProvider);
    await client.from('repair_tickets').update({
      'estimated_cost': amount,
      'quote_generated_at': DateTime.now().toIso8601String(),
    }).eq('id', widget.ticketId);
    final user = Supabase.instance.client.auth.currentUser;
    await client.from('repair_ticket_events').insert({
      'ticket_id': widget.ticketId,
      'event_type': 'quote_generated',
      'old_value': null,
      'new_value': amount.toString(),
      'created_by': user?.id,
      'notes': 'Devis généré: $amount DA',
    });
    _fetchFullData();
    _showToast('Devis généré', Colors.green);
  }

  Future<void> _markQuoteAsSent(Color color) async {
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        title: const Text('Mode d\'envoi du devis', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['WhatsApp', 'SMS', 'Appel', 'Email', 'En personne'].map((m) => ListTile(
            leading: Icon(_quoteMethodIcon(m), color: _neonCyan),
            title: Text(m, style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, m),
          )).toList(),
        ),
      ),
    );
    if (method == null) return;

    final client = ref.read(supabaseClientProvider);
    await client.from('repair_tickets').update({
      'quote_sent_at': DateTime.now().toIso8601String(),
      'quote_sent_method': method,
    }).eq('id', widget.ticketId);
    final user = Supabase.instance.client.auth.currentUser;
    await client.from('repair_ticket_events').insert({
      'ticket_id': widget.ticketId,
      'event_type': 'quote_sent',
      'old_value': null,
      'new_value': method,
      'created_by': user?.id,
      'notes': 'Devis envoyé par $method',
    });
    _fetchFullData();
    _showToast('Devis marqué comme envoyé', Colors.green);
  }

  Future<void> _recordCustomerApproval(Color color) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final amountCtrl = TextEditingController(text: (_ticket?['approved_amount'] as num?)?.toStringAsFixed(0) ?? (_ticket?['estimated_cost'] as num?)?.toStringAsFixed(0) ?? '0');
        final reasonCtrl = TextEditingController();
        String? action = 'approve';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: _panelDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
            title: const Text('Réponse du client', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: action == 'approve' ? _neonEmerald.withOpacity(0.2) : Colors.transparent,
                          foregroundColor: action == 'approve' ? _neonEmerald : _textMuted,
                          side: BorderSide(color: action == 'approve' ? _neonEmerald : _glassBorder),
                        ),
                        onPressed: () => setDialogState(() => action = 'approve'),
                        child: const Text('APPROUVER'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: action == 'reject' ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
                          foregroundColor: action == 'reject' ? Colors.redAccent : _textMuted,
                          side: BorderSide(color: action == 'reject' ? Colors.redAccent : _glassBorder),
                        ),
                        onPressed: () => setDialogState(() => action = 'reject'),
                        child: const Text('REFUSER'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (action == 'approve')
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Montant approuvé (DA)', labelStyle: TextStyle(color: _textMuted)),
                  ),
                if (action == 'reject')
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Motif du refus', labelStyle: TextStyle(color: _textMuted)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
                onPressed: () => Navigator.pop(ctx, {'action': action, 'amount': amountCtrl.text, 'reason': reasonCtrl.text}),
                child: const Text('ENREGISTRER'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;
    final isApproved = result['action'] == 'approve';
    final client = ref.read(supabaseClientProvider);
    final updates = <String, dynamic>{
      'customer_approved': isApproved,
      'approved_at': DateTime.now().toIso8601String(),
    };
    if (isApproved) {
      updates['approved_amount'] = double.tryParse(result['amount'] ?? '') ?? 0;
    } else {
      updates['rejection_reason'] = result['reason'] ?? '';
    }
    await client.from('repair_tickets').update(updates).eq('id', widget.ticketId);
    final user = Supabase.instance.client.auth.currentUser;
    await client.from('repair_ticket_events').insert({
      'ticket_id': widget.ticketId,
      'event_type': isApproved ? 'quote_approved' : 'quote_rejected',
      'old_value': null,
      'new_value': isApproved ? result['amount'] : result['reason'],
      'created_by': user?.id,
      'notes': isApproved ? 'Client a approuvé le devis' : 'Client a refusé le devis',
    });
    _fetchFullData();
    _showToast(isApproved ? 'Approbation enregistrée' : 'Refus enregistré', isApproved ? Colors.green : Colors.redAccent);
  }

  IconData _quoteMethodIcon(String method) {
    switch (method) {
      case 'WhatsApp': return Icons.chat;
      case 'SMS': return Icons.sms;
      case 'Appel': return Icons.phone;
      case 'Email': return Icons.email;
      default: return Icons.person;
    }
  }

  // --- Quality Control ---
  Future<void> _showQCDialog(Color color) async {
    final notesCtrl = TextEditingController(text: _ticket?['qc_notes'] as String? ?? '');
    String? selectedStatus = _ticket?['qc_status'] as String? ?? 'Réussi';
    bool tested = _ticket?['device_tested'] as bool? ?? false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
          title: const Text('Contrôle Qualité', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedStatus == 'Réussi' ? _neonEmerald.withOpacity(0.2) : Colors.transparent,
                        foregroundColor: selectedStatus == 'Réussi' ? _neonEmerald : _textMuted,
                        side: BorderSide(color: selectedStatus == 'Réussi' ? _neonEmerald : _glassBorder),
                      ),
                      onPressed: () => setDialogState(() => selectedStatus = 'Réussi'),
                      child: const Text('RÉUSSI'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedStatus == 'Échoué' ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
                        foregroundColor: selectedStatus == 'Échoué' ? Colors.redAccent : _textMuted,
                        side: BorderSide(color: selectedStatus == 'Échoué' ? Colors.redAccent : _glassBorder),
                      ),
                      onPressed: () => setDialogState(() => selectedStatus = 'Échoué'),
                      child: const Text('ÉCHOUÉ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Appareil testé fonctionnel', style: TextStyle(color: Colors.white)),
                value: tested,
                activeColor: _neonEmerald,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setDialogState(() => tested = v ?? false),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Notes CQ', labelStyle: TextStyle(color: _textMuted)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
              onPressed: () => Navigator.pop(ctx, {'status': selectedStatus, 'tested': tested, 'notes': notesCtrl.text}),
              child: const Text('ENREGISTRER'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final client = ref.read(supabaseClientProvider);
    final user = Supabase.instance.client.auth.currentUser;
    await client.from('repair_tickets').update({
      'qc_status': result['status'],
      'qc_notes': (result['notes'] as String).trim(),
      'qc_done_by': user?.id,
      'qc_done_at': DateTime.now().toIso8601String(),
      'device_tested': result['tested'],
    }).eq('id', widget.ticketId);
    await client.from('repair_ticket_events').insert({
      'ticket_id': widget.ticketId,
      'event_type': 'qc_result',
      'old_value': _ticket?['qc_status'] as String? ?? 'En attente',
      'new_value': result['status'] as String,
      'created_by': user?.id,
      'notes': 'CQ: ${result['status']} - ${(result['notes'] as String).trim()}',
    });
    _fetchFullData();
    _showToast('CQ enregistré: ${result['status']}', Colors.green);
  }

  Future<void> _resetQC() async {
    final client = ref.read(supabaseClientProvider);
    final user = Supabase.instance.client.auth.currentUser;
    await client.from('repair_tickets').update({
      'qc_status': 'En attente',
      'qc_notes': null,
      'qc_done_by': null,
      'qc_done_at': null,
      'device_tested': false,
    }).eq('id', widget.ticketId);
    await client.from('repair_ticket_events').insert({
      'ticket_id': widget.ticketId,
      'event_type': 'qc_reset',
      'old_value': _ticket?['qc_status'] as String? ?? 'En attente',
      'new_value': 'En attente',
      'created_by': user?.id,
      'notes': 'CQ réinitialisé',
    });
    _fetchFullData();
    _showToast('CQ réinitialisé', Colors.orangeAccent);
  }

  // --- 5. إلغاء التذكرة بالكامل (الدرع الواقي) ---
  Future<void> _cancelTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        title: const Text('Annuler le dossier ?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Toutes les pièces "Utilisées" seront retournées au stock. Cette action est irréversible.', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non', style: TextStyle(color: _textMuted))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, Annuler')),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      // إرجاع كل القطع السليمة للمخزون
      for (var p in _parts) {
        if (p['part_status'] == 'Utilisé') {
          // تغيير حالة القطعة في التذكرة لكي لا تحسب مرة أخرى (قاعدة البيانات مسؤولة عن المخزون إن كان لها Trigger)
          await client.from('repair_parts').update({'part_status': 'Retourné'}).eq('id', p['id']);
        }
      }
      // تسجيل الحدث
      final user = Supabase.instance.client.auth.currentUser;
      final oldStatus = _ticket?['status'] as String? ?? 'En attente';
      await client.from('repair_ticket_events').insert({
        'ticket_id': widget.ticketId,
        'event_type': 'status_change',
        'old_value': oldStatus,
        'new_value': 'Annulé',
        'created_by': user?.id,
        'notes': 'Annulation du dossier',
      });

      // تغيير حالة التذكرة
      await client.from('repair_tickets').update({'status': 'Annulé'}).eq('id', widget.ticketId);
      _fetchFullData();
      _showToast('Dossier annulé et stock restauré.', Colors.green);
    } catch (e) {
      _showToast('Erreur: $e', Colors.redAccent);
      _fetchFullData();
    }
  }

  Future<void> _showAssignTechnicianDialog(List<Map<String, dynamic>> profiles, String? currentId, Color color) async {
    final client = ref.read(supabaseClientProvider);
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        title: const Text('Affecter un technicien', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_off, color: _textMuted),
                title: const Text('Non affecté', style: TextStyle(color: _textMuted)),
                selected: currentId == null,
                onTap: () => Navigator.pop(ctx, '__unassign__'),
              ),
              const Divider(color: _glassBorder),
              ...profiles.map((p) => ListTile(
                leading: const Icon(Icons.person_pin, color: _neonEmerald),
                title: Text(p['full_name'] ?? 'Sans nom', style: const TextStyle(color: Colors.white)),
                selected: p['id'] == currentId,
                onTap: () => Navigator.pop(ctx, p['id'] as String),
              )),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return;
    final newValue = selected == '__unassign__' ? null : selected;
    final oldValue = _ticket?['assigned_technician_id'] as String?;

    await client.from('repair_tickets').update({'assigned_technician_id': newValue}).eq('id', widget.ticketId);
    final user = Supabase.instance.client.auth.currentUser;
    await client.from('repair_ticket_events').insert({
      'ticket_id': widget.ticketId,
      'event_type': 'technician_assignment',
      'old_value': oldValue,
      'new_value': newValue,
      'created_by': user?.id,
      'notes': newValue == null ? 'Technicien désaffecté' : 'Technicien affecté',
    });
    _fetchFullData();
    _showToast(newValue == null ? 'Technicien désaffecté' : 'Technicien affecté', Colors.green);
  }

  void _showToast(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showSearchStockDialog(BuildContext context, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: _StockSearchDialog(
          color: color,
          onProductSelected: (product) => _addPartToTicket(product),
        ),
      ),
    );
  }

  // --- 6. Paiements ---
  double get _totalPartsCost {
    double total = 0;
    for (var p in _parts) {
      if (p['part_status'] == 'Utilisé') {
        total += (p['charged_price'] as num).toDouble();
      }
    }
    return total;
  }

  double get _totalPayments {
    double total = (_ticket?['advance_payment'] as num?)?.toDouble() ?? 0;
    for (var p in _payments) {
      total += (p['amount'] as num).toDouble();
    }
    return total;
  }

  double get _remainingBalance {
    final labor = (_ticket?['labor_cost'] as num?)?.toDouble() ?? 0;
    final discount = (_ticket?['discount'] as num?)?.toDouble() ?? 0;
    return (_totalPartsCost + labor - discount) - _totalPayments;
  }

  Future<void> _recordPayment(double amount, String method, String? notes) async {
    final client = ref.read(supabaseClientProvider);
    final user = Supabase.instance.client.auth.currentUser;
    try {
      await client.from('repair_payments').insert({
        'ticket_id': widget.ticketId,
        'amount': amount,
        'payment_method': method,
        'notes': notes,
        'created_by': user?.id,
      });
      _fetchFullData();
      _showToast('Paiement de $amount DA enregistré', _neonEmerald);
    } catch (e) {
      _showToast('Erreur: $e', Colors.redAccent);
    }
  }

  Future<void> _showPaymentDialog(Color color) async {
    final amountCtrl = TextEditingController();
    String selectedMethod = 'Espèces';
    final notesCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        title: const Text('Enregistrer un paiement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reste à payer: ${_remainingBalance.toStringAsFixed(0)} DA',
                  style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setLocalState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Montant (DA)',
                        prefixIcon: Icon(Icons.attach_money, color: _textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      dropdownColor: _panelDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Méthode de paiement',
                        prefixIcon: Icon(Icons.payment, color: _textMuted),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Espèces', child: Text('Espèces')),
                        DropdownMenuItem(value: 'Carte', child: Text('Carte bancaire')),
                        DropdownMenuItem(value: 'Virement', child: Text('Virement')),
                        DropdownMenuItem(value: 'Chèque', child: Text('Chèque')),
                      ],
                      onChanged: (v) => setLocalState(() => selectedMethod = v!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Notes (optionnel)',
                        prefixIcon: Icon(Icons.notes, color: _textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonEmerald, foregroundColor: Colors.white),
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) {
                _showToast('Montant invalide', Colors.redAccent);
                return;
              }
              Navigator.pop(ctx);
              _recordPayment(amount, selectedMethod, notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
            },
            child: const Text('Confirmer le paiement', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);
    final activeNeon = isOwner ? _neonCyan : _neonEmerald;

    if (_isLoading) return const Scaffold(backgroundColor: _bgCarbon, body: Center(child: CircularProgressIndicator(color: _neonCyan)));
    if (_ticket == null) return Scaffold(backgroundColor: _bgCarbon, body: Center(child: TextButton(onPressed: () => context.pop(), child: const Text('TICKET INTROUVABLE - RETOUR', style: TextStyle(color: Colors.redAccent)))));

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Stack(
        children: [
          _buildAmbientGlow(activeNeon),
          Column(
            children: [
              _buildTopHeader(context, activeNeon),
              Expanded(
                child: Row(
                  children: [
                    _buildLeftSidebar(activeNeon),
                    Expanded(child: _buildMainOperations(activeNeon)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlow(Color color) {
    return Positioned(
      top: -100, right: -100,
      child: Container(width: 600, height: 600, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.03), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 200, spreadRadius: 50)])),
    );
  }

  Widget _buildTopHeader(BuildContext context, Color color) {
    final qrHash = _ticket?['qr_code_hash']?.toString() ?? 'TICKET';
    final shortHash = qrHash.length > 8 ? qrHash.substring(0, 8) : qrHash;
    final isCanceled = _ticket?['status'] == 'Annulé';

    return Container(
      height: 80, padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: _panelDark, border: Border(bottom: BorderSide(color: _glassBorder))),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
          const SizedBox(width: 16),
          Text('DOSSIER #${shortHash.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
          const Spacer(),
          _buildStatusBadge(_ticket?['status'] ?? 'En attente', color),
          if (!isCanceled) ...[
            const SizedBox(width: 16),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: _panelDark,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'cancel', child: Text('Annuler le dossier (Retour Stock)', style: TextStyle(color: Colors.redAccent))),
              ],
              onSelected: (val) { if (val == 'cancel') _cancelTicket(); },
            )
          ]
        ],
      ),
    );
  }

  Widget _buildLeftSidebar(Color color) {
    final bool isAnon = _ticket?['customer_id'] == null;
    final String clientName = isAnon ? (_ticket?['client_name_temp'] ?? 'Anonyme') : (_ticket?['customers']?['full_name'] ?? 'Client');
    final String clientPhone = isAnon ? (_ticket?['client_phone_temp'] ?? 'N/A') : (_ticket?['customers']?['phone_number'] ?? 'N/A');

    return Container(
      width: 350, padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: _glassBorder))),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('INFORMATIONS APPAREIL', Icons.smartphone, color),
            _buildInfoTile('Modèle', _ticket?['device_name'] ?? 'N/A', Icons.phone_android),
            _buildInfoTile('IMEI / SN', _ticket?['imei'] ?? 'N/A', Icons.qr_code_scanner),
            _buildInfoTile('Code / Schéma', _ticket?['device_password'] ?? 'Aucun', Icons.lock_open),
            const SizedBox(height: 24),
            _buildSectionHeader('DIAGNOSTIC INITIAL', Icons.visibility, color),
            Text(_ticket?['pre_diagnostic'] ?? 'Aucun constat.', style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 32),
            _buildSectionHeader('CLIENT', Icons.person, color),
            Text(clientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(clientPhone, style: const TextStyle(color: _textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            _buildSectionHeader('TECHNICIEN AFFECTÉ', Icons.build, color),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: ref.read(supabaseClientProvider).from('profiles').select('id, full_name').order('full_name'),
              builder: (ctx, snap) {
                final profiles = snap.data ?? [];
                final currentId = _ticket?['assigned_technician_id'] as String?;
                final currentName = profiles.where((p) => p['id'] == currentId).map((p) => p['full_name'] as String).firstOrNull ?? 'Non affecté';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _ticket?['status'] == 'Annulé' ? null : () => _showAssignTechnicianDialog(profiles, currentId, color),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Icon(Icons.person_pin, color: currentId != null ? _neonEmerald : _textMuted, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(currentName, style: TextStyle(color: currentId != null ? Colors.white : _textMuted, fontSize: 13)),
                          ),
                          if (_ticket?['status'] != 'Annulé') ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 12, color: _textMuted),
                          ],
                        ],
                      ),
                    ),
                    if (snap.hasError)
                      Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainOperations(Color color) {
    return Column(
      children: [
        Expanded(child: _buildPartsSection(color)),
        const SizedBox(height: 16),
        _buildPaymentsSection(color),
        const SizedBox(height: 16),
        _buildQuoteSection(color),
        const SizedBox(height: 16),
        _buildQCSection(color),
        const SizedBox(height: 16),
        _buildFinancialSummary(color),
      ],
    );
  }

  Widget _buildQCSection(Color color) {
    final isCanceled = _ticket?['status'] == 'Annulé';
    final qcStatus = _ticket?['qc_status'] as String? ?? 'En attente';
    final deviceTested = _ticket?['device_tested'] as bool? ?? false;

    Color qcColor;
    switch (qcStatus) {
      case 'Réussi':
        qcColor = _neonEmerald;
        break;
      case 'Échoué':
        qcColor = Colors.redAccent;
        break;
      default:
        qcColor = _textMuted;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: qcColor.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: qcColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CONTRÔLE QUALITÉ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('QC: $qcStatus • Testé: ${deviceTested ? 'Oui' : 'Non'}', style: TextStyle(color: qcColor, fontSize: 11)),
                if (qcStatus == 'Échoué' && _ticket?['qc_notes'] != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('Note: ${_ticket!['qc_notes']}', style: const TextStyle(color: Colors.redAccent, fontSize: 11))),
              ],
            ),
          ),
          if (!isCanceled && qcStatus != 'Réussi')
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionChip(qcStatus == 'En attente' ? 'CQ Réussi' : 'Retour CQ', Icons.check_circle, _neonEmerald, () => _showQCDialog(color)),
                if (qcStatus != 'En attente')
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildActionChip('Réinitialiser', Icons.refresh, _textMuted, () => _resetQC()),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuoteSection(Color color) {
    final isCanceled = _ticket?['status'] == 'Annulé';
    final quoteGenerated = _ticket?['quote_generated_at'] != null;
    final quoteSent = _ticket?['quote_sent_at'] != null;
    final customerApproved = _ticket?['customer_approved'] as bool?;
    final quoteSentMethod = _ticket?['quote_sent_method'] as String?;

    String statusText;
    Color statusColor;
    if (customerApproved == true) {
      statusText = 'Approuvé (${_ticket?['approved_amount'] ?? ''} DA)';
      statusColor = _neonEmerald;
    } else if (customerApproved == false) {
      statusText = 'Refusé: ${_ticket?['rejection_reason'] ?? ''}';
      statusColor = Colors.redAccent;
    } else if (quoteSent) {
      statusText = 'Envoyé par $quoteSentMethod';
      statusColor = Colors.orangeAccent;
    } else if (quoteGenerated) {
      statusText = 'Généré';
      statusColor = color;
    } else {
      statusText = 'Non généré';
      statusColor = _textMuted;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: statusColor.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DEVIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(statusText, style: TextStyle(color: statusColor, fontSize: 11)),
              ],
            ),
          ),
          if (!isCanceled)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!quoteGenerated)
                  _buildActionChip('Générer', Icons.description, color, () => _showQuoteDialog(color))
                else ...[
                  if (!quoteSent)
                    _buildActionChip('Envoyer', Icons.send, Colors.orangeAccent, () => _markQuoteAsSent(color))
                  else if (customerApproved == null)
                    _buildActionChip('Client', Icons.thumbs_up_down, _neonEmerald, () => _recordCustomerApproval(color)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, Color chipColor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: chipColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: chipColor.withOpacity(0.3))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: chipColor),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartsSection(Color color) {
    final isCanceled = _ticket?['status'] == 'Annulé';
    return Container(
      decoration: BoxDecoration(color: _panelDark.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PIÈCES ET COMPOSANTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (!isCanceled)
                  ElevatedButton.icon(
                    onPressed: () => _showSearchStockDialog(context, color),
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('AJOUTER'),
                    style: ElevatedButton.styleFrom(backgroundColor: color.withOpacity(0.1), foregroundColor: color),
                  ),
              ],
            ),
          ),
          const Divider(color: _glassBorder, height: 1),
          Expanded(
            child: _parts.isEmpty 
              ? const Center(child: Text('Aucune pièce consommée', style: TextStyle(color: _textMuted)))
              : ListView.builder(
                  itemCount: _parts.length,
                  itemBuilder: (context, index) {
                    final part = _parts[index];
                    final isDefective = part['part_status'] == 'Défectueux';
                    final isReturned = part['part_status'] == 'Retourné';
                    
                    return ListTile(
                      title: Text(part['products']?['product_name'] ?? 'Inconnu', style: TextStyle(color: isDefective ? Colors.redAccent : Colors.white, decoration: isReturned ? TextDecoration.lineThrough : null)),
                      subtitle: Text('État: ${part['part_status'] ?? 'Utilisé'}', style: TextStyle(color: isDefective ? Colors.redAccent : color.withOpacity(0.7), fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${part['charged_price']} DA', style: TextStyle(color: isReturned || isDefective ? _textMuted : Colors.white, fontWeight: FontWeight.bold, decoration: isReturned || isDefective ? TextDecoration.lineThrough : null)),
                          if (!isCanceled && !isReturned) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: _textMuted, size: 18),
                              color: _panelDark,
                              itemBuilder: (_) => [
                                if (!isDefective) const PopupMenuItem(value: 'defect', child: Text('Marquer Défectueux', style: TextStyle(color: Colors.orangeAccent))),
                                const PopupMenuItem(value: 'delete', child: Text('Supprimer (Retour Stock)', style: TextStyle(color: Colors.redAccent))),
                              ],
                              onSelected: (val) {
                                if (val == 'delete') _removePart(part);
                                if (val == 'defect') _changePartStatus(part, 'Défectueux');
                              },
                            )
                          ]
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

  Widget _buildPaymentsSection(Color color) {
    final isCanceled = _ticket?['status'] == 'Annulé';
    return Container(
      decoration: BoxDecoration(color: _panelDark.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PAIEMENTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (!isCanceled)
                  ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(color),
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('AJOUTER PAIEMENT'),
                    style: ElevatedButton.styleFrom(backgroundColor: _neonEmerald.withOpacity(0.1), foregroundColor: _neonEmerald),
                  ),
              ],
            ),
          ),
          const Divider(color: _glassBorder, height: 1),
          if (_payments.isEmpty && ((_ticket?['advance_payment'] as num?)?.toDouble() ?? 0) <= 0)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucun paiement enregistré', style: TextStyle(color: _textMuted))),
            )
          else
            ...List.generate(_payments.length + (((_ticket?['advance_payment'] as num?)?.toDouble() ?? 0) > 0 ? 1 : 0), (index) {
              final isAdvance = ((_ticket?['advance_payment'] as num?)?.toDouble() ?? 0) > 0 && index == 0;
              final payment = isAdvance ? null : _payments[index - (((_ticket?['advance_payment'] as num?)?.toDouble() ?? 0) > 0 ? 1 : 0)];
              final amount = isAdvance ? (_ticket?['advance_payment'] as num?)?.toDouble() ?? 0 : (payment!['amount'] as num).toDouble();
              final method = isAdvance ? 'Avance' : (payment!['payment_method'] ?? 'Espèces');
              final date = isAdvance ? (_ticket?['created_at'] ?? '') : (payment!['paid_at'] ?? '');

              return ListTile(
                dense: true,
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: isAdvance ? color.withOpacity(0.15) : _neonEmerald.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(isAdvance ? Icons.payments_outlined : Icons.check_circle_outline, color: isAdvance ? color : _neonEmerald, size: 18),
                ),
                title: Text('${amount.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('$method • ${DateTime.tryParse(date.toString())?.toString().substring(0, 16) ?? ''}', style: const TextStyle(color: _textMuted, fontSize: 12)),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(Color color) {
    final partsTotal = _totalPartsCost;
    final labor = (_ticket?['labor_cost'] as num?)?.toDouble() ?? 0;
    final discount = (_ticket?['discount'] as num?)?.toDouble() ?? 0;
    final totalPaid = _totalPayments;
    final remaining = _remainingBalance;

    final isCanceled = _ticket?['status'] == 'Annulé';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMoneyStat('PIÈCES', partsTotal, _textMuted),
          _buildEditableMoneyStat('M.O (Main d\'œuvre)', labor, _textMuted, isCanceled ? null : () => _updateFinance('labor_cost', 'la Main d\'œuvre', labor)),
          _buildEditableMoneyStat('REMISE', discount, Colors.redAccent, isCanceled ? null : () => _updateFinance('discount', 'la Remise', discount)),
          _buildMoneyStat('PAYÉ', totalPaid, _neonEmerald),
          Container(width: 1, height: 40, color: _glassBorder),
          _buildMoneyStat(isCanceled ? 'ANNULÉ' : 'RESTE', isCanceled ? 0 : remaining, isCanceled ? Colors.redAccent : color, isBig: true),
        ],
      ),
    );
  }

  // --- Helpers ---
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11))]));
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(icon, color: _textMuted, size: 16), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))])]));
  }

  Widget _buildStatusBadge(String status, Color color) {
    final statusColor = status == 'Annulé' ? Colors.redAccent : color;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.5))), child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)));
  }

  Widget _buildMoneyStat(String label, double value, Color color, {bool isBig = false}) {
    return Column(children: [Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)), const SizedBox(height: 4), Text('${value.toStringAsFixed(0)} DA', style: TextStyle(color: color, fontSize: isBig ? 22 : 16, fontWeight: FontWeight.w900))]);
  }

  Widget _buildEditableMoneyStat(String label, double value, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)),
                if (onTap != null) ...[const SizedBox(width: 4), const Icon(Icons.edit, size: 10, color: _textMuted)],
              ],
            ),
            const SizedBox(height: 4),
            Text('${value.toStringAsFixed(0)} DA', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

// --- نافذة البحث الزجاجية (لم تتغير) ---
class _StockSearchDialog extends StatefulWidget {
  final Color color;
  final Function(Map<String, dynamic>) onProductSelected;
  const _StockSearchDialog({required this.color, required this.onProductSelected});

  @override
  State<_StockSearchDialog> createState() => _StockSearchDialogState();
}

class _StockSearchDialogState extends State<_StockSearchDialog> {
  String _searchQuery = '';
  int? _selectedCategoryId;
  List<dynamic> _categories = [];
  bool _isLoadingCats = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await Supabase.instance.client.from('categories').select('id, category_name');
      if (mounted) setState(() { _categories = res; _isLoadingCats = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingCats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    var baseQuery = client.from('products').select('*, categories(category_name)').gt('stock_quantity', 0).ilike('product_name', '%$_searchQuery%');
    if (_selectedCategoryId != null) baseQuery = baseQuery.eq('category_id', _selectedCategoryId!);
    final futureQuery = baseQuery.limit(15);

    return AlertDialog(
      backgroundColor: _panelDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: 'Rechercher une pièce...', hintStyle: const TextStyle(color: _textMuted), prefixIcon: Icon(Icons.search, color: widget.color), border: InputBorder.none),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          if (!_isLoadingCats && _categories.isNotEmpty) ...[
            const Divider(color: _glassBorder, height: 1), const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_buildCatChip('Tous', null), ..._categories.map((c) => _buildCatChip(c['category_name'], c['id']))])),
          ]
        ],
      ),
      content: SizedBox(
        width: 500, height: 400,
        child: FutureBuilder(
          future: futureQuery,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: widget.color));
            final products = snap.data as List? ?? [];
            if (products.isEmpty) return const Center(child: Text('Aucun produit disponible', style: TextStyle(color: _textMuted)));
            return ListView.separated(
              itemCount: products.length, separatorBuilder: (_, __) => const Divider(color: _glassBorder, height: 1),
              itemBuilder: (ctx, i) {
                final p = products[i];
                final catName = p['categories']?['category_name'] ?? 'N/A';
                return ListTile(
                  title: Row(children: [Expanded(child: Text(p['product_name'] ?? 'Inconnu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: widget.color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: widget.color.withOpacity(0.3))), child: Text(catName, style: TextStyle(color: widget.color, fontSize: 10, fontWeight: FontWeight.bold)))]),
                  subtitle: Text('Stock: ${p['stock_quantity']} | Prix: ${p['reference_price']} DA', style: const TextStyle(color: _textMuted, fontSize: 13)),
                  trailing: IconButton(icon: Icon(Icons.add_shopping_cart, color: widget.color), onPressed: () { widget.onProductSelected(p); Navigator.pop(context); }),
                  onTap: () { widget.onProductSelected(p); Navigator.pop(context); },
                );
              },
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer', style: TextStyle(color: _textMuted)))],
    );
  }

  Widget _buildCatChip(String label, int? id) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: selected ? widget.color : _textMuted, fontSize: 11)),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategoryId = selected ? null : id),
        backgroundColor: Colors.transparent, selectedColor: widget.color.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: selected ? widget.color : _glassBorder)),
        showCheckmark: false,
      ),
    );
  }
}