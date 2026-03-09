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

      if (!mounted) return;
      setState(() {
        _ticket = ticketData;
        _parts = List<Map<String, dynamic>>.from(partsData ?? []);
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
      final int currentStock = product['stock_quantity'] ?? 0;
      await client.from('products').update({'stock_quantity': currentStock - 1}).eq('id', product['id']);
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
      // إرجاع المخزون فقط إذا كانت القطعة مستخدمة (ليست تالفة)
      if (part['part_status'] == 'Utilisé') {
        final productRes = await client.from('products').select('stock_quantity').eq('id', part['product_id']).single();
        int currentStock = productRes['stock_quantity'] ?? 0;
        await client.from('products').update({'stock_quantity': currentStock + 1}).eq('id', part['product_id']);
      }
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
          final productRes = await client.from('products').select('stock_quantity').eq('id', p['product_id']).single();
          int currentStock = productRes['stock_quantity'] ?? 0;
          await client.from('products').update({'stock_quantity': currentStock + 1}).eq('id', p['product_id']);
          // تغيير حالة القطعة في التذكرة لكي لا تحسب مرة أخرى
          await client.from('repair_parts').update({'part_status': 'Retourné'}).eq('id', p['id']);
        }
      }
      // تغيير حالة التذكرة
      await client.from('repair_tickets').update({'status': 'Annulé'}).eq('id', widget.ticketId);
      _fetchFullData();
      _showToast('Dossier annulé et stock restauré.', Colors.green);
    } catch (e) {
      _showToast('Erreur: $e', Colors.redAccent);
      _fetchFullData();
    }
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

  Widget _buildFinancialSummary(Color color) {
    double partsTotal = 0;
    for (var p in _parts) { 
      // القطع التالفة أو المرجعة لا تحسب على الزبون
      if (p['part_status'] == 'Utilisé') {
        partsTotal += (p['charged_price'] as num).toDouble(); 
      }
    }
    double labor = (_ticket?['labor_cost'] as num?)?.toDouble() ?? 0;
    double discount = (_ticket?['discount'] as num?)?.toDouble() ?? 0;
    double advance = (_ticket?['advance_payment'] as num?)?.toDouble() ?? 0;
    double remaining = (partsTotal + labor - discount) - advance;

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
          _buildMoneyStat('ACOMPTE', advance, Colors.greenAccent),
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