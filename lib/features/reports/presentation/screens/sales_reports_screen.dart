import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/core/providers/shortcuts_provider.dart';
import 'package:laidani_repair/core/utils/csv_export.dart';
import 'package:laidani_repair/features/reports/presentation/widgets/report_filter_bar.dart';
import 'package:laidani_repair/features/reports/presentation/widgets/report_summary_card.dart';
import 'package:laidani_repair/features/reports/presentation/widgets/report_invoice_list.dart';
import 'package:laidani_repair/features/reports/presentation/providers/reports_provider.dart';

class SalesReportsScreen extends ConsumerWidget {
  const SalesReportsScreen({super.key});

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final client = ref.read(supabaseClientProvider);
    final filter = ref.read(reportFilterProvider);

    var q = client.from('sales_invoices')
        .select('''
          id, total_amount, discount, final_amount, invoice_date,
          customer:customers(full_name, phone_number),
          worker:profiles(full_name)
        ''');

    q = q.gte('invoice_date', filter.startDate.toUtc().toIso8601String());
    q = q.lte('invoice_date', filter.endDate.toUtc().toIso8601String());
    if (filter.workerId != null) {
      q = q.eq('worker_id', filter.workerId!);
    }
    if (filter.customerId != null) {
      q = q.eq('customer_id', filter.customerId!);
    }

    final invoices = await q.order('invoice_date', ascending: false);

    final headers = ['ID', 'Date', 'Client', 'Téléphone', 'Employé', 'Total', 'Remise', 'Final'];
    final rows = invoices.map((inv) => [
      inv['id'],
      inv['invoice_date']?.toString() ?? '',
      inv['customer'] is Map ? (inv['customer'] as Map)['full_name'] ?? '' : '',
      inv['customer'] is Map ? (inv['customer'] as Map)['phone_number'] ?? '' : '',
      inv['worker'] is Map ? (inv['worker'] as Map)['full_name'] ?? '' : '',
      (inv['total_amount'] as num?)?.toDouble() ?? 0,
      (inv['discount'] as num?)?.toDouble() ?? 0,
      (inv['final_amount'] as num?)?.toDouble() ?? 0,
    ]).toList();

    final csv = await exportToCsv(headers: headers, rows: rows);
    await shareCsv(context, csv, 'ventes_${DateTime.now().millisecondsSinceEpoch}.csv');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(exportCsvRequestProvider, (_, __) {
      _exportCsv(context, ref);
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('RAPPORTS DES VENTES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exporter CSV',
            onPressed: () => _exportCsv(context, ref),
          ),
        ],
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
