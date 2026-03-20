import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/features/reports/data/repositories/reports_repository.dart';

const _sentinel = Object();

class ReportFilter {
  final DateTime startDate;
  final DateTime endDate;
  final String? workerId;
  final String? customerId;
  final String periodLabel;

  ReportFilter({
    required this.startDate,
    required this.endDate,
    this.workerId,
    this.customerId,
    required this.periodLabel,
  });

  ReportFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    Object? workerId = _sentinel,
    Object? customerId = _sentinel,
    String? periodLabel,
  }) {
    return ReportFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      workerId: workerId == _sentinel ? this.workerId : workerId as String?,
      customerId: customerId == _sentinel ? this.customerId : customerId as String?,
      periodLabel: periodLabel ?? this.periodLabel,
    );
  }
}

class ReportSummary {
  final double totalRevenue;
  final double totalDiscount;
  final double netRevenue;
  final int invoiceCount;

  ReportSummary({
    required this.totalRevenue,
    required this.totalDiscount,
    required this.netRevenue,
    required this.invoiceCount,
  });
}

class ReportFilterNotifier extends StateNotifier<ReportFilter> {
  ReportFilterNotifier()
      : super(ReportFilter(
          startDate: DateTime.utc(DateTime.now().toUtc().year, DateTime.now().toUtc().month, DateTime.now().toUtc().day),
          endDate: DateTime.utc(DateTime.now().toUtc().year, DateTime.now().toUtc().month, DateTime.now().toUtc().day, 23, 59, 59),
          periodLabel: "Aujourd'hui",
        ));

  void updateFilter({
    DateTime? startDate,
    DateTime? endDate,
    String? workerId,
    String? customerId,
    String? periodLabel,
  }) {
    state = state.copyWith(
      startDate: startDate,
      endDate: endDate,
      workerId: workerId,
      customerId: customerId,
      periodLabel: periodLabel,
    );
  }
}

final reportFilterProvider = StateNotifierProvider<ReportFilterNotifier, ReportFilter>((ref) {
  return ReportFilterNotifier();
});

final salesReportProvider = AutoDisposeFutureProvider<List<Map<String, dynamic>>>((ref) async {
  final filter = ref.watch(reportFilterProvider);
  final repo = ref.watch(reportsRepositoryProvider);

  return repo.fetchSalesReport(
    startDate: filter.startDate,
    endDate: filter.endDate,
    workerId: filter.workerId,
    customerId: filter.customerId,
  );
});

final reportSummaryProvider = Provider<ReportSummary>((ref) {
  final asyncReport = ref.watch(salesReportProvider);

  return asyncReport.maybeWhen(
    data: (invoices) {
      double totalRev = 0;
      double totalDisc = 0;
      double netRev = 0;

      for (var inv in invoices) {
        totalRev += (double.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0);
        totalDisc += (double.tryParse(inv['discount']?.toString() ?? '0') ?? 0);
        netRev += (double.tryParse(inv['final_amount']?.toString() ?? '0') ?? 0);
      }

      return ReportSummary(
        totalRevenue: totalRev,
        totalDiscount: totalDisc,
        netRevenue: netRev,
        invoiceCount: invoices.length,
      );
    },
    orElse: () => ReportSummary(
      totalRevenue: 0,
      totalDiscount: 0,
      netRevenue: 0,
      invoiceCount: 0,
    ),
  );
});
