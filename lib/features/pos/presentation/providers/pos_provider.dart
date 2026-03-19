import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/features/pos/data/models/cart_item_model.dart';
import 'package:laidani_repair/features/pos/data/models/customer_model.dart';
import 'package:laidani_repair/features/pos/data/models/product_model.dart';
import 'package:laidani_repair/features/pos/data/repositories/sales_repository.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

// ─── Cart State ───────────────────────────────────────────────────────────────

class CartState {
  final List<CartItem> items;
  final CustomerModel? selectedCustomer; // null = anonymous walk-in
  final double discount;

  const CartState({
    this.items = const [],
    this.selectedCustomer,
    this.discount = 0.0,
  });

  double get totalAmount =>
      items.fold(0.0, (sum, item) => sum + item.subtotal);

  double get finalAmount => (totalAmount - discount).clamp(0.0, double.infinity);

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    List<CartItem>? items,
    Object? selectedCustomer = _sentinel,
    double? discount,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedCustomer: selectedCustomer == _sentinel
          ? this.selectedCustomer
          : selectedCustomer as CustomerModel?,
      discount: discount ?? this.discount,
    );
  }
}

const _sentinel = Object();

// ─── Cart Notifier ────────────────────────────────────────────────────────────

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// Add a product or increment its quantity if already in cart.
  void addProduct(ProductModel product) {
    final idx = state.items.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      final updated = List<CartItem>.from(state.items);
      final existing = updated[idx];
      // Don't exceed available stock
      if (existing.quantity >= product.stockQuantity) return;
      updated[idx] = existing.copyWith(quantity: existing.quantity + 1);
      state = state.copyWith(items: updated);
    } else {
      if (product.stockQuantity <= 0) return;
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            product: product,
            quantity: 1,
            sellPrice: product.referencePrice,
          ),
        ],
      );
    }
  }

  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.product.id != productId).toList(),
    );
  }

  void incrementQty(String productId) {
    _updateQty(productId, 1);
  }

  void decrementQty(String productId) {
    final item = state.items.firstWhere((i) => i.product.id == productId,
        orElse: () => throw StateError('Item not found'));
    if (item.quantity <= 1) {
      removeItem(productId);
    } else {
      _updateQty(productId, -1);
    }
  }

  /// Update the sell price for a specific cart item and recalculate item discount.
  void updateSellPrice(String productId, double price) {
    final idx = state.items.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;
    final updated = List<CartItem>.from(state.items);
    final item = updated[idx];
    final validPrice = price.clamp(0, double.infinity).toDouble();
    final newDiscount = item.product.referencePrice - validPrice;
    updated[idx] = item.copyWith(
      sellPrice: validPrice,
      discountAmount: newDiscount,
    );
    state = state.copyWith(items: updated);
  }

  /// Update the discount amount for a specific item and recalculate its sell price.
  void updateItemDiscount(String productId, double discount) {
    final idx = state.items.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;
    final updated = List<CartItem>.from(state.items);
    final item = updated[idx];
    final validDiscount = discount.clamp(0, item.product.referencePrice).toDouble();
    final newPrice = item.product.referencePrice - validDiscount;
    updated[idx] = item.copyWith(
      sellPrice: newPrice,
      discountAmount: validDiscount,
    );
    state = state.copyWith(items: updated);
  }

  void setDiscount(double discount) {
    state = state.copyWith(
        discount: discount.clamp(0.0, state.totalAmount));
  }

  void setCustomer(CustomerModel? customer) {
    state = state.copyWith(selectedCustomer: customer);
  }

  void clear() {
    state = const CartState();
  }

  void _updateQty(String productId, int delta) {
    final idx = state.items.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;
    final updated = List<CartItem>.from(state.items);
    final item = updated[idx];
    final newQty = item.quantity + delta;
    if (newQty > item.product.stockQuantity) return;
    updated[idx] = item.copyWith(quantity: newQty);
    state = state.copyWith(items: updated);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);

// ─── Checkout Notifier ────────────────────────────────────────────────────────

class CheckoutNotifier extends StateNotifier<AsyncValue<String?>> {
  final SalesRepository _salesRepo;
  final Ref _ref;

  CheckoutNotifier(this._salesRepo, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> checkout({required double amountPaid}) async {
    final cart = _ref.read(cartProvider);
    if (cart.isEmpty) return false;

    final user = _ref.read(currentUserProvider);
    if (user == null) return false;

    state = const AsyncValue.loading();

    state = const AsyncValue.loading();

    try {
      final invoiceId = await _salesRepo.checkout(
        customerId: cart.selectedCustomer?.id,
        workerId: user.id,
        items: cart.items,
        discount: cart.discount,
        amountPaid: amountPaid,
      );
      
      state = AsyncValue.data(invoiceId);
      _ref.read(cartProvider.notifier).clear();
      return true;
    } catch (e, st) {
      debugPrint('🚨 CRITICAL CHECKOUT ERROR 🚨');
      debugPrint('Error Details: $e');
      debugPrint('Stacktrace: $st');
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, AsyncValue<String?>>((ref) {
  return CheckoutNotifier(ref.watch(salesRepositoryProvider), ref);
});

// ─── Realtime Streams ─────────────────────────────────────────────────────────

final recentSalesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('sales_invoices')
      .stream(primaryKey: ['id'])
      .order('invoice_date', ascending: false)
      .limit(5);
});

final todayRevenueStreamProvider = StreamProvider<double>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('sales_invoices')
      .stream(primaryKey: ['id'])
      .map((invoices) {
        final now = DateTime.now();
        return invoices.where((inv) {
          final date = DateTime.tryParse(inv['invoice_date']?.toString() ?? '');
          if (date == null) return false;
          final local = date.toLocal();
          return local.year == now.year && local.month == now.month && local.day == now.day;
        }).fold(0.0, (sum, inv) => sum + (double.tryParse(inv['final_amount']?.toString() ?? '0') ?? 0.0));
      });
});

// ─── Keyboard Shortcut Providers ──────────────────────────────────────────────


final searchFocusRequestProvider = StateProvider<int>((ref) => 0);
final clientFocusRequestProvider = StateProvider<int>((ref) => 0);
final checkoutRequestProvider = StateProvider<int>((ref) => 0);
final helpDialogRequestProvider = StateProvider<int>((ref) => 0);