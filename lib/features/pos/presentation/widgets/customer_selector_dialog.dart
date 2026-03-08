import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/features/pos/data/models/customer_model.dart';
import 'package:laidani_repair/features/pos/data/repositories/customer_repository.dart';

/// A dialog for selecting a registered customer for the current sale.
/// Returns the selected [CustomerModel], or null if cancelled.
class CustomerSelectorDialog extends ConsumerStatefulWidget {
  const CustomerSelectorDialog({super.key});

  @override
  ConsumerState<CustomerSelectorDialog> createState() =>
      _CustomerSelectorDialogState();
}

class _CustomerSelectorDialogState
    extends ConsumerState<CustomerSelectorDialog> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.people, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sélectionner un client',
                      style: TextStyle(
                          color: AppTheme.onBackground,
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close,
                        color: AppTheme.onSurfaceMuted),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher par nom ou téléphone...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: 8),

            // Anonymous option
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_outline,
                    color: AppTheme.onSurfaceMuted, size: 20),
              ),
              title: const Text('Client anonyme (زبون عابر)',
                  style: TextStyle(color: AppTheme.onSurface)),
              subtitle: const Text('Aucun suivi de dette',
                  style: TextStyle(
                      color: AppTheme.onSurfaceMuted, fontSize: 11)),
              onTap: () => Navigator.pop(context, null),
            ),
            const Divider(height: 1),

            // Customers list
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Erreur: $e',
                        style: const TextStyle(color: AppTheme.error))),
                data: (customers) {
                  final filtered = _search.isEmpty
                      ? customers
                      : customers
                          .where((c) =>
                              c.fullName
                                  .toLowerCase()
                                  .contains(_search.toLowerCase()) ||
                              (c.phoneNumber ?? '')
                                  .contains(_search))
                          .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Aucun client trouvé',
                          style: TextStyle(
                              color: AppTheme.onSurfaceMuted)),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 60),
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primary.withOpacity(0.15),
                          radius: 18,
                          child: Text(
                            c.fullName.isNotEmpty
                                ? c.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.primaryLight,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(c.fullName,
                            style: const TextStyle(
                                color: AppTheme.onBackground,
                                fontWeight: FontWeight.w600)),
                        subtitle: c.phoneNumber != null
                            ? Text(c.phoneNumber!,
                                style: const TextStyle(
                                    color: AppTheme.onSurfaceMuted,
                                    fontSize: 12))
                            : null,
                        trailing: c.hasDebt
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Dette: ${c.totalDebt.toStringAsFixed(0)} DA',
                                  style: const TextStyle(
                                      color: AppTheme.error,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              )
                            : null,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
