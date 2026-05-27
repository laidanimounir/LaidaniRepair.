import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/pos/data/repositories/product_repository.dart';
import 'package:laidani_repair/features/pos/presentation/providers/pos_provider.dart';

/// Payment dialog shown at checkout.
/// Lets the cashier enter the amount paid and validates the sale.
class CheckoutDialog extends ConsumerStatefulWidget {
  const CheckoutDialog({super.key});

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _amountController = TextEditingController();
  double _amountPaid = 0.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final isLoading = checkoutState.isLoading;
    final change = (_amountPaid - cart.finalAmount).clamp(
        double.negativeInfinity, double.infinity);
    final remainder =
        (cart.finalAmount - _amountPaid).clamp(0.0, double.infinity);
    final isPartial = _amountPaid > 0 && _amountPaid < cart.finalAmount;
    final isFullyPaid = _amountPaid >= cart.finalAmount;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.payment,
                color: AppTheme.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Paiement'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                      'Nb. articles', '${cart.itemCount}',
                      icon: Icons.inventory_2_outlined),
                  if (cart.selectedCustomer != null)
                    _SummaryRow('Client',
                        cart.selectedCustomer!.fullName,
                        icon: Icons.person_outline),
                  if (cart.discount > 0)
                    _SummaryRow('Remise',
                        '-${cart.discount.toStringAsFixed(0)} DA',
                        color: AppTheme.error),
                  const Divider(height: 16),
                  _SummaryRow('TOTAL DÛ',
                      '${cart.finalAmount.toStringAsFixed(0)} DA',
                      bold: true,
                      color: AppTheme.secondary),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Promo Code
            cart.promoCode != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_offer, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Code: ${cart.promoCode} (-${cart.promoDiscount.toStringAsFixed(0)} DA)',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => ref.read(cartProvider.notifier).clearPromoCode(),
                          child: const Icon(Icons.close, size: 16, color: Colors.greenAccent),
                        ),
                      ],
                    ),
                  )
                : TextButton.icon(
                    icon: const Icon(Icons.local_offer, size: 16),
                    label: const Text('Code promo'),
                    onPressed: () => _showPromoInput(context),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                  ),
            const SizedBox(height: 12),

            // Amount paid input
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              decoration: const InputDecoration(
                labelText: 'Montant reçu (DA)',
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'DA',
              ),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onBackground),
              onChanged: (v) =>
                  setState(() => _amountPaid = double.tryParse(v) ?? 0.0),
            ),
            const SizedBox(height: 16),

            // Feedback row
            if (_amountPaid > 0) ...[
              if (isFullyPaid)
                _FeedbackChip(
                  icon: Icons.check_circle,
                  label: change > 0
                      ? 'Monnaie à rendre: ${change.toStringAsFixed(0)} DA'
                      : 'Paiement exact ✓',
                  color: Colors.greenAccent.shade400,
                ),
              if (isPartial)
                _FeedbackChip(
                  icon: Icons.warning_amber_rounded,
                  label:
                      'Paiement partiel — Reste: ${remainder.toStringAsFixed(0)} DA',
                  color: AppTheme.warning,
                ),
              if (cart.selectedCustomer == null && isPartial)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠ Sélectionnez un client pour enregistrer la dette.',
                    style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],

            // Error from checkout
            if (checkoutState.hasError) ...[
              const SizedBox(height: 12),
              Text(
                'Erreur: ${checkoutState.error}',
                style: const TextStyle(color: AppTheme.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: (_amountPaid <= 0 || isLoading)
              ? null
              : () => _submit(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondary,
            foregroundColor: Colors.black87,
          ),
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black87))
              : const Icon(Icons.check, size: 18),
          label: const Text('Confirmer',
              style:
                  TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Future<void> _showPromoInput(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code promo'),
        backgroundColor: AppTheme.surfaceContainerHigh,
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Entrez le code promo',
            prefixIcon: Icon(Icons.local_offer),
          ),
          style: const TextStyle(color: Colors.white),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty || !mounted) return;

    final client = ref.read(supabaseClientProvider);
    final result = await client
        .from('promotions')
        .select()
        .eq('code', code)
        .eq('is_active', true)
        .maybeSingle();

    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code promo invalide ou expiré')),
        );
      }
      return;
    }

    final now = DateTime.now().toUtc();
    final expiresAt = result['expires_at'] != null
        ? DateTime.tryParse(result['expires_at'].toString())
        : null;
    if (expiresAt != null && now.isAfter(expiresAt)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce code promo a expiré')),
        );
      }
      return;
    }

    final maxUses = result['max_uses'] as int?;
    final usedCount = (result['used_count'] as num?)?.toInt() ?? 0;
    if (maxUses != null && usedCount >= maxUses) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce code promo a atteint sa limite d\'utilisation')),
        );
      }
      return;
    }

    final cart = ref.read(cartProvider);
    final minPurchase = (result['min_purchase'] as num?)?.toDouble() ?? 0;
    if (cart.finalAmount < minPurchase) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Montant minimum requis: ${minPurchase.toStringAsFixed(0)} DA')),
        );
      }
      return;
    }

    final discountType = result['discount_type'] as String;
    final discountValue = (result['discount_value'] as num).toDouble();
    double promoDiscount;
    if (discountType == 'percentage') {
      promoDiscount = cart.finalAmount * discountValue / 100;
    } else {
      promoDiscount = discountValue;
    }

    ref.read(cartProvider.notifier).applyPromoCode(code, promoDiscount);
  }

  Future<void> _submit(BuildContext context) async {
    final success = await ref
        .read(checkoutProvider.notifier)
        .checkout(amountPaid: _amountPaid);

    if (!mounted) return;

    if (success) {
      // Refresh all streams after sale (same as CartPanel)
      ref.invalidate(productsStreamProvider);
      ref.invalidate(recentSalesStreamProvider);
      ref.invalidate(todayRevenueStreamProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              SizedBox(width: 10),
              Text('Vente enregistrée avec succès !'),
            ],
          ),
          backgroundColor: AppTheme.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  final IconData? icon;

  const _SummaryRow(this.label, this.value,
      {this.bold = false, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppTheme.onSurfaceMuted),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  color: AppTheme.onSurfaceMuted,
                  fontSize: bold ? 14 : 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color ?? AppTheme.onBackground,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w600,
                  fontSize: bold ? 15 : 13)),
        ],
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FeedbackChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
