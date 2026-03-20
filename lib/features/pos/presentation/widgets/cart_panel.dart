import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/features/pos/data/models/cart_item_model.dart';
import 'package:laidani_repair/features/pos/data/models/customer_model.dart';
import 'package:laidani_repair/features/pos/presentation/providers/pos_provider.dart';
import 'package:laidani_repair/features/pos/presentation/widgets/customer_selector_dialog.dart';
import 'package:laidani_repair/features/pos/presentation/widgets/ticket_dialog.dart';

class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key});

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  bool _isCredit = false;
  final TextEditingController _paidController = TextEditingController();

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout() async {
    final cart = ref.read(cartProvider);
    final finalAmount = cart.finalAmount;
    final paid = _isCredit ? (double.tryParse(_paidController.text) ?? 0.0) : finalAmount;
    
    // The checkout logic returns a string (invoiceId) or null
    final success = await ref.read(checkoutProvider.notifier).checkout(amountPaid: paid);
    
    if (success) {
      if (mounted) {
        final currentCartData = ref.read(cartProvider);
        Future.microtask(() async {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => TicketDialog(cart: currentCartData, amountPaid: paid),
          );
          if (mounted) {
            ref.read(cartProvider.notifier).clear();
            setState(() {
              _isCredit = false;
              _paidController.clear();
            });
          }
        });
      }
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le panier'),
        content: const Text('Voulez-vous supprimer tous les articles ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(cartProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(checkoutRequestProvider, (_, __) {
      if (!ref.read(cartProvider).isEmpty && !ref.read(checkoutProvider).isLoading) {
        _handleCheckout();
      }
    });

    ref.listen(clientFocusRequestProvider, (_, __) async {
       final customer = await showDialog<CustomerModel?>(
          context: context,
          builder: (_) => const CustomerSelectorDialog(),
        );
        if (customer != null) {
          ref.read(cartProvider.notifier).setCustomer(customer);
        } else if (customer == null && context.mounted) {
          ref.read(cartProvider.notifier).setCustomer(null);
        }
    });

    final cart = ref.watch(cartProvider);
    final checkoutState = ref.watch(checkoutProvider);
    
    // Dynamic Debt Calculation
    final hasCustomer = cart.selectedCustomer != null;
    final double paid = _isCredit ? (double.tryParse(_paidController.text) ?? 0.0) : cart.finalAmount;
    final double remainingDebt = (cart.finalAmount - paid).clamp(0.0, double.infinity);

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
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2A2A50)))),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Panier', style: TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                if (!cart.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                if (!cart.isEmpty) const SizedBox(width: 8),
                if (!cart.isEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.error, size: 18),
                    tooltip: 'Vider le panier',
                    onPressed: _confirmClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Smart Cart Items
          Expanded(
            flex: 4,
            child: cart.isEmpty
                ? const _EmptyCart()
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF2A2A50)),
                    itemBuilder: (_, i) => _CartItemRow(item: cart.items[i]),
                  ),
          ),

          // Middle - Payment & Client
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              border: Border(top: BorderSide(color: Color(0xFF2A2A50))),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Huge Total Amount (Neon Glow)
                Center(
                  child: Text(
                    '${cart.finalAmount.toStringAsFixed(0)} DA',
                    style: const TextStyle(
                      color: Color(0xFF00E5FF), // النيون السماوي الصريح
                      fontSize: 40, 
                      fontWeight: FontWeight.w900, 
                      shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 12, offset: Offset(0, 0))]
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Customer Selector
                _CustomerSelector(),
                const SizedBox(height: 12),

                // Dynamic Debt Controls
                if (hasCustomer) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ajouter Avance/Crédit', style: TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.bold)),
                      Switch(
                        value: _isCredit,
                        activeColor: AppTheme.primary,
                        onChanged: (val) {
                          setState(() {
                            _isCredit = val;
                            if (!val) _paidController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  if (_isCredit) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _paidController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                            decoration: InputDecoration(
                              labelText: 'Montant Payé (DA)', 
                              labelStyle: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
                              isDense: true, 
                              filled: true,
                              fillColor: const Color(0xFF1A1A2E), // خلفية زجاجية
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2A2A50))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2A2A50))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.primary)),
                            ),
                            onChanged: (v) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dette Restante', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                              Text('${remainingDebt.toStringAsFixed(0)} DA', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w900, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],

                // Checkout Button (Neon Theme)
                SizedBox(
                  height: 55, // زر عريض ومحترم
                  child: ElevatedButton.icon(
                    onPressed: cart.isEmpty || checkoutState.isLoading ? null : _handleCheckout,
                    icon: checkoutState.isLoading 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : const Icon(Icons.payment, size: 20),
                    label: Text(checkoutState.isLoading ? 'En cours...' : '💳 VALIDER LA VENTE [F9]'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cart.isEmpty ? AppTheme.surfaceContainer : const Color(0xFF161625), // لون داكن
                      foregroundColor: cart.isEmpty ? AppTheme.onSurfaceMuted : const Color(0xFF00E5FF), // نص سماوي نيون
                      disabledBackgroundColor: AppTheme.surfaceContainer,
                      disabledForegroundColor: AppTheme.onSurfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: cart.isEmpty ? Colors.transparent : const Color(0xFF00E5FF), width: 1.5), // إطار مشع
                      ),
                      shadowColor: cart.isEmpty ? Colors.transparent : const Color(0xFF00E5FF).withOpacity(0.4),
                      elevation: cart.isEmpty ? 0 : 8,
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom - Recent Sales Stream
          const Expanded(
            flex: 2,
            child: _RecentSalesList(),
          ),
        ],
      ),
    );
  }
}

// ─── Cart Item Row (Editable Prix & Remise) ──────────────────────────────────

class _CartItemRow extends ConsumerStatefulWidget {
  final CartItem item;
  const _CartItemRow({required this.item});

  @override
  ConsumerState<_CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends ConsumerState<_CartItemRow> {
  final _prixController = TextEditingController();
  final _remiseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prixController.text = widget.item.sellPrice.toStringAsFixed(0);
    _remiseController.text = widget.item.discountAmount.toStringAsFixed(0);
  }

  @override
  void didUpdateWidget(_CartItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.sellPrice != widget.item.sellPrice && !FocusScope.of(context).hasFocus) {
       _prixController.text = widget.item.sellPrice.toStringAsFixed(0);
    }
    if (oldWidget.item.discountAmount != widget.item.discountAmount && !FocusScope.of(context).hasFocus) {
       _remiseController.text = widget.item.discountAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _prixController.dispose();
    _remiseController.dispose();
    super.dispose();
  }

  void _onPrixSubmitted(String val) {
    final price = double.tryParse(val) ?? widget.item.product.referencePrice;
    ref.read(cartProvider.notifier).updateSellPrice(widget.item.product.id, price);
  }

  void _onRemiseSubmitted(String val) {
    final maxRemise = widget.item.product.referencePrice;
    final remise = (double.tryParse(val) ?? 0.0).clamp(0.0, maxRemise);
    ref.read(cartProvider.notifier).updateItemDiscount(widget.item.product.id, remise.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppTheme.error),
                  onPressed: () => ref.read(cartProvider.notifier).removeItem(widget.item.product.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
                Expanded(
                  child: Text(
                    widget.item.product.productName,
                    style: const TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis, // تأكيد إخفاء النص الطويل
                  ),
                ),
                Text(
                  '${widget.item.subtotal.toStringAsFixed(0)} DA',
                  style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w900, fontSize: 14),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Qty Controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyBtn(icon: Icons.remove, onTap: () => ref.read(cartProvider.notifier).decrementQty(widget.item.product.id)),
                  Container(
                    width: 30,
                    alignment: Alignment.center,
                    child: Text('${widget.item.quantity}', style: const TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  _QtyBtn(icon: Icons.add, onTap: () => ref.read(cartProvider.notifier).incrementQty(widget.item.product.id)),
                ],
              ),
              const SizedBox(width: 12),
              
              // 🚀 تم إصلاح تصميم حقل السعر (Prix) 🚀
              Container(
                height: 35,
                width: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E), // خلفية زجاجية داكنة
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextFormField(
                  controller: _prixController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero, // توسيط النص
                    border: InputBorder.none,
                    prefixText: ' Prix: ',
                    prefixStyle: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  onFieldSubmitted: _onPrixSubmitted,
                ),
              ),
              
              const SizedBox(width: 8),
              
              // 🚀 تم إصلاح تصميم حقل الخصم (Remise) 🚀
              Container(
                height: 35,
                width: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextFormField(
                  controller: _remiseController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero, // توسيط النص
                    border: InputBorder.none,
                    prefixText: ' Rem: ',
                    prefixStyle: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  onChanged: _onRemiseSubmitted,
                  onFieldSubmitted: _onRemiseSubmitted,
                ),
              ),
            ],
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
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: AppTheme.primaryLight),
      ),
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
          ref.read(cartProvider.notifier).setCustomer(null);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected != null ? AppTheme.primary : const Color(0xFF2A2A50)),
        ),
        child: Row(
          children: [
            Icon(selected != null ? Icons.person : Icons.person_outline, size: 18, color: selected != null ? AppTheme.primary : AppTheme.onSurfaceMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected?.fullName ?? 'Client anonyme (زبون عابر)',
                style: TextStyle(color: selected != null ? AppTheme.onBackground : AppTheme.onSurfaceMuted, fontSize: 13, fontWeight: selected != null ? FontWeight.w700 : FontWeight.w400),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected != null)
              GestureDetector(
                onTap: () => ref.read(cartProvider.notifier).setCustomer(null),
                child: const Icon(Icons.close, size: 16, color: AppTheme.onSurfaceMuted),
              )
            else
              const Icon(Icons.arrow_drop_down, color: AppTheme.onSurfaceMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Sales List ────────────────────────────────────────────────────────

class _RecentSalesList extends ConsumerWidget {
  const _RecentSalesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesStream = ref.watch(recentSalesStreamProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border(top: BorderSide(color: Color(0xFF2A2A50))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Dernières Ventes', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: salesStream.when(
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => const Center(child: Text('Aucune vente récente', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12))),
              data: (sales) {
                if (sales.isEmpty) {
                  return const Center(child: Text('Aucune vente récente', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sales.length,
                  itemBuilder: (context, i) {
                    final sale = sales[i];
                    final date = DateTime.tryParse(sale['created_at']?.toString() ?? '') ?? DateTime.now();
                    final formattedDate = DateFormat('HH:mm').format(date.toLocal());
                    final total = double.tryParse(sale['final_amount']?.toString() ?? '0') ?? 0.0;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                      title: Text('${total.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      trailing: Text(formattedDate, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Cart ────────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 48, color: AppTheme.onSurfaceMuted),
          SizedBox(height: 12),
          Text('Panier vide', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}