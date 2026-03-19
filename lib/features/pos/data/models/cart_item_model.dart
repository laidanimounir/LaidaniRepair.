import 'package:laidani_repair/features/pos/data/models/product_model.dart';

/// A single line item in the POS cart.
class CartItem {
  final ProductModel product;
  final int quantity;
  final double sellPrice; // editable custom price
  final double discountAmount; // remise

  const CartItem({
    required this.product,
    required this.quantity,
    required this.sellPrice,
    this.discountAmount = 0.0,
  });

  double get subtotal => quantity * sellPrice;

  CartItem copyWith({int? quantity, double? sellPrice, double? discountAmount}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      sellPrice: sellPrice ?? this.sellPrice,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem && product.id == other.product.id;

  @override
  int get hashCode => product.id.hashCode;
}
