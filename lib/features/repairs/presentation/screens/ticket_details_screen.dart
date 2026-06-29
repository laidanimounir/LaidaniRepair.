import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/core/providers/shortcuts_provider.dart';
import 'package:laidani_repair/core/services/groq_service.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';
import 'package:laidani_repair/core/utils/invoice_pdf.dart';
import 'package:laidani_repair/core/utils/quote_pdf.dart';
import 'package:laidani_repair/core/utils/warranty_pdf.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:laidani_repair/constants/repair_status.dart';
import 'package:laidani_repair/services/print_service.dart';
import 'package:laidani_repair/widgets/repairs/ticket_header_widget.dart';
import 'package:laidani_repair/widgets/repairs/device_info_sidebar.dart';
import 'package:laidani_repair/widgets/repairs/repair_parts_widget.dart';
import 'package:laidani_repair/widgets/repairs/ticket_financials_widget.dart';
import 'package:laidani_repair/widgets/repairs/stock_search_dialog.dart';

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
  List<Map<String, dynamic>> _warrantyClaims = [];
  List<Map<String, dynamic>> _photos = [];
  List<Map<String, dynamic>> _notifications = [];
  Map<String, dynamic>? _feedbackData;
  RealtimeChannel? _channel;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isPublicPageEnabled = false;
  bool _showPricesOnPublic = false;
  int _publicPageViews = 0;
  bool _hidePhoneOnPublic = false;
  bool _hideTechnicianOnPublic = false;
  bool _hideHistoryOnPublic = false;
  String _publicPageMessage = '';
  final TextEditingController _messageCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchFullData());
    _channel = Supabase.instance.client
        .channel('ticket_${widget.ticketId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'repair_tickets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.ticketId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord != null && _isPublicPageEnabled) {
              final newViews = (newRecord['public_page_views'] as num?)?.toInt() ?? 0;
              if (newViews > _publicPageViews && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(children: [
                      Icon(Icons.visibility, color: _neonCyan),
                      SizedBox(width: 8),
                      Text('Le client a consulté la page de suivi'),
                    ]),
                    backgroundColor: const Color(0xFF161b22),
                    duration: const Duration(seconds: 4),
                  ),
                );
                setState(() => _publicPageViews = newViews);
                return;
              }
            }
            _fetchFullData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'repair_parts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: widget.ticketId,
          ),
          callback: (_) => _fetchFullData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'repair_payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: widget.ticketId,
          ),
          callback: (_) => _fetchFullData(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // --- جلب البيانات ---
  Future<void> _fetchFullData() async {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.difference(_lastFetch).inMilliseconds < 500) return;
    _lastFetch = now;
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final ticketData = await client.from('repair_tickets').select('*, customers(full_name, phone_number), profiles!repair_tickets_worker_id_fkey(full_name)').eq('id', widget.ticketId).maybeSingle();
      final partsData = await client.from('repair_parts').select('*, products(product_name, reference_price)').eq('ticket_id', widget.ticketId);
      final paymentsData = await client.from('repair_payments').select('*').eq('ticket_id', widget.ticketId).order('paid_at', ascending: false);
      final eventsData = await client.from('repair_ticket_events').select('*').eq('ticket_id', widget.ticketId).order('created_at', ascending: true);
      final warrantyData = await client.from('warranty_claims').select('*').or('original_ticket_id.eq.${widget.ticketId},claim_ticket_id.eq.${widget.ticketId}').order('claimed_at', ascending: false);
      final photosData = await client.from('repair_photos').select('*').eq('ticket_id', widget.ticketId).order('created_at', ascending: false);
      final photos = List<Map<String, dynamic>>.from(photosData);
      for (final photo in photos) {
        final path = photo['storage_path'] as String?;
        if (path != null && path.isNotEmpty) {
          try {
            photo['signed_url'] = await Supabase.instance.client.storage.from('repair-photos').createSignedUrl(path, 3600);
          } catch (_) {
            photo['signed_url'] = null;
          }
        }
      }
      final notifData = await client.from('repair_notifications').select('*').eq('ticket_id', widget.ticketId).order('sent_at', ascending: false);
      final feedbackRow = await client.from('customer_feedback').select('*').eq('ticket_id', widget.ticketId).maybeSingle();

      if (!mounted) return;
      setState(() {
        _ticket = ticketData;
        if (_ticket != null) _ticket!['repair_ticket_events'] = List<Map<String, dynamic>>.from(eventsData);
        _parts = List<Map<String, dynamic>>.from(partsData);
        _payments = List<Map<String, dynamic>>.from(paymentsData);
        _warrantyClaims = List<Map<String, dynamic>>.from(warrantyData);
        _photos = photos;
        _notifications = List<Map<String, dynamic>>.from(notifData);
        _feedbackData = feedbackRow;
        _isPublicPageEnabled = ticketData?['is_public_page_enabled'] as bool? ?? false;
        _showPricesOnPublic = ticketData?['show_prices_on_public'] as bool? ?? false;
        _publicPageViews = (ticketData?['public_page_views'] as num?)?.toInt() ?? 0;
        _hidePhoneOnPublic = ticketData?['hide_phone_on_public'] as bool? ?? false;
        _hideTechnicianOnPublic = ticketData?['hide_technician_on_public'] as bool? ?? false;
        _hideHistoryOnPublic = ticketData?['hide_history_on_public'] as bool? ?? false;
        _publicPageMessage = ticketData?['public_page_message'] as String? ?? '';
        _messageCtrl.text = _publicPageMessage;
        _isLoading = false;
      });
      _syncPaymentStatus();
      _syncFinalCost();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 0. Suggestion IA de pièces ---
  Future<void> _suggestPartsAI(Color color) async {
    final device = _ticket?['device_name']?.toString() ?? '';
    final brand = _ticket?['device_brand']?.toString() ?? '';
    final issue = _ticket?['issue_description']?.toString() ?? '';
    final diag = _ticket?['pre_diagnostic']?.toString() ?? '';
    final deviceType = _ticket?['device_type']?.toString() ?? 'Appareil';

    if (device.isEmpty || issue.isEmpty) {
      _showToast('Informations insuffisantes pour l\'analyse IA', Colors.orangeAccent);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final suggestedParts = await GroqService().suggestParts(
        deviceType: deviceType,
        brand: brand,
        problemDescription: issue,
        diagnosticNotes: diag,
      );

      if (!mounted) return;

      if (suggestedParts.isEmpty) {
        _showToast('Aucune suggestion IA pour ce problème', Colors.orangeAccent);
        setState(() => _isLoading = false);
        return;
      }

      final client = ref.read(supabaseClientProvider);
      final productsData = await client.from('products').select();
      final allProducts = List<Map<String, dynamic>>.from(productsData);

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final matches = <Map<String, dynamic>>[];
            for (final suggestion in suggestedParts) {
              final partName = suggestion['partName']?.toString().toLowerCase() ?? '';
              final quantity = suggestion['quantity'] as int? ?? 1;
              for (final product in allProducts) {
                final productName = (product['product_name']?.toString() ?? '').toLowerCase();
                if (productName.contains(partName) || partName.contains(productName)) {
                  matches.add({
                    ...product,
                    '_suggestedQty': quantity,
                    '_matchedTerm': suggestion['partName'],
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: _panelDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.5))),
              title: const Row(children: [Icon(Icons.psychology, color: Color(0xFF9C27B0)), SizedBox(width: 8), Text('Pièces suggérées par IA', style: TextStyle(color: Colors.white))]),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('L\'IA suggère les pièces suivantes:', style: TextStyle(color: _textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    ...suggestedParts.map((sp) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.build_circle, size: 14, color: Color(0xFF9C27B0)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(sp['partName']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 13))),
                          Text('x${sp['quantity'] ?? 1}', style: const TextStyle(color: _textMuted, fontSize: 12)),
                        ],
                      ),
                    )),
                    const Divider(color: _glassBorder, height: 24),
                    if (matches.isNotEmpty) ...[
                      const Text('Correspondances trouvées en stock:', style: TextStyle(color: _neonEmerald, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 8),
                      ...matches.take(6).map((m) {
                        final stock = (m['stock_quantity'] as num?)?.toInt() ?? 0;
                        final price = (m['reference_price'] as num?)?.toDouble() ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m['product_name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text('Stock: $stock | Prix: $price DA', style: TextStyle(color: stock > 0 ? _neonEmerald : Colors.redAccent, fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (stock > 0)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: _neonEmerald.withOpacity(0.1), foregroundColor: _neonEmerald, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _addPartToTicket(m);
                                  },
                                  child: const Text('Ajouter', style: TextStyle(fontSize: 11)),
                                ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      const Text('Aucune correspondance trouvée dans le stock', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: _textMuted))),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) _showToast('Erreur IA: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 1. إضافة قطعة (خصم من المخزون) ---
  Future<void> _addPartToTicket(Map<String, dynamic> product) async {
    final name = product['product_name']?.toString() ?? 'Produit';
    final stockQty = (product['stock_quantity'] as num?)?.toInt() ?? 0;
    final refPrice = (product['reference_price'] as num?)?.toDouble() ?? 0;

    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: refPrice.toStringAsFixed(0));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        title: Row(
          children: [
            const Icon(Icons.build_circle, color: _neonCyan, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Ajouter: $name', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
          ],
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) {
            qtyCtrl.addListener(() => setDialogState(() {}));
            priceCtrl.addListener(() => setDialogState(() {}));
            final enteredPrice = double.tryParse(priceCtrl.text) ?? refPrice;
            final enteredQty = int.tryParse(qtyCtrl.text) ?? 1;
            final total = enteredPrice * enteredQty;
            return SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Quantité',
                            labelStyle: const TextStyle(color: _textMuted),
                            helperText: 'Stock dispo: $stockQty',
                            helperStyle: const TextStyle(color: _textMuted, fontSize: 10),
                            filled: true,
                            fillColor: _bgCarbon.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Prix unitaire',
                            suffixText: 'DA',
                            labelStyle: const TextStyle(color: _textMuted),
                            filled: true,
                            fillColor: _bgCarbon.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total: ${total.toStringAsFixed(0)} DA',
                    style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text);
              final price = double.tryParse(priceCtrl.text);
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Quantité invalide'), backgroundColor: Colors.redAccent));
                return;
              }
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Prix invalide'), backgroundColor: Colors.redAccent));
                return;
              }
              if (qty > stockQty) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Stock insuffisant (dispo: $stockQty)'), backgroundColor: Colors.redAccent));
                return;
              }
              Navigator.pop(ctx, {'quantity': qty, 'charged_price': price});
            },
            child: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == null) return;

    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('repair_parts').insert({
        'ticket_id': widget.ticketId,
        'product_id': product['id'],
        'quantity': result['quantity'],
        'charged_price': result['charged_price'],
        'shop_cost_price': product['purchase_price'] ?? 0,
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

  Future<void> _editPartDetails(Map<String, dynamic> part) async {
    final currentQty = (part['quantity'] as num?)?.toInt() ?? 1;
    final currentPrice = (part['charged_price'] as num?)?.toDouble() ?? 0;
    final qtyCtrl = TextEditingController(text: currentQty.toString());
    final priceCtrl = TextEditingController(text: currentPrice.toStringAsFixed(0));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        title: const Text('Modifier la pièce', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) {
            qtyCtrl.addListener(() => setDialogState(() {}));
            priceCtrl.addListener(() => setDialogState(() {}));
            final qty = int.tryParse(qtyCtrl.text) ?? 1;
            final price = double.tryParse(priceCtrl.text) ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Quantité', labelStyle: TextStyle(color: _textMuted)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: const InputDecoration(labelText: 'Prix unitaire (DA)', labelStyle: TextStyle(color: _textMuted)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text('Total: ${(qty * price).toStringAsFixed(0)} DA', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
            onPressed: () {
              Navigator.pop(ctx, {'quantity': int.tryParse(qtyCtrl.text) ?? currentQty, 'charged_price': double.tryParse(priceCtrl.text) ?? currentPrice});
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null) {
      final client = ref.read(supabaseClientProvider);
      try {
        await client.from('repair_parts').update({
          'quantity': result['quantity'],
          'charged_price': result['charged_price'],
        }).eq('id', part['id']);
        _fetchFullData();
        _showToast('Pièce mise à jour', _neonEmerald);
      } catch (e) {
        _showToast('Erreur: $e', Colors.redAccent);
      }
    }
  }

  void _showPartStatusMenu(Map<String, dynamic> part) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panelDark,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ['Neuf', 'Occasion', 'Défectueux', 'Retourné'].map((status) => ListTile(
          title: Text(status, style: const TextStyle(color: Colors.white)),
          leading: Icon(
            status == 'Neuf' ? Icons.check_circle : status == 'Occasion' ? Icons.recycling : status == 'Défectueux' ? Icons.report_problem : Icons.undo,
            color: status == 'Neuf' ? _neonEmerald : status == 'Occasion' ? Colors.orangeAccent : status == 'Défectueux' ? Colors.redAccent : _textMuted,
          ),
          onTap: () {
            Navigator.pop(ctx);
            _changePartStatus(part, status);
          },
        )).toList(),
      ),
    );
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

    try {
      final fullTicket = await client.from('repair_tickets').select('*, customers(full_name, phone_number)').eq('id', widget.ticketId).single();
      final partsList = await client.from('repair_parts').select('*, products(product_name)').eq('ticket_id', widget.ticketId);
      await previewOrPrintQuotePdf(fullTicket, List<Map<String, dynamic>>.from(partsList));
    } catch (_) {}
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

  // --- Warranty Claims ---
  Future<void> _showWarrantyClaimDialog(Color color) async {
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
                hintText: 'Ex: L\'écran ne s\'allume plus, la batterie gonfle...',
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
            onPressed: () => reasonCtrl.text.trim().isEmpty ? null : Navigator.pop(ctx, {'reason': reasonCtrl.text.trim()}),
            child: const Text('SOUMETTRE'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final client = ref.read(supabaseClientProvider);
    final user = Supabase.instance.client.auth.currentUser;
    await client.from('warranty_claims').insert({
      'original_ticket_id': widget.ticketId,
      'claim_reason': result['reason'],
      'claim_status': 'Ouvert',
      'created_by': user?.id,
    });
    await client.from('repair_ticket_events').insert({
      'ticket_id': widget.ticketId,
      'event_type': 'warranty_claim_opened',
      'old_value': null,
      'new_value': result['reason'],
      'created_by': user?.id,
      'notes': 'Réclamation garantie: ${result['reason']}',
    });
    _fetchFullData();
    _showToast('Réclamation enregistrée', Colors.orangeAccent);
  }

  Future<void> _showWarrantyClaimsListDialog(Color color) async {
    final claims = List<Map<String, dynamic>>.from(_warrantyClaims);
    if (claims.isEmpty) return;

    final statuses = ['Ouvert', 'En cours', 'Résolu', 'Refusé'];
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
          title: const Text('Suivi des réclamations', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: claims.length,
              itemBuilder: (ctx, i) {
                final c = claims[i];
                final status = c['claim_status'] as String? ?? 'Ouvert';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['claim_reason'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: status,
                            dropdownColor: _panelDark,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) async {
                              if (v == null) return;
                              final client = ref.read(supabaseClientProvider);
                              final user = Supabase.instance.client.auth.currentUser;
                              final updates = <String, dynamic>{'claim_status': v};
                              if (v == 'Résolu' || v == 'Refusé') updates['resolved_at'] = DateTime.now().toIso8601String();
                              await client.from('warranty_claims').update(updates).eq('id', c['id']);
                              await client.from('repair_ticket_events').insert({
                                'ticket_id': widget.ticketId,
                                'event_type': 'warranty_claim_status',
                                'old_value': status,
                                'new_value': v,
                                'created_by': user?.id,
                                'notes': 'Statut réclamation: $status → $v',
                              });
                              setDialogState(() => c['claim_status'] = v);
                              _fetchFullData();
                              _showToast('Statut mis à jour: $v', Colors.green);
                            },
                          ),
                          const Spacer(),
                          Text(DateTime.tryParse(c['claimed_at'] ?? '')?.toString().substring(0, 10) ?? '', style: const TextStyle(color: _textMuted, fontSize: 10)),
                        ],
                      ),
                      if (c['resolution'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Résolution: ${c['resolution']}', style: const TextStyle(color: _neonEmerald, fontSize: 11)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: _textMuted))),
          ],
        ),
      ),
    );
  }

  // --- Device Photos ---
  Future<void> _uploadPhoto(Color color) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (file == null) return;

    final captionCtrl = TextEditingController();
    String? photoType = 'intake';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panelDark,
          title: const Text('Ajouter une photo', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: photoType,
                dropdownColor: _panelDark,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Type', labelStyle: TextStyle(color: _textMuted)),
                items: ['intake', 'repair', 'handover'].map((t) => DropdownMenuItem(value: t, child: Text(t == 'intake' ? 'Réception' : t == 'repair' ? 'Réparation' : 'Remise'))).toList(),
                onChanged: (v) => setDialogState(() => photoType = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Légende (optionnelle)', labelStyle: TextStyle(color: _textMuted)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('TÉLÉCHARGER'),
            ),
          ],
        ),
      ),
    );

    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = Supabase.instance.client.auth.currentUser;
      final ext = file.path.split('.').last;
      final storagePath = '${widget.ticketId}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage.from('repair-photos').upload(storagePath, File(file.path));

      await client.from('repair_photos').insert({
        'ticket_id': widget.ticketId,
        'storage_path': storagePath,
        'caption': captionCtrl.text.trim().isEmpty ? null : captionCtrl.text.trim(),
        'photo_type': photoType ?? 'intake',
        'uploaded_by': user?.id,
      });

      _fetchFullData();
      _showToast('Photo ajoutée', Colors.green);
    } catch (e) {
      _showToast('Erreur: $e', Colors.redAccent);
      _fetchFullData();
    }
  }

  Future<void> _viewPhoto(String path, String? caption) async {
    final signedUrl = await Supabase.instance.client.storage.from('repair-photos').createSignedUrl(path, 3600);
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(signedUrl, fit: BoxFit.contain, height: 400),
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(caption, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo, Color color) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        title: const Text('Supprimer cette photo ?', style: TextStyle(color: Colors.redAccent)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non', style: TextStyle(color: _textMuted))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final path = photo['storage_path'] as String? ?? '';
      await Supabase.instance.client.storage.from('repair-photos').remove([path]);
      await ref.read(supabaseClientProvider).from('repair_photos').delete().eq('id', photo['id']);
      _fetchFullData();
      _showToast('Photo supprimée', Colors.orangeAccent);
    } catch (e) {
      _showToast('Erreur: $e', Colors.redAccent);
    }
  }

  // --- WhatsApp Auto-Notification ---
  String _getWhatsAppTemplate(String status) {
    final device = _ticket?['device_name'] ?? 'votre appareil';
    switch (status) {
      case 'en_diagnostic':
        return '🔧 Votre $device est en cours de diagnostic chez LaidaniRepair. Nous vous tiendrons informé de l\'évolution.';
      case 'en_reparation':
        return '🛠️ La réparation de votre $device a commencé chez LaidaniRepair. Notre technicien est à l\'œuvre!';
      case 'pret':
        return '✅ Bonne nouvelle! Votre $device est prêt! Vous pouvez venir le récupérer à l\'atelier LaidaniRepair.';
      case 'livre':
        return '🚀 Merci! Votre $device a été livré et réparé avec soin par LaidaniRepair. N\'hésitez pas à nous laisser un avis!';
      default:
        return '📱 Votre dossier $device chez LaidaniRepair est maintenant: $status.';
    }
  }

  String _getWhatsAppUrl(String phone, String message) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final encoded = Uri.encodeComponent(message);
    return 'https://wa.me/$cleaned?text=$encoded';
  }

  Future<void> _sendWhatsAppNotification(String status) async {
    final client = ref.read(supabaseClientProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final message = _getWhatsAppTemplate(status);
    String? phone;
    if (_ticket?['customers']?['phone_number'] != null) {
      phone = _ticket!['customers']!['phone_number'].toString();
    } else if (_ticket?['client_phone_temp'] != null) {
      phone = _ticket!['client_phone_temp'].toString();
    }
    if (phone == null || phone.isEmpty) return;

    await client.from('repair_notifications').insert({
      'ticket_id': widget.ticketId,
      'notification_method': 'WhatsApp',
      'notification_status': 'Envoyé',
      'notes': 'Auto: $status - "$message"',
      'sent_by': user?.id,
    });
    await client.from('repair_tickets').update({
      'last_notification_at': DateTime.now().toIso8601String(),
      'last_notification_method': 'WhatsApp',
      'customer_notified': true,
    }).eq('id', widget.ticketId);

    final url = _getWhatsAppUrl(phone, message);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    }
    _fetchFullData();
    _showToast('WhatsApp envoyé: $status', _neonEmerald);
  }

  Future<void> _sendWhatsApp(String phone) async {
    if (phone.isEmpty || phone == 'N/A') return;
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]+'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone');
    try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (_) {}
  }

  void _showWhatsAppStatusDialog() {
    final status = _ticket?['status'] as String? ?? 'En attente';
    final phone = _ticket?['customers']?['phone_number']?.toString() ?? _ticket?['client_phone_temp']?.toString();
    if (phone == null || phone.isEmpty) return;
    final message = _getWhatsAppTemplate(status);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        title: const Row(children: [Icon(Icons.chat, color: Color(0xFF25D366)), SizedBox(width: 8), Text('WhatsApp Client', style: TextStyle(color: Colors.white))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Message qui sera envoyé:', style: TextStyle(color: _textMuted, fontSize: 11)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF075E54).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
            icon: const Icon(Icons.send),
            label: const Text('ENVOYER WHATSAPP'),
            onPressed: () {
              Navigator.pop(ctx);
              _sendWhatsAppNotification(status);
            },
          ),
        ],
      ),
    );
  }

  // --- Notification Tracking ---
  Future<void> _showNotificationDialog(Color color) async {
    String? method = 'WhatsApp';
    String? status = 'Envoyé';
    final notesCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
          title: const Text('Enregistrer une notification', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: method, dropdownColor: _panelDark, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Méthode', labelStyle: TextStyle(color: _textMuted)),
                items: ['WhatsApp', 'Appel', 'SMS', 'En personne'].map((m) => DropdownMenuItem(value: m, child: Row(children: [Icon(_notifIcon(m), size: 18, color: _neonCyan), const SizedBox(width: 8), Text(m)]))).toList(),
                onChanged: (v) => setDialogState(() => method = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status, dropdownColor: _panelDark, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Statut', labelStyle: TextStyle(color: _textMuted)),
                items: ['Envoyé', 'Répondu', 'Pas de réponse', 'Rappeler'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setDialogState(() => status = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Notes', labelStyle: TextStyle(color: _textMuted))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: _bgCarbon),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ENREGISTRER'),
            ),
          ],
        ),
      ),
    );

    final client = ref.read(supabaseClientProvider);
    final user = Supabase.instance.client.auth.currentUser;
    await client.from('repair_notifications').insert({
      'ticket_id': widget.ticketId,
      'notification_method': method,
      'notification_status': status,
      'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      'sent_by': user?.id,
    });
    await client.from('repair_tickets').update({
      'last_notification_at': DateTime.now().toIso8601String(),
      'last_notification_method': method,
      'customer_notified': true,
    }).eq('id', widget.ticketId);
    _fetchFullData();
    _showToast('Notification enregistrée', Colors.green);
  }

  IconData _notifIcon(String method) {
    switch (method) {
      case 'WhatsApp': return Icons.chat;
      case 'Appel': return Icons.phone;
      case 'SMS': return Icons.sms;
      default: return Icons.person;
    }
  }

  // --- Customer Feedback ---
  Future<void> _showFeedbackDialog(Color color) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
          title: const Text('Avis client', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Notez votre satisfaction', style: TextStyle(color: _textMuted)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starRating = i + 1;
                  return IconButton(
                    icon: Icon(starRating <= rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
                    onPressed: () => setDialogState(() => rating = starRating),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(controller: commentCtrl, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Commentaire (optionnel)', labelStyle: TextStyle(color: _textMuted))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: _bgCarbon),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ENREGISTRER'),
            ),
          ],
        ),
      ),
    );

    final client = ref.read(supabaseClientProvider);
    await client.from('customer_feedback').insert({
      'ticket_id': widget.ticketId,
      'rating': rating,
      'comment': commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
    });
    _fetchFullData();
    _showToast('Avis enregistré', Colors.green);
  }

  // --- Handover (Remise au client) ---
  Future<void> _showHandoverDialog(Color color) async {
    final accessoriesRaw = _ticket?['accessories_included'];
    List<String> allAccessories = [];
    if (accessoriesRaw is List) {
      allAccessories = accessoriesRaw.cast<String>();
    } else if (accessoriesRaw is String && accessoriesRaw.isNotEmpty) {
      allAccessories = accessoriesRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final returnedNotifier = ValueNotifier<Set<String>>({});
    final notesCtrl = TextEditingController(text: _ticket?['handover_notes'] as String? ?? '');
    final notifiedCtrl = TextEditingController(text: _ticket?['last_notification_method'] as String? ?? '');
    final warrantyCtrl = TextEditingController(text: (_ticket?['warranty_days'] as num?)?.toInt().toString() ?? '30');
    String? selectedCondition = _ticket?['device_condition_at_handover'] as String? ?? 'Bon';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
          title: const Text('Confirmer la remise', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('État de l\'appareil', style: TextStyle(color: _textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCondition,
                    dropdownColor: _panelDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      filled: true, fillColor: _bgCarbon,
                      border: OutlineInputBorder(),
                    ),
                    items: ['Excellent', 'Bon', 'Acceptable', 'Avec réserve']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedCondition = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('Garantie (jours)', style: TextStyle(color: _textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: warrantyCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '30',
                      hintStyle: TextStyle(color: _textMuted),
                      filled: true, fillColor: _bgCarbon,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (allAccessories.isNotEmpty) ...[
                    const Text('Accessoires rendus', style: TextStyle(color: _textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    ...allAccessories.map((acc) => CheckboxListTile(
                      title: Text(acc, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      value: returnedNotifier.value.contains(acc),
                      activeColor: _neonEmerald,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) {
                        final s = Set<String>.from(returnedNotifier.value);
                        if (v == true) { s.add(acc); } else { s.remove(acc); }
                        returnedNotifier.value = s;
                      },
                    )),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Notes de remise', labelStyle: TextStyle(color: _textMuted)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notifiedCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Client notifié via (WhatsApp, Appel...)', labelStyle: TextStyle(color: _textMuted)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonEmerald, foregroundColor: _bgCarbon),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CONFIRMER LA REMISE'),
            ),
          ],
        ),
      ),
    );

    final client = ref.read(supabaseClientProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final returnedAccessories = returnedNotifier.value.toList();
    await client.from('repair_tickets').update({
      'device_condition_at_handover': selectedCondition,
      'handover_notes': notesCtrl.text.trim(),
      'handover_confirmed_at': DateTime.now().toIso8601String(),
      'accessories_returned': returnedAccessories,
      'last_notification_method': notifiedCtrl.text.trim().isNotEmpty ? notifiedCtrl.text.trim() : null,
      'last_notification_at': DateTime.now().toIso8601String(),
      'customer_notified': notifiedCtrl.text.trim().isNotEmpty,
      'warranty_days': int.tryParse(warrantyCtrl.text.trim()) ?? 0,
      'warranty_expires_at': DateTime.now().add(Duration(days: int.tryParse(warrantyCtrl.text.trim()) ?? 0)).toIso8601String(),
    }).eq('id', widget.ticketId);
    await client.from('repair_ticket_events').insert({
      'ticket_id': widget.ticketId,
      'event_type': 'handover_confirmed',
      'old_value': null,
      'new_value': selectedCondition,
      'created_by': user?.id,
      'notes': 'Remise confirmée. État: $selectedCondition',
    });
    _fetchFullData();
    _scheduleMaintenanceReminder(client);
    try {
      final parts = await client.from('repair_parts').select('*, products(product_name)').eq('ticket_id', widget.ticketId);
      final updatedTicket = await client.from('repair_tickets').select('*, customers(full_name, phone_number)').eq('id', widget.ticketId).single();
      await previewOrPrintPdf(updatedTicket, List<Map<String, dynamic>>.from(parts));
    } catch (_) {}
    try {
      final parts = await client.from('repair_parts').select('*, products(product_name)').eq('ticket_id', widget.ticketId);
      final updatedTicket = await client.from('repair_tickets').select('*, customers(full_name, phone_number)').eq('id', widget.ticketId).single();
      await previewOrPrintWarrantyPdf(updatedTicket, List<Map<String, dynamic>>.from(parts));
    } catch (_) {}
    _showToast('Remise confirmée', Colors.green);

    if (mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan)),
          title: const Text('Marquer comme livré ?', style: TextStyle(color: Colors.white)),
          content: const Text('L\'appareil a été remis au client. Voulez-vous passer le statut à « Livré » ?', style: TextStyle(color: _textMuted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard', style: TextStyle(color: _textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonEmerald, foregroundColor: _bgCarbon),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Oui, Livré'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final ticketId = widget.ticketId;
        await client.from('repair_tickets').update({
          'status': 'Livré',
          'delivered_at': DateTime.now().toIso8601String(),
        }).eq('id', ticketId);
        await client.from('repair_ticket_events').insert({
          'ticket_id': ticketId,
          'event_type': 'status_change',
          'old_value': _ticket?['status'],
          'new_value': 'Livré',
          'created_by': user?.id,
          'notes': 'Livré automatiquement après remise confirmée',
        });
        await _syncPaymentStatus();
        _fetchFullData();
      }
    }
  }

  Future<void> _scheduleMaintenanceReminder(SupabaseClient client) async {
    final customerId = _ticket?['customer_id'] as String?;
    if (customerId == null) return;
    final remindDate = DateTime.now().add(const Duration(days: 180));
    final deviceName = _ticket?['device_name'] ?? 'Appareil';
    await client.from('maintenance_reminders').insert({
      'repair_ticket_id': widget.ticketId,
      'customer_id': customerId,
      'remind_at': remindDate.toIso8601String().substring(0, 10),
      'message': 'Maintenance recommandée pour $deviceName (6 mois après réparation)',
    });
  }

  // --- 4.5 Dupliquer le ticket ---
  Future<void> _duplicateTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        title: const Text('Dupliquer le ticket ?', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
        content: const Text('Un nouveau ticket sera créé avec les mêmes informations (client, appareil, problème). Les pièces et paiements ne seront pas copiés.', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non', style: TextStyle(color: _textMuted))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon), onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, Dupliquer')),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = Supabase.instance.client.auth.currentUser;
      final qrHash = 'LR-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond.toString().substring(0, 3)}';

      await client.from('repair_tickets').insert({
        'customer_id': _ticket?['customer_id'],
        'client_name_temp': _ticket?['client_name_temp'],
        'client_phone_temp': _ticket?['client_phone_temp'],
        'worker_id': user?.id,
        'device_type': _ticket?['device_type'],
        'device_brand': _ticket?['device_brand'],
        'device_name': _ticket?['device_name'],
        'issue_description': _ticket?['issue_description'],
        'imei': _ticket?['imei'],
        'serial_number': _ticket?['serial_number'],
        'device_password': _ticket?['device_password'],
        'accessories_included': _ticket?['accessories_included'],
        'pre_diagnostic': _ticket?['pre_diagnostic'],
        'estimated_cost': _ticket?['estimated_cost'],
        'final_cost': _ticket?['final_cost'] ?? 0,
        'labor_cost': _ticket?['labor_cost'],
        'qr_code_hash': qrHash,
        'status': 'En attente',
        'payment_status': 'Non payé',
        'paid_amount': 0,
      });

      _showToast('Ticket dupliqué avec succès !', _neonCyan);
      _fetchFullData();
    } catch (e) {
      _showToast('Erreur: $e', Colors.redAccent);
      _fetchFullData();
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
      builder: (ctx) => StockSearchDialog(
        color: color,
        onProductSelected: (product) => _addPartToTicket(product),
      ),
    );
  }

  // --- 6. Paiements ---
  double get _totalPartsCost {
    double total = 0;
    for (var p in _parts) {
      if (p['part_status'] == 'Utilisé') {
        final price = (p['charged_price'] as num?)?.toDouble() ?? 0;
        final qty = (p['quantity'] as num?)?.toInt() ?? 1;
        total += price * qty;
      }
    }
    return total;
  }

  double get _totalPartsCostForProfit {
    double total = 0;
    for (var p in _parts) {
      if (p['part_status'] == 'Utilisé') {
        final cost = (p['shop_cost_price'] as num?)?.toDouble() ?? 0;
        final qty = (p['quantity'] as num?)?.toInt() ?? 1;
        total += cost * qty;
      }
    }
    return total;
  }

  double get _totalPayments {
    double total = 0;
    for (var p in _payments) {
      total += (p['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  double get _effectiveLabor {
    final billingType = _ticket?['billing_type'] as String? ?? 'parts_and_labor';
    if (billingType == 'parts_only') return 0;
    return (_ticket?['labor_cost'] as num?)?.toDouble() ?? 0;
  }

  double get _effectivePartsCost {
    final billingType = _ticket?['billing_type'] as String? ?? 'parts_and_labor';
    if (billingType == 'labor_only') return 0;
    return _totalPartsCost;
  }

  double get _remainingBalance {
    final discount = (_ticket?['discount'] as num?)?.toDouble() ?? 0;
    final advance = (_ticket?['advance_payment'] as num?)?.toDouble() ?? 0;
    return (_effectivePartsCost + _effectiveLabor - discount) - advance - _totalPayments;
  }

  double get _totalCost {
    return _effectivePartsCost + _effectiveLabor;
  }

  double get _netProfit {
    final finalCost = (_ticket?['final_cost'] as num?)?.toDouble() ?? 0;
    return finalCost - _totalPartsCostForProfit - _effectiveLabor;
  }

  double get _profitMarginPercent {
    final finalCost = (_ticket?['final_cost'] as num?)?.toDouble() ?? 0;
    if (finalCost <= 0) return 0;
    return (_netProfit / finalCost) * 100;
  }

  Future<void> _syncFinalCost() async {
    final client = ref.read(supabaseClientProvider);
    try {
      final parts = await client
          .from('repair_parts')
          .select('charged_price, quantity, part_status')
          .eq('ticket_id', widget.ticketId);

      final billingType = _ticket?['billing_type'] as String? ?? 'parts_and_labor';
      final partsTotal = parts.fold<double>(0, (sum, p) {
        final status = p['part_status'] as String?;
        if (status != 'Utilisé') return sum;
        final price = (p['charged_price'] as num?)?.toDouble() ?? 0;
        final qty = (p['quantity'] as num?)?.toDouble() ?? 1;
        return sum + (price * qty);
      });

      final labor = billingType == 'parts_only' ? 0 : ((_ticket?['labor_cost'] as num?)?.toDouble() ?? 0);
      final discount = (_ticket?['discount'] as num?)?.toDouble() ?? 0;
      final computed = billingType == 'labor_only' ? 0 : partsTotal + labor - discount;
      final currentFinalCost = (_ticket?['final_cost'] as num?)?.toDouble() ?? 0;

      if ((computed - currentFinalCost).abs() < 0.01) return;

      await client
          .from('repair_tickets')
          .update({'final_cost': computed})
          .eq('id', widget.ticketId);

      setState(() => _ticket!['final_cost'] = computed);
    } catch (e) {
      debugPrint('_syncFinalCost error: $e');
    }
  }

  Future<void> _syncPaymentStatus() async {
    final client = ref.read(supabaseClientProvider);
    try {
      final ticket = await client.from('repair_tickets')
          .select('final_cost, paid_amount, advance_payment, payment_status')
          .eq('id', widget.ticketId)
          .maybeSingle();
      if (ticket == null) return;
      final finalCost = (ticket['final_cost'] as num?)?.toDouble() ?? 0;
      final paid = (ticket['paid_amount'] as num?)?.toDouble() ?? 0;
      final advance = (ticket['advance_payment'] as num?)?.toDouble() ?? 0;
      final currentStatus = ticket['payment_status'] as String? ?? '';

      final netCost = (finalCost - advance).clamp(0, double.infinity);

      String newStatus;
      if (paid >= netCost && netCost > 0) {
        newStatus = 'Payé';
      } else if (paid > 0 || advance > 0) {
        newStatus = 'Avance';
      } else {
        newStatus = 'Non payé';
      }

      if (newStatus == currentStatus) return;

      await client.from('repair_tickets')
          .update({'payment_status': newStatus})
          .eq('id', widget.ticketId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sync paiement: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
      // Update paid_amount on ticket
      final paymentsSum = await client.from('repair_payments')
          .select('amount')
          .eq('ticket_id', widget.ticketId);
      final totalPaid = paymentsSum.fold<num>(0, (s, p) => s + (p['amount'] as num));
      await client.from('repair_tickets')
          .update({'paid_amount': totalPaid.toDouble()})
          .eq('id', widget.ticketId);
      await _syncPaymentStatus();
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
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    if (_isLoading) return const Scaffold(backgroundColor: _bgCarbon, body: Center(child: CircularProgressIndicator(color: _neonCyan)));
    if (_ticket == null) return Scaffold(backgroundColor: _bgCarbon, body: Center(child: TextButton(onPressed: () => context.pop(), child: const Text('TICKET INTROUVABLE - RETOUR', style: TextStyle(color: Colors.redAccent)))));

    ref.listen(printRequestProvider, (_, __) async {
      try {
        final client = ref.read(supabaseClientProvider);
        final parts = List<Map<String, dynamic>>.from(_parts);
        final updatedTicket = await client.from('repair_tickets').select('*, customers(full_name, phone_number)').eq('id', widget.ticketId).single();
        await previewOrPrintPdf(updatedTicket, parts);
      } catch (_) {}
    });

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Column(
        children: [
          _buildTopHeader(context, activeNeon, isDesktop),
          Expanded(
            child: isDesktop
                ? Row(
                    children: [
                      _buildLeftSidebar(activeNeon),
                      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildMainOperations(activeNeon, isOwner))),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildMobileInfoCards(activeNeon),
                        const SizedBox(height: 12),
                        _buildMainOperations(activeNeon, isOwner),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _printTicketFromDetails() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final parts = await client.from('repair_parts').select('*, products(product_name)').eq('ticket_id', widget.ticketId);
      final ticket = await client.from('repair_tickets').select('*, customers(full_name, phone_number)').eq('id', widget.ticketId).single();
      await previewOrPrintPdf(ticket, List<Map<String, dynamic>>.from(parts));
    } catch (e) {
      _showToast('Erreur impression: $e', Colors.redAccent);
    }
  }

  Widget _buildMobileInfoCards(Color color) {
    final bool isAnon = _ticket?['customer_id'] == null;
    final String clientName = isAnon ? (_ticket?['client_name_temp'] ?? 'Anonyme') : (_ticket?['customers']?['full_name'] ?? 'Client');
    final String clientPhone = isAnon ? (_ticket?['client_phone_temp'] ?? 'N/A') : (_ticket?['customers']?['phone_number'] ?? 'N/A');
    final estimatedCost = (_ticket?['estimated_cost'] as num?)?.toDouble() ?? 0;
    final finalCost = (_ticket?['final_cost'] as num?)?.toDouble() ?? estimatedCost;
    final advance = (_ticket?['advance_payment'] as num?)?.toDouble() ?? 0;
    final paid = _totalPayments;
    final remaining = _remainingBalance;
    final deviceBrand = _ticket?['device_brand'] as String?;
    final deviceType = _ticket?['device_type'] as String?;
    final device = [if (deviceBrand?.isNotEmpty == true) deviceBrand, _ticket?['device_name']].where((s) => s?.isNotEmpty == true).join(' ');
    final paymentStatus = _ticket?['payment_status'] as String? ?? 'Non payé';
    final billingType = _ticket?['billing_type'] as String? ?? 'parts_and_labor';
    final issue = _ticket?['issue_description'] as String? ?? '';
    final techName = _ticket?['profiles']?['full_name'] as String?;

    return Column(
      children: [
        _buildCompactCard(Icons.person, 'Client', '$clientName — $clientPhone', color),
        const SizedBox(height: 6),
        _buildCompactCard(Icons.phone_android, 'Appareil', device.isNotEmpty ? device : (_ticket?['device_name'] ?? 'N/A'), color),
        if (deviceType != null && deviceType.isNotEmpty)
          _buildCompactCard(Icons.category, 'Type', deviceType, color, compact: true),
        if (issue.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildCompactCard(Icons.report_problem, 'Problème', issue, color),
        ],
        if (techName != null && techName.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildCompactCard(Icons.engineering, 'Technicien', techName, color),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _glassBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: const Text('FINANCES', style: TextStyle(color: _textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Color(RepairStatus.paymentStatusColor(paymentStatus)).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(paymentStatus, style: TextStyle(color: Color(RepairStatus.paymentStatusColor(paymentStatus)), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total: ${(finalCost).toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.white, fontSize: 12)),
                Text('Payé: ${paid.toStringAsFixed(0)} DA', style: const TextStyle(color: _neonEmerald, fontSize: 12)),
              ]),
              if (remaining > 0)
                Padding(padding: const EdgeInsets.only(top: 2), child: Text('Reste: ${remaining.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        if (_ticket?['imei']?.toString().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          _buildCompactCard(Icons.qr_code_scanner, 'IMEI', _ticket!['imei'].toString(), color),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: () => _sendWhatsApp(clientPhone),
                icon: const Icon(Icons.chat, size: 16),
                label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: () => launchUrl(Uri.parse('tel:$clientPhone')),
                icon: const Icon(Icons.call, size: 16),
                label: const Text('Appeler', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactCard(IconData icon, String label, String value, Color color, {bool compact = false}) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _glassBorder)),
          child: Row(children: [Icon(icon, color: color, size: 14), const SizedBox(width: 8), Text('$label: ', style: const TextStyle(color: _textMuted, fontSize: 11)), Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)))],),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _glassBorder)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
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

  Widget _buildTopHeader(BuildContext context, Color color, bool isDesktop) {
    return TicketHeaderWidget(
      ticket: _ticket!,
      accentColor: color,
      isDesktop: isDesktop,
      onBack: () => context.pop(),
      onDuplicate: _duplicateTicket,
      onCancel: _cancelTicket,
      onPrintComplete: () {
        setState(() {
          _ticket!['customer_ticket_printed_at'] = DateTime.now().toIso8601String();
        });
      },
    );
  }

  Widget _buildLeftSidebar(Color color) {
    final status = _ticket?['status'] as String? ?? 'En attente';
    final statusClr = Color(RepairStatus.statusColor(status));

    return Container(
      width: 350,
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: _glassBorder))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _glassBorder)),
              color: statusClr.withOpacity(0.05),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: statusClr.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusClr.withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon(status), color: statusClr, size: 20),
                    const SizedBox(width: 10),
                    Text(status, style: TextStyle(color: statusClr, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
                  ]),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ref.read(supabaseClientProvider).from('profiles').select('id, full_name').order('full_name'),
              builder: (ctx, snap) {
                final profiles = snap.data ?? [];
                final currentId = _ticket?['assigned_technician_id'] as String?;
                return DeviceInfoSidebar(
                  ticket: _ticket!,
                  accentColor: color,
                  photos: _photos,
                  notifications: _notifications,
                  profiles: profiles,
                  currentTechnicianId: currentId,
                  isCanceled: _ticket?['status'] == RepairStatus.annule,
                  onUploadPhoto: () => _uploadPhoto(color),
                  onViewPhoto: _viewPhoto,
                  onDeletePhoto: (photo) => _deletePhoto(photo, color),
                  onAddNotification: () => _showNotificationDialog(color),
                  onSendWhatsApp: _showWhatsAppStatusDialog,
                  onAssignTechnician: (profiles, currentId) => _showAssignTechnicianDialog(profiles, currentId, color),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'En attente': return Icons.hourglass_empty;
      case 'Terminé': return Icons.check_circle;
      case 'Livré': return Icons.local_shipping;
      case 'Annulé': return Icons.cancel;
      default: return Icons.all_inbox;
    }
  }

  Widget _buildQRCodeSection(Color color) {
    final qrHash = _ticket?['qr_code_hash'] as String?;
    if (qrHash == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        children: [
          QrImageView(data: 'https://laidaniphone.vercel.app?qr=$qrHash', version: QrVersions.auto, size: 100, backgroundColor: Colors.white, padding: EdgeInsets.zero),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('QR CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(qrHash, style: TextStyle(color: _textMuted, fontSize: 11, fontFamily: 'monospace')),
                const SizedBox(height: 8),
                Text('Scannez pour suivre la réparation', style: TextStyle(color: _textMuted, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.print, color: color),
            tooltip: 'Imprimer',
            onPressed: () => _printQR(context, 'https://laidaniphone.vercel.app?qr=$qrHash'),
          ),
        ],
      ),
    );
  }

  void _printQR(BuildContext context, String data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            QrImageView(data: data, version: QrVersions.auto, size: 250, backgroundColor: Colors.white),
            const SizedBox(height: 16),
            Text('URL: $data', style: const TextStyle(color: _textMuted, fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: _textMuted))),
        ],
      ),
    );
  }

  Widget _buildMainOperations(Color color, bool isOwner) {
    return Column(
      children: [
        _buildStatusProgressBar(color),
        const SizedBox(height: 16),
        _buildTimelineSection(color),
        const SizedBox(height: 16),
        _buildFinancialWidget(color),
        const SizedBox(height: 16),
        _buildPartsWidget(color, isOwner),
        const SizedBox(height: 16),
        _buildQuoteSection(color),
        const SizedBox(height: 16),
        _buildPaymentsSection(color),
        const SizedBox(height: 16),
        _buildQRCodeSection(color),
        const SizedBox(height: 16),
        _buildQCSection(color),
        const SizedBox(height: 16),
        _buildWarrantySection(color),
        const SizedBox(height: 16),
        _buildPublicPageSection(color),
        const SizedBox(height: 16),
        _buildHandoverSection(color),
        const SizedBox(height: 16),
        _buildFeedbackSection(color),
        if (isOwner && _isNotCanceled) ...[
          const SizedBox(height: 16),
          _buildProfitMarginCard(color),
        ],
      ],
    );
  }

  Widget _buildPartsWidget(Color color, bool isOwner) {
    return RepairPartsWidget(
      parts: _parts,
      accentColor: color,
      isCanceled: _ticket?['status'] == RepairStatus.annule,
      isOwner: isOwner,
      onAddPart: () => _showSearchStockDialog(context, color),
      onEditPart: _editPartDetails,
      onChangeStatus: _showPartStatusMenu,
      onRemovePart: _removePart,
      onSuggestAI: () => _suggestPartsAI(color),
    );
  }

  Widget _buildStatusProgressBar(Color color) {
    final status = _ticket?['status'] as String? ?? 'En attente';
    final paymentStatus = _ticket?['payment_status'] as String? ?? 'Non payé';
    final billingType = _ticket?['billing_type'] as String? ?? 'parts_and_labor';
    final billingLabel = {'labor_only': 'M.O uniquement', 'parts_only': 'Pièces uniquement', 'parts_and_labor': 'Pièces + M.O'}[billingType] ?? '';
    final steps = ['Reçu', 'En attente', 'Terminé', 'Livré'];
    final stepIndex = status == 'Livré' ? 4 : status == 'Terminé' ? 3 : status == 'Annulé' ? -1 : 1;
    final isCanceled = status == 'Annulé';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCanceled)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
              child: const Text('⚠ Cette réparation a été annulée', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            )
          else
            Row(
              children: List.generate(steps.length, (i) {
                final step = i + 1;
                final done = step <= stepIndex;
                final active = step == stepIndex;
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? _neonEmerald : (active ? color : Colors.grey[800]),
                          border: Border.all(color: done ? _neonEmerald : (active ? color : _glassBorder), width: 2),
                          boxShadow: active ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)] : null,
                        ),
                        child: Center(child: Text(done ? '✓' : '$step', style: TextStyle(color: done || active ? _bgCarbon : _textMuted, fontSize: 12, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(height: 6),
                      Text(steps[i], style: TextStyle(color: done ? _neonEmerald : (active ? color : _textMuted), fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.normal), textAlign: TextAlign.center),
                    ],
                  ),
                );
              }),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Color(RepairStatus.paymentStatusColor(paymentStatus)).withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Color(RepairStatus.paymentStatusColor(paymentStatus)).withOpacity(0.3))),
                child: Text(paymentStatus, style: TextStyle(color: Color(RepairStatus.paymentStatusColor(paymentStatus)), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              if (billingLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
                  child: Text(billingLabel, style: TextStyle(color: color, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            _buildInfoChip('Créé', _ticket?['created_at']?.toString().substring(0, 10) ?? '', Icons.calendar_today),
            const SizedBox(width: 12),
            _buildInfoChip('Prévu', _ticket?['estimated_completion_date']?.toString() ?? '', Icons.schedule),
            const Spacer(),
            if (_isNotCanceled && (_ticket?['status'] as String?) != 'Terminé')
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: _neonEmerald, padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () => _updateStatus('Terminé'),
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Terminer', style: TextStyle(fontSize: 12)),
              ),
          ]),
          if (_payments.any((p) => (p['is_refunded'] as bool?) == true))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.undo, color: Colors.redAccent, size: 14), SizedBox(width: 6), Text('Remboursé', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))]),
                    ..._payments.where((p) => (p['is_refunded'] as bool?) == true).map((p) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${(p['refund_amount'] as num?)?.toDouble() ?? 0} DA — ${p['refund_reason'] ?? ''}', style: const TextStyle(color: _textMuted, fontSize: 11)),
                    )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(Color color) {
    final events = _ticket?['repair_ticket_events'] as List<dynamic>?;
    if (events == null || events.isEmpty) return const SizedBox.shrink();

    final eventLabels = {
      'status_change': 'Changement de statut',
      'quote_generated': 'Devis généré',
      'quote_sent': 'Devis envoyé',
      'qc_result': 'Contrôle qualité',
      'part_added': 'Pièce ajoutée',
      'handover_confirmed': 'Remise confirmée',
      'warranty_claim_opened': 'Réclamation garantie',
      'warranty_claim_status': 'Statut réclamation',
      'refund_processed': 'Remboursement',
      'refund_partial': 'Remboursement partiel',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.timeline, color: _neonCyan, size: 16),
            SizedBox(width: 8),
            Text('Historique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Spacer(),
          ]),
          const SizedBox(height: 12),
          ...events.take(10).map((e) {
            final m = e as Map<String, dynamic>;
            final type = m['event_type'] as String? ?? '';
            final notes = m['notes'] as String?;
            final date = m['created_at'] as String?;
            final frenchDate = date != null ? DateTime.tryParse(date) : null;
            final timeStr = frenchDate != null ? '${frenchDate.day.toString().padLeft(2, '0')}/${frenchDate.month.toString().padLeft(2, '0')} ${frenchDate.hour.toString().padLeft(2, '0')}:${frenchDate.minute.toString().padLeft(2, '0')}' : '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                    Container(width: 1, height: 30, color: _glassBorder),
                  ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(eventLabels[type] ?? type, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                          Text(timeStr, style: const TextStyle(color: _textMuted, fontSize: 10)),
                        ]),
                        if (notes != null && notes.isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 2), child: Text(notes, style: const TextStyle(color: _textMuted, fontSize: 11))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFinancialWidget(Color color) {
    return TicketFinancialsWidget(
      ticket: _ticket!,
      accentColor: color,
      partsCost: _totalPartsCost,
      totalPayments: _totalPayments,
      isOwner: ref.watch(isOwnerProvider),
      onEditLabor: () => _updateFinance('labor_cost', 'la Main d\'œuvre', (_ticket?['labor_cost'] as num?)?.toDouble() ?? 0),
      onEditDiscount: () => _updateFinance('discount', 'la Remise', (_ticket?['discount'] as num?)?.toDouble() ?? 0),
    );
  }

  Widget _buildProfitMarginCard(Color color) {
    final totalCost = _totalCost;
    final netProfit = _netProfit;
    final margin = _profitMarginPercent;
    final isPositive = netProfit >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPositive ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: isPositive ? Colors.greenAccent : Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              const Text('MARGE BÉNÉFICIAIRE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text('${margin.toStringAsFixed(1)}%', style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Coût total', '${totalCost.toStringAsFixed(0)} DA', _textMuted),
              _buildMiniStat('Bénéfice net', '${netProfit.toStringAsFixed(0)} DA', isPositive ? Colors.greenAccent : Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: _textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  bool get _isNotCanceled => _ticket?['status'] != 'Annulé';

  Widget _buildHandoverSection(Color color) {
    final status = _ticket?['status'] as String? ?? '';
    final isDelivered = status == 'Livré';
    final isCanceled = status == 'Annulé';
    final handoverConfirmed = _ticket?['handover_confirmed_at'] != null;
    final condition = _ticket?['device_condition_at_handover'] as String?;

    if (!isDelivered && !handoverConfirmed) return const SizedBox.shrink();

    Color sectionColor = handoverConfirmed ? _neonEmerald : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: sectionColor.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(handoverConfirmed ? Icons.task_alt : Icons.swap_horiz, color: sectionColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('REMISE AU CLIENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(handoverConfirmed ? 'Remise confirmée: $condition' : 'En attente de remise', style: TextStyle(color: sectionColor, fontSize: 11)),
                if (_ticket?['handover_notes'] != null && handoverConfirmed)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('Note: ${_ticket!['handover_notes']}', style: const TextStyle(color: _textMuted, fontSize: 11))),
              ],
            ),
          ),
          if (!isCanceled && !handoverConfirmed)
            _buildActionChip('Confirmer remise', Icons.check_circle, _neonEmerald, () => _showHandoverDialog(color)),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(Color color) {
    final isCanceled = _ticket?['status'] == 'Annulé';
    final handoverConfirmed = _ticket?['handover_confirmed_at'] != null;
    if (!handoverConfirmed || isCanceled) return const SizedBox.shrink();

    final feedback = _feedbackData;
    final hasFeedback = feedback != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(Icons.star, color: hasFeedback ? Colors.amber : _textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SATISFACTION CLIENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                if (hasFeedback) ...[
                  Row(children: List.generate(5, (i) => Icon(i < (_feedbackData!['rating'] as int? ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 16))),
                  if (_feedbackData!['comment'] != null)
                    Text('${_feedbackData!['comment']}', style: const TextStyle(color: _textMuted, fontSize: 11)),
                ] else ...[
                  const Text('Aucun avis', style: TextStyle(color: _textMuted, fontSize: 11)),
                ],
              ],
            ),
          ),
          if (!hasFeedback)
            _buildActionChip('Noter', Icons.star_rate, Colors.amber, () => _showFeedbackDialog(color)),
        ],
      ),
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

  Widget _buildPublicPageSection(Color color) {
    final isOwner = ref.watch(isOwnerProvider);
    if (!isOwner) return const SizedBox.shrink();
    final qrHash = _ticket?['qr_code_hash'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161b22), borderRadius: BorderRadius.circular(12), border: Border.all(color: _neonCyan.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.public, color: _neonCyan, size: 18),
            SizedBox(width: 8),
            Text('Page publique client', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(title: const Text('Activer la page de suivi', style: TextStyle(color: Colors.white, fontSize: 13)), value: _isPublicPageEnabled, activeColor: _neonCyan, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => _updatePublicPageSettings(isEnabled: v)),
          SwitchListTile(title: const Text('Afficher les prix', style: TextStyle(color: Colors.white, fontSize: 13)), value: _showPricesOnPublic, activeColor: _neonCyan, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => _updatePublicPageSettings(showPrices: v)),
          SwitchListTile(title: const Text('Masquer le téléphone', style: TextStyle(color: Colors.white, fontSize: 13)), value: _hidePhoneOnPublic, activeColor: Colors.orangeAccent, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => _updatePublicPageSettings(hidePhone: v)),
          SwitchListTile(title: const Text('Masquer le technicien', style: TextStyle(color: Colors.white, fontSize: 13)), value: _hideTechnicianOnPublic, activeColor: Colors.orangeAccent, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => _updatePublicPageSettings(hideTechnician: v)),
          SwitchListTile(title: const Text('Masquer l\'historique', style: TextStyle(color: Colors.white, fontSize: 13)), value: _hideHistoryOnPublic, activeColor: Colors.orangeAccent, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => _updatePublicPageSettings(hideHistory: v)),
          const SizedBox(height: 8),
          TextField(
            controller: _messageCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Message personnalisé (visible par le client)',
              labelStyle: TextStyle(color: _textMuted, fontSize: 13),
              hintText: 'Ex: Votre appareil est prêt, merci de venir le récupérer.',
              hintStyle: TextStyle(color: _textMuted, fontSize: 11),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _glassBorder)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
            ),
            maxLines: 2,
            onChanged: (v) => _publicPageMessage = v,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Enregistrer le message', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan.withOpacity(0.2), foregroundColor: _neonCyan),
              onPressed: () {
                _updatePublicPageSettings(message: _publicPageMessage);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message enregistré ✓'), duration: Duration(seconds: 1)));
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.visibility, color: Colors.grey[500], size: 16),
            const SizedBox(width: 6),
            Text('Vues: $_publicPageViews', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ]),
          if (_isPublicPageEnabled && qrHash != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.link, size: 16),
                label: const Text('Copier le lien public', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  final url = 'https://laidaniphone.vercel.app?qr=$qrHash';
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié ✓')));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updatePublicPageSettings({bool? isEnabled, bool? showPrices, bool? hidePhone, bool? hideTechnician, bool? hideHistory, String? message}) async {
    final updates = <String, dynamic>{};
    if (isEnabled != null) updates['is_public_page_enabled'] = isEnabled;
    if (showPrices != null) updates['show_prices_on_public'] = showPrices;
    if (hidePhone != null) updates['hide_phone_on_public'] = hidePhone;
    if (hideTechnician != null) updates['hide_technician_on_public'] = hideTechnician;
    if (hideHistory != null) updates['hide_history_on_public'] = hideHistory;
    if (message != null) updates['public_page_message'] = message;
    if (updates.isEmpty) return;
    try {
      await Supabase.instance.client.from('repair_tickets').update(updates).eq('id', widget.ticketId);
      if (mounted) setState(() {
        if (isEnabled != null) _isPublicPageEnabled = isEnabled;
        if (showPrices != null) _showPricesOnPublic = showPrices;
        if (hidePhone != null) _hidePhoneOnPublic = hidePhone;
        if (hideTechnician != null) _hideTechnicianOnPublic = hideTechnician;
        if (hideHistory != null) _hideHistoryOnPublic = hideHistory;
        if (message != null) { _publicPageMessage = message; _messageCtrl.text = message; }
      });
    } catch (_) {}
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: _textMuted, size: 12),
      const SizedBox(width: 4),
      Text('$label: $value', style: const TextStyle(color: _textMuted, fontSize: 11)),
    ]);
  }

  Future<void> _updateStatus(String newStatus) async {
    final oldStatus = _ticket?['status'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Changer le statut ?', style: TextStyle(color: Colors.white)),
        content: Text('Passer de « $oldStatus » à « $newStatus » ?', style: const TextStyle(color: _textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      final user = Supabase.instance.client.auth.currentUser;
      await client.from('repair_tickets').update({'status': newStatus, if (newStatus == 'Livré') 'delivered_at': DateTime.now().toIso8601String(), if (newStatus == 'Terminé') 'completed_at': DateTime.now().toIso8601String()}).eq('id', widget.ticketId);
      await client.from('repair_ticket_events').insert({'ticket_id': widget.ticketId, 'event_type': 'status_change', 'old_value': oldStatus, 'new_value': newStatus, 'created_by': user?.id, 'notes': 'Changement de statut: $oldStatus → $newStatus'});
      _fetchFullData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Widget _buildWarrantySection(Color color) {
    final isCanceled = _ticket?['status'] == 'Annulé';
    final warrantyDays = (_ticket?['warranty_days'] as num?)?.toInt() ?? 0;
    final expiresAt = _ticket?['warranty_expires_at'] as String?;
    final isExpired = expiresAt != null && DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) == true;
    final hasWarranty = warrantyDays > 0 || (expiresAt != null && !isExpired);

    Color warrantyColor = isExpired ? Colors.redAccent : (hasWarranty ? Colors.orangeAccent : _textMuted);
    final activeClaims = _warrantyClaims.where((c) => c['claim_status'] != 'Résolu' && c['claim_status'] != 'Refusé').toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: warrantyColor.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: warrantyColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GARANTIE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                if (hasWarranty) ...[
                  Text('$warrantyDays jours • Expire: ${expiresAt != null ? DateTime.tryParse(expiresAt)?.toString().substring(0, 10) ?? '' : ''}${isExpired ? ' (EXPIRÉE)' : ''}', style: TextStyle(color: warrantyColor, fontSize: 11)),
                ] else ...[
                  const Text('Sans garantie', style: TextStyle(color: _textMuted, fontSize: 11)),
                ],
                if (activeClaims.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${activeClaims.length} réclamation(s) active(s)', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                  ),
                if (_warrantyClaims.isNotEmpty)
                  ..._warrantyClaims.map((c) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('• ${c['claim_reason'] ?? ''} [${c['claim_status']}]', style: const TextStyle(color: _textMuted, fontSize: 10)),
                  )),
              ],
            ),
          ),
          if (!isCanceled && hasWarranty && !isExpired)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionChip('Réclamer', Icons.report_problem, Colors.orangeAccent, () => _showWarrantyClaimDialog(color)),
                if (activeClaims.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildActionChip('Suivi', Icons.track_changes, _neonCyan, () => _showWarrantyClaimsListDialog(color)),
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
                  _buildActionChip('Devis PDF', Icons.picture_as_pdf, color, () => _showQuoteDialog(color)),
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

