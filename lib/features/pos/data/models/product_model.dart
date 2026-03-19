class ProductModel {
  final String id;
  final int? categoryId;
  final String productName;
  final String? barcode;
  final int stockQuantity;
  final double referencePrice;

  const ProductModel({
    required this.id,
    this.categoryId,
    required this.productName,
    this.barcode,
    required this.stockQuantity,
    required this.referencePrice,
  });

  bool get inStock => stockQuantity > 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as int?,
      productName: json['product_name'] as String? ?? '',
      barcode: json['barcode'] as String?,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      referencePrice: (json['reference_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ProductModel copyWith({
    String? id,
    int? categoryId,
    String? productName,
    String? barcode,
    int? stockQuantity,
    double? referencePrice,
  }) {
    return ProductModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      referencePrice: referencePrice ?? this.referencePrice,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ProductModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}