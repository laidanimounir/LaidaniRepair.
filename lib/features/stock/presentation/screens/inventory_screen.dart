import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/stock/presentation/providers/stock_providers.dart';

// --- Cyber Glass Theme Constants ---
const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonPurple = Color(0xFFB000FF);

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;
    final productsAsync = ref.watch(inventoryListProvider);

    return Scaffold(
      backgroundColor: _bgCarbon,
      floatingActionButton: isDesktop ? null : FloatingActionButton(
        onPressed: () => _showProductDialog(context, ref),
        backgroundColor: _neonPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
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
                        const Text('INVENTAIRE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _showProductDialog(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _neonPurple.withOpacity(0.1),
                            foregroundColor: _neonPurple,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            side: BorderSide(color: _neonPurple.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('NOUVEAU PRODUIT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _neonPurple)),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (list) {
                if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 64, color: _textMuted.withOpacity(0.2)), const SizedBox(height: 16), const Text('Aucun produit en stock.', style: TextStyle(color: _textMuted))]));
                return isDesktop ? _buildDesktopTable(context, ref, list) : _buildMobileList(context, ref, list);
              },
            ),
          ),
        ],
      ),
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

void _showProductDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existing}) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: _ProductFormDialog(ref: ref, existing: existing)),
  );
}

class _ProductFormDialog extends StatefulWidget {
  final WidgetRef ref;
  final Map<String, dynamic>? existing;
  const _ProductFormDialog({required this.ref, this.existing});
  @override State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final TextEditingController _nameCtrl, _barcodeCtrl, _buyPriceCtrl, _sellPriceCtrl, _qtyCtrl, _minStockCtrl;
  int? _selectedCatId;
  bool _isLoading = false;

  @override void initState() {
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

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: _textMuted, fontSize: 13), prefixIcon: Icon(icon, color: _textMuted, size: 18), filled: true, fillColor: _bgCarbon.withOpacity(0.5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _neonPurple)));

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _selectedCatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom et Catégorie obligatoires'), backgroundColor: Colors.redAccent)); return;
    }
    setState(() => _isLoading = true);
    try {
      final client = widget.ref.read(supabaseClientProvider);
      final data = {'product_name': _nameCtrl.text.trim(), 'category_id': _selectedCatId, 'barcode': _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(), 'purchase_price': double.tryParse(_buyPriceCtrl.text) ?? 0, 'reference_price': double.tryParse(_sellPriceCtrl.text) ?? 0, 'stock_quantity': int.tryParse(_qtyCtrl.text) ?? 0, 'min_stock': int.tryParse(_minStockCtrl.text) ?? 5};
      if (widget.existing != null) { await client.from('products').update(data).eq('id', widget.existing!['id']); } else { await client.from('products').insert(data); }
      // The stream automatically updates the UI, but we can invalidate fallback categories if needed
      widget.ref.invalidate(categoriesProvider);
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.existing != null ? 'Produit mis à jour' : 'Produit ajouté'), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override Widget build(BuildContext context) {
    return Dialog(backgroundColor: _panelDark.withOpacity(0.95), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder, width: 1.5)), child: Container(width: 600, padding: const EdgeInsets.all(24), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.inventory_2, color: _neonPurple), const SizedBox(width: 12), Text(widget.existing != null ? 'MODIFIER LE PRODUIT' : 'NOUVEAU PRODUIT', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]), const SizedBox(height: 24),
      TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Nom du produit *', Icons.label)), const SizedBox(height: 16),
      Row(children: [Expanded(child: FutureBuilder(future: widget.ref.read(supabaseClientProvider).from('categories').select(), builder: (ctx, snap) { if (!snap.hasData) return const CircularProgressIndicator(color: _neonPurple); final cats = snap.data as List; return DropdownButtonFormField<int>(value: _selectedCatId, dropdownColor: _panelDark, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Catégorie *', Icons.category), items: cats.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['category_name']))).toList(), onChanged: (v) => setState(() => _selectedCatId = v)); })), const SizedBox(width: 16), Expanded(child: TextField(controller: _barcodeCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Code Barres', Icons.qr_code)))]), const SizedBox(height: 16),
      Row(children: [Expanded(child: TextField(controller: _buyPriceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Prix d\'achat (DA)', Icons.shopping_cart))), const SizedBox(width: 16), Expanded(child: TextField(controller: _sellPriceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Prix de vente (DA)', Icons.sell)))]), const SizedBox(height: 16),
      Row(children: [Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Quantité en stock', Icons.layers))), const SizedBox(width: 16), Expanded(child: TextField(controller: _minStockCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Seuil d\'alerte (Min)', Icons.warning_amber)))]), const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: _textMuted))), const SizedBox(width: 16), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _neonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _isLoading ? null : _submit, child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(widget.existing != null ? 'ENREGISTRER' : 'AJOUTER', style: const TextStyle(fontWeight: FontWeight.bold)))])
    ]))));
  }
}
