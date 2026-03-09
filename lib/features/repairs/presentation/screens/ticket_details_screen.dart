import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchFullData());
  }

  Future<void> _fetchFullData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final client = ref.read(supabaseClientProvider);
      
      // 1. جلب التذكرة (تنجح دائماً)
      final ticketData = await client
          .from('repair_tickets')
          .select('*, customers(full_name, phone_number)')
          .eq('id', widget.ticketId)
          .maybeSingle();

      // 2. جلب القطع (تم تصحيح أسماء الأعمدة هنا)
      final partsData = await client
          .from('repair_parts')
          .select('*, products(product_name, reference_price)') // تم التصحيح ✅
          .eq('ticket_id', widget.ticketId);

      if (!mounted) return;

      setState(() {
        _ticket = ticketData;
        _parts = List<Map<String, dynamic>>.from(partsData ?? []);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur Fetch: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);
    final activeNeon = isOwner ? _neonCyan : _neonEmerald;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bgCarbon,
        body: Center(child: CircularProgressIndicator(color: _neonCyan)),
      );
    }

    if (_ticket == null) {
      return Scaffold(
        backgroundColor: _bgCarbon,
        appBar: AppBar(backgroundColor: _panelDark, foregroundColor: Colors.white),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text('TICKET INTROUVABLE', 
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
              TextButton(onPressed: () => context.pop(), child: const Text('Retour'))
            ],
          ),
        ),
      );
    }

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

  // --- UI Builders ---
  Widget _buildAmbientGlow(Color color) {
    return Positioned(
      top: -100, right: -100,
      child: Container(
        width: 600, height: 600,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.03),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 200, spreadRadius: 50)],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, Color color) {
    final qrHash = _ticket?['qr_code_hash']?.toString() ?? 'TICKET';
    final shortHash = qrHash.length > 8 ? qrHash.substring(0, 8) : qrHash;
    return Container(
      height: 80, padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: _panelDark, border: Border(bottom: BorderSide(color: _glassBorder))),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
          const SizedBox(width: 16),
          Text('DOSSIER TECHNIQUE #${shortHash.toUpperCase()}', 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
          const Spacer(),
          _buildStatusBadge(_ticket?['status'] ?? 'En attente', color),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMainOperations(Color color) {
    return Column(
      children: [
        Expanded(child: _buildPartsSection(color)),
        const SizedBox(height: 24),
        _buildFinancialSummary(color),
      ],
    );
  }

  Widget _buildPartsSection(Color color) {
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
                ElevatedButton.icon(
                  onPressed: () {}, // سنبرمجه لاحقاً
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
                    return ListTile(
                      title: Text(part['products']?['product_name'] ?? 'Inconnu', style: const TextStyle(color: Colors.white)),
                      subtitle: Text('État: ${part['part_status'] ?? 'Utilisé'}', style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
                      trailing: Text('${part['charged_price']} DA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(Color color) {
    double partsTotal = 0;
    for (var p in _parts) { partsTotal += (p['charged_price'] as num).toDouble(); }
    double labor = (_ticket?['labor_cost'] as num?)?.toDouble() ?? 0;
    double discount = (_ticket?['discount'] as num?)?.toDouble() ?? 0;
    double advance = (_ticket?['advance_payment'] as num?)?.toDouble() ?? 0;
    double remaining = (partsTotal + labor - discount) - advance;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMoneyStat('PIÈCES', partsTotal, _textMuted),
          _buildMoneyStat('M.O', labor, _textMuted),
          _buildMoneyStat('REMISE', discount, Colors.redAccent),
          _buildMoneyStat('ACOMPTE', advance, Colors.greenAccent),
          Container(width: 1, height: 40, color: _glassBorder),
          _buildMoneyStat('RESTE', remaining, color, isBig: true),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11))]),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [Icon(icon, color: _textMuted, size: 16), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))])]),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))), child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)));
  }

  Widget _buildMoneyStat(String label, double value, Color color, {bool isBig = false}) {
    return Column(children: [Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)), Text('${value.toStringAsFixed(0)} DA', style: TextStyle(color: color, fontSize: isBig ? 22 : 16, fontWeight: FontWeight.w900))]);
  }
}