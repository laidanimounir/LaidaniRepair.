import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/pos/data/models/customer_model.dart';

class CustomerRepository {
  final _client;

  CustomerRepository(this._client);

  /// Fetches all registered customers, ordered by full_name.
  Future<List<CustomerModel>> fetchRegisteredCustomers({
    String? search,
  }) async {
    var query = _client
        .from('customers')
        .select('id, full_name, phone_number, total_debt, is_registered')
        .eq('is_registered', true);

    if (search != null && search.trim().isNotEmpty) {
      query = query.or(
          'full_name.ilike.%${search.trim()}%,phone_number.ilike.%${search.trim()}%');
    }

    final data = await query.order('full_name');
    return (data as List).map((e) => CustomerModel.fromJson(e)).toList();
  }

  /// Creates a new registered customer and returns the created record.
  Future<CustomerModel> createCustomer({
    required String fullName,
    String? phoneNumber,
  }) async {
    final data = await _client
        .from('customers')
        .insert({
          'full_name': fullName,
          'phone_number': phoneNumber,
          'is_registered': true,
        })
        .select()
        .single();
    return CustomerModel.fromJson(data);
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(supabaseClientProvider));
});

final customersProvider = FutureProvider<List<CustomerModel>>((ref) {
  return ref.watch(customerRepositoryProvider).fetchRegisteredCustomers();
});
