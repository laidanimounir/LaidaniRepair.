import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/pos/data/models/product_model.dart';
import 'package:laidani_repair/features/pos/data/repositories/product_repository.dart';
import 'package:laidani_repair/features/pos/presentation/providers/pos_provider.dart';
import 'package:laidani_repair/features/pos/presentation/widgets/cart_panel.dart';
import 'package:laidani_repair/features/pos/presentation/widgets/product_card.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  // We no longer rely on HardwareKeyboard.instance which can fail globally.
  // We forcefully attach a Focus widget to the root of the screen.
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(helpDialogRequestProvider, (_, __) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Raccourcis Clavier [Aide]'),
          backgroundColor: AppTheme.surfaceContainerHigh,
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• F1 : Rechercher un produit / scanner code-barres', style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              Text('• F2 : Sélectionner un client', style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              Text('• F9 : Valider la vente', style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              Text('• Echap : Vider le panier', style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              Text('• F12 : Afficher cette aide', style: TextStyle(color: Colors.white)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    });

    final isDesktop = MediaQuery.of(context).size.width >= 800;
    
    // Forcefully wrap the entire POS tree inside an active Focus Node.
    return Focus(
      autofocus: true,
      canRequestFocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f1) {
            ref.read(searchFocusRequestProvider.notifier).state++;
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.f2) {
            ref.read(clientFocusRequestProvider.notifier).state++;
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.f9) {
            ref.read(checkoutRequestProvider.notifier).state++;
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
             ref.read(cartProvider.notifier).clear();
             return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.f12) {
            ref.read(helpDialogRequestProvider.notifier).state++;
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: isDesktop ? const _DesktopPosLayout() : const _MobilePosLayout(),
    );
  }
}

// ─── Desktop Layout ───────────────────────────────────────────────────────────

class _DesktopPosLayout extends StatelessWidget {
  const _DesktopPosLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _TopRecetteBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: products panel
              const Expanded(
                flex: 62,
                child: _ProductsPanel(),
              ),
              // Right: cart panel (fixed width)
              const SizedBox(
                width: 380, // Made wider for new cart ui
                child: CartPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopRecetteBar extends ConsumerWidget {
  const _TopRecetteBar();

  void _showDailySalesDialog(BuildContext context, WidgetRef ref) async {
    final client = ref.read(supabaseClientProvider);
    final nowUtc = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day).toIso8601String();
    final endOfDay = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 23, 59, 59).toIso8601String();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Détails des Ventes du Jour', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceContainerHigh,
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: client
            .from('sales_invoices')
            .select()
            .gte('invoice_date', startOfDay)
            .lte('invoice_date', endOfDay)
            .order('invoice_date', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(width: 400, height: 200, child: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox(width: 400, height: 100, child: Center(child: Text('Aucune vente aujourd\'hui', style: TextStyle(color: AppTheme.onSurfaceMuted))));
            }
            final sales = snapshot.data!;
            return SizedBox(
              width: 500,
              height: 400,
              child: ListView.builder(
                itemCount: sales.length,
                itemBuilder: (context, index) {
                   final sale = sales[index];
                   final time = DateTime.tryParse(sale['invoice_date'].toString())?.toLocal();
                   final formatTime = time != null ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}' : '';
                   final amount = double.tryParse(sale['final_amount']?.toString() ?? '0') ?? 0.0;
                   return ListTile(
                     leading: const Icon(Icons.receipt, color: AppTheme.primary),
                     title: Text('Ticket #${sale['id']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                     subtitle: Text('Heure: $formatTime', style: const TextStyle(color: AppTheme.onSurfaceMuted)),
                     trailing: Text('${amount.toStringAsFixed(0)} DA', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 15)),
                   );
                }
              ),
            );
          }
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            child: const Text('Fermer'),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayRev = ref.watch(todayRevenueStreamProvider);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDailySalesDialog(context, ref),
        splashColor: AppTheme.primary.withOpacity(0.2),
        hoverColor: AppTheme.primary.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            border: Border(bottom: BorderSide(color: Color(0xFF2A2A50))),
          ),
          child: Row(
            children: [
              const Icon(Icons.analytics, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Recette du Jour :', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              todayRev.when(
                 data: (val) => Text('${val.toStringAsFixed(0)} DA', style: const TextStyle(color: AppTheme.success, fontSize: 18, fontWeight: FontWeight.w900)),
                 loading: () => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                 error: (_, __) => const Text('Erreur', style: TextStyle(color: AppTheme.error)),
              ),
              const Spacer(),
              const Text('Cliquer pour les détails', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(width: 24),
              TextButton.icon(
                 icon: const Icon(Icons.help_outline, size: 16),
                 label: const Text('Aide & Raccourcis [F12]'),
                 onPressed: () => ref.read(helpDialogRequestProvider.notifier).state++,
                 style: TextButton.styleFrom(foregroundColor: AppTheme.onSurfaceMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mobile Layout ────────────────────────────────────────────────────────────

class _MobilePosLayout extends ConsumerWidget {
  const _MobilePosLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider).itemCount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: const _ProductsPanel(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: cartCount == 0
            ? null
            : () => _showCartBottomSheet(context),
        backgroundColor:
            cartCount == 0 ? AppTheme.surfaceContainer : AppTheme.secondary,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.shopping_cart),
        label: Text(
          cartCount == 0 ? 'Panier vide' : 'Panier ($cartCount)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: const CartPanel(),
      ),
    );
  }
}

// ─── Products Panel ───────────────────────────────────────────────────────────

class _ProductsPanel extends ConsumerStatefulWidget {
  const _ProductsPanel();

  @override
  ConsumerState<_ProductsPanel> createState() => _ProductsPanelState();
}

class _ProductsPanelState extends ConsumerState<_ProductsPanel> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _handleSearchSubmit(String val) {
    final query = val.trim();
    if (query.isEmpty) {
      _searchFocus.requestFocus();
      return;
    }

    final productsAsync = ref.read(productsStreamProvider);
    final products = productsAsync.valueOrNull;

    if (products == null || products.isEmpty) {
      return; 
    }

    ProductModel? matchedProduct;

    // Strict exact barcode match first
    final exactBarcodeMatches = products.where((p) => p.barcode?.toLowerCase() == query.toLowerCase()).toList();

    if (exactBarcodeMatches.length == 1) {
      matchedProduct = exactBarcodeMatches.first;
    } else if (products.length == 1) {
      matchedProduct = products.first;
    }

    if (matchedProduct != null && matchedProduct.stockQuantity > 0) {
      // Auto-add product
      ref.read(cartProvider.notifier).addProduct(matchedProduct);
      
      // Force clearing of the field out of the render cycle
      Future.microtask(() {
        _searchController.clear();
        ref.read(productSearchProvider.notifier).state = '';
        _searchFocus.requestFocus();
      });
    } else {
      // Not found or out of stock, just regain focus
      _searchFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchFocusRequestProvider, (_, __) => _searchFocus.requestFocus());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar: search + title
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainer,
            border: Border(bottom: BorderSide(color: Color(0xFF2A2A50))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.point_of_sale, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Point de Vente',
                    style: TextStyle(
                        color: AppTheme.onBackground,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.onSurfaceMuted, size: 18),
                    tooltip: 'Actualiser les produits',
                    onPressed: () => ref.invalidate(productsStreamProvider),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Search bar
              TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un produit ou scanner un code-barres...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => ref.read(productSearchProvider.notifier).state = v,
                onSubmitted: _handleSearchSubmit,
              ),
            ],
          ),
        ),

        // Category filter chips
        const _CategoryFilterRow(),

        // Products grid
        const Expanded(child: _ProductGrid()),
      ],
    );
  }
}

// ─── Category Filter Chips ────────────────────────────────────────────────────

class _CategoryFilterRow extends ConsumerWidget {
  const _CategoryFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedId = ref.watch(selectedCategoryProvider);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: categoriesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (categories) => ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // "All" chip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: FilterChip(
                label: const Text('Tous'),
                selected: selectedId == null,
                onSelected: (_) =>
                    ref.read(selectedCategoryProvider.notifier).state = null,
                showCheckmark: false,
                selectedColor: AppTheme.primary.withOpacity(0.2),
                side: BorderSide(
                  color: selectedId == null
                      ? AppTheme.primary
                      : const Color(0xFF2A2A50),
                ),
                labelStyle: TextStyle(
                  color: selectedId == null
                      ? AppTheme.primaryLight
                      : AppTheme.onSurface,
                  fontWeight: selectedId == null
                      ? FontWeight.w600
                      : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
            // Category chips
            ...categories.map((cat) {
              final isSelected = selectedId == cat.id;
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 8),
                child: FilterChip(
                  label: Text(cat.categoryName),
                  selected: isSelected,
                  onSelected: (_) => ref
                      .read(selectedCategoryProvider.notifier)
                      .state = isSelected ? null : cat.id,
                  showCheckmark: false,
                  selectedColor: AppTheme.primary.withOpacity(0.2),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primary
                        : const Color(0xFF2A2A50),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryLight
                        : AppTheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Product Grid ─────────────────────────────────────────────────────────────

class _ProductGrid extends ConsumerWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    // Dynamic cross-axis count based on available width
    final crossAxisCount = screenWidth >= 1200
        ? 5
        : screenWidth >= 900
            ? 4
            : screenWidth >= 650
                ? 3
                : 2;

    return productsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 36),
            const SizedBox(height: 12),
            Text('Erreur de chargement:\n$e',
                style: const TextStyle(color: AppTheme.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(productsStreamProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
      data: (products) {
        if (products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 48, color: AppTheme.onSurfaceMuted),
                SizedBox(height: 12),
                Text('Aucun produit trouvé',
                    style: TextStyle(
                        color: AppTheme.onSurfaceMuted, fontSize: 15)),
                SizedBox(height: 4),
                Text(
                    'Vérifiez les filtres ou ajoutez des produits dans Stock & Achats.',
                    style: TextStyle(
                        color: AppTheme.onSurfaceMuted, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => ProductCard(product: products[i]),
        );
      },
    );
  }
}
