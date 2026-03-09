import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/core/theme/app_theme.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _ticketsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('repair_tickets')
      .select('*, customers(full_name, phone_number), profiles(full_name)')
      .order('created_at', ascending: false)
      .limit(100);
});

final _statusFilter = StateProvider<String?>((ref) => null);

// ─── Repairs Screen ───────────────────────────────────────────────────────────

class RepairsScreen extends ConsumerWidget {
  const RepairsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(_ticketsProvider);
    final statusF = ref.watch(_statusFilter);

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
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.build_circle, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Réparations', style: TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w700, fontSize: 18)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.onSurfaceMuted, size: 18),
                      onPressed: () => ref.invalidate(_ticketsProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Status filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatusChip(label: 'Tous', value: null, current: statusF, ref: ref),
                      _StatusChip(label: 'En attente', value: 'En attente', current: statusF, ref: ref),
                      _StatusChip(label: 'En cours', value: 'En cours', current: statusF, ref: ref),
                      _StatusChip(label: 'Terminé', value: 'Terminé', current: statusF, ref: ref),
                      _StatusChip(label: 'Livré', value: 'Livré', current: statusF, ref: ref),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tickets list
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: AppTheme.error))),
              data: (tickets) {
                final filtered = statusF == null ? tickets : tickets.where((t) => t['status'] == statusF).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Aucun ticket de réparation', style: TextStyle(color: AppTheme.onSurfaceMuted)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _TicketCard(ticket: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewTicketDialog(context, ref),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─── Status Chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? current;
  final WidgetRef ref;

  const _StatusChip({required this.label, required this.value, required this.current, required this.ref});

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => ref.read(_statusFilter.notifier).state = selected ? null : value,
        showCheckmark: false,
        selectedColor: _statusColor(value).withOpacity(0.2),
        side: BorderSide(color: selected ? _statusColor(value) : const Color(0xFF2A2A50)),
        labelStyle: TextStyle(
          color: selected ? _statusColor(value) : AppTheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 12,
        ),
      ),
    );
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'En attente': return Colors.orangeAccent;
    case 'En cours': return Colors.blueAccent;
    case 'Terminé': return Colors.greenAccent;
    case 'Livré': return AppTheme.secondary;
    default: return AppTheme.primary;
  }
}

IconData _statusIcon(String? status) {
  switch (status) {
    case 'En attente': return Icons.hourglass_empty;
    case 'En cours': return Icons.build;
    case 'Terminé': return Icons.check_circle;
    case 'Livré': return Icons.local_shipping;
    default: return Icons.help_outline;
  }
}

// ─── Ticket Card ──────────────────────────────────────────────────────────────

class _TicketCard extends ConsumerWidget {
  final Map<String, dynamic> ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ticket['status'] as String? ?? 'En attente';
    final customer = ticket['customers']?['full_name'] ?? 'Inconnu';
    final device = ticket['device_name'] ?? '';
    final issue = ticket['issue_description'] ?? '';
    final estimated = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
    final finalCost = (ticket['final_cost'] as num?)?.toDouble() ?? 0;
    final date = DateTime.tryParse(ticket['created_at'] ?? '')?.toString().substring(0, 16) ?? '';
    final qrHash = ticket['qr_code_hash'] ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor(status).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(_statusIcon(status), color: _statusColor(status), size: 18),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(date, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          // Device + Customer
          Text(device, style: const TextStyle(color: AppTheme.onBackground, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text('Client: $customer', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
          if (issue.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(issue, style: const TextStyle(color: AppTheme.onSurface, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          // Bottom row
          Row(
            children: [
              Text('Est: ${estimated.toStringAsFixed(0)} DA', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
              const SizedBox(width: 12),
              if (finalCost > 0)
                Text('Final: ${finalCost.toStringAsFixed(0)} DA', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w600, fontSize: 12)),
              const Spacer(),
              if (qrHash.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code, size: 12, color: AppTheme.primaryLight),
                      const SizedBox(width: 3),
                      Text('QR', style: const TextStyle(color: AppTheme.primaryLight, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              // Status update button
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.onSurfaceMuted),
                itemBuilder: (_) => ['En attente', 'En cours', 'Terminé', 'Livré']
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
                onSelected: (newStatus) async {
                  final client = ref.read(supabaseClientProvider);
                  final updates = <String, dynamic>{'status': newStatus};
                  if (newStatus == 'Livré') updates['delivered_at'] = DateTime.now().toIso8601String();
                  await client.from('repair_tickets').update(updates).eq('id', ticket['id']);
                  ref.invalidate(_ticketsProvider);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── New Ticket Dialog ────────────────────────────────────────────────────────

void _showNewTicketDialog(BuildContext context, WidgetRef ref) {
  final deviceCtrl = TextEditingController();
  final issueCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  String? selectedCustomerId;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nouveau ticket de réparation'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Customer selector
              FutureBuilder(
                future: ref.read(supabaseClientProvider).from('customers').select('id, full_name, phone_number').eq('is_registered', true).order('full_name'),
                builder: (ctx2, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final custs = snap.data as List;
                  return StatefulBuilder(
                    builder: (ctx3, setState3) => DropdownButtonFormField<String>(
                      value: selectedCustomerId,
                      decoration: const InputDecoration(labelText: 'Client'),
                      isExpanded: true,
                      items: custs.map((c) => DropdownMenuItem<String>(
                        value: c['id'] as String,
                        child: Text('${c['full_name']} — ${c['phone_number'] ?? ''}'),
                      )).toList(),
                      onChanged: (v) => setState3(() => selectedCustomerId = v),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: deviceCtrl, decoration: const InputDecoration(labelText: 'Appareil (ex: iPhone 13 Pro)')),
              const SizedBox(height: 12),
              TextField(controller: issueCtrl, decoration: const InputDecoration(labelText: 'Description du problème'), maxLines: 3),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: const InputDecoration(labelText: 'Coût estimé (DA)', suffixText: 'DA'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            final device = deviceCtrl.text.trim();
            final issue = issueCtrl.text.trim();
            final cost = double.tryParse(costCtrl.text) ?? 0;
            
            if (selectedCustomerId == null || device.isEmpty || issue.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Veuillez remplir les champs obligatoires (Client, Appareil, Description)'), backgroundColor: Colors.redAccent),
              );
              return;
            }
            
            final messenger = ScaffoldMessenger.of(context);
            final container = ProviderScope.containerOf(context);
            Navigator.pop(ctx);
            
            try {
              final client = container.read(supabaseClientProvider);
              final user = Supabase.instance.client.auth.currentUser;
              // Generate a unique QR hash
              final qrHash = 'LR-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999).toString().padLeft(4, '0')}';
              await client.from('repair_tickets').insert({
                'customer_id': selectedCustomerId,
                'worker_id': user?.id,
                'device_name': device,
                'issue_description': issue,
                'estimated_cost': cost,
                'qr_code_hash': qrHash,
                'status': 'En attente',
              });
              container.invalidate(_ticketsProvider);
              messenger.showSnackBar(
                const SnackBar(content: Text('Ticket de réparation créé avec succès'), backgroundColor: Colors.green),
              );
            } catch (e) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Erreur lors de la création du ticket.'), backgroundColor: Colors.redAccent),
              );
            }
          },
          child: const Text('Créer le ticket'),
        ),
      ],
    ),
  );
}
