import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/core/providers/shortcuts_provider.dart';
import 'package:laidani_repair/core/services/groq_service.dart';
import 'package:laidani_repair/core/utils/csv_export.dart';

// --- Cyber Glass Theme Constants ---
const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);

// ─── Providers ────────────────────────────────────────────────────────────────

final _realtimeRepairsTicker = StreamProvider<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('repair_tickets')
      .stream(primaryKey: ['id'])
      .map((_) => DateTime.now().millisecondsSinceEpoch);
});

final _ticketsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(_realtimeRepairsTicker);
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('repair_tickets')
      .select('*, customers(full_name, phone_number), assigned_technician:profiles!repair_tickets_assigned_technician_id_fkey(full_name), worker:profiles!repair_tickets_worker_id_fkey(full_name)')
      .order('created_at', ascending: false)
      .limit(100);
});

final _statusFilter = StateProvider<String?>((ref) => null);
final _slaFilter = StateProvider<String?>((ref) => null);
final _bulkModeProvider = StateProvider<bool>((ref) => false);
final _selectedTicketsProvider = StateProvider<Set<String>>((ref) => Set<String>());

// ─── Repairs Screen (Responsive) ────────────────────────────────────────

class RepairsScreen extends ConsumerWidget {
  const RepairsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(_ticketsProvider);
    final statusF = ref.watch(_statusFilter);
    final slaF = ref.watch(_slaFilter);
    final bulkMode = ref.watch(_bulkModeProvider);
    final selectedTickets = ref.watch(_selectedTicketsProvider);

    ref.listen(newTicketRequestProvider, (_, __) {
      _showNewTicketDialog(context, ref);
    });

    // تحديد نوع الجهاز (حاسوب أم هاتف)
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      backgroundColor: _bgCarbon,
      // 🌟 إضافة الزر العائم للهاتف فقط 🌟
      floatingActionButton: isDesktop ? null : FloatingActionButton(
        backgroundColor: _neonCyan,
        foregroundColor: _bgCarbon,
        onPressed: () => _showNewTicketDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 1. Header & Filters
          Container(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            decoration: const BoxDecoration(
              color: _panelDark,
              border: Border(bottom: BorderSide(color: _glassBorder, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _neonCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _neonCyan.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.build_circle_outlined, color: _neonCyan, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        isDesktop ? 'GESTION DES RÉPARATIONS' : 'RÉPARATIONS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isDesktop ? 18 : 16, letterSpacing: 1.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: _textMuted),
                      onPressed: () => ref.invalidate(_ticketsProvider),
                      tooltip: 'Rafraîchir',
                    ),
                    IconButton(
                      icon: Icon(bulkMode ? Icons.checklist : Icons.checklist_outlined, color: bulkMode ? _neonCyan : _textMuted),
                      onPressed: () {
                        ref.read(_bulkModeProvider.notifier).state = !bulkMode;
                        ref.read(_selectedTicketsProvider.notifier).state = {};
                      },
                      tooltip: 'Mode sélection multiple',
                    ),
                    // 🌟 إخفاء زر الإضافة من الأعلى في الهاتف 🌟
                    if (isDesktop) ...[
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showNewTicketDialog(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _neonCyan.withOpacity(0.1),
                          foregroundColor: _neonCyan,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          side: BorderSide(color: _neonCyan.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('NOUVEAU TICKET', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatusChip(label: 'Tous', value: null, current: statusF, ref: ref),
                      _StatusChip(label: 'En attente', value: 'En attente', current: statusF, ref: ref),
                      _StatusChip(label: 'En cours', value: 'En cours', current: statusF, ref: ref),
                      _StatusChip(label: 'Terminé', value: 'Terminé', current: statusF, ref: ref),
                      _StatusChip(label: 'Livré', value: 'Livré', current: statusF, ref: ref),
                      _StatusChip(label: '📋 Historique', value: '__history__', current: statusF, ref: ref),
                      const SizedBox(width: 16),
                      Container(width: 1, height: 24, color: _glassBorder),
                      const SizedBox(width: 16),
                      _SlaChip(label: '🟢 Dans les temps', value: 'green', ref: ref),
                      _SlaChip(label: '🟡 Urgent (<24h)', value: 'yellow', ref: ref),
                      _SlaChip(label: '🔴 En retard', value: 'red', ref: ref),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Custom Cyber Data Table (Responsive)
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (tickets) {
                final filtered = statusF == null ? tickets : statusF == '__history__'
                    ? tickets.where((t) => t['status'] == 'Terminé' || t['status'] == 'Livré').toList()
                    : tickets.where((t) => t['status'] == statusF).toList();

                List<Map<String, dynamic>> slaFiltered = filtered;
                if (slaF != null) {
                  slaFiltered = filtered.where((t) {
                    final sla = _getSlaStatus(t);
                    return sla == slaF;
                  }).toList();
                }
                
                if (slaFiltered.isEmpty) return _buildEmptyState();

                return Column(
                  children: [
                    if (bulkMode && selectedTickets.isNotEmpty)
                      _buildBulkActionBar(ref, slaFiltered, selectedTickets),

                    // 🌟 إظهار رأس الجدول للحاسوب فقط 🌟
                    if (isDesktop)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _glassBorder, width: 1))),
                        child: Row(
                          children: [
                            _buildTableHead('TICKET / DATE', flex: 2),
                            _buildTableHead('CLIENT', flex: 2),
                            _buildTableHead('APPAREIL & PROBLÈME', flex: 3),
                            _buildTableHead('STATUT', flex: 2),
                            _buildTableHead('FINANCES', flex: 2),
                            _buildTableHead('ACTIONS', flex: 1, alignRight: true),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: slaFiltered.length,
                        itemBuilder: (context, index) {
                          final ticket = slaFiltered[index];
                          final ticketId = ticket['id'] as String;
                          final isSelected = selectedTickets.contains(ticketId);

                          if (bulkMode) {
                            return GestureDetector(
                              onTap: () {
                                final set = Set<String>.from(selectedTickets);
                                if (isSelected) {
                                  set.remove(ticketId);
                                } else {
                                  set.add(ticketId);
                                }
                                ref.read(_selectedTicketsProvider.notifier).state = set;
                              },
                              child: isDesktop
                                  ? _CyberTableRow.withCheckbox(
                                      ticket: ticket, ref: ref,
                                      selected: isSelected,
                                    )
                                  : _MobileTicketCard.withCheckbox(
                                      ticket: ticket, ref: ref,
                                      selected: isSelected,
                                    ),
                            );
                          }

                          // 🌟 اختيار طريقة العرض المناسبة 🌟
                          return isDesktop 
                              ? _CyberTableRow(ticket: slaFiltered[index], ref: ref)
                              : _MobileTicketCard(ticket: slaFiltered[index], ref: ref);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHead(String title, {required int flex, bool alignRight = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: _textMuted.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('Aucun ticket trouvé.', style: TextStyle(color: _textMuted)),
        ],
      ),
    );
  }
}

// ─── Table Row (Cyber Style) - للحاسوب فقط ──────────────────────────────────

class _CyberTableRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final WidgetRef ref;
  final bool selected;

  const _CyberTableRow({required this.ticket, required this.ref, this.selected = false});
  _CyberTableRow.withCheckbox({required this.ticket, required this.ref, required this.selected});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'En attente';
    final isAnon = ticket['customer_id'] == null;
    final customerName = isAnon ? (ticket['client_name_temp'] ?? 'Client Anonyme') : (ticket['customers']?['full_name'] ?? 'Inconnu');
    final customerPhone = isAnon ? (ticket['client_phone_temp'] ?? '') : (ticket['customers']?['phone_number'] ?? '');
    
    final device = ticket['device_name'] ?? '';
    final issue = ticket['issue_description'] ?? '';
    final date = DateTime.tryParse(ticket['created_at'] ?? '')?.toString().substring(0, 16) ?? '';
    final qrHash = ticket['qr_code_hash']?.toString().substring(0, 8) ?? '';

    final estimated = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
    final advance = (ticket['advance_payment'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _glassBorder, width: 0.5)),
        color: selected ? _neonCyan.withOpacity(0.1) : _getSlaRowColor(ticket),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, color: selected ? _neonCyan : _textMuted.withOpacity(0.3), size: 20),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#$qrHash', style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: _textMuted, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isAnon ? Icons.person_outline : Icons.person, size: 14, color: isAnon ? _textMuted : _neonCyan),
                    const SizedBox(width: 6),
                    Expanded(child: Text(customerName, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                if (customerPhone.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(customerPhone, style: const TextStyle(color: _textMuted, fontSize: 11)),
                ]
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(issue, style: const TextStyle(color: _textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor(status).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(status), color: _statusColor(status), size: 12),
                    const SizedBox(width: 6),
                    Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Est: ${estimated.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.white, fontSize: 12)),
                if (advance > 0)
                  Text('Avance: ${advance.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.dashboard_customize_outlined, color: _neonCyan, size: 20),
                    tooltip: 'Gérer le ticket',
                    onPressed: () => context.push('/repair-details/${ticket['id']}'),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: _textMuted, size: 20),
                    color: _panelDark,
                    itemBuilder: (_) => ['En attente', 'En cours', 'Terminé', 'Livré']
                        .map((s) => PopupMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onSelected: (newStatus) async {
                      final client = ref.read(supabaseClientProvider);
                      final user = Supabase.instance.client.auth.currentUser;
                      final oldStatus = ticket['status'] as String? ?? 'En attente';
                      await client.from('repair_ticket_events').insert({
                        'ticket_id': ticket['id'],
                        'event_type': 'status_change',
                        'old_value': oldStatus,
                        'new_value': newStatus,
                        'created_by': user?.id,
                        'notes': 'Changement de statut: $oldStatus → $newStatus',
                      });
                      final updates = <String, dynamic>{'status': newStatus};
                      if (newStatus == 'Livré') {
                        updates['delivered_at'] = DateTime.now().toIso8601String();
                        await _syncFinalCostBeforeDelivery(client, ticket['id'] as String, ticket);
                        _addLoyaltyPointsForRepair(client, ticket);
                      }
                      await client.from('repair_tickets').update(updates).eq('id', ticket['id']);
                      ref.invalidate(_ticketsProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _syncFinalCostBeforeDelivery(SupabaseClient client, String ticketId, Map<String, dynamic> ticket) async {
  final parts = await client
      .from('repair_parts')
      .select('charged_price, quantity')
      .eq('ticket_id', ticketId);
  final partsTotal = parts.fold<double>(0, (sum, p) {
    final price = (p['charged_price'] as num?)?.toDouble() ?? 0;
    final qty = (p['quantity'] as num?)?.toDouble() ?? 1;
    return sum + (price * qty);
  });
  final labor = (ticket['labor_cost'] as num?)?.toDouble() ?? 0;
  final discount = (ticket['discount'] as num?)?.toDouble() ?? 0;
  final computed = partsTotal + labor - discount;
  await client.from('repair_tickets').update({'final_cost': computed}).eq('id', ticketId);
  ticket['final_cost'] = computed;
}

Future<void> _addLoyaltyPointsForRepair(SupabaseClient client, Map<String, dynamic> ticket) async {
  final customerId = ticket['customer_id'] as String?;
  if (customerId == null) return;
  final finalCost = (ticket['final_cost'] as num?)?.toDouble() ?? 0;
  final points = (finalCost / 50).floor();
  if (points <= 0) return;
  final existing = await client.from('customers').select('loyalty_points').eq('id', customerId).maybeSingle();
  final currentPoints = (existing?['loyalty_points'] as num?)?.toInt() ?? 0;
  await client.from('customers').update({'loyalty_points': currentPoints + points}).eq('id', customerId);
  await client.from('loyalty_transactions').insert({
    'customer_id': customerId,
    'points': points,
    'reason': 'Réparation terminée: ${finalCost.toStringAsFixed(0)} DA',
  });
}

// ─── Mobile Ticket Card - للهاتف فقط 🌟 ───────────────────────────────────────
class _MobileTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final WidgetRef ref;
  final bool selected;

  const _MobileTicketCard({required this.ticket, required this.ref, this.selected = false});
  _MobileTicketCard.withCheckbox({required this.ticket, required this.ref, required this.selected});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'En attente';
    final isAnon = ticket['customer_id'] == null;
    final customerName = isAnon ? (ticket['client_name_temp'] ?? 'Client Anonyme') : (ticket['customers']?['full_name'] ?? 'Inconnu');
    final device = ticket['device_name'] ?? '';
    final issue = ticket['issue_description'] ?? '';
    final date = DateTime.tryParse(ticket['created_at'] ?? '')?.toString().substring(0, 16) ?? '';
    final qrHash = ticket['qr_code_hash']?.toString().substring(0, 8) ?? '';
    
    final estimated = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
    final advance = (ticket['advance_payment'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? _neonCyan.withOpacity(0.05) : _getSlaCardColor(ticket),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? _neonCyan.withOpacity(0.5) : _getSlaBorderColor(ticket)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selected != null)
            Align(
              alignment: Alignment.topRight,
              child: Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, color: selected ? _neonCyan : _textMuted.withOpacity(0.3), size: 20),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#$qrHash', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(height: 2),
                  Text(date, style: const TextStyle(color: _textMuted, fontSize: 11)),
                ]
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor(status).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(status), color: _statusColor(status), size: 10),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ]
          ),
          const Divider(color: _glassBorder, height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(isAnon ? Icons.person_outline : Icons.person, size: 14, color: _neonCyan),
                      const SizedBox(width: 6),
                      Expanded(child: Text(customerName, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.phone_android, size: 14, color: _textMuted),
                      const SizedBox(width: 6),
                      Expanded(child: Text(device, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    ]),
                  ]
                )
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.dashboard_customize_outlined, color: _neonCyan),
                    onPressed: () => context.push('/repair-details/${ticket['id']}'),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: _textMuted, size: 20),
                    color: _panelDark,
                    itemBuilder: (_) => ['En attente', 'En cours', 'Terminé', 'Livré']
                        .map((s) => PopupMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onSelected: (newStatus) async {
                      final client = ref.read(supabaseClientProvider);
                      final user = Supabase.instance.client.auth.currentUser;
                      final oldStatus = ticket['status'] as String? ?? 'En attente';
                      await client.from('repair_ticket_events').insert({
                        'ticket_id': ticket['id'],
                        'event_type': 'status_change',
                        'old_value': oldStatus,
                        'new_value': newStatus,
                        'created_by': user?.id,
                        'notes': 'Changement de statut: $oldStatus → $newStatus',
                      });
                      final updates = <String, dynamic>{'status': newStatus};
                      if (newStatus == 'Livré') {
                        updates['delivered_at'] = DateTime.now().toIso8601String();
                        await _syncFinalCostBeforeDelivery(client, ticket['id'] as String, ticket);
                        _addLoyaltyPointsForRepair(client, ticket);
                      }
                      await client.from('repair_tickets').update(updates).eq('id', ticket['id']);
                      ref.invalidate(_ticketsProvider);
                    },
                  ),
                ]
              )
            ]
          ),
          const SizedBox(height: 12),
          Text('Problème: $issue', style: const TextStyle(color: _textMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Est: ${estimated.toStringAsFixed(0)} DA', style: const TextStyle(color: _textMuted, fontSize: 12)),
                Text('Avance: ${advance.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ]
            )
          )
        ],
      ),
    );
  }
}

// ─── Status Chip & Helpers ────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? current;
  final WidgetRef ref;

  const _StatusChip({required this.label, required this.value, required this.current, required this.ref});

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    final color = _statusColor(value);
    
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => ref.read(_statusFilter.notifier).state = selected ? null : value,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : _glassBorder),
          ),
          child: Text(label, style: TextStyle(color: selected ? color : _textMuted, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ),
      ),
    );
  }
}

class _SlaChip extends StatelessWidget {
  final String label;
  final String value;
  final WidgetRef ref;

  const _SlaChip({required this.label, required this.value, required this.ref});

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(_slaFilter) == value;
    Color color;
    switch (value) {
      case 'green': color = Colors.greenAccent; break;
      case 'yellow': color = Colors.orangeAccent; break;
      case 'red': color = Colors.redAccent; break;
      default: color = _textMuted;
    }
    
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => ref.read(_slaFilter.notifier).state = selected ? null : value,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : _glassBorder),
          ),
          child: Text(label, style: TextStyle(color: selected ? color : _textMuted, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        ),
      ),
    );
  }
}

String _getSlaStatus(Map<String, dynamic> ticket) {
  final status = ticket['status'] as String?;
  if (status == 'Terminé' || status == 'Livré') return 'green';
  final estimated = ticket['estimated_completion_date'] as String?;
  if (estimated == null) return 'green';
  final date = DateTime.tryParse(estimated);
  if (date == null) return 'green';
  final now = DateTime.now();
  if (date.isBefore(now)) return 'red';
  if (date.difference(now).inHours < 24) return 'yellow';
  return 'green';
}

Color _statusColor(String? status) {
  switch (status) {
    case 'En attente': return Colors.orangeAccent;
    case 'En cours': return Colors.blueAccent;
    case 'Terminé': return Colors.greenAccent;
    case 'Livré': return Colors.purpleAccent;
    default: return _neonCyan;
  }
}

IconData _statusIcon(String? status) {
  switch (status) {
    case 'En attente': return Icons.hourglass_empty;
    case 'En cours': return Icons.build;
    case 'Terminé': return Icons.check_circle;
    case 'Livré': return Icons.local_shipping;
    default: return Icons.all_inbox;
  }
}

bool _isOverdue(Map<String, dynamic> ticket) {
  final status = ticket['status'] as String?;
  if (status == 'Terminé' || status == 'Livré') return false;
  final estimated = ticket['estimated_completion_date'] as String?;
  if (estimated == null) return false;
  final date = DateTime.tryParse(estimated);
  if (date == null) return false;
  return date.isBefore(DateTime.now());
}

Color _getSlaRowColor(Map<String, dynamic> ticket) {
  switch (_getSlaStatus(ticket)) {
    case 'red': return Colors.redAccent.withOpacity(0.05);
    case 'yellow': return Colors.orangeAccent.withOpacity(0.04);
    default: return _panelDark;
  }
}

Color _getSlaCardColor(Map<String, dynamic> ticket) {
  switch (_getSlaStatus(ticket)) {
    case 'red': return Colors.redAccent.withOpacity(0.08);
    case 'yellow': return Colors.orangeAccent.withOpacity(0.06);
    default: return _panelDark.withOpacity(0.5);
  }
}

Color _getSlaBorderColor(Map<String, dynamic> ticket) {
  switch (_getSlaStatus(ticket)) {
    case 'red': return Colors.redAccent.withOpacity(0.5);
    case 'yellow': return Colors.orangeAccent.withOpacity(0.4);
    default: return _glassBorder;
  }
}

Widget _buildBulkActionBar(WidgetRef ref, List<Map<String, dynamic>> tickets, Set<String> selected) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(color: _neonCyan.withOpacity(0.08), border: Border(bottom: BorderSide(color: _neonCyan.withOpacity(0.3)))),
    child: Row(
      children: [
        Text('${selected.length} sélectionné(s)', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _showBulkStatusDialog(ref, selected),
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Changer statut', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _showBulkAssignDialog(ref, selected),
          icon: const Icon(Icons.person_add, size: 16),
          label: const Text('Assigner tech.', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _exportSelectedCsv(ref, tickets, selected),
          icon: const Icon(Icons.file_download, size: 16),
          label: const Text('Exporter', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}

Future<void> _showBulkStatusDialog(WidgetRef ref, Set<String> selected) async {
  if (selected.isEmpty) return;
  final statuses = ['En attente', 'En cours', 'Terminé', 'Livré'];
  final status = await showDialog<String>(
    context: ref.context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _panelDark,
      title: const Text('Changer le statut', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: statuses.map((s) => ListTile(
          title: Text(s, style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(ctx, s),
        )).toList(),
      ),
    ),
  );
  if (status == null) return;
  final client = ref.read(supabaseClientProvider);
  final user = Supabase.instance.client.auth.currentUser;
  for (final id in selected) {
    await client.from('repair_tickets').update({'status': status}).eq('id', id);
    await client.from('repair_ticket_events').insert({
      'ticket_id': id,
      'event_type': 'status_change',
      'new_value': status,
      'created_by': user?.id,
      'notes': 'Changement de statut groupé: → $status',
    });
  }
  ref.invalidate(_ticketsProvider);
  ref.read(_selectedTicketsProvider.notifier).state = {};
}

Future<void> _showBulkAssignDialog(WidgetRef ref, Set<String> selected) async {
  if (selected.isEmpty) return;
  final profiles = await ref.read(supabaseClientProvider).from('profiles').select('id, full_name');
  final techId = await showDialog<String>(
    context: ref.context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _panelDark,
      title: const Text('Assigner un technicien', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: (profiles as List).map((p) => ListTile(
            title: Text(p['full_name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, p['id']?.toString()),
          )).toList(),
        ),
      ),
    ),
  );
  if (techId == null) return;
  final client = ref.read(supabaseClientProvider);
  for (final id in selected) {
    await client.from('repair_tickets').update({'assigned_technician_id': techId}).eq('id', id);
  }
  ref.invalidate(_ticketsProvider);
  ref.read(_selectedTicketsProvider.notifier).state = {};
}

Future<void> _exportSelectedCsv(WidgetRef ref, List<Map<String, dynamic>> tickets, Set<String> selected) async {
  final selectedTickets = tickets.where((t) => selected.contains(t['id'] as String)).toList();
  final headers = ['ID', 'Client', 'Appareil', 'Problème', 'Statut', 'Coût'];
  final rows = selectedTickets.map((t) => [
    t['id']?.toString() ?? '',
    t['customers']?['full_name']?.toString() ?? t['client_name_temp']?.toString() ?? '',
    t['device_name']?.toString() ?? '',
    t['issue_description']?.toString() ?? '',
    t['status']?.toString() ?? '',
    (t['estimated_cost'] as num?)?.toString() ?? '0',
  ]).toList();
  final csv = await exportToCsv(headers: headers, rows: rows);
  final dir = Directory.systemTemp;
  final file = File('${dir.path}/tickets_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csv);
}

// ─── New Ticket Dialog (Two-Column Cyber Layout - Responsive) ─────────────────────────────

void _showNewTicketDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: _NewTicketForm(ref: ref),
    ),
  );
}

class _NewTicketForm extends StatefulWidget {
  final WidgetRef ref;
  const _NewTicketForm({required this.ref});

  @override
  State<_NewTicketForm> createState() => _NewTicketFormState();
}

class _NewTicketFormState extends State<_NewTicketForm> {
  bool _isAnonymous = false; 
  String? _selectedCustomerId;
  final _anonNameCtrl = TextEditingController();
  final _anonPhoneCtrl = TextEditingController();
  
  final _deviceCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  String? _deviceType;
  final _brandCtrl = TextEditingController();
  
  final _imeiCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _diagCtrl = TextEditingController();
  final _accessoriesCtrl = TextEditingController();
  
  final _costCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  final _laborCtrl = TextEditingController();
  DateTime? _estimatedCompletionDate; 

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // 🌟 التجاوب في نافذة الإضافة 🌟
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 24 : 12),
      child: Container(
        width: isDesktop ? 900 : double.infinity,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: _panelDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _glassBorder, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30)],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _glassBorder))),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: _neonCyan),
                  const SizedBox(width: 12),
                  Expanded(child: Text('NOUVEAU DOSSIER DE RÉPARATION', style: TextStyle(color: Colors.white, fontSize: isDesktop ? 18 : 14, fontWeight: FontWeight.bold, letterSpacing: 1), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            
            // Form Body
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: isDesktop 
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildLeftColumn()),
                        Container(width: 1, color: _glassBorder, margin: const EdgeInsets.symmetric(horizontal: 24)),
                        Expanded(flex: 4, child: _buildRightColumn()),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildLeftColumn(),
                          const SizedBox(height: 24),
                          const Divider(color: _glassBorder),
                          const SizedBox(height: 24),
                          _buildRightColumn(),
                        ],
                      ),
                    ),
              ),
            ),
            
            // Footer Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _glassBorder))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annuler', style: TextStyle(color: _textMuted)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      foregroundColor: _bgCarbon,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _bgCarbon, strokeWidth: 2))
                      : const Text('GÉNÉRER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Left Column ---
  Widget _buildLeftColumn() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('1. Informations Client', Icons.person_outline),
          SwitchListTile(
            title: const Text('Client de passage (Anonyme)', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Ne pas enregistrer ce client dans la base', style: TextStyle(color: _textMuted, fontSize: 12)),
            value: _isAnonymous,
            activeColor: _neonCyan,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _isAnonymous = v),
          ),
          const SizedBox(height: 12),
          if (_isAnonymous) ...[
            Row(
              children: [
                Expanded(child: _buildTextField(_anonNameCtrl, 'Nom (Optionnel)', icon: Icons.person)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(_anonPhoneCtrl, 'Téléphone (Optionnel)', icon: Icons.phone)),
              ],
            ),
          ] else ...[
            FutureBuilder(
              future: widget.ref.read(supabaseClientProvider).from('customers').select('id, full_name, phone_number').eq('is_registered', true).order('full_name'),
              builder: (ctx, snap) {
                if (!snap.hasData) return const CircularProgressIndicator(color: _neonCyan);
                final custs = snap.data as List;
                return DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  dropdownColor: _panelDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Sélectionner un client *', Icons.people),
                  items: custs.map((c) => DropdownMenuItem<String>(
                    value: c['id'] as String,
                    child: Text('${c['full_name']} — ${c['phone_number'] ?? ''}'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedCustomerId = v),
                );
              },
            ),
          ],
          
          const SizedBox(height: 32),
          _buildSectionTitle('2. L\'appareil', Icons.smartphone),
          _buildTextField(_deviceCtrl, 'Modèle de l\'appareil * (ex: Samsung S23)', icon: Icons.phone_android),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _deviceType,
            dropdownColor: _panelDark,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Type d\'appareil', Icons.devices),
            items: ['Téléphone', 'Tablette', 'Ordinateur', 'Console', 'Montre', 'Autre']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _deviceType = v),
          ),
          const SizedBox(height: 12),
          _buildTextField(_brandCtrl, 'Marque (ex: Samsung, Apple)', icon: Icons.badge),
          const SizedBox(height: 16),
          _buildTextField(_issueCtrl, 'Problème signalé par le client *', icon: Icons.warning_amber_rounded, maxLines: 2),
          const SizedBox(height: 12),
          _buildDiagnosticAIButton(),
          const SizedBox(height: 8),
          _buildPriceEstimatorButton(),
        ],
      ),
    );
  }

  // --- Right Column ---
  Widget _buildRightColumn() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('3. Diagnostic & Sécurité (Optionnel)', Icons.security),
          Row(
            children: [
              Expanded(child: _buildTextField(_imeiCtrl, 'IMEI', icon: Icons.qr_code)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(_serialCtrl, 'N° de série', icon: Icons.confirmation_number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField(_passwordCtrl, 'Code / Schéma', icon: Icons.lock_open)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(_accessoriesCtrl, 'Accessoires fournis', icon: Icons.backpack)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(_diagCtrl, 'Bilan visuel / État initial (ex: écran déjà fissuré)', icon: Icons.visibility_outlined, maxLines: 2),

          const SizedBox(height: 32),
          _buildSectionTitle('4. Finances initiales', Icons.attach_money),
          _buildTextField(_costCtrl, 'Coût estimé (Pièces incluses)', icon: Icons.calculate, isNumber: true, suffix: 'DA'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField(_advanceCtrl, 'Acompte (Avance)', icon: Icons.payments_outlined, isNumber: true, suffix: 'DA')),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(_laborCtrl, 'Main d\'œuvre (M.O)', icon: Icons.handyman_outlined, isNumber: true, suffix: 'DA')),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 3)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _estimatedCompletionDate = picked);
            },
            child: InputDecorator(
              decoration: _inputDecoration('Date fin estimée (SLA)', Icons.schedule).copyWith(suffixIcon: const Icon(Icons.date_range, color: _textMuted, size: 18)),
              child: Text(
                _estimatedCompletionDate != null
                    ? '${_estimatedCompletionDate!.day.toString().padLeft(2, '0')}/${_estimatedCompletionDate!.month.toString().padLeft(2, '0')}/${_estimatedCompletionDate!.year}'
                    : 'Sélectionner une date',
                style: TextStyle(color: _estimatedCompletionDate != null ? Colors.white : _textMuted, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticAIButton() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _diagnosticIA,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF9C27B0),
            side: const BorderSide(color: Color(0xFF9C27B0)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.psychology, size: 18),
          label: const Text('Diagnostic IA (Groq)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _diagnosticIA() async {
    final device = _deviceCtrl.text.trim();
    final issue = _issueCtrl.text.trim();
    final brand = _brandCtrl.text.trim();

    if (device.isEmpty || issue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le modèle et le problème d\'abord'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await GroqService().diagnoseProblem(
        deviceType: _deviceType ?? 'Appareil',
        brand: brand.isEmpty ? 'Inconnu' : brand,
        description: issue,
      );

      if (!mounted) return;

      final cause = result['probableCause'] ?? '';
      final steps = result['recommendedSteps'] as List? ?? [];
      final difficulty = result['difficulty'] ?? 'Moyen';
      final parts = result['suggestedParts'] as List? ?? [];

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _neonCyan.withOpacity(0.5))),
          title: const Row(
            children: [
              Icon(Icons.psychology, color: Color(0xFF9C27B0)),
              SizedBox(width: 8),
              Text('Diagnostic IA', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cause probable:', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(cause, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Difficulté:', style: TextStyle(color: _textMuted, fontSize: 11)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: difficulty == 'Facile' ? Colors.green.withOpacity(0.1) : difficulty == 'Difficile' ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: difficulty == 'Facile' ? Colors.green : difficulty == 'Difficile' ? Colors.red : Colors.orange, width: 0.5),
                  ),
                  child: Text(difficulty, style: TextStyle(color: difficulty == 'Facile' ? Colors.green : difficulty == 'Difficile' ? Colors.red : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Étapes recommandées:', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  ...steps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.key + 1}. ', style: const TextStyle(color: _neonCyan, fontSize: 12)),
                        Expanded(child: Text(e.value.toString(), style: const TextStyle(color: Colors.white, fontSize: 12))),
                      ],
                    ),
                  )),
                ],
                if (parts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Pièces suggérées:', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  ...parts.map((p) => Row(
                    children: [
                      const Icon(Icons.build_circle, size: 12, color: _textMuted),
                      const SizedBox(width: 4),
                      Text('- ${p.toString()}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  )),
                ],
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: _textMuted),
                    SizedBox(width: 4),
                    Expanded(child: Text('Ces suggestions sont générées par IA. Vérifiez toujours avec un diagnostic manuel.', style: TextStyle(color: _textMuted, fontSize: 10, fontStyle: FontStyle.italic))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer', style: TextStyle(color: _textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
              onPressed: () {
                Navigator.pop(ctx);
                if (cause.isNotEmpty) {
                  final currentDiag = _diagCtrl.text;
                  _diagCtrl.text = '$currentDiag\n[IA] Cause probable: $cause'.trim();
                }
              },
              child: const Text('Appliquer au diagnostic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur IA: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPriceEstimatorButton() {
    final device = _deviceCtrl.text.trim();
    final brand = _brandCtrl.text.trim();
    final issue = _issueCtrl.text.trim();
    final hasInfo = device.isNotEmpty && issue.isNotEmpty;

    return Opacity(
      opacity: hasInfo ? 1.0 : 0.5,
      child: OutlinedButton.icon(
        onPressed: hasInfo ? _estimatePriceIA : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00BCD4),
          side: const BorderSide(color: Color(0xFF00BCD4)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.attach_money, size: 18),
        label: const Text('Estimer le prix (IA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Future<void> _estimatePriceIA() async {
    final device = _deviceCtrl.text.trim();
    final issue = _issueCtrl.text.trim();
    final brand = _brandCtrl.text.trim();

    setState(() => _isLoading = true);
    try {
      final result = await GroqService().estimatePrice(
        deviceType: _deviceType ?? 'Appareil',
        brand: brand.isEmpty ? 'Inconnu' : brand,
        problemDescription: issue,
      );

      if (!mounted) return;

      final minPrice = (result['minPrice'] as num?)?.toDouble() ?? 0;
      final maxPrice = (result['maxPrice'] as num?)?.toDouble() ?? 0;
      final estimatedTime = result['estimatedTime'] ?? 'Non spécifié';
      final confidence = result['confidence'] ?? 'Moyenne';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _neonCyan.withOpacity(0.5))),
          title: const Row(
            children: [
              Icon(Icons.attach_money, color: Color(0xFF00BCD4)),
              SizedBox(width: 8),
              Text('Estimation IA', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
                child: Column(
                  children: [
                    Text('${minPrice.toStringAsFixed(0)} - ${maxPrice.toStringAsFixed(0)} DA', style: const TextStyle(color: _neonCyan, fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Fourchette de prix estimée', style: const TextStyle(color: _textMuted, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _estimationInfoRow(Icons.timer, 'Temps estimé', estimatedTime),
              const SizedBox(height: 8),
              _estimationInfoRow(Icons.verified, 'Confiance', confidence),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 12, color: _textMuted),
                  SizedBox(width: 4),
                  Expanded(child: Text('Estimation générée par IA. Ajustez selon votre expertise.', style: TextStyle(color: _textMuted, fontSize: 10, fontStyle: FontStyle.italic))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ignorer', style: TextStyle(color: _textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), foregroundColor: _bgCarbon),
              onPressed: () {
                Navigator.pop(ctx);
                final avgPrice = ((minPrice + maxPrice) / 2).round().toDouble();
                _costCtrl.text = avgPrice.toStringAsFixed(0);
              },
              child: const Text('Appliquer le prix moyen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur estimation: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _estimationInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _textMuted),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: _textMuted, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: _textMuted, size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {required IconData icon, int maxLines = 1, bool isNumber = false, String? suffix}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : null,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: _inputDecoration(label, icon).copyWith(suffixText: suffix, suffixStyle: const TextStyle(color: _textMuted)),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: _textMuted, size: 18),
      filled: true,
      fillColor: _bgCarbon.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _neonCyan)),
    );
  }

  Future<void> _submit() async {
    final device = _deviceCtrl.text.trim();
    final issue = _issueCtrl.text.trim();
    
    if ((!_isAnonymous && _selectedCustomerId == null) || device.isEmpty || issue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir les champs obligatoires (*)'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final client = widget.ref.read(supabaseClientProvider);
      final user = Supabase.instance.client.auth.currentUser;
      final qrHash = 'LR-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999).toString().padLeft(4, '0')}';
      
      final cost = double.tryParse(_costCtrl.text) ?? 0;
      final advance = double.tryParse(_advanceCtrl.text) ?? 0;
      final labor = double.tryParse(_laborCtrl.text) ?? 0;

      await client.from('repair_tickets').insert({
        'customer_id': _isAnonymous ? null : _selectedCustomerId,
        'client_name_temp': _isAnonymous ? _anonNameCtrl.text.trim() : null,
        'client_phone_temp': _isAnonymous ? _anonPhoneCtrl.text.trim() : null,
        'worker_id': user?.id,
        'device_type': _deviceType,
        'brand': _brandCtrl.text.trim(),
        'device_name': device,
        'issue_description': issue,
        'imei': _imeiCtrl.text.trim(),
        'serial_number': _serialCtrl.text.trim(),
        'device_password': _passwordCtrl.text.trim(),
        'accessories': _accessoriesCtrl.text.trim(),
        'pre_diagnostic': _diagCtrl.text.trim(),
        'estimated_cost': cost,
        'advance_payment': advance,
        'labor_cost': labor,
        'qr_code_hash': qrHash,
        'status': 'En attente',
        'estimated_completion_date': _estimatedCompletionDate?.toIso8601String().substring(0, 10),
      });
      
      widget.ref.invalidate(_ticketsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dossier créé avec succès !'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}