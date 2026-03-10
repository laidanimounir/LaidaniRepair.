import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

// --- Cyber Glass Theme Constants ---
const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonPurple = Color(0xFFB000FF);
const Color _neonCyan = Color(0xFF00E5FF);

// ─── Providers ────────────────────────────────────────────────────────────────

final _productsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('products')
      .select('id, product_name, barcode, stock_quantity, reference_price, purchase_price, min_stock, category_id, categories(category_name)')
      .order('created_at', ascending: false);
});

final _categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client.from('categories').select().order('category_name');
});

final _suppliersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client.from('suppliers').select().order('supplier_name');
});

final _purchasesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('purchase_invoices')
      .select('id, total_amount, invoice_date, suppliers(supplier_name), profiles(full_name)')
      .order('invoice_date', ascending: false)
      .limit(50);
});

// ─── Stock Screen ─────────────────────────────────────────────────────────────

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {})); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      backgroundColor: _bgCarbon,
      floatingActionButton: isDesktop ? null : _buildFloatingActionButton(context),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: _panelDark,
              border: Border(bottom: BorderSide(color: _glassBorder, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _neonPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _neonPurple.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: _neonPurple, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Text('STOCK & ACHATS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _showAddDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _neonPurple.withOpacity(0.1),
                            foregroundColor: _neonPurple,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            side: BorderSide(color: _neonPurple.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_box_outlined),
                          label: Text(_getAddButtonLabel(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: _neonPurple,
                  labelColor: _neonPurple,
                  unselectedLabelColor: _textMuted,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(icon: Icon(Icons.inventory_2), text: 'Produits'),
                    Tab(icon: Icon(Icons.local_shipping), text: 'Achats'),
                    Tab(icon: Icon(Icons.store), text: 'Fournisseurs'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ProductsTab(isDesktop: isDesktop),
                _PurchasesTab(isDesktop: isDesktop),
                _SuppliersTab(isDesktop: isDesktop),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAddButtonLabel() {
    switch (_tabController.index) {
      case 0: return 'NOUVEAU PRODUIT';
      case 1: return 'NOUVEL ACHAT';
      case 2: return 'NOUVEAU FOURNISSEUR';
      default: return 'AJOUTER';
    }
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showAddDialog(context),
      backgroundColor: _neonPurple,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    );
  }

  void _showAddDialog(BuildContext context) {
    switch (_tabController.index) {
      case 0: _showProductDialog(context, ref); break;
      case 1: _showPurchaseDialog(context, ref); break; 
      case 2: _showSupplierDialog(context, ref); break; 
    }
  }
}

// ─── Products Tab ─────────────────────────────────────────────────────────────

class _ProductsTab extends ConsumerWidget {
  final bool isDesktop;
  const _ProductsTab({required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(_productsProvider);
    
    return products.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _neonPurple)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 64, color: _textMuted.withOpacity(0.2)), const SizedBox(height: 16), const Text('Aucun produit en stock.', style: TextStyle(color: _textMuted))]));
        }
        return isDesktop ? _buildDesktopTable(context, ref, list) : _buildMobileList(context, ref, list);
      },
    );
  }

  Widget _buildDesktopTable(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> products) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _glassBorder, width: 1))),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('PRODUIT & CATÉGORIE', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('CODE BARRES', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('PRIX (ACHAT / VENTE)', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Text('STOCK', textAlign: TextAlign.center, style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (ctx, i) {
              final p = products[i];
              final catName = p['categories']?['category_name'] ?? '—';
              final qty = p['stock_quantity'] ?? 0;
              final minStock = p['min_stock'] ?? 5;
              final isLowStock = qty <= minStock;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _glassBorder, width: 0.5))),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['product_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(catName, style: const TextStyle(color: _neonPurple, fontSize: 11))])),
                    Expanded(flex: 2, child: Text(p['barcode'] ?? '—', style: const TextStyle(color: _textMuted, fontFamily: 'monospace', fontSize: 12))),
                    Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('A: ${p['purchase_price'] ?? 0} DA', style: const TextStyle(color: _textMuted, fontSize: 11)), const SizedBox(height: 2), Text('V: ${p['reference_price'] ?? 0} DA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])),
                    Expanded(flex: 1, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: isLowStock ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: isLowStock ? Colors.redAccent.withOpacity(0.5) : Colors.greenAccent.withOpacity(0.3))), child: Text('$qty', style: TextStyle(color: isLowStock ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold))))),
                    Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: IconButton(icon: const Icon(Icons.edit_outlined, color: _textMuted, size: 20), onPressed: () => _showProductDialog(context, ref, existing: p)))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (ctx, i) {
        final p = products[i];
        final catName = p['categories']?['category_name'] ?? '—';
        final qty = p['stock_quantity'] ?? 0;
        final minStock = p['min_stock'] ?? 5;
        final isLowStock = qty <= minStock;

        return InkWell(
          onTap: () => _showProductDialog(context, ref, existing: p),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _panelDark.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(p['product_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: isLowStock ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text('Qté: $qty', style: TextStyle(color: isLowStock ? Colors.redAccent : Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(catName, style: const TextStyle(color: _neonPurple, fontSize: 11)),
                const Divider(color: _glassBorder, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Achat: ${p['purchase_price'] ?? 0} DA', style: const TextStyle(color: _textMuted, fontSize: 12)),
                    Text('Vente: ${p['reference_price'] ?? 0} DA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Add/Edit Product Dialog ──────────────────────────────────────────────────

void _showProductDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existing}) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: _ProductFormDialog(ref: ref, existing: existing),
    ),
  );
}

class _ProductFormDialog extends StatefulWidget {
  final WidgetRef ref;
  final Map<String, dynamic>? existing;
  const _ProductFormDialog({required this.ref, this.existing});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _buyPriceCtrl;
  late final TextEditingController _sellPriceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _minStockCtrl;
  
  int? _selectedCatId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?['product_name'] ?? '');
    _barcodeCtrl = TextEditingController(text: p?['barcode'] ?? '');
    _buyPriceCtrl = TextEditingController(text: (p?['purchase_price'] as num?)?.toString() ?? '');
    _sellPriceCtrl = TextEditingController(text: (p?['reference_price'] as num?)?.toString() ?? '');
    _qtyCtrl = TextEditingController(text: (p?['stock_quantity'] ?? 0).toString());
    _minStockCtrl = TextEditingController(text: (p?['min_stock'] ?? 5).toString());
    _selectedCatId = p?['category_id'];
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
    prefixIcon: Icon(icon, color: _textMuted, size: 18),
    filled: true,
    fillColor: _bgCarbon.withOpacity(0.5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _neonPurple)),
  );

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selectedCatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom et Catégorie obligatoires'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = widget.ref.read(supabaseClientProvider);
      final data = {
        'product_name': name,
        'category_id': _selectedCatId,
        'barcode': _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        'purchase_price': double.tryParse(_buyPriceCtrl.text) ?? 0,
        'reference_price': double.tryParse(_sellPriceCtrl.text) ?? 0,
        'stock_quantity': int.tryParse(_qtyCtrl.text) ?? 0,
        'min_stock': int.tryParse(_minStockCtrl.text) ?? 5,
      };

      if (widget.existing != null) {
        await client.from('products').update(data).eq('id', widget.existing!['id']);
      } else {
        await client.from('products').insert(data);
      }
      
      widget.ref.invalidate(_productsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.existing != null ? 'Produit mis à jour' : 'Produit ajouté'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      backgroundColor: _panelDark.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder, width: 1.5)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2, color: _neonPurple),
                  const SizedBox(width: 12),
                  Text(isEdit ? 'MODIFIER LE PRODUIT' : 'NOUVEAU PRODUIT', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Nom du produit *', Icons.label)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FutureBuilder(
                      future: widget.ref.read(supabaseClientProvider).from('categories').select(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) return const CircularProgressIndicator(color: _neonPurple);
                        final cats = snap.data as List;
                        return DropdownButtonFormField<int>(
                          value: _selectedCatId,
                          dropdownColor: _panelDark,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDeco('Catégorie *', Icons.category),
                          items: cats.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['category_name']))).toList(),
                          onChanged: (v) => setState(() => _selectedCatId = v),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: TextField(controller: _barcodeCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Code Barres', Icons.qr_code))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: _buyPriceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Prix d\'achat (DA)', Icons.shopping_cart))),
                  const SizedBox(width: 16),
                  Expanded(child: TextField(controller: _sellPriceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Prix de vente (DA)', Icons.sell))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Quantité en stock', Icons.layers))),
                  const SizedBox(width: 16),
                  Expanded(child: TextField(controller: _minStockCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Seuil d\'alerte (Min)', Icons.warning_amber))),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _neonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isEdit ? 'ENREGISTRER' : 'AJOUTER', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Suppliers Tab ────────────────────────────────────────────────────────────

class _SuppliersTab extends ConsumerWidget {
  final bool isDesktop;
  const _SuppliersTab({required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(_suppliersProvider);
    
    return suppliers.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _neonPurple)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.store_outlined, size: 64, color: _textMuted.withOpacity(0.2)), const SizedBox(height: 16), const Text('Aucun fournisseur enregistré.', style: TextStyle(color: _textMuted))]));
        }
        return isDesktop ? _buildDesktopTable(list) : _buildMobileList(list);
      },
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> suppliers) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _glassBorder, width: 1))),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('FOURNISSEUR', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('TÉLÉPHONE', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('DÛ (DETTE)', textAlign: TextAlign.right, style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (ctx, i) {
              final s = suppliers[i];
              final due = (s['total_due'] as num?)?.toDouble() ?? 0.0;
              final hasDebt = due > 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _glassBorder, width: 0.5))),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Row(
                      children: [
                        CircleAvatar(backgroundColor: _neonPurple.withOpacity(0.15), child: Text((s['supplier_name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: _neonPurple, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 16),
                        Text(s['supplier_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    )),
                    Expanded(flex: 2, child: Text(s['phone_number'] ?? '—', style: const TextStyle(color: _textMuted))),
                    Expanded(flex: 2, child: Align(
                      alignment: Alignment.centerRight,
                      child: hasDebt 
                        ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.5))), child: Text('Dû: ${due.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)))
                        : const Text('0 DA', style: TextStyle(color: _textMuted)),
                    )),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> suppliers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suppliers.length,
      itemBuilder: (ctx, i) {
        final s = suppliers[i];
        final due = (s['total_due'] as num?)?.toDouble() ?? 0.0;
        final hasDebt = due > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _panelDark.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: _neonPurple.withOpacity(0.15), child: Text((s['supplier_name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: _neonPurple, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['supplier_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(s['phone_number'] ?? '—', style: const TextStyle(color: _textMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (hasDebt)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.redAccent.withOpacity(0.3))), child: Text('Dû: ${due.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)))
              else
                const Text('0 DA', style: TextStyle(color: _textMuted, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Add Supplier Dialog ──────────────────────────────────────────────────────

void _showSupplierDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: _SupplierFormDialog(ref: ref),
    ),
  );
}

class _SupplierFormDialog extends StatefulWidget {
  final WidgetRef ref;
  const _SupplierFormDialog({required this.ref});

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
    prefixIcon: Icon(icon, color: _textMuted, size: 18),
    filled: true,
    fillColor: _bgCarbon.withOpacity(0.5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _neonPurple)),
  );

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom du fournisseur obligatoire'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = widget.ref.read(supabaseClientProvider);
      await client.from('suppliers').insert({
        'supplier_name': name,
        'phone_number': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      });
      
      widget.ref.invalidate(_suppliersProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fournisseur ajouté !'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _panelDark.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder, width: 1.5)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.store, color: _neonPurple),
                SizedBox(width: 12),
                Text('NOUVEAU FOURNISSEUR', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Nom du fournisseur *', Icons.person)),
            const SizedBox(height: 16),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Téléphone', Icons.phone)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('AJOUTER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ─── Purchases Tab (Placeholder for Phase 3) ──────────────────────────────────

class _PurchasesTab extends ConsumerWidget {
  final bool isDesktop;
  const _PurchasesTab({required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(child: Text('Achats - En attente de la phase 3 (Système ERP)...', style: TextStyle(color: _textMuted)));
  }
}

// 🌟 Placeholder to prevent undefined method error
void _showPurchaseDialog(BuildContext context, WidgetRef ref) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le système d\'achats complet sera bientôt disponible !'), backgroundColor: Colors.orangeAccent));
}