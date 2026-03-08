import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/pos/data/models/category_model.dart';
import 'package:laidani_repair/features/pos/data/models/product_model.dart';

class ProductRepository {
  final _client;

  ProductRepository(this._client);

  /// Fetches all categories ordered by name.
  Future<List<CategoryModel>> fetchCategories() async {
    final data = await _client
        .from('categories')
        .select('id, category_name')
        .order('category_name');
    return (data as List).map((e) => CategoryModel.fromJson(e)).toList();
  }

  /// Fetches all products with stock > 0, optionally filtered by [categoryId].
  /// If [search] is non-empty, filters by product_name or barcode.
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
      // ilike search on product_name OR barcode
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

// Selected category filter (null = all categories)
final selectedCategoryProvider = StateProvider<int?>((ref) => null);

// Search text
final productSearchProvider = StateProvider<String>((ref) => '');

final productsProvider = FutureProvider<List<ProductModel>>((ref) {
  final categoryId = ref.watch(selectedCategoryProvider);
  final search = ref.watch(productSearchProvider);
  return ref
      .watch(productRepositoryProvider)
      .fetchProducts(categoryId: categoryId, search: search);
});
