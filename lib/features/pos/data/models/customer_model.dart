/// Dart model for the `customers` table.
/// Used across POS (customer selection) and Clients screen.
class CustomerModel {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final double totalDebt;
  final bool isRegistered;

  const CustomerModel({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    required this.totalDebt,
    required this.isRegistered,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'زبون عابر',
      phoneNumber: json['phone_number'] as String?,
      totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0.0,
      isRegistered: json['is_registered'] as bool? ?? false,
    );
  }

  bool get hasDebt => totalDebt > 0;

  /// Display label for the customer selector.
  String get displayLabel =>
      phoneNumber != null ? '$fullName — $phoneNumber' : fullName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CustomerModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
