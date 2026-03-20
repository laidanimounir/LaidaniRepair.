import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/pos/presentation/providers/pos_provider.dart';

class TicketDialog extends ConsumerStatefulWidget {
  final CartState cart;
  final double amountPaid;

  const TicketDialog({
    super.key,
    required this.cart,
    required this.amountPaid,
  });

  @override
  ConsumerState<TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends ConsumerState<TicketDialog> {
  double? _realTotalDebt;

  @override
  void initState() {
    super.initState();
    if (widget.cart.selectedCustomer != null) {
      _fetchRealDebt();
    }
  }

  Future<void> _fetchRealDebt() async {
    final client = ref.read(supabaseClientProvider);
    final result = await client
        .from('customers')
        .select('total_debt')
        .eq('id', widget.cart.selectedCustomer!.id)
        .single();
    if (mounted) {
      setState(() {
        _realTotalDebt = (result['total_debt'] as num).toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateStr = dateFormat.format(DateTime.now());
    
    final remainingDebt = (widget.cart.finalAmount - widget.amountPaid).clamp(0.0, double.infinity);

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
            if (widget.cart.selectedCustomer != null) ...[
              const Align(alignment: Alignment.centerLeft, child: Text('Client:', style: TextStyle(color: Colors.black54, fontSize: 12))),
              Align(alignment: Alignment.centerLeft, child: Text(widget.cart.selectedCustomer!.fullName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14))),
              if (widget.cart.selectedCustomer!.phoneNumber != null)
                Align(alignment: Alignment.centerLeft, child: Text(widget.cart.selectedCustomer!.phoneNumber!, style: const TextStyle(color: Colors.black87, fontSize: 12))),
              const SizedBox(height: 16),
              const Divider(color: Colors.black26, thickness: 1, height: 1),
              const SizedBox(height: 16),
            ],

            // Items
            ...widget.cart.items.map((item) {
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
            _TicketRow('Sous-total', '${widget.cart.totalAmount.toStringAsFixed(0)} DA'),
            if (widget.cart.discount > 0) ...[
               const SizedBox(height: 4),
               _TicketRow('Remise Globale', '-${widget.cart.discount.toStringAsFixed(0)} DA'),
            ],
            const SizedBox(height: 8),
            _TicketRow('TOTAL', '${widget.cart.finalAmount.toStringAsFixed(0)} DA', isBold: true, size: 18),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.black26, thickness: 1, height: 1),
            const SizedBox(height: 16),

            // Payments
            _TicketRow('Payé', '${widget.amountPaid.toStringAsFixed(0)} DA'),
            if (widget.cart.selectedCustomer != null) ...[
              const SizedBox(height: 4),
              if (_realTotalDebt == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                    ),
                  ),
                )
              else if (_realTotalDebt! > 0)
                _TicketRow('Dette Globale', '${_realTotalDebt!.toStringAsFixed(0)} DA', isBold: true),
            ] else if (remainingDebt > 0) ...[
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
