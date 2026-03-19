import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:laidani_repair/features/pos/presentation/providers/pos_provider.dart';

class TicketDialog extends StatelessWidget {
  final CartState cart;
  final double amountPaid;

  const TicketDialog({
    super.key,
    required this.cart,
    required this.amountPaid,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateStr = dateFormat.format(DateTime.now());
    
    final remainingDebt = (cart.finalAmount - amountPaid).clamp(0.0, double.infinity);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: Colors.white, // Thermal paper look
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shop Header
            const Text('LAIDANI REPAIR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
            const SizedBox(height: 4),
            const Text('Réparation & Accessoires', style: TextStyle(color: Colors.black87, fontSize: 12)),
            const SizedBox(height: 12),
            Text(dateStr, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.black26, thickness: 1, height: 1),
            const SizedBox(height: 16),
            
            // Client Info
            if (cart.selectedCustomer != null) ...[
              const Align(alignment: Alignment.centerLeft, child: Text('Client:', style: TextStyle(color: Colors.black54, fontSize: 12))),
              Align(alignment: Alignment.centerLeft, child: Text(cart.selectedCustomer!.fullName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14))),
              if (cart.selectedCustomer!.phoneNumber != null)
                Align(alignment: Alignment.centerLeft, child: Text(cart.selectedCustomer!.phoneNumber!, style: const TextStyle(color: Colors.black87, fontSize: 12))),
              const SizedBox(height: 16),
              const Divider(color: Colors.black26, thickness: 1, height: 1),
              const SizedBox(height: 16),
            ],

            // Items
            ...cart.items.map((item) {
               return Padding(
                 padding: const EdgeInsets.only(bottom: 8),
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('${item.quantity}x', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                     const SizedBox(width: 8),
                     Expanded(child: Text(item.product.productName, style: const TextStyle(color: Colors.black))),
                     Text('${item.subtotal.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                   ],
                 ),
               );
            }),

            const SizedBox(height: 8),
            const Divider(color: Colors.black26, thickness: 1, height: 1),
            const SizedBox(height: 16),

            // Totals
            _TicketRow('Sous-total', '${cart.totalAmount.toStringAsFixed(0)} DA'),
            if (cart.discount > 0) ...[
               const SizedBox(height: 4),
               _TicketRow('Remise Globale', '-${cart.discount.toStringAsFixed(0)} DA'),
            ],
            const SizedBox(height: 8),
            _TicketRow('TOTAL', '${cart.finalAmount.toStringAsFixed(0)} DA', isBold: true, size: 18),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.black26, thickness: 1, height: 1),
            const SizedBox(height: 16),

            // Payments
            _TicketRow('Payé', '${amountPaid.toStringAsFixed(0)} DA'),
            if (remainingDebt > 0) ...[
              const SizedBox(height: 4),
              _TicketRow('Dette Restante', '${remainingDebt.toStringAsFixed(0)} DA', isBold: true),
            ],

            const SizedBox(height: 24),
            const Text('Merci de votre visite !', style: TextStyle(color: Colors.black87, fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print, size: 18, color: Colors.black),
                    label: const Text('Imprimer', style: TextStyle(color: Colors.black)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black26)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impression lancée...')));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Suivant'),
                  ),
                ),
              ],
            )
          ],
        )
      )
    );
  }
}

class _TicketRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final double size;

  const _TicketRow(this.label, this.value, {this.isBold = false, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: size)),
        Text(value, style: TextStyle(color: Colors.black, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: size)),
      ],
    );
  }
}
