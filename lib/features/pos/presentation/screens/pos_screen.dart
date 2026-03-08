import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/features/pos/data/repositories/product_repository.dart';
import 'package:laidani_repair/features/pos/presentation/providers/pos_provider.dart';
import 'package:laidani_repair/features/pos/presentation/widgets/cart_panel.dart';
import 'package:laidani_repair/features/pos/presentation/widgets/checkout_dialog.dart';
import 'package:laidani_repair/features/pos/presentation/widgets/product_card.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    return isDesktop ? const _DesktopPosLayout() : const _MobilePosLayout();
  }
}

// ─── Desktop Layout ───────────────────────────────────────────────────────────

class _DesktopPosLayout extends StatelessWidget {
  const _DesktopPosLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: products panel
        const Expanded(
          flex: 62,
          child: _ProductsPanel(),
        ),
        // Right: cart panel (fixed width)
        const SizedBox(
          width: 320,
          child: CartPanel(),
        ),
      ],
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

class _ProductsPanel extends ConsumerWidget {
  const _ProductsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar: search + title
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainer,
            border:
                Border(bottom: BorderSide(color: Color(0xFF2A2A50))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.point_of_sale,
                      color: AppTheme.primary, size: 20),
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
                    icon: const Icon(Icons.refresh,
                        color: AppTheme.onSurfaceMuted, size: 18),
                    tooltip: 'Actualiser les produits',
                    onPressed: () => ref.invalidate(productsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Search bar
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher un produit ou scanner un code-barres...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (v) =>
                    ref.read(productSearchProvider.notifier).state = v,
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
    final productsAsync = ref.watch(productsProvider);
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
              onPressed: () => ref.invalidate(productsProvider),
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
