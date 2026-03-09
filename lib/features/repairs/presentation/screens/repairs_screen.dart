import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/core/providers/supabase_provider.dart';

// --- Cyber Glass Theme Constants ---
const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);

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

// ─── Repairs Screen (Responsive) ────────────────────────────────────────

class RepairsScreen extends ConsumerWidget {
  const RepairsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(_ticketsProvider);
    final statusF = ref.watch(_statusFilter);
    
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
                final filtered = statusF == null ? tickets : tickets.where((t) => t['status'] == statusF).toList();
                
                if (filtered.isEmpty) return _buildEmptyState();

                return Column(
                  children: [
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
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          // 🌟 اختيار طريقة العرض المناسبة 🌟
                          return isDesktop 
                              ? _CyberTableRow(ticket: filtered[index], ref: ref)
                              : _MobileTicketCard(ticket: filtered[index], ref: ref);
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

  const _CyberTableRow({required this.ticket, required this.ref});

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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _glassBorder, width: 0.5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                      final updates = <String, dynamic>{'status': newStatus};
                      if (newStatus == 'Livré') updates['delivered_at'] = DateTime.now().toIso8601String();
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

// ─── Mobile Ticket Card - للهاتف فقط 🌟 ───────────────────────────────────────
class _MobileTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final WidgetRef ref;

  const _MobileTicketCard({required this.ticket, required this.ref});

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
        color: _panelDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      final updates = <String, dynamic>{'status': newStatus};
                      if (newStatus == 'Livré') updates['delivered_at'] = DateTime.now().toIso8601String();
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
  
  final _imeiCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _diagCtrl = TextEditingController();
  
  final _costCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  final _laborCtrl = TextEditingController(); 

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
          const SizedBox(height: 16),
          _buildTextField(_issueCtrl, 'Problème signalé par le client *', icon: Icons.warning_amber_rounded, maxLines: 2),
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
              Expanded(child: _buildTextField(_imeiCtrl, 'IMEI / Série', icon: Icons.qr_code)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(_passwordCtrl, 'Code / Schéma', icon: Icons.lock_open)),
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
        ],
      ),
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
        'device_name': device,
        'issue_description': issue,
        'imei': _imeiCtrl.text.trim(),
        'device_password': _passwordCtrl.text.trim(),
        'pre_diagnostic': _diagCtrl.text.trim(),
        'estimated_cost': cost,
        'advance_payment': advance,
        'labor_cost': labor,
        'qr_code_hash': qrHash,
        'status': 'En attente',
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