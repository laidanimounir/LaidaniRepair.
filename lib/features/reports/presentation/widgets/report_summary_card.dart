import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/features/reports/presentation/providers/reports_provider.dart';

class ReportSummaryCard extends ConsumerWidget {
  const ReportSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reportSummaryProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildCard('Total Ventes', summary.totalRevenue, AppTheme.success, Icons.arrow_upward),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildCard('Total Remises', summary.totalDiscount, AppTheme.error, Icons.arrow_downward),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildCard('Net', summary.netRevenue, const Color(0xFF00E5FF), Icons.account_balance_wallet, isNeon: true, subtitle: '${summary.invoiceCount} Facture(s)'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, double amount, Color color, IconData icon, {bool isNeon = false, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNeon ? color.withOpacity(0.5) : const Color(0xFF2A2A50)),
        boxShadow: isNeon ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: AppTheme.onSurfaceMuted, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${amount.toStringAsFixed(2)} DA',
            style: TextStyle(
              color: isNeon ? color : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }
}
