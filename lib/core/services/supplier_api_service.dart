abstract interface class SupplierApiService {
  Future<Map<String, dynamic>> searchPart(String query, String supplierId);
  Future<List<Map<String, dynamic>>> getCatalog(String supplierId, {int page = 1, int limit = 20});
  Future<Map<String, dynamic>> placeOrder({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    String? shippingAddress,
  });
  Future<Map<String, dynamic>> checkOrderStatus(String orderId);
  Future<List<Map<String, dynamic>>> getAvailableSuppliers();
}

final List<Map<String, dynamic>> mockSuppliers = [
  {'id': '1', 'name': 'TechParts Algérie', 'phone': '+213 23 45 67 89', 'website': 'www.techparts.dz'},
  {'id': '2', 'name': 'MobilePro Distribution', 'phone': '+213 21 98 76 54', 'website': 'www.mobilepro.dz'},
  {'id': '3', 'name': 'ElectroPlus', 'phone': '+213 27 12 34 56', 'website': 'www.electroplus.dz'},
];

final List<Map<String, dynamic>> mockCatalog = [
  {'id': 'c1', 'name': 'Écran iPhone 14', 'brand': 'Apple', 'price': 8500, 'stock': 50, 'supplierId': '1'},
  {'id': 'c2', 'name': 'Batterie Samsung S23', 'brand': 'Samsung', 'price': 3500, 'stock': 30, 'supplierId': '1'},
  {'id': 'c3', 'name': 'Connecteur de charge USB-C', 'brand': 'Generic', 'price': 800, 'stock': 200, 'supplierId': '2'},
  {'id': 'c4', 'name': 'Vitre tactile Huawei P40', 'brand': 'Huawei', 'price': 4200, 'stock': 25, 'supplierId': '2'},
  {'id': 'c5', 'name': 'Nappe LCD iPhone 13', 'brand': 'Apple', 'price': 6200, 'stock': 40, 'supplierId': '3'},
  {'id': 'c6', 'name': 'Haut-parleur Xiaomi Redmi Note', 'brand': 'Xiaomi', 'price': 1200, 'stock': 60, 'supplierId': '3'},
  {'id': 'c7', 'name': 'Coque arrière Samsung A54', 'brand': 'Samsung', 'price': 1800, 'stock': 35, 'supplierId': '1'},
  {'id': 'c8', 'name': 'Caméra arrière iPhone 12', 'brand': 'Apple', 'price': 7500, 'stock': 15, 'supplierId': '2'},
];
