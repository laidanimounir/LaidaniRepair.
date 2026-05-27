import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/core/utils/csv_export.dart';
import 'package:laidani_repair/core/services/groq_service.dart';
import 'package:laidani_repair/features/stock/presentation/providers/stock_providers.dart';

// --- Cyber Glass Theme Constants ---
const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonPurple = Color(0xFFB000FF);

final _bulkModeInventory = StateProvider<bool>((ref) => false);
final _selectedProducts = StateProvider<Set<dynamic>>((ref) => Set<dynamic>());

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  bool _lowStockOnly = false;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

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
                        IconButton(
                          icon: Icon(ref.watch(_bulkModeInventory) ? Icons.checklist : Icons.checklist_outlined, color: ref.watch(_bulkModeInventory) ? _neonPurple : _textMuted),
                          tooltip: 'Mode sélection multiple',
                          onPressed: () {
                            ref.read(_bulkModeInventory.notifier).state = !ref.read(_bulkModeInventory);
                            ref.read(_selectedProducts.notifier).state = {};
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download, color: _textMuted),
                          tooltip: 'Exporter CSV',
                          onPressed: () => _exportInventoryCsv(context, ref),
                        ),
                        IconButton(
                          icon: const Icon(Icons.psychology, color: _textMuted),
                          tooltip: 'Analyse IA des stocks',
                          onPressed: () => _analyzeStockIA(context, ref),
                        ),
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
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: _neonPurple,
                  labelColor: _neonPurple,
                  unselectedLabelColor: _textMuted,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(icon: Icon(Icons.inventory_2), text: 'Produits'),
                    Tab(icon: Icon(Icons.analytics), text: 'Analytiques'),
                  ],
                ),
              ],
            ),
          ),
          _buildLowStockBanner(ref),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildProductList(ref, productsAsync, isDesktop),
                _buildAnalyticsTab(ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> productsAsync, bool isDesktop) {
    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _neonPurple)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
      data: (list) {
        final filtered = _lowStockOnly
            ? list.where((p) => (p['stock_quantity'] ?? 0) <= (p['min_stock'] ?? 5)).toList()
            : list;
        if (filtered.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_lowStockOnly ? Icons.check_circle_outline : Icons.inventory_2_outlined, size: 64, color: _textMuted.withOpacity(0.2)), const SizedBox(height: 16), Text(_lowStockOnly ? 'Aucun produit en rupture.' : 'Aucun produit en stock.', style: const TextStyle(color: _textMuted))]));
        return isDesktop ? _buildDesktopTable(context, ref, filtered) : _buildMobileList(context, ref, filtered);
      },
    );
  }

  Widget _buildAnalyticsTab(WidgetRef ref) {
    final productsAsync = ref.watch(inventoryListProvider);
    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _neonPurple)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('Aucune donnée disponible', style: TextStyle(color: _textMuted)));
        }

        final sortedBySales = List<Map<String, dynamic>>.from(products)
          ..sort((a, b) => ((b['stock_quantity'] as num?)?.toInt() ?? 0).compareTo((a['stock_quantity'] as num?)?.toInt() ?? 0));
        final top10 = sortedBySales.take(10).toList();

        final slowMoving = products.where((p) => ((p['stock_quantity'] as num?)?.toInt() ?? 0) > ((p['min_stock'] as num?)?.toInt() ?? 5)).toList();
        final slowMovingSorted = List<Map<String, dynamic>>.from(slowMoving)
          ..sort((a, b) => ((a['stock_quantity'] as num?)?.toInt() ?? 0).compareTo((b['stock_quantity'] as num?)?.toInt() ?? 0));
        final slowest10 = slowMovingSorted.take(10).toList();

        final totalStock = products.fold<int>(0, (s, p) => s + ((p['stock_quantity'] as num?)?.toInt() ?? 0));
        final totalValue = products.fold<double>(0, (s, p) => s + ((p['reference_price'] as num?)?.toDouble() ?? 0) * ((p['stock_quantity'] as num?)?.toInt() ?? 0));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildKpiCard('Produits totaux', '${products.length}', _neonPurple),
                  const SizedBox(width: 12),
                  _buildKpiCard('Stock total', '$totalStock unités', _neonPurple),
                  const SizedBox(width: 12),
                  _buildKpiCard('Valeur totale', '${totalValue.toStringAsFixed(0)} DA', Color(0xFF00E676)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('TOP 10 - PRODUITS LES PLUS STOCKÉS', style: TextStyle(color: _neonPurple, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (top10.isNotEmpty ? (top10.first['stock_quantity'] as num?)?.toDouble() ?? 50 : 50) + 10,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                          final idx = v.toInt();
                          if (idx >= 0 && idx < top10.length) {
                            final name = top10[idx]['product_name']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(name.length > 6 ? '${name.substring(0, 6)}..' : name, style: const TextStyle(color: _textMuted, fontSize: 8), textAlign: TextAlign.center),
                            );
                          }
                          return const SizedBox();
                        }, reservedSize: 30)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(color: _textMuted, fontSize: 10)))),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 10, getDrawingHorizontalLine: (v) => FlLine(color: _glassBorder, strokeWidth: 0.5)),
                      borderData: FlBorderData(show: false),
                      barGroups: top10.asMap().entries.map((e) {
                        return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: (e.value['stock_quantity'] as num?)?.toDouble() ?? 0, color: _neonPurple, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('PRODUITS À FAIBLE MOUVEMENT', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
              const SizedBox(height: 12),
              if (slowest10.isNotEmpty)
                ...slowest10.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                  child: Row(
                    children: [
                      Expanded(child: Text(p['product_name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 13))),
                      Text('Stock: ${p['stock_quantity'] ?? 0}, Min: ${p['min_stock'] ?? 5}', style: const TextStyle(color: _textMuted, fontSize: 11)),
                    ],
                  ),
                )),
              const SizedBox(height: 8),
              const Row(children: [Icon(Icons.info_outline, size: 12, color: _textMuted), SizedBox(width: 4), Text('Données basées sur les quantités en stock actuelles', style: TextStyle(color: _textMuted, fontSize: 10, fontStyle: FontStyle.italic))]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockBanner(WidgetRef ref) {
    return ref.watch(inventoryListProvider).when(
      data: (list) {
        final lowStockCount = list.where((p) => (p['stock_quantity'] ?? 0) <= (p['min_stock'] ?? 5)).length;
        if (lowStockCount == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('$lowStockCount produit(s) en rupture de stock', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13))),
              TextButton(
                onPressed: () => setState(() => _lowStockOnly = !_lowStockOnly),
                child: Text(_lowStockOnly ? 'Voir tout' : 'Voir', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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


  Future<void> _exportInventoryCsv(BuildContext context, WidgetRef ref) async {
    final products = ref.read(inventoryListProvider).valueOrNull ?? [];
    final headers = ['Nom', 'Code barres', 'Catégorie', 'Prix achat', 'Prix vente', 'Stock', 'Stock min'];
    final rows = products.map((p) => [
      p['product_name'] ?? '',
      p['barcode'] ?? '',
      p['categories'] is Map ? (p['categories'] as Map)['category_name'] ?? '' : '',
      (p['purchase_price'] as num?)?.toDouble() ?? 0,
      (p['reference_price'] as num?)?.toDouble() ?? 0,
      (p['stock_quantity'] as num?)?.toInt() ?? 0,
      (p['min_stock'] as num?)?.toInt() ?? 5,
    ]).toList();
    final csv = await exportToCsv(headers: headers, rows: rows);
    await shareCsv(context, csv, 'inventaire_${DateTime.now().millisecondsSinceEpoch}.csv');
  }

  Future<void> _analyzeStockIA(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: _panelDark,
        content: Row(children: [CircularProgressIndicator(color: _neonPurple), SizedBox(width: 16), Text('Analyse IA en cours...', style: TextStyle(color: Colors.white))]),
      ),
    );
    try {
      final products = ref.read(inventoryListProvider).valueOrNull ?? [];
      final result = await GroqService().suggestReorder(products);
      if (!context.mounted) return;
      Navigator.pop(context);

      final Map<String, Color> urgencyColors = {
        'Haute': Colors.redAccent,
        'Moyenne': Colors.orangeAccent,
        'Basse': Colors.greenAccent,
      };

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _neonPurple.withOpacity(0.5))),
          title: const Row(children: [Icon(Icons.psychology, color: _neonPurple), SizedBox(width: 8), Text('Analyse IA - Réapprovisionnement', style: TextStyle(color: Colors.white))]),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recommandations de l\'IA:', style: TextStyle(color: _textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                ...result.take(10).map((r) {
                  final urgency = r['urgency']?.toString() ?? 'Moyenne';
                  final color = urgencyColors[urgency] ?? _neonPurple;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _bgCarbon.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['productName']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('Qté suggérée: ${r['suggestedQuantity'] ?? 0}', style: const TextStyle(color: _textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.5))),
                          child: Text(urgency, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }),
                if (result.isEmpty)
                  const Text('Aucune recommandation spécifique pour le moment.', style: TextStyle(color: _textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                const Row(children: [Icon(Icons.info_outline, size: 12, color: _textMuted), SizedBox(width: 4), Expanded(child: Text('Analyse générée par IA. Ajustez selon votre expertise.', style: TextStyle(color: _textMuted, fontSize: 10, fontStyle: FontStyle.italic)))]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: _textMuted))),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur IA: $e'), backgroundColor: Colors.redAccent));
      }
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
