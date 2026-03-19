import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/pos/data/models/category_model.dart';
import 'package:laidani_repair/features/pos/data/models/product_model.dart';

class ProductRepository {
  final _client;

  ProductRepository(this._client);

  Future<List<CategoryModel>> fetchCategories() async {
    final data = await _client
        .from('categories')
        .select('id, category_name')
        .order('category_name');
    return (data as List).map((e) => CategoryModel.fromJson(e)).toList();
  }

  Future<List<ProductModel>> fetchProducts({
    int? categoryId,
    String? search,
  }) async {
    var query = _client.from('products').select(
        'id, category_id, product_name, barcode, stock_quantity, reference_price');

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (search != null && search.trim().isNotEmpty) {
      query = query.or(
          'product_name.ilike.%${search.trim()}%,barcode.ilike.%${search.trim()}%');
    }

    final data = await query.order('product_name');
    return (data as List).map((e) => ProductModel.fromJson(e)).toList();
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(supabaseClientProvider));
});

// ─── Riverpod providers ──────────────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) {
  return ref.watch(productRepositoryProvider).fetchCategories();
});

final selectedCategoryProvider = StateProvider<int?>((ref) => null);
final productSearchProvider = StateProvider<String>((ref) => '');

final productsProvider = FutureProvider<List<ProductModel>>((ref) {
  final categoryId = ref.watch(selectedCategoryProvider);
  final search = ref.watch(productSearchProvider);
  return ref
      .watch(productRepositoryProvider)
      .fetchProducts(categoryId: categoryId, search: search);
});

final productsStreamProvider = StreamProvider<List<ProductModel>>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  final categoryId = ref.watch(selectedCategoryProvider);
  final search = ref.watch(productSearchProvider);

  await for (final data in client.from('products').stream(primaryKey: ['id'])) {
    List<ProductModel> products = data.map<ProductModel>((e) => ProductModel.fromJson(e)).toList();
    
    if (categoryId != null) {
      products = products.where((p) => p.categoryId == categoryId).toList();
    }
    
    if (search.isNotEmpty) {
      final s = search.toLowerCase();
      products = products.where((p) => 
        p.productName.toLowerCase().contains(s) || 
        (p.barcode?.toLowerCase().contains(s) ?? false)
      ).toList();
    }
    
    products.sort((a, b) => a.productName.compareTo(b.productName));
    yield products;
  }
});