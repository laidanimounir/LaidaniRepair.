import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/features/reports/presentation/providers/reports_provider.dart';

class ReportInvoiceList extends ConsumerWidget {
  const ReportInvoiceList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(salesReportProvider);

    return reportAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            const Text('Erreur de chargement', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(salesReportProvider),
              child: const Text('Réessayer'),
            )
          ],
        ),
      ),
      data: (invoices) {
        if (invoices.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, color: AppTheme.onSurfaceMuted, size: 64),
                SizedBox(height: 16),
                Text('Aucune vente trouvée', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final inv = invoices[index];
            return _buildInvoiceCard(inv);
          },
        );
      },
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final dateStr = inv['invoice_date']?.toString() ?? '';
    final date = DateTime.tryParse(dateStr)?.toLocal();
    final formattedDate = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : '';
    
    final customer = inv['customers']?['full_name'] ?? 'Client anonyme';
    final worker = inv['profiles']?['full_name'] ?? 'Employé inconnu';
    
    final discount = double.tryParse(inv['discount']?.toString() ?? '0') ?? 0;
    final net = double.tryParse(inv['final_amount']?.toString() ?? '0') ?? 0;
    
    final items = inv['sales_items'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: AppTheme.onSurfaceMuted,
          iconColor: AppTheme.primaryLight,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formattedDate, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(customer, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (discount > 0)
                    Text('-${discount.toStringAsFixed(2)} DA', style: const TextStyle(color: AppTheme.error, fontSize: 12, decoration: TextDecoration.lineThrough)),
                  Text('${net.toStringAsFixed(2)} DA', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              )
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.top(8.0),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 14, color: AppTheme.primaryLight),
                const SizedBox(width: 4),
                Text('${items.length} article(s)', style: const TextStyle(color: AppTheme.primaryLight, fontSize: 12)),
                const SizedBox(width: 16),
                const Icon(Icons.person_outline, size: 14, color: AppTheme.onSurfaceMuted),
                const SizedBox(width: 4),
                Text(worker, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: Column(
                children: items.map((item) {
                  final qty = item['quantity']?.toString() ?? '1';
                  final price = double.tryParse(item['sell_price']?.toString() ?? '0') ?? 0;
                  final pname = item['products']?['product_name'] ?? 'Produit';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${qty}x $pname', style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
                        ),
                        Text('${(price * int.parse(qty)).toStringAsFixed(2)} DA', style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }
}
