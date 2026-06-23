import 'package:laidani_repair/features/pos/data/models/product_model.dart';

/// A single line item in the POS cart.
class CartItem {
  final ProductModel product;
  final int quantity;
  final double sellPrice; // editable custom price
  final double discountAmount; // remise
  final double costPrice; // unit purchase cost for profit tracking

  const CartItem({
    required this.product,
    required this.quantity,
    required this.sellPrice,
    this.discountAmount = 0.0,
    this.costPrice = 0.0,
  });

  double get subtotal => quantity * sellPrice;

  double get cost => quantity * costPrice;

  double get profit => subtotal - cost;

  CartItem copyWith({
    int? quantity,
    double? sellPrice,
    double? discountAmount,
    double? costPrice,
  }) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      sellPrice: sellPrice ?? this.sellPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      costPrice: costPrice ?? this.costPrice,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem && product.id == other.product.id;

  @override
  int get hashCode => product.id.hashCode;
}
