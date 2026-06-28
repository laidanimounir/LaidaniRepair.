import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/constants/repair_status.dart';
import 'package:laidani_repair/core/utils/warranty_pdf.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

class WarrantyScreen extends ConsumerStatefulWidget {
  const WarrantyScreen({super.key});

  @override
  ConsumerState<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends ConsumerState<WarrantyScreen> {
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _parts = [];
  List<Map<String, dynamic>> _claims = [];
  bool _loading = false;
  String? _error;
  String? _searchError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() { _loading = true; _error = null; _searchError = null; _ticket = null; });
    try {
      final client = ref.read(supabaseClientProvider);
      final query = client.from('repair_tickets')
          .select('*, customers(full_name, phone_number)');

      final data = q.length >= 10 && !q.contains('-')
          ? await query.eq('client_phone_temp', q).or('customers.phone_number.eq.$q').maybeSingle()
          : await query.eq('qr_code_hash', q).maybeSingle();

      if (data == null) {
        if (mounted) setState(() { _searchError = 'Aucun ticket trouvé pour "$q"'; _loading = false; });
        return;
      }

      final ticket = Map<String, dynamic>.from(data);
      final ticketId = ticket['id'] as String;

      final partsResp = await client.from('repair_parts')
          .select('*, products(product_name)')
          .eq('ticket_id', ticketId);
      final claimsResp = await client.from('warranty_claims')
          .select('*')
          .eq('original_ticket_id', ticketId)
          .order('claimed_at', ascending: false);

      if (mounted) {
        setState(() {
          _ticket = ticket;
          _parts = List<Map<String, dynamic>>.from(partsResp);
          _claims = List<Map<String, dynamic>>.from(claimsResp);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _warrantyStatusColor() {
    final expiresAt = _ticket?['warranty_expires_at'] as String?;
    final warrantyDays = (_ticket?['warranty_days'] as num?)?.toInt() ?? 0;
    if (warrantyDays == 0 && expiresAt == null) return _textMuted;
    if (expiresAt != null) {
      final expiry = DateTime.tryParse(expiresAt);
      if (expiry != null) return expiry.isBefore(DateTime.now()) ? Colors.redAccent : _neonEmerald;
    }
    return _neonEmerald;
  }

  String _warrantyStatusText() {
    final expiresAt = _ticket?['warranty_expires_at'] as String?;
    final warrantyDays = (_ticket?['warranty_days'] as num?)?.toInt() ?? 0;
    if (warrantyDays == 0 && expiresAt == null) return 'Non défini';
    if (expiresAt != null) {
      final expiry = DateTime.tryParse(expiresAt);
      if (expiry != null) return expiry.isBefore(DateTime.now()) ? 'Expiré' : 'Valide';
    }
    return 'Valide';
  }

  int _daysRemaining() {
    final expiresAt = _ticket?['warranty_expires_at'] as String?;
    if (expiresAt == null) return 0;
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return 0;
    return expiry.difference(DateTime.now()).inDays;
  }

  Future<void> _printWarranty() async {
    if (_ticket == null) return;
    try {
      await previewOrPrintWarrantyPdf(_ticket!, _parts);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _showNewClaimDialog() async {
    if (_ticket == null) return;
    final reasonCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        title: const Text('Nouvelle réclamation garantie', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Décrivez le problème rencontré', style: TextStyle(color: _textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Ex: L'écran ne s'allume plus...",
                hintStyle: TextStyle(color: _textMuted),
                filled: true, fillColor: _bgCarbon,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: _bgCarbon),
            onPressed: () => Navigator.pop(ctx, {'reason': reasonCtrl.text.trim()}),
            child: const Text('SOUMETTRE'),
          ),
        ],
      ),
    );

    if (result == null || result['reason']!.isEmpty) return;
    try {
      final client = ref.read(supabaseClientProvider);
      final user = Supabase.instance.client.auth.currentUser;
      await client.from('warranty_claims').insert({
        'original_ticket_id': _ticket!['id'],
        'claim_reason': result['reason'],
        'claim_status': 'Ouvert',
        'created_by': user?.id,
      });
      await client.from('repair_ticket_events').insert({
        'ticket_id': _ticket!['id'],
        'event_type': 'warranty_claim_opened',
        'new_value': result['reason'],
        'created_by': user?.id,
        'notes': 'Réclamation garantie: ${result['reason']}',
      });
      final claimsResp = await client.from('warranty_claims')
          .select('*')
          .eq('original_ticket_id', _ticket!['id'])
          .order('claimed_at', ascending: false);
      if (mounted) setState(() => _claims = List<Map<String, dynamic>>.from(claimsResp));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réclamation enregistrée'), backgroundColor: Colors.orangeAccent));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _updateClaimStatus(String claimId, String newStatus) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final updates = <String, dynamic>{'claim_status': newStatus};
      if (newStatus == 'Résolu' || newStatus == 'Refusé') updates['resolved_at'] = DateTime.now().toIso8601String();
      await client.from('warranty_claims').update(updates).eq('id', claimId);
      final claimsResp = await client.from('warranty_claims')
          .select('*')
          .eq('original_ticket_id', _ticket!['id'])
          .order('claimed_at', ascending: false);
      if (mounted) setState(() => _claims = List<Map<String, dynamic>>.from(claimsResp));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recherche par QR ou Téléphone', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Code QR du ticket ou numéro de téléphone...',
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
          if (_searchError != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(_searchError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildTicketCard() {
    final t = _ticket!;
    final customerName = t['customers']?['full_name'] ?? t['client_name_temp'] ?? 'Inconnu';
    final customerPhone = t['customers']?['phone_number'] ?? t['client_phone_temp'] ?? '';
    final device = '${t['device_brand'] ?? ''} ${t['device_name'] ?? ''}'.trim();
    if (device.isEmpty && (t['device_name'] ?? '').isNotEmpty) t['device_name'] as String;
    final createdAt = t['created_at'] != null ? DateTime.tryParse(t['created_at'] as String)?.toString().substring(0, 10) ?? '' : '';
    final warrantyDays = (t['warranty_days'] as num?)?.toInt() ?? 0;
    final expiresAt = t['warranty_expires_at'] as String?;
    final statusColor = _warrantyStatusColor();
    final statusText = _warrantyStatusText();
    final daysRemaining = _daysRemaining();
    final isConfigured = warrantyDays > 0 || expiresAt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isConfigured)
          Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Garantie non configurée — définissez la durée de garantie lors de la remise de l\'appareil', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: _neonCyan, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(customerName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.4))),
                    child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (customerPhone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Tél: $customerPhone', style: const TextStyle(color: _textMuted, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              _buildInfoRow(Icons.phone_android, 'Appareil', device),
              _buildInfoRow(Icons.calendar_today, 'Date de réparation', createdAt),
              _buildInfoRow(Icons.shield_outlined, 'Durée de garantie', warrantyDays > 0 ? '$warrantyDays jours' : 'Non définie'),
              if (expiresAt != null)
                _buildInfoRow(Icons.event, "Date d'expiration", DateTime.tryParse(expiresAt)?.toString().substring(0, 10) ?? ''),
              if (isConfigured)
                _buildInfoRow(Icons.timer, 'Jours restants', daysRemaining > 0 ? '$daysRemaining jours' : 'Expiré'),
              if ((t['imei'] ?? '').toString().isNotEmpty)
                _buildInfoRow(Icons.qr_code, 'IMEI/SN', t['imei'].toString()),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _printWarranty,
                icon: const Icon(Icons.print, size: 20),
                label: const Text('Imprimer carte de garantie', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            if (isConfigured && !statusText.contains('Expiré'))
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: _bgCarbon, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _showNewClaimDialog,
                  icon: const Icon(Icons.report_problem, size: 20),
                  label: const Text('Nouvelle réclamation', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),

        if (_claims.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('RÉCLAMATIONS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._claims.map((c) => _buildClaimCard(c)),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: _textMuted, size: 16),
          const SizedBox(width: 10),
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: _textMuted, fontSize: 13))),
          Expanded(child: Text(value.isNotEmpty ? value : '-', style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> c) {
    final status = c['claim_status'] as String? ?? 'Ouvert';
    final statuses = ['Ouvert', 'En cours', 'Résolu', 'Refusé'];
    Color badgeColor;
    switch (status) {
      case 'Résolu': badgeColor = _neonEmerald; break;
      case 'Refusé': badgeColor = Colors.redAccent; break;
      default: badgeColor = Colors.orangeAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(c['claim_reason'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: badgeColor.withOpacity(0.4))),
                child: Text(status, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(DateTime.tryParse(c['claimed_at'] ?? '')?.toString().substring(0, 10) ?? '', style: const TextStyle(color: _textMuted, fontSize: 11)),
              const Spacer(),
              if (c['resolution'] != null && (c['resolution'] as String).isNotEmpty)
                Expanded(child: Text('Résolution: ${c['resolution']}', style: const TextStyle(color: _neonEmerald, fontSize: 11), textAlign: TextAlign.right)),
            ],
          ),
          if (status != 'Résolu' && status != 'Refusé') ...[
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: status,
              isDense: true,
              dropdownColor: _panelDark,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: const SizedBox(),
              items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => v != null ? _updateClaimStatus(c['id'] as String, v) : null,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    const Icon(Icons.verified_user, color: _neonCyan, size: 24),
                    const SizedBox(width: 12),
                    const Text('Garanties', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_ticket != null)
                      Text('N° ${_ticket!['id'].toString().substring(0, 8)}', style: const TextStyle(color: _textMuted, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSearchBar(),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _neonCyan)))
                else if (_ticket != null)
                  Expanded(child: SingleChildScrollView(child: _buildTicketCard()))
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, color: _textMuted.withOpacity(0.5), size: 64),
                          const SizedBox(height: 16),
                          const Text('Recherchez un ticket par QR ou numéro de téléphone', style: TextStyle(color: _textMuted, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );

          if (isDesktop) {
            return Center(child: SizedBox(width: 900, child: content));
          }
          return content;
        },
      ),
    );
  }
}
