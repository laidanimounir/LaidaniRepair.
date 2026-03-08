/// Dart model for the `categories` table.
class CategoryModel {
  final int id;
  final String categoryName;

  const CategoryModel({required this.id, required this.categoryName});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      categoryName: json['category_name'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CategoryModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
