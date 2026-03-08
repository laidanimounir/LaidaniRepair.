import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/pos/data/models/cart_item_model.dart';

class SalesRepository {
  final _client;

  SalesRepository(this._client);

  /// Inserts a complete sale:
  ///   1. Creates a `sales_invoices` row.
  ///   2. Bulk-inserts all `sales_items`.
  ///   3. If [amountPaid] > 0 AND customer is identified, records a
  ///      `customer_payments` row so the DB trigger can update `total_debt`.
  ///
  /// Returns the new invoice ID.
  Future<String> checkout({
    required String? customerId, // null → anonymous walk-in
    required String workerId,
    required List<CartItem> items,
    required double discount,
    required double amountPaid,
  }) async {
    final totalAmount =
        items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final finalAmount = (totalAmount - discount).clamp(0.0, double.infinity);

    // 1. Create invoice
    final invoiceRow = await _client
        .from('sales_invoices')
        .insert({
          'customer_id': customerId,
          'worker_id': workerId,
          'total_amount': totalAmount,
          'discount': discount,
          'final_amount': finalAmount,
        })
        .select('id')
        .single();

    final invoiceId = invoiceRow['id'] as String;

    // 2. Bulk-insert line items
    final itemsPayload = items
        .map((item) => {
              'invoice_id': invoiceId,
              'product_id': item.product.id,
              'quantity': item.quantity,
              'sell_price': item.sellPrice,
            })
        .toList();

    await _client.from('sales_items').insert(itemsPayload);

    // 3. Record the immediate (possibly partial) payment
    //    Only meaningful for identified customers — anonymous walk-ins
    //    don't have a debt account to update.
    if (amountPaid > 0 && customerId != null) {
      await _client.from('customer_payments').insert({
        'customer_id': customerId,
        'worker_id': workerId,
        'amount_paid': amountPaid,
      });
    }

    return invoiceId;
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(supabaseClientProvider));
});
