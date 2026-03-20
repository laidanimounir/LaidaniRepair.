import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/pos/data/models/cart_item_model.dart';

class SalesRepository {
  final _client;

  SalesRepository(this._client);

 
  Future<String> checkout({
    required String? customerId,
    required String workerId,
    required List<CartItem> items,
    required double discount,
    required double amountPaid,
  }) async {
    final totalAmount = items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final finalAmount = totalAmount;

    
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

    
    final itemsPayload = items.map((item) => {
          'invoice_id': invoiceId,
          'product_id': item.product.id,
          'quantity': item.quantity,
          'sell_price': item.sellPrice,
        }).toList();

    await _client.from('sales_items').insert(itemsPayload);



    if (customerId != null) {
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