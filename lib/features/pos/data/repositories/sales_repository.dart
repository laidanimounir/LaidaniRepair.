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
    String? promoCode,
    required double amountPaid,
  }) async {
    final totalAmount = items.fold<double>(
      0.0, (sum, item) => sum + (item.product.referencePrice * item.quantity)
    );
    final finalAmount = items.fold<double>(
      0.0, (sum, item) => sum + item.subtotal
    );

    
    final invoiceRow = await _client
        .from('sales_invoices')
        .insert({
          'customer_id': customerId,
          'worker_id': workerId,
          'total_amount': totalAmount,
          'discount': discount,
          'final_amount': finalAmount - discount,
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

    if (promoCode != null) {
      final promo = await _client
          .from('promotions')
          .select('used_count')
          .eq('code', promoCode)
          .maybeSingle();
      if (promo != null) {
        await _client
            .from('promotions')
            .update({'used_count': (promo['used_count'] as num).toInt() + 1})
            .eq('code', promoCode);
      }
    }

    if (customerId != null) {
      await _client.from('customer_payments').insert({
        'customer_id': customerId,
        'worker_id': workerId,
        'amount_paid': amountPaid,
      });

      final loyaltyPoints = (finalAmount / 100).floor();
      if (loyaltyPoints > 0) {
        final existing = await _client.from('customers').select('loyalty_points').eq('id', customerId).maybeSingle();
        final currentPoints = (existing?['loyalty_points'] as num?)?.toInt() ?? 0;
        await _client.from('customers').update({'loyalty_points': currentPoints + loyaltyPoints}).eq('id', customerId);
        await _client.from('loyalty_transactions').insert({
          'customer_id': customerId,
          'points': loyaltyPoints,
          'reason': 'Achat ${finalAmount.toStringAsFixed(0)} DA',
        });
      }
    }

    return invoiceId;
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(supabaseClientProvider));
});