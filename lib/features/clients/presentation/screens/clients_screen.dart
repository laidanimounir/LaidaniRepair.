import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/core/utils/csv_export.dart';
import 'package:laidani_repair/core/services/groq_service.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _customersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('customers')
      .stream(primaryKey: ['id'])
      .eq('is_registered', true)
      .order('total_debt', ascending: false);
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

final _customerInvoicesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, customerId) async {
    final client = ref.watch(supabaseClientProvider);
    return await client.from('sales_invoices')
        .select('id, total_amount, final_amount, discount, invoice_date')
        .eq('customer_id', customerId)
        .order('invoice_date', ascending: false)
        .limit(20);
  },
);

final _customerRepairsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, customerId) async {
    final client = ref.watch(supabaseClientProvider);
    return await client.from('repair_tickets')
        .select('id, device_name, status, estimated_cost, final_cost, created_at, paid_amount')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(20);
  },
);

// ─── Clients Screen ───────────────────────────────────────────────────────────

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(_customersStreamProvider);

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
                  icon: const Icon(Icons.file_download, color: AppTheme.onSurfaceMuted, size: 18),
                  tooltip: 'Exporter CSV',
                  onPressed: () => _exportCustomersCsv(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.onSurfaceMuted, size: 18),
                  onPressed: () => ref.invalidate(_customersStreamProvider),
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
}

Future<void> _analyzeCustomerIA(BuildContext context, WidgetRef ref, Map<String, dynamic> customer) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      backgroundColor: AppTheme.surfaceContainer,
      content: Row(children: [CircularProgressIndicator(color: AppTheme.primary), SizedBox(width: 16), Text('Analyse client IA...', style: TextStyle(color: Colors.white))]),
    ),
  );

  try {
    final client = ref.read(supabaseClientProvider);
    final customerId = customer['id'] as String;

    final purchaseData = await client.from('sales_invoices').select('total_amount, invoice_date').eq('customer_id', customerId).limit(20);
    final repairData = await client.from('repair_tickets').select('estimated_cost, status, created_at').eq('customer_id', customerId).limit(20);
    final paymentsData = await client.from('customer_payments').select('amount_paid, payment_date').eq('customer_id', customerId).limit(20);

    final totalPaid = paymentsData.fold(0.0, (sum, p) => sum + ((p['amount_paid'] as num?)?.toDouble() ?? 0));
    final totalDebt = (customer['total_debt'] as num?)?.toDouble() ?? 0;
    final paymentBehavior = totalPaid > 0
        ? (totalDebt == 0 ? 'Toujours payé' : 'Paiements partiels')
        : 'Aucun paiement';
    final loyaltyPoints = (customer['loyalty_points'] as num?)?.toInt() ?? 0;

    final result = await GroqService().analyzeCustomer(
      purchaseHistory: List<Map<String, dynamic>>.from(purchaseData),
      repairHistory: List<Map<String, dynamic>>.from(repairData),
      paymentBehavior: paymentBehavior,
      loyaltyPoints: loyaltyPoints,
    );

    if (!context.mounted) return;
    Navigator.pop(context);

    final valueScore = (result['valueScore'] as num?)?.toDouble() ?? 0;
    final churnRisk = result['churnRisk']?.toString() ?? 'Moyen';
    final personalizedOffer = result['personalizedOffer']?.toString() ?? '';
    final bestContactTime = result['bestContactTime']?.toString() ?? '';

    final riskColor = churnRisk == 'Élevé'
        ? Colors.redAccent
        : churnRisk == 'Moyen'
            ? Colors.orangeAccent
            : Colors.greenAccent;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.psychology, color: Color(0xFF9C27B0)), SizedBox(width: 8), Text('Analyse Client IA', style: TextStyle(color: Colors.white))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${customer['full_name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        const Text('Score de valeur', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('${valueScore.toStringAsFixed(0)}/100', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: valueScore / 100, backgroundColor: Colors.white12, color: valueScore > 70 ? Colors.greenAccent : valueScore > 40 ? Colors.orangeAccent : Colors.redAccent),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: riskColor.withOpacity(0.3))),
                    child: Column(
                      children: [
                        const Text('Risque de départ', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(churnRisk, style: TextStyle(color: riskColor, fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (personalizedOffer.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Offre personnalisée', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(personalizedOffer, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppTheme.onSurfaceMuted),
                const SizedBox(width: 4),
                Text('Meilleur moment de contact: ', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                Text(bestContactTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            const Row(children: [Icon(Icons.info_outline, size: 12, color: AppTheme.onSurfaceMuted), SizedBox(width: 4), Expanded(child: Text('Analyse générée par IA. À titre indicatif uniquement.', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 10, fontStyle: FontStyle.italic)))]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur IA: $e'), backgroundColor: Colors.redAccent));
    }
  }
}
}

// ─── CSV Export ────────────────────────────────────────────────────────────────

Future<void> _exportCustomersCsv(BuildContext context, WidgetRef ref) async {
  final client = ref.read(supabaseClientProvider);
  final customers = await client
      .from('customers')
      .select('full_name, phone_number, total_debt, created_at')
      .eq('is_registered', true)
      .order('total_debt', ascending: false);

  final headers = ['Nom', 'Téléphone', 'Dette', 'Date inscription'];
  final rows = customers.map((c) => [
    c['full_name'] ?? '',
    c['phone_number'] ?? '',
    (c['total_debt'] as num?)?.toDouble() ?? 0,
    c['created_at']?.toString() ?? '',
  ]).toList();

  final csv = await exportToCsv(headers: headers, rows: rows);
  await shareCsv(context, csv, 'clients_${DateTime.now().millisecondsSinceEpoch}.csv');
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
    final invoicesAsync = ref.watch(_customerInvoicesProvider(customer['id'] as String));
    final repairsAsync = ref.watch(_customerRepairsProvider(customer['id'] as String));

    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Points: ${(customer['loyalty_points'] as num?)?.toInt() ?? 0} pts',
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (ref.watch(isOwnerProvider))
                  ElevatedButton.icon(
                    onPressed: () => _analyzeCustomerIA(context, ref, customer),
                    icon: const Icon(Icons.psychology, size: 16),
                    label: const Text('Analyse IA', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0).withOpacity(0.15),
                      foregroundColor: const Color(0xFF9C27B0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
            const TabBar(
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.onSurfaceMuted,
              indicatorColor: AppTheme.primary,
              tabs: [
                Tab(text: 'Achats'),
                Tab(text: 'Réparations'),
                Tab(text: 'Paiements'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _listView(invoicesAsync, 'Aucun achat', (i) {
                    final date = DateTime.tryParse(i['invoice_date'] ?? '')?.toString().substring(0, 10) ?? '';
                    final total = (i['final_amount'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.receipt_outlined, color: Colors.amber, size: 20),
                      title: Text('${total.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(date, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                    );
                  }),
                  _listView(repairsAsync, 'Aucune réparation', (r) {
                    final date = DateTime.tryParse(r['created_at'] ?? '')?.toString().substring(0, 10) ?? '';
                    final cost = (r['final_cost'] as num?)?.toDouble() ?? (r['estimated_cost'] as num?)?.toDouble() ?? 0;
                    final paid = (r['paid_amount'] as num?)?.toDouble() ?? 0;
                    final status = r['status'] ?? '';
                    return ListTile(
                      leading: const Icon(Icons.build_circle_outlined, color: AppTheme.primary, size: 20),
                      title: Text(r['device_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text('$date • $status • ${cost.toStringAsFixed(0)} DA (Payé: ${paid.toStringAsFixed(0)} DA)', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                    );
                  }),
                  _listView(paymentsAsync, 'Aucun paiement', (p) {
                    final date = DateTime.tryParse(p['payment_date'] ?? '')?.toString().substring(0, 16) ?? '';
                    return ListTile(
                      leading: const Icon(Icons.payments_outlined, color: Colors.greenAccent, size: 20),
                      title: Text('${(p['amount_paid'] as num).toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700)),
                      subtitle: Text('$date • ${p['profiles']?['full_name'] ?? ''}', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listView(AsyncValue<List<Map<String, dynamic>>> async, String emptyText, Widget Function(Map<String, dynamic>) itemBuilder) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: AppTheme.error)),
      data: (items) {
        if (items.isEmpty) return Center(child: Text(emptyText, style: const TextStyle(color: AppTheme.onSurfaceMuted)));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => itemBuilder(items[i]),
        );
      },
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
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Le nom complet est obligatoire'), backgroundColor: Colors.redAccent),
              );
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            final container = ProviderScope.containerOf(context);
            Navigator.pop(ctx);
            
            try {
              final client = container.read(supabaseClientProvider);
              await client.from('customers').insert({
                'full_name': name,
                'phone_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                'is_registered': true,
              });
              container.invalidate(_customersStreamProvider);
              messenger.showSnackBar(
                const SnackBar(content: Text('Client ajouté avec succès'), backgroundColor: Colors.green),
              );
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Erreur: impossible d\'ajouter le client. Veuillez vérifier vos entrées.'), backgroundColor: Colors.redAccent),
              );
            }
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
            final amountText = amountCtrl.text.trim();
            final amount = double.tryParse(amountText) ?? 0;
            if (amount <= 0 || amount > debt) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Veuillez entrer un montant valide (supérieur à 0 et inférieur ou égal à la dette)'), backgroundColor: Colors.redAccent),
              );
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            final container = ProviderScope.containerOf(context);
            Navigator.pop(ctx); // pop dialog
            Navigator.pop(context); // pop bottom sheet
            
            try {
              final client = container.read(supabaseClientProvider);
              final user = Supabase.instance.client.auth.currentUser;
              await client.from('customer_payments').insert({
                'customer_id': customer['id'],
                'worker_id': user?.id,
                'amount_paid': amount,
              });
              container.invalidate(_customersStreamProvider);
              container.invalidate(_paymentsProvider(customer['id'] as String));
              messenger.showSnackBar(
                const SnackBar(content: Text('Paiement enregistré avec succès'), backgroundColor: Colors.green),
              );
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Erreur lors de l\'enregistrement du paiement.'), backgroundColor: Colors.redAccent),
              );
            }
          },
          child: const Text('Confirmer le paiement'),
        ),
      ],
    ),
  );
}
