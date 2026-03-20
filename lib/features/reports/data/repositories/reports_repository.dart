import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

class ReportsRepository {
  final _client;

  ReportsRepository(this._client);

  Future<List<Map<String, dynamic>>> fetchSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    String? workerId,
    String? customerId,
  }) async {
    var query = _client
        .from('sales_invoices')
        .select('*, customers(full_name), profiles!worker_id(full_name), sales_items(quantity, sell_price, products(product_name))')
        .gte('invoice_date', startDate.toUtc().toIso8601String())
        .lte('invoice_date', endDate.toUtc().toIso8601String())
        .order('invoice_date', ascending: false);

    if (workerId != null && workerId.isNotEmpty) {
      query = query.eq('worker_id', workerId);
    }
    if (customerId != null && customerId.isNotEmpty) {
      query = query.eq('customer_id', customerId);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(supabaseClientProvider));
});
