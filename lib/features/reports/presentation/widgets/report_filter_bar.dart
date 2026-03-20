import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/features/reports/presentation/providers/reports_provider.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

class ReportFilterBar extends ConsumerWidget {
  const ReportFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A50))),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildDatesChips(context, ref, filter),
          const SizedBox(width: 8),
          _buildWorkerDropdown(ref, filter),
          const SizedBox(width: 8),
          _buildCustomerDropdown(ref, filter),
        ],
      ),
    );
  }

  Widget _buildDatesChips(BuildContext context, WidgetRef ref, ReportFilter filter) {
    final periods = ["Aujourd'hui", "Semaine", "Mois", "Total", "Personnalisé"];
    
    return Wrap(
      spacing: 8,
      children: periods.map((period) {
        final isSelected = filter.periodLabel == period;
        return ChoiceChip(
          label: Text(period),
          selected: isSelected,
          onSelected: (selected) {
            if (!selected) return;
            if (period == "Personnalisé") {
              _showCustomDateRange(context, ref);
            } else {
              _applyPreset(ref, period);
            }
          },
          selectedColor: const Color(0xFF2E2B6E),
          backgroundColor: AppTheme.surfaceContainerHigh,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF2A2A50)),
          ),
        );
      }).toList(),
    );
  }

  void _applyPreset(WidgetRef ref, String period) {
    final nowUtc = DateTime.now().toUtc();
    DateTime start;
    DateTime end = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 23, 59, 59);

    if (period == "Aujourd'hui") {
      start = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    } else if (period == "Semaine") {
      start = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day).subtract(Duration(days: nowUtc.weekday - 1));
    } else if (period == "Mois") {
      start = DateTime.utc(nowUtc.year, nowUtc.month, 1);
    } else { // Total
      start = DateTime.utc(2000, 1, 1); 
    }

    ref.read(reportFilterProvider.notifier).updateFilter(
      startDate: start,
      endDate: end,
      periodLabel: period,
    );
  }

  Future<void> _showCustomDateRange(BuildContext context, WidgetRef ref) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme,
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(reportFilterProvider.notifier).updateFilter(
        startDate: DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
        endDate: DateTime.utc(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        periodLabel: "Personnalisé",
      );
    }
  }

  Widget _buildWorkerDropdown(WidgetRef ref, ReportFilter filter) {
    final client = ref.watch(supabaseClientProvider);
    return FutureBuilder<List<dynamic>>(
      future: client.from('profiles').select('id, full_name'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
          return Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2A50)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: null,
                hint: const Text('Tous les employés', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
                dropdownColor: AppTheme.surfaceContainerHigh,
                items: const [
                  DropdownMenuItem(value: null, child: Text("Tous les employés", style: TextStyle(color: AppTheme.onSurface, fontSize: 13))),
                ],
                onChanged: null,
              ),
            ),
          );
        }
        final workers = snapshot.data ?? [];
        final workerIds = [null, ...workers.map((w) => w['id'] as String?)];
        final safeWorkerId = workerIds.contains(filter.workerId) ? filter.workerId : null;
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A50)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: safeWorkerId,
              hint: const Text('Tous les employés', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
              dropdownColor: AppTheme.surfaceContainerHigh,
              items: [
                const DropdownMenuItem(value: null, child: Text("Tous les employés", style: TextStyle(color: AppTheme.onSurface, fontSize: 13))),
                ...workers.map((w) => DropdownMenuItem(
                      value: w['id'],
                      child: Text(w['full_name'] ?? 'Employé', style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
                    ))
              ],
              onChanged: (val) {
                ref.read(reportFilterProvider.notifier).updateFilter(workerId: val);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerDropdown(WidgetRef ref, ReportFilter filter) {
    final client = ref.watch(supabaseClientProvider);
    return FutureBuilder<List<dynamic>>(
      future: client.from('customers').select('id, full_name').order('full_name'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
          return Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2A50)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: null,
                hint: const Text('Tous les clients', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
                dropdownColor: AppTheme.surfaceContainerHigh,
                items: const [
                  DropdownMenuItem(value: null, child: Text("Tous les clients", style: TextStyle(color: AppTheme.onSurface, fontSize: 13))),
                ],
                onChanged: null,
              ),
            ),
          );
        }
        final customers = snapshot.data ?? [];
        final customerIds = [null, ...customers.map((c) => c['id'] as String?)];
        final safeCustomerId = customerIds.contains(filter.customerId) ? filter.customerId : null;
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A50)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: safeCustomerId,
              hint: const Text('Tous les clients', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
              dropdownColor: AppTheme.surfaceContainerHigh,
              items: [
                const DropdownMenuItem(value: null, child: Text("Tous les clients", style: TextStyle(color: AppTheme.onSurface, fontSize: 13))),
                ...customers.map((c) => DropdownMenuItem(
                      value: c['id'],
                      child: Text(c['full_name'] ?? 'Client anonyme', style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
                    ))
              ],
              onChanged: (val) {
                ref.read(reportFilterProvider.notifier).updateFilter(customerId: val);
              },
            ),
          ),
        );
      },
    );
  }
}
