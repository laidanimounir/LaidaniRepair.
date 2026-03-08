import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _productsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('products')
      .select('id, product_name, barcode, stock_quantity, reference_price, category_id, categories(category_name)')
      .order('product_name');
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

class _StockScreenState extends ConsumerState<StockScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: AppTheme.surfaceContainer,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.inventory_2), text: 'Produits'),
                Tab(icon: Icon(Icons.local_shipping), text: 'Achats'),
                Tab(icon: Icon(Icons.store), text: 'Fournisseurs'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ProductsTab(),
                _PurchasesTab(),
                _SuppliersTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final idx = _tabController.index;
    switch (idx) {
      case 0:
        _showProductDialog(context, ref);
        break;
      case 1:
        _showPurchaseDialog(context, ref);
        break;
      case 2:
        _showSupplierDialog(context, ref);
        break;
    }
  }
}

// ─── Products Tab ─────────────────────────────────────────────────────────────

class _ProductsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(_productsProvider);
    return products.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error))),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('Aucun produit', style: TextStyle(color: AppTheme.onSurfaceMuted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = list[i];
            final catName = p['categories']?['category_name'] ?? '—';
            final qty = p['stock_quantity'] ?? 0;
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: qty > 0 ? AppTheme.primary.withOpacity(0.15) : AppTheme.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2, size: 20,
                    color: qty > 0 ? AppTheme.primaryLight : AppTheme.error),
              ),
              title: Text(p['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.onBackground)),
              subtitle: Text('$catName • Code: ${p['barcode'] ?? '—'}', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(p['reference_price'] as num?)?.toStringAsFixed(0) ?? '0'} DA',
                      style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700)),
                  Text('Qté: $qty',
                      style: TextStyle(color: qty > 0 ? AppTheme.onSurfaceMuted : AppTheme.error, fontSize: 12)),
                ],
              ),
              onTap: () => _showProductDialog(context, ref, existing: p),
            );
          },
        );
      },
    );
  }
}

// ─── Purchases Tab ────────────────────────────────────────────────────────────

class _PurchasesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(_purchasesProvider);
    return purchases.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error))),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('Aucun achat enregistré', style: TextStyle(color: AppTheme.onSurfaceMuted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final inv = list[i];
            final supplier = inv['suppliers']?['supplier_name'] ?? 'Inconnu';
            final worker = inv['profiles']?['full_name'] ?? '';
            final date = DateTime.tryParse(inv['invoice_date'] ?? '')?.toString().substring(0, 10) ?? '';
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long, size: 20, color: AppTheme.secondary),
              ),
              title: Text('Achat — $supplier', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.onBackground)),
              subtitle: Text('$date • Par: $worker', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
              trailing: Text('${(inv['total_amount'] as num?)?.toStringAsFixed(0) ?? '0'} DA',
                  style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700)),
            );
          },
        );
      },
    );
  }
}

// ─── Suppliers Tab ────────────────────────────────────────────────────────────

class _SuppliersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(_suppliersProvider);
    return suppliers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error))),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('Aucun fournisseur', style: TextStyle(color: AppTheme.onSurfaceMuted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = list[i];
            final due = (s['total_due'] as num?)?.toDouble() ?? 0.0;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withOpacity(0.15),
                child: Text((s['supplier_name'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w700)),
              ),
              title: Text(s['supplier_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.onBackground)),
              subtitle: Text(s['phone_number'] ?? '—', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
              trailing: due > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text('Dû: ${due.toStringAsFixed(0)} DA',
                          style: const TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.w600)),
                    )
                  : const Text('0 DA', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            );
          },
        );
      },
    );
  }
}

// ─── Add/Edit Product Dialog ──────────────────────────────────────────────────

void _showProductDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existing}) {
  final isEdit = existing != null;
  final nameCtrl = TextEditingController(text: existing?['product_name'] ?? '');
  final barcodeCtrl = TextEditingController(text: existing?['barcode'] ?? '');
  final priceCtrl = TextEditingController(text: (existing?['reference_price'] as num?)?.toString() ?? '');
  final qtyCtrl = TextEditingController(text: (existing?['stock_quantity'] ?? 0).toString());
  int? catId = existing?['category_id'];

  showDialog(
    context: context,
    builder: (ctx) {
      final cats = ref.read(_categoriesProvider);
      return AlertDialog(
        title: Text(isEdit ? 'Modifier le produit' : 'Nouveau produit'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du produit')),
                const SizedBox(height: 12),
                TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Code-barres')),
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    decoration: const InputDecoration(labelText: 'Prix de référence (DA)', suffixText: 'DA')),
                const SizedBox(height: 12),
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Quantité en stock')),
                const SizedBox(height: 12),
                cats.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (categories) {
                    return StatefulBuilder(
                      builder: (ctx2, setDialogState) {
                        return DropdownButtonFormField<int>(
                          value: catId,
                          decoration: const InputDecoration(labelText: 'Catégorie'),
                          items: categories.map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int, child: Text(c['category_name'] as String))).toList(),
                          onChanged: (v) => setDialogState(() => catId = v),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              final data = {
                'product_name': nameCtrl.text.trim(),
                'barcode': barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                'reference_price': double.tryParse(priceCtrl.text) ?? 0,
                'stock_quantity': int.tryParse(qtyCtrl.text) ?? 0,
                'category_id': catId,
              };
              if (isEdit) {
                await client.from('products').update(data).eq('id', existing['id']);
              } else {
                await client.from('products').insert(data);
              }
              ref.invalidate(_productsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
          ),
        ],
      );
    },
  );
}

// ─── Add Supplier Dialog ──────────────────────────────────────────────────────

void _showSupplierDialog(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nouveau fournisseur'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du fournisseur')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            final client = ref.read(supabaseClientProvider);
            await client.from('suppliers').insert({
              'supplier_name': nameCtrl.text.trim(),
              'phone_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
            });
            ref.invalidate(_suppliersProvider);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Ajouter'),
        ),
      ],
    ),
  );
}

// ─── Add Purchase Dialog ──────────────────────────────────────────────────────

void _showPurchaseDialog(BuildContext context, WidgetRef ref) {
  final amountCtrl = TextEditingController();
  String? selectedSupplierId;

  showDialog(
    context: context,
    builder: (ctx) {
      final suppliers = ref.read(_suppliersProvider);
      return AlertDialog(
        title: const Text('Nouvel achat'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              suppliers.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Erreur'),
                data: (list) => StatefulBuilder(
                  builder: (ctx2, setState2) => DropdownButtonFormField<String>(
                    value: selectedSupplierId,
                    decoration: const InputDecoration(labelText: 'Fournisseur'),
                    items: list.map((s) => DropdownMenuItem<String>(
                      value: s['id'] as String,
                      child: Text(s['supplier_name'] as String),
                    )).toList(),
                    onChanged: (v) => setState2(() => selectedSupplierId = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: const InputDecoration(labelText: 'Montant total (DA)', suffixText: 'DA')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              final user = Supabase.instance.client.auth.currentUser;
              await client.from('purchase_invoices').insert({
                'supplier_id': selectedSupplierId,
                'worker_id': user?.id,
                'total_amount': double.tryParse(amountCtrl.text) ?? 0,
              });
              ref.invalidate(_purchasesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      );
    },
  );
}
