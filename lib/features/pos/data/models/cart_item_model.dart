import 'package:laidani_repair/features/pos/data/models/product_model.dart';

/// A single line item in the POS cart.
class CartItem {
  final ProductModel product;
  final int quantity;
  final double sellPrice; // editable per item (can differ from reference_price)

  const CartItem({
    required this.product,
    required this.quantity,
    required this.sellPrice,
  });

  double get subtotal => quantity * sellPrice;

  CartItem copyWith({int? quantity, double? sellPrice}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      sellPrice: sellPrice ?? this.sellPrice,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem && product.id == other.product.id;

  @override
  int get hashCode => product.id.hashCode;
}
