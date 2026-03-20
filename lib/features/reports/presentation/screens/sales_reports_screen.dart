import 'package:flutter/material.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/features/reports/presentation/widgets/report_filter_bar.dart';
import 'package:laidani_repair/features/reports/presentation/widgets/report_summary_card.dart';
import 'package:laidani_repair/features/reports/presentation/widgets/report_invoice_list.dart';

class SalesReportsScreen extends StatelessWidget {
  const SalesReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('RAPPORTS DES VENTES'),
      ),
      body: const Column(
        children: [
          ReportFilterBar(),
          ReportSummaryCard(),
          Expanded(
            child: ReportInvoiceList(),
          ),
        ],
      ),
    );
  }
}
