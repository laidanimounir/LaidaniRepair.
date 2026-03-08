import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/features/pos/data/models/cart_item_model.dart';
import 'package:laidani_repair/features/pos/data/models/customer_model.dart';
import 'package:laidani_repair/features/pos/data/models/product_model.dart';
import 'package:laidani_repair/features/pos/data/repositories/sales_repository.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';

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

  /// Update the sell price for a specific cart item.
  void updateSellPrice(String productId, double price) {
    final idx = state.items.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;
    final updated = List<CartItem>.from(state.items);
    updated[idx] = updated[idx].copyWith(sellPrice: price.clamp(0, double.infinity));
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

    final result = await AsyncValue.guard(() => _salesRepo.checkout(
          customerId: cart.selectedCustomer?.id,
          workerId: user.id,
          items: cart.items,
          discount: cart.discount,
          amountPaid: amountPaid,
        ));

    state = result;

    if (result.hasValue && result.value != null) {
      _ref.read(cartProvider.notifier).clear();
      return true;
    }
    return false;
  }
}

final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, AsyncValue<String?>>((ref) {
  return CheckoutNotifier(ref.watch(salesRepositoryProvider), ref);
});
