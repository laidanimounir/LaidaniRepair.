import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/core/providers/supabase_provider.dart';
// تم الاستغناء عن AppTheme هنا لاستخدام ألوان الـ Cyber Glass المخصصة

// ─── Cyber Glass Theme Constants ──────────────────────────────────────────
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
      // نجلب بيانات الزبون المسجل (إن وُجد)
      .select('*, customers(full_name, phone_number), profiles(full_name)')
      .order('created_at', ascending: false)
      .limit(100);
});

final _statusFilter = StateProvider<String?>((ref) => null);

// ─── Repairs Screen (Cyber Table View) ────────────────────────────────────────

class RepairsScreen extends ConsumerWidget {
  const RepairsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(_ticketsProvider);
    final statusF = ref.watch(_statusFilter);

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Column(
        children: [
          // 1. Header & Filters
          Container(
            padding: const EdgeInsets.all(24),
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
                    const Text(
                      'GESTION DES RÉPARATIONS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
                    ),
                    const Spacer(),
                    // زر التحديث الزجاجي
                    IconButton(
                      icon: const Icon(Icons.refresh, color: _textMuted),
                      onPressed: () => ref.invalidate(_ticketsProvider),
                      tooltip: 'Rafraîchir',
                    ),
                    const SizedBox(width: 16),
                    // زر إضافة تذكرة
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
                  ],
                ),
                const SizedBox(height: 24),
                // الفلاتر (Status Chips)
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

          // 2. Custom Cyber Data Table
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (tickets) {
                final filtered = statusF == null ? tickets : tickets.where((t) => t['status'] == statusF).toList();
                
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _glassBorder, width: 1)),
                      ),
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
                    // Table Body (Rows)
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _CyberTableRow(ticket: filtered[index], ref: ref);
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

// ─── Table Row (Cyber Style) ──────────────────────────────────────────────────

class _CyberTableRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final WidgetRef ref;

  const _CyberTableRow({required this.ticket, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'En attente';
    
    // استخراج الزبون: إما مسجل أو عابر
    final isAnon = ticket['customer_id'] == null;
    final customerName = isAnon ? (ticket['client_name_temp'] ?? 'Client Anonyme') : (ticket['customers']?['full_name'] ?? 'Inconnu');
    final customerPhone = isAnon ? (ticket['client_phone_temp'] ?? '') : (ticket['customers']?['phone_number'] ?? '');
    
    final device = ticket['device_name'] ?? '';
    final issue = ticket['issue_description'] ?? '';
    final date = DateTime.tryParse(ticket['created_at'] ?? '')?.toString().substring(0, 16) ?? '';
    final qrHash = ticket['qr_code_hash']?.toString().substring(0, 8) ?? ''; // إظهار جزء من الكود فقط

    final estimated = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
    final advance = (ticket['advance_payment'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _glassBorder, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. TICKET / DATE
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
          // 2. CLIENT
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
          // 3. APPAREIL & PROBLÈME
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
          // 4. STATUT
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
          // 5. FINANCES
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
          // 6. ACTIONS
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // زر إدارة التذكرة (سيربط لاحقاً بنافذة لوحة التحكم)
                IconButton(
  icon: const Icon(Icons.dashboard_customize_outlined, color: _neonCyan, size: 20),
  tooltip: 'Gérer le ticket',
  onPressed: () {
    // الانتقال السلس إلى شاشة تفاصيل التذكرة باستخدام الـ ID
    context.push('/repair-details/${ticket['id']}');
  },
),
                  // التغيير السريع للحالة
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
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : _textMuted,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
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

// ─── New Ticket Dialog (Glassmorphism + Optional Fields) ────────────────────

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
  bool _isAnonymous = false; // خيار الزبون العابر
  
  String? _selectedCustomerId;
  final _anonNameCtrl = TextEditingController();
  final _anonPhoneCtrl = TextEditingController();
  
  final _deviceCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  
  // الحقول الاختيارية الجديدة
  final _imeiCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _diagCtrl = TextEditingController();
  
  final _costCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController(); // التسبيق

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: _panelDark.withOpacity(0.9),
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
              child: const Row(
                children: [
                  Icon(Icons.receipt_long, color: _neonCyan),
                  SizedBox(width: 12),
                  Text('NOUVEAU TICKET', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ),
            
            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION: CLIENT ---
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
                    
                    // --- SECTION: APPAREIL ---
                    _buildSectionTitle('2. Appareil & Diagnostic', Icons.smartphone),
                    _buildTextField(_deviceCtrl, 'Modèle de l\'appareil * (ex: Samsung S23)', icon: Icons.phone_android),
                    const SizedBox(height: 16),
                    _buildTextField(_issueCtrl, 'Problème signalé par le client *', icon: Icons.warning_amber_rounded, maxLines: 2),
                    const SizedBox(height: 16),
                    
                    // Optional Info Row
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_imeiCtrl, 'IMEI / Série (Optionnel)', icon: Icons.qr_code)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_passwordCtrl, 'Code / Schéma (Optionnel)', icon: Icons.lock_open)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_diagCtrl, 'Bilan visuel / État initial (Optionnel - ex: écran déjà fissuré)', icon: Icons.visibility_outlined, maxLines: 2),

                    const SizedBox(height: 32),
                    
                    // --- SECTION: FINANCES ---
                    _buildSectionTitle('3. Finances', Icons.attach_money),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_costCtrl, 'Coût estimé (Optionnel)', icon: Icons.calculate, isNumber: true, suffix: 'DA')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_advanceCtrl, 'Acompte / Avance (Optionnel)', icon: Icons.payments_outlined, isNumber: true, suffix: 'DA')),
                      ],
                    ),
                  ],
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
                      : const Text('GÉNÉRER LE TICKET', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    
    // التحقق من الحقول الإجبارية فقط
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
        'qr_code_hash': qrHash,
        'status': 'En attente',
      });
      
      widget.ref.invalidate(_ticketsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket créé avec succès !'), backgroundColor: Colors.green));
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