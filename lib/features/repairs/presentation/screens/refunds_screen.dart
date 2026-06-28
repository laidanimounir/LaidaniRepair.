import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';
import 'package:laidani_repair/constants/repair_status.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

class RefundsScreen extends ConsumerStatefulWidget {
  const RefundsScreen({super.key});

  @override
  ConsumerState<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends ConsumerState<RefundsScreen> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _parts = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = false;
  String? _error;
  String? _searchError;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() { _loading = true; _error = null; _searchError = null; _ticket = null; });
    try {
      final client = ref.read(supabaseClientProvider);
      Map<String, dynamic>? result;

      if (q.contains('-') && q.length >= 36) {
        result = await client
            .from('repair_tickets')
            .select('*, customers(full_name, phone_number)')
            .eq('id', q.trim())
            .maybeSingle();
      } else {
        result = await client
            .from('repair_tickets')
            .select('*, customers(full_name, phone_number)')
            .or('client_phone_temp.ilike.%$q%')
            .limit(1)
            .maybeSingle();
      }

      if (result == null) {
        if (mounted) setState(() { _searchError = 'Aucun ticket trouvé'; _loading = false; });
        return;
      }
      await _loadTicketDetails(client, Map<String, dynamic>.from(result));
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadTicketDetails(SupabaseClient client, Map<String, dynamic> ticket) async {
    final ticketId = ticket['id'] as String;
    final payments = await client.from('repair_payments').select('*').eq('ticket_id', ticketId).order('paid_at', ascending: false);
    final parts = await client.from('repair_parts').select('*, products(product_name)').eq('ticket_id', ticketId);
    if (mounted) {
      setState(() {
        _ticket = ticket;
        _payments = List<Map<String, dynamic>>.from(payments);
        _parts = List<Map<String, dynamic>>.from(parts);
        _loading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final data = await client
          .from('repair_payments')
          .select('*, repair_tickets!inner(id, customers(full_name, phone_number))')
          .eq('is_refunded', true)
          .order('refunded_at', ascending: false)
          .limit(50);
      if (mounted) setState(() => _history = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> _processFullRefund(String paymentId, double amount) async {
    final reasonCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        title: const Text('Confirmer le remboursement', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Montant à rembourser: ${amount.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Motif du remboursement...', hintStyle: TextStyle(color: _textMuted), filled: true, fillColor: _bgCarbon, border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: const Text('REMBOURSER'),
          ),
        ],
      ),
    );

    if (result == null) return;
    try {
      final client = ref.read(supabaseClientProvider);
      final user = Supabase.instance.client.auth.currentUser;
      await client.from('repair_payments').update({
        'is_refunded': true,
        'refund_amount': amount,
        'refund_type': 'full',
        'refunded_at': DateTime.now().toIso8601String(),
        'refund_reason': result,
      }).eq('id', paymentId);
      await client.from('repair_tickets').update({'payment_status': 'Remboursé'}).eq('id', _ticket!['id']);
      await client.from('repair_ticket_events').insert({
        'ticket_id': _ticket!['id'],
        'event_type': 'refund_processed',
        'new_value': amount.toString(),
        'created_by': user?.id,
        'notes': 'Remboursement complet: $result',
      });
      await _refreshTicket(client);
      await _loadHistory();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remboursement effectué'), backgroundColor: _neonEmerald));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _processPartialRefund(String paymentId, double paidAmount) async {
    String refundType = 'full';
    final amountCtrl = TextEditingController(text: paidAmount.toStringAsFixed(0));
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
          title: const Text('Remboursement partiel', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Type de remboursement', style: TextStyle(color: _textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _refundTypeChip('Pièces', 'parts', refundType, (v) => setDialogState(() => refundType = v!)),
                    _refundTypeChip('M.O.', 'labor', refundType, (v) => setDialogState(() => refundType = v!)),
                    _refundTypeChip('Les deux', 'both', refundType, (v) => setDialogState(() => refundType = v!)),
                    _refundTypeChip('Tout', 'full', refundType, (v) => setDialogState(() => refundType = v!)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Montant (DA)', labelStyle: TextStyle(color: _textMuted)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Motif du remboursement...', hintStyle: TextStyle(color: _textMuted), filled: true, fillColor: _bgCarbon, border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: _bgCarbon),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('REMBOURSER PARTIEL'),
            ),
          ],
        ),
      ),
    );

    final refundAmt = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (refundAmt <= 0) return;
    try {
      final client = ref.read(supabaseClientProvider);
      final user = Supabase.instance.client.auth.currentUser;
      await client.from('repair_payments').update({
        'is_refunded': true,
        'refund_amount': refundAmt,
        'refund_type': refundType,
        'refunded_at': DateTime.now().toIso8601String(),
        'refund_reason': reasonCtrl.text.trim(),
      }).eq('id', paymentId);
      if (refundAmt >= paidAmount) {
        await client.from('repair_tickets').update({'payment_status': 'Remboursé'}).eq('id', _ticket!['id']);
      }
      await client.from('repair_ticket_events').insert({
        'ticket_id': _ticket!['id'],
        'event_type': 'refund_partial',
        'new_value': '$refundAmt ($refundType)',
        'created_by': user?.id,
        'notes': 'Remboursement partiel: ${reasonCtrl.text.trim()}',
      });
      await _refreshTicket(client);
      await _loadHistory();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remboursement partiel effectué'), backgroundColor: Colors.orangeAccent));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _returnPartsToStock() async {
    if (_parts.isEmpty) return;
    final usedParts = _parts.where((p) => p['part_status'] == 'Utilisé').toList();
    if (usedParts.isEmpty) return;

    final checked = <String, bool>{};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
          title: const Text('Retourner les pièces en stock ?', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: usedParts.map((p) {
              final pid = p['id'] as String;
              final name = p['products']?['product_name'] ?? 'Pièce';
              final qty = (p['quantity'] as num?)?.toInt() ?? 1;
              return CheckboxListTile(
                title: Text('$name (x$qty)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                value: checked[pid] ?? true,
                activeColor: _neonCyan,
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setDialogState(() => checked[pid] = v ?? false),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonEmerald, foregroundColor: _bgCarbon),
              onPressed: () => Navigator.pop(ctx, Set<String>.from(checked.entries.where((e) => e.value).map((e) => e.key))),
              child: const Text('Retourner en stock'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty) return;
    try {
      final client = ref.read(supabaseClientProvider);
      for (final pid in result) {
        await client.from('repair_parts').update({'part_status': 'Retourné'}).eq('id', pid);
      }
      await _refreshTicket(client);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pièces retournées en stock'), backgroundColor: _neonEmerald));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _refreshTicket(SupabaseClient client) async {
    if (_ticket == null) return;
    final ticketId = _ticket!['id'];
    final updated = await client.from('repair_tickets').select('*, customers(full_name, phone_number)').eq('id', ticketId).maybeSingle();
    final payments = await client.from('repair_payments').select('*').eq('ticket_id', ticketId).order('paid_at', ascending: false);
    final parts = await client.from('repair_parts').select('*, products(product_name)').eq('ticket_id', ticketId);
    if (mounted) {
      setState(() {
        if (updated != null) _ticket = Map<String, dynamic>.from(updated);
        _payments = List<Map<String, dynamic>>.from(payments);
        _parts = List<Map<String, dynamic>>.from(parts);
      });
    }
  }

  Widget _refundTypeChip(String label, String value, String current, ValueChanged<String?> onSelected) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: selected ? _bgCarbon : Colors.white, fontSize: 12)),
      selected: selected,
      backgroundColor: _panelDark,
      selectedColor: _neonCyan,
      side: BorderSide(color: selected ? _neonCyan : _glassBorder),
      onSelected: (_) => onSelected(value),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ID du ticket ou téléphone...',
                hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                filled: true, fillColor: _bgCarbon,
                prefixIcon: const Icon(Icons.search, color: _neonCyan, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _glassBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _glassBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _neonCyan)),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            onPressed: _loading ? null : _search,
            icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _bgCarbon)) : const Icon(Icons.search, size: 20),
            label: const Text('Rechercher', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard() {
    final t = _ticket!;
    final customerName = t['customers']?['full_name'] ?? t['client_name_temp'] ?? 'Inconnu';
    final customerPhone = t['customers']?['phone_number'] ?? t['client_phone_temp'] ?? '';
    final device = '${t['device_brand'] ?? ''} ${t['device_name'] ?? ''}'.trim();
    final finalCost = (t['final_cost'] as num?)?.toDouble() ?? 0;
    final advance = (t['advance_payment'] as num?)?.toDouble() ?? 0;
    final paid = (t['paid_amount'] as num?)?.toDouble() ?? 0;
    final paymentStatus = t['payment_status'] as String? ?? 'Non payé';

    Color statusColor = paymentStatus == 'Remboursé' ? Colors.redAccent : Colors.orangeAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(customerName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.4))),
                    child: Text(paymentStatus, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (customerPhone.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Tél: $customerPhone', style: const TextStyle(color: _textMuted, fontSize: 13))),
              if (device.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(device, style: const TextStyle(color: _textMuted, fontSize: 13))),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildAmountChip('Total', finalCost, _neonCyan),
                  const SizedBox(width: 8),
                  _buildAmountChip('Avance', advance, Colors.orangeAccent),
                  const SizedBox(width: 8),
                  _buildAmountChip('Payé', paid, _neonEmerald),
                ],
              ),
            ],
          ),
        ),

        if (_payments.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('PAIEMENTS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._payments.map((p) => _buildPaymentCard(p)),
        ],

        if (_parts.any((p) => p['part_status'] == 'Utilisé')) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('PIÈCES', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: _neonEmerald),
                onPressed: _returnPartsToStock,
                icon: const Icon(Icons.replay, size: 16),
                label: const Text('Retourner en stock', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._parts.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
            child: Row(
              children: [
                Expanded(child: Text(p['products']?['product_name'] ?? 'Pièce', style: const TextStyle(color: Colors.white, fontSize: 13))),
                Text('x${p['quantity'] ?? 1}', style: const TextStyle(color: _textMuted, fontSize: 12)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p['part_status'] == 'Retourné' ? Colors.greenAccent.withOpacity(0.1) : _textMuted.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p['part_status'] ?? '', style: TextStyle(color: p['part_status'] == 'Retourné' ? _neonEmerald : _textMuted, fontSize: 11)),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildAmountChip(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text('${amount.toStringAsFixed(0)} DA', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> p) {
    final isRefunded = p['is_refunded'] as bool? ?? false;
    final amount = (p['amount'] as num?)?.toDouble() ?? 0;
    final refundAmt = (p['refund_amount'] as num?)?.toDouble() ?? 0;
    final method = p['payment_method'] ?? '';
    final paidAt = p['paid_at'] != null ? DateTime.tryParse(p['paid_at'] as String)?.toString().substring(0, 16) ?? '' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRefunded ? Colors.redAccent.withOpacity(0.1) : _bgCarbon,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isRefunded ? Colors.redAccent.withOpacity(0.3) : _glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$amount DA ($method)', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(paidAt, style: const TextStyle(color: _textMuted, fontSize: 11)),
            ],
          ),
          if (isRefunded) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.undo, color: Colors.redAccent, size: 14),
                const SizedBox(width: 6),
                Text('Remboursé: $refundAmt DA (${p['refund_type'] ?? ''})', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ),
            if (p['refund_reason'] != null && (p['refund_reason'] as String).isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('Motif: ${p['refund_reason']}', style: const TextStyle(color: _textMuted, fontSize: 11))),
          ] else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: () => _processFullRefund(p['id'] as String, amount),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Rembourser', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent, side: const BorderSide(color: Colors.orangeAccent), padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: () => _processPartialRefund(p['id'] as String, amount),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Partiel', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Aucun remboursement', style: TextStyle(color: _textMuted))));
    }
    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final r = _history[i];
        final rt = r['repair_tickets'] as Map<String, dynamic>?;
        final c = rt != null ? (rt['customers'] as Map<String, dynamic>?) : null;
        final clientName = c?['full_name'] ?? 'Inconnu';
        final phone = c?['phone_number'] ?? '';
        final refundAmt = (r['refund_amount'] as num?)?.toDouble() ?? 0;
        final refundedAt = r['refunded_at'] != null ? DateTime.tryParse(r['refunded_at'] as String)?.toString().substring(0, 16) ?? '' : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _glassBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(clientName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                  Text(refundedAt, style: const TextStyle(color: _textMuted, fontSize: 11)),
                ],
              ),
              if (phone.isNotEmpty) Text('Tél: $phone', style: const TextStyle(color: _textMuted, fontSize: 11)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('$refundAmt DA', style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(r['refund_type'] ?? '', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                  ),
                ],
              ),
              if (r['refund_reason'] != null && (r['refund_reason'] as String).isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(r['refund_reason'], style: const TextStyle(color: _textMuted, fontSize: 11))),
            ],
          ),
        );
      },
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
                    const Icon(Icons.undo, color: _neonCyan, size: 24),
                    const SizedBox(width: 12),
                    const Text('Remboursements', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSearchBar(),
                if (_searchError != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(_searchError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                const SizedBox(height: 16),
                Expanded(
                  child: _ticket != null
                      ? SingleChildScrollView(child: _buildTicketCard())
                      : Column(
                          children: [
                            TabBar(
                              controller: _tabController,
                              labelColor: _neonCyan,
                              unselectedLabelColor: _textMuted,
                              indicatorColor: _neonCyan,
                              tabs: const [
                                Tab(text: 'Recherche'),
                                Tab(text: 'Historique'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  if (_loading)
                                    const Center(child: CircularProgressIndicator(color: _neonCyan))
                                  else
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.search_off, color: _textMuted.withOpacity(0.5), size: 64),
                                          const SizedBox(height: 16),
                                          const Text('Recherchez un ticket par ID ou téléphone', style: TextStyle(color: _textMuted, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  _buildHistoryTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
          if (isDesktop) return Center(child: SizedBox(width: 900, child: content));
          return content;
        },
      ),
    );
  }
}
