import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);

final _realtimeTicker = StreamProvider<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('repair_tickets')
      .stream(primaryKey: ['id'])
      .map((_) => DateTime.now().millisecondsSinceEpoch);
});

final _myTicketsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(_realtimeTicker);
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return await client
      .from('repair_tickets')
      .select('*, customers(full_name, phone_number), profiles!repair_tickets_assigned_technician_id_fkey(full_name)')
      .eq('assigned_technician_id', user.id)
      .order('created_at', ascending: false)
      .limit(50);
});

class TechnicianBoardScreen extends ConsumerWidget {
  const TechnicianBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(_myTicketsProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            decoration: const BoxDecoration(
              color: _panelDark,
              border: Border(bottom: BorderSide(color: _glassBorder, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _neonCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _neonCyan.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.assignment_ind_outlined, color: _neonCyan, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'MON TABLEAU DE BORD TECHNICIEN',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: _textMuted),
                  onPressed: () => ref.invalidate(_myTicketsProvider),
                  tooltip: 'Rafraîchir',
                ),
              ],
            ),
          ),
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (tickets) {
                if (tickets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 64, color: _textMuted.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        const Text('Aucun ticket assigné.', style: TextStyle(color: _textMuted)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) => _TicketCard(ticket: tickets[index], ref: ref),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final WidgetRef ref;
  const _TicketCard({required this.ticket, required this.ref});

  String _slaText() {
    final estimated = ticket['estimated_completion_date'] as String?;
    if (estimated == null) return '';
    final date = DateTime.tryParse(estimated);
    if (date == null) return '';
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return 'EN RETARD';
    if (diff.inDays > 0) return '${diff.inDays}j ${diff.inHours % 24}h';
    return '${diff.inHours}h ${diff.inMinutes % 60}min';
  }

  Color _slaColor() {
    final estimated = ticket['estimated_completion_date'] as String?;
    if (estimated == null) return _textMuted;
    final date = DateTime.tryParse(estimated);
    if (date == null) return _textMuted;
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return Colors.redAccent;
    if (diff.inHours < 24) return Colors.orangeAccent;
    return _neonCyan;
  }

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'En attente';
    final isAnon = ticket['customer_id'] == null;
    final customerName = isAnon ? (ticket['client_name_temp'] ?? 'Client Anonyme') : (ticket['customers']?['full_name'] ?? 'Inconnu');
    final device = ticket['device_name'] ?? '';
    final issue = ticket['issue_description'] ?? '';
    final date = DateTime.tryParse(ticket['created_at'] ?? '')?.toString().substring(0, 16) ?? '';
    final qrHash = ticket['qr_code_hash']?.toString().substring(0, 8) ?? '';
    final slaText = _slaText();
    final slaColor = _slaColor();
    final isOverdue = slaColor == Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOverdue ? Colors.redAccent.withOpacity(0.4) : _glassBorder),
      ),
      child: InkWell(
        onTap: () => context.push('/repair-details/${ticket['id']}'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _statusColor(status).withOpacity(0.3)),
                  ),
                  child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text('#$qrHash', style: const TextStyle(color: _textMuted, fontFamily: 'monospace', fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.person_outline, size: 14, color: _neonCyan),
                        const SizedBox(width: 6),
                        Expanded(child: Text(customerName, style: const TextStyle(color: _textMuted, fontSize: 13), overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ),
                ),
                if (slaText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: slaColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: slaColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(slaText, style: TextStyle(color: slaColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('SLA', style: TextStyle(color: slaColor.withOpacity(0.7), fontSize: 9)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(issue, style: const TextStyle(color: _textMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: _textMuted),
                const SizedBox(width: 6),
                Text(date, style: const TextStyle(color: _textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'En attente': return Colors.orangeAccent;
    case 'Terminé': return Colors.greenAccent;
    case 'Livré': return Colors.purpleAccent;
    default: return _neonCyan;
  }
}
