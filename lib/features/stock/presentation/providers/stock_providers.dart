import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

// 1. Categories Provider (One-time fetch, as Categories rarely change)
final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client.from('categories').select().order('category_name');
});

// 2. Realtime Products Stream Provider
final productsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  
  return client
      .from('products')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) => List<Map<String, dynamic>>.from(data));
});

// 3. Computed Inventory List Provider (Watches both Stream & Categories)
final inventoryListProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final streamAsync = ref.watch(productsStreamProvider);
  final catsAsync = ref.watch(categoriesProvider);

  // If either is loading or has an error, propagate that state
  if (streamAsync.isLoading || catsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  
  if (streamAsync.hasError) {
    return AsyncValue.error(streamAsync.error!, streamAsync.stackTrace!);
  }
  if (catsAsync.hasError) {
    return AsyncValue.error(catsAsync.error!, catsAsync.stackTrace!);
  }

  // Both have data, map the categories dynamically
  final products = streamAsync.value ?? [];
  final categories = catsAsync.value ?? [];

  // Create a fast lookup map for categories: {id: category_name}
  final categoryMap = {
    for (var c in categories) c['id']: c['category_name']
  };

  final populatedProducts = products.map((product) {
    // Clone product map to avoid mutating stream data directly
    final mappedProduct = Map<String, dynamic>.from(product); 
    
    // Inject the category block natively as the UI expects it
    final catId = mappedProduct['category_id'];
    mappedProduct['categories'] = {
      'category_name': categoryMap[catId] ?? '—'
    };
    
    return mappedProduct;
  }).toList();

  return AsyncValue.data(populatedProducts);
});

// 4. Suppliers Provider
final suppliersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client.from('suppliers').select().order('supplier_name');
});

// 5. Purchases Provider
final purchasesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('purchase_invoices')
      .select('id, total_amount, paid_amount, invoice_date, suppliers(supplier_name), profiles(full_name)')
      .order('invoice_date', ascending: false)
      .limit(50);
});
