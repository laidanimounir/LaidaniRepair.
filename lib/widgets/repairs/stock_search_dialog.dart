import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laidani_repair/constants/repair_status.dart';

class StockSearchDialog extends StatefulWidget {
  final Color color;
  final void Function(Map<String, dynamic> product) onProductSelected;

  const StockSearchDialog({super.key, required this.color, required this.onProductSelected});

  @override
  State<StockSearchDialog> createState() => _StockSearchDialogState();
}

class _StockSearchDialogState extends State<StockSearchDialog> {
  String _searchQuery = '';
  int? _selectedCategoryId;
  List<dynamic> _categories = [];
  bool _isLoadingCats = true;

  static const Color _panelDark = Color(0xFF0A0F1A);
  static const Color _glassBorder = Color(0x1AFFFFFF);
  static const Color _textMuted = Color(0xFF8A9BB4);
  static const Color _bgCarbon = Color(0xFF050914);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _neonEmerald = Color(0xFF10B981);

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
        children: [
          TextField(
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(hintText: 'Rechercher une pièce...', hintStyle: TextStyle(color: _textMuted), prefixIcon: Icon(Icons.search, color: _textMuted), border: InputBorder.none),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          if (!_isLoadingCats && _categories.isNotEmpty)
            SizedBox(
              height: 35,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _catChip('Tous', null),
                  ..._categories.map((c) => _catChip(c['category_name'] as String, c['id'] as int)),
                ],
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 450,
        height: 350,
        child: FutureBuilder<List<dynamic>>(
          future: futureQuery,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _neonCyan));
            if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.redAccent)));
            final results = snap.data ?? [];
            if (results.isEmpty) return const Center(child: Text('Aucune correspondance trouvée dans le stock', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)));
            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (ctx, i) {
                final m = results[i];
                final stock = (m['stock_quantity'] as num?)?.toInt() ?? 0;
                final minStock = (m['min_stock'] as num?)?.toInt() ?? 0;
                final price = (m['reference_price'] as num?)?.toDouble() ?? 0;
                final stockColor = stock == 0 ? Colors.redAccent : stock <= minStock ? Colors.orangeAccent : _neonEmerald;
                final stockLabel = stock == 0 ? 'RUPTURE' : stock <= minStock ? 'BAS ($stock)' : 'En stock ($stock)';

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m['product_name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: stockColor)),
                          const SizedBox(width: 6),
                          Text(stockLabel, style: TextStyle(color: stockColor, fontSize: 11)),
                          const SizedBox(width: 12),
                          Text('${price.toStringAsFixed(0)} DA', style: const TextStyle(color: _textMuted, fontSize: 11)),
                        ]),
                      ]),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _neonEmerald.withOpacity(0.1), foregroundColor: _neonEmerald, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      onPressed: stock == 0 ? () => _showZeroStockOverride(m) : () { Navigator.pop(context); widget.onProductSelected(m); },
                      child: Text(stock == 0 ? 'Forcer' : 'Ajouter', style: const TextStyle(fontSize: 11)),
                    ),
                  ]),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer', style: TextStyle(color: _textMuted))),
      ],
    );
  }

  void _showZeroStockOverride(Map<String, dynamic> product) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        title: const Row(children: [Icon(Icons.warning, color: Colors.redAccent), SizedBox(width: 8), Text('Stock épuisé', style: TextStyle(color: Colors.white))]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${product['product_name'] ?? 'Cette pièce'} est en rupture de stock.', style: const TextStyle(color: _textMuted)),
          const SizedBox(height: 12),
          TextField(controller: reasonCtrl, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Motif du dépassement...', hintStyle: TextStyle(color: _textMuted), border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); widget.onProductSelected(product); },
            child: const Text('Forcer l\'ajout'),
          ),
        ],
      ),
    );
  }

  Widget _catChip(String label, int? id) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: selected ? Colors.black : _textMuted, fontSize: 11)),
        selected: selected,
        selectedColor: _neonCyan,
        backgroundColor: _bgCarbon,
        side: BorderSide(color: selected ? _neonCyan : _glassBorder),
        onSelected: (_) => setState(() => _selectedCategoryId = id),
      ),
    );
  }
}
