import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/features/pos/data/models/product_model.dart';
import 'package:laidani_repair/features/pos/presentation/providers/pos_provider.dart';

class ProductCard extends ConsumerWidget {
  final ProductModel product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider).items;
    final inCart = cartItems.any((i) => i.product.id == product.id);
    final cartQty = inCart
        ? cartItems.firstWhere((i) => i.product.id == product.id).quantity
        : 0;
    final isOutOfStock = product.stockQuantity <= 0;

    return GestureDetector(
      onTap: isOutOfStock
          ? null
          : () => ref.read(cartProvider.notifier).addProduct(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: inCart
              ? AppTheme.primary.withOpacity(0.12)
              : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCart
                ? AppTheme.primary.withOpacity(0.5)
                : const Color(0xFF2A2A50),
            width: inCart ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? const Color(0xFF2A2A50)
                          : AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: isOutOfStock
                          ? AppTheme.onSurfaceMuted
                          : AppTheme.primaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Product name
                  Text(
                    product.productName,
                    style: TextStyle(
                      color: isOutOfStock
                          ? AppTheme.onSurfaceMuted
                          : AppTheme.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // Price
                  Text(
                    '${product.referencePrice.toStringAsFixed(0)} DA',
                    style: TextStyle(
                      color: isOutOfStock
                          ? AppTheme.onSurfaceMuted
                          : AppTheme.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Stock badge
                  Row(
                    children: [
                      Icon(
                        isOutOfStock
                            ? Icons.remove_circle_outline
                            : Icons.check_circle_outline,
                        size: 12,
                        color: isOutOfStock
                            ? AppTheme.error
                            : Colors.greenAccent.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOutOfStock
                            ? 'Rupture de stock'
                            : 'Qté: ${product.stockQuantity}',
                        style: TextStyle(
                          color: isOutOfStock
                              ? AppTheme.error
                              : AppTheme.onSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Cart quantity badge
            if (inCart)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$cartQty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            // Out of stock overlay
            if (isOutOfStock)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
