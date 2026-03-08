import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/features/pos/data/models/customer_model.dart';
import 'package:laidani_repair/features/pos/presentation/providers/pos_provider.dart';
import 'package:laidani_repair/features/pos/presentation/widgets/customer_selector_dialog.dart';
import 'package:laidani_repair/features/pos/presentation/widgets/checkout_dialog.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border(left: BorderSide(color: Color(0xFF2A2A50))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Color(0xFF2A2A50))),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Panier',
                  style: TextStyle(
                    color: AppTheme.onBackground,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (!cart.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                if (!cart.isEmpty) const SizedBox(width: 8),
                if (!cart.isEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined,
                        color: AppTheme.error, size: 18),
                    tooltip: 'Vider le panier',
                    onPressed: () => _confirmClear(context, ref),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Cart Items
          Expanded(
            child: cart.isEmpty
                ? _EmptyCart()
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        _CartItemRow(item: cart.items[i]),
                  ),
          ),

          // Totals + Customer + Actions
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF2A2A50))),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Discount input
                _DiscountRow(),
                const SizedBox(height: 10),

                // Subtotal
                _TotalRow(
                    label: 'Sous-total',
                    amount: cart.totalAmount,
                    muted: true),
                if (cart.discount > 0)
                  _TotalRow(
                      label: 'Remise',
                      amount: -cart.discount,
                      muted: true,
                      color: AppTheme.error),
                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),
                _TotalRow(
                    label: 'TOTAL',
                    amount: cart.finalAmount,
                    bold: true),
                const SizedBox(height: 12),

                // Customer selector
                _CustomerSelector(),
                const SizedBox(height: 12),

                // Checkout button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: cart.isEmpty
                        ? null
                        : () => _openCheckout(context, ref),
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('Valider la vente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.black87,
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le panier'),
        content: const Text('Voulez-vous supprimer tous les articles ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(cartProvider.notifier).clear();
  }

  void _openCheckout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CheckoutDialog(),
    );
  }
}

// ─── Cart Item Row ────────────────────────────────────────────────────────────

class _CartItemRow extends ConsumerWidget {
  final item;
  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          // Remove button
          IconButton(
            icon: const Icon(Icons.close, size: 14, color: AppTheme.error),
            onPressed: () => ref
                .read(cartProvider.notifier)
                .removeItem(item.product.id),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          ),
          const SizedBox(width: 6),
          // Product name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.productName,
                  style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.sellPrice.toStringAsFixed(0)} DA/u',
                  style: const TextStyle(
                      color: AppTheme.onSurfaceMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          // Quantity controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyBtn(
                icon: Icons.remove,
                onTap: () => ref
                    .read(cartProvider.notifier)
                    .decrementQty(item.product.id),
              ),
              Container(
                width: 30,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              _QtyBtn(
                icon: Icons.add,
                onTap: () => ref
                    .read(cartProvider.notifier)
                    .incrementQty(item.product.id),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Subtotal
          Text(
            '${item.subtotal.toStringAsFixed(0)} DA',
            style: const TextStyle(
                color: AppTheme.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF3A3A60)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppTheme.onSurface),
      ),
    );
  }
}

// ─── Discount Row ─────────────────────────────────────────────────────────────

class _DiscountRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Row(
      children: [
        const Icon(Icons.discount_outlined,
            size: 15, color: AppTheme.onSurfaceMuted),
        const SizedBox(width: 6),
        const Text('Remise:',
            style:
                TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            style: const TextStyle(
                color: AppTheme.onBackground,
                fontSize: 13,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              suffixText: 'DA',
              suffixStyle: const TextStyle(
                  color: AppTheme.onSurfaceMuted, fontSize: 12),
              hintText: '0',
              hintStyle: const TextStyle(
                  color: AppTheme.onSurfaceMuted, fontSize: 13),
            ),
            onChanged: (v) {
              final val = double.tryParse(v) ?? 0.0;
              ref.read(cartProvider.notifier).setDiscount(val);
            },
          ),
        ),
      ],
    );
  }
}

// ─── Total Row ────────────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  final bool muted;
  final Color? color;

  const _TotalRow({
    required this.label,
    required this.amount,
    this.bold = false,
    this.muted = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        color ?? (muted ? AppTheme.onSurface : AppTheme.onBackground);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: textColor,
                fontSize: bold ? 15 : 13,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w400)),
        Text(
          '${amount >= 0 ? '' : ''}${amount.toStringAsFixed(0)} DA',
          style: TextStyle(
              color: color ?? (bold ? AppTheme.secondary : textColor),
              fontSize: bold ? 16 : 13,
              fontWeight:
                  bold ? FontWeight.w700 : FontWeight.w500),
        ),
      ],
    );
  }
}

// ─── Customer Selector ────────────────────────────────────────────────────────

class _CustomerSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(cartProvider).selectedCustomer;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final customer = await showDialog<CustomerModel?>(
          context: context,
          builder: (_) => const CustomerSelectorDialog(),
        );
        if (customer != null) {
          ref.read(cartProvider.notifier).setCustomer(customer);
        } else if (customer == null && context.mounted) {
          // "None" selected - clear customer
          ref.read(cartProvider.notifier).setCustomer(null);
        }
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected != null
                ? AppTheme.primary.withOpacity(0.4)
                : const Color(0xFF2A2A50),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected != null
                  ? Icons.person
                  : Icons.person_outline,
              size: 18,
              color: selected != null
                  ? AppTheme.primary
                  : AppTheme.onSurfaceMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected?.fullName ?? 'Client anonyme (زبون عابر)',
                style: TextStyle(
                  color: selected != null
                      ? AppTheme.onBackground
                      : AppTheme.onSurfaceMuted,
                  fontSize: 13,
                  fontWeight: selected != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected != null)
              GestureDetector(
                onTap: () =>
                    ref.read(cartProvider.notifier).setCustomer(null),
                child: const Icon(Icons.close,
                    size: 16, color: AppTheme.onSurfaceMuted),
              )
            else
              const Icon(Icons.arrow_drop_down,
                  color: AppTheme.onSurfaceMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Empty Cart ────────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 48, color: AppTheme.onSurfaceMuted),
          SizedBox(height: 12),
          Text(
            'Panier vide',
            style: TextStyle(
                color: AppTheme.onSurfaceMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            'Cliquez sur un produit pour l\'ajouter',
            style: TextStyle(
                color: AppTheme.onSurfaceMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
