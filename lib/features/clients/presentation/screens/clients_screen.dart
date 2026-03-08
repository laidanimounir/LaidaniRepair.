import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _customersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client.from('customers').select().eq('is_registered', true).order('full_name');
});

final _paymentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, customerId) async {
    final client = ref.watch(supabaseClientProvider);
    return await client
        .from('customer_payments')
        .select('id, amount_paid, payment_date, profiles(full_name)')
        .eq('customer_id', customerId)
        .order('payment_date', ascending: false)
        .limit(20);
  },
);

// ─── Clients Screen ───────────────────────────────────────────────────────────

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(_customersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainer,
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A50))),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Clients & Dettes',
                    style: TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w700, fontSize: 18)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.onSurfaceMuted, size: 18),
                  onPressed: () => ref.invalidate(_customersProvider),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error))),
              data: (customers) {
                if (customers.isEmpty) {
                  return const Center(
                    child: Text('Aucun client enregistré', style: TextStyle(color: AppTheme.onSurfaceMuted)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = customers[i];
                    final debt = (c['total_debt'] as num?)?.toDouble() ?? 0.0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primary.withOpacity(0.15),
                        child: Text(
                          (c['full_name'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(c['full_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.onBackground)),
                      subtitle: Text(c['phone_number'] ?? '—',
                          style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                      trailing: debt > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                              ),
                              child: Text('${debt.toStringAsFixed(0)} DA',
                                  style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
                            )
                          : const Text('0 DA',
                              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                      onTap: () => _showCustomerDetail(context, ref, c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context, ref),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}

// ─── Customer Detail Bottom Sheet ─────────────────────────────────────────────

void _showCustomerDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> customer) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceContainer,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: _CustomerDetailPanel(customer: customer),
    ),
  );
}

class _CustomerDetailPanel extends ConsumerWidget {
  final Map<String, dynamic> customer;
  const _CustomerDetailPanel({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debt = (customer['total_debt'] as num?)?.toDouble() ?? 0.0;
    final paymentsAsync = ref.watch(_paymentsProvider(customer['id'] as String));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withOpacity(0.2),
                child: Text(
                  (customer['full_name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w700, fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer['full_name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.onBackground)),
                    Text(customer['phone_number'] ?? '—', style: const TextStyle(color: AppTheme.onSurfaceMuted)),
                  ],
                ),
              ),
              // Debt badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: debt > 0 ? AppTheme.error.withOpacity(0.15) : Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Dette: ${debt.toStringAsFixed(0)} DA',
                  style: TextStyle(
                    color: debt > 0 ? AppTheme.error : Colors.greenAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Pay debt button
          if (debt > 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showPayDebtDialog(context, ref, customer),
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('Enregistrer un paiement'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, foregroundColor: Colors.black87),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Historique des paiements', style: TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: paymentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: AppTheme.error)),
              data: (payments) {
                if (payments.isEmpty) {
                  return const Center(child: Text('Aucun paiement', style: TextStyle(color: AppTheme.onSurfaceMuted)));
                }
                return ListView.separated(
                  itemCount: payments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = payments[i];
                    final date = DateTime.tryParse(p['payment_date'] ?? '')?.toString().substring(0, 16) ?? '';
                    return ListTile(
                      leading: const Icon(Icons.payments_outlined, color: Colors.greenAccent, size: 20),
                      title: Text('${(p['amount_paid'] as num).toStringAsFixed(0)} DA',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700)),
                      subtitle: Text('$date • ${p['profiles']?['full_name'] ?? ''}',
                          style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Customer Dialog ──────────────────────────────────────────────────────

void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nouveau client'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom complet')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            final client = ref.read(supabaseClientProvider);
            await client.from('customers').insert({
              'full_name': nameCtrl.text.trim(),
              'phone_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
              'is_registered': true,
            });
            ref.invalidate(_customersProvider);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Ajouter'),
        ),
      ],
    ),
  );
}

// ─── Pay Debt Dialog ──────────────────────────────────────────────────────────

void _showPayDebtDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> customer) {
  final amountCtrl = TextEditingController();
  final debt = (customer['total_debt'] as num?)?.toDouble() ?? 0.0;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Paiement de dette'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Client: ${customer['full_name']}', style: const TextStyle(color: AppTheme.onBackground)),
            const SizedBox(height: 4),
            Text('Dette actuelle: ${debt.toStringAsFixed(0)} DA',
                style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: const InputDecoration(labelText: 'Montant reçu', suffixText: 'DA'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            final client = ref.read(supabaseClientProvider);
            final user = Supabase.instance.client.auth.currentUser;
            await client.from('customer_payments').insert({
              'customer_id': customer['id'],
              'worker_id': user?.id,
              'amount_paid': double.tryParse(amountCtrl.text) ?? 0,
            });
            ref.invalidate(_customersProvider);
            ref.invalidate(_paymentsProvider(customer['id'] as String));
            if (ctx.mounted) Navigator.pop(ctx);
            if (ctx.mounted) Navigator.pop(ctx); // close bottom sheet too
          },
          child: const Text('Confirmer le paiement'),
        ),
      ],
    ),
  );
}
