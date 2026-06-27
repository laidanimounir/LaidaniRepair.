import 'package:flutter/material.dart';

class TicketFinancialsWidget extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final Color accentColor;
  final double partsCost;
  final double totalPayments;
  final bool isOwner;
  final VoidCallback? onEditLabor;
  final VoidCallback? onEditDiscount;
  final VoidCallback? onRecordPayment;

  const TicketFinancialsWidget({
    super.key,
    required this.ticket,
    required this.accentColor,
    required this.partsCost,
    required this.totalPayments,
    required this.isOwner,
    this.onEditLabor,
    this.onEditDiscount,
    this.onRecordPayment,
  });

  static const Color _panelDark = Color(0xFF0A0F1A);
  static const Color _glassBorder = Color(0x1AFFFFFF);
  static const Color _textMuted = Color(0xFF8A9BB4);
  static const Color _neonEmerald = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final billingType = ticket['billing_type'] as String? ?? 'parts_and_labor';
    final labor = (ticket['labor_cost'] as num?)?.toDouble() ?? 0;
    final discount = (ticket['discount'] as num?)?.toDouble() ?? 0;
    final estimatedCost = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
    final finalCost = (ticket['final_cost'] as num?)?.toDouble() ?? 0;
    final remaining = (partsCost + (billingType == 'parts_only' ? 0 : labor) - discount) - totalPayments;
    final isCanceled = ticket['status'] == 'Annulé';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('RÉSUMÉ FINANCIER', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
            if (!isCanceled && onRecordPayment != null)
              TextButton.icon(onPressed: onRecordPayment, icon: Icon(Icons.payment, color: accentColor, size: 16), label: Text('Paiement', style: TextStyle(color: accentColor, fontSize: 12))),
          ]),
          const SizedBox(height: 12),
          if (billingType != 'labor_only')
            _row('Pièces', '${partsCost.toStringAsFixed(0)} DA'),
          if (billingType != 'parts_only')
            _row('M.O', '${labor.toStringAsFixed(0)} DA', onTap: isCanceled ? null : onEditLabor),
          if (discount > 0) _row('Remise', '-${discount.toStringAsFixed(0)} DA', color: Colors.redAccent, onTap: isCanceled ? null : onEditDiscount),
          const Divider(color: _glassBorder),
          _row('Total dû', '${(partsCost + (billingType == 'parts_only' ? 0 : labor) - discount).toStringAsFixed(0)} DA', bold: true),
          _row('Payé', '${totalPayments.toStringAsFixed(0)} DA', color: _neonEmerald),
          if (remaining > 0)
            _row('Reste à payer', '${remaining.toStringAsFixed(0)} DA', color: Colors.orangeAccent, bold: true),
          if (finalCost > 0) ...[
            const Divider(color: _glassBorder),
            _row('Coût final enregistré', '${finalCost.toStringAsFixed(0)} DA'),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false, VoidCallback? onTap}) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: _textMuted, fontSize: 12)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
    if (onTap != null) return InkWell(onTap: onTap, child: child);
    return child;
  }
}
