import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
const Color _neonEmerald = Color(0xFF10B981);

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
      .select('*, customers(full_name, phone_number), profiles!repair_tickets_assigned_technician_id_fkey(full_name)')
      .order('created_at', ascending: false)
      .limit(100);
});

final _statusFilter = StateProvider<String?>((ref) => null);
final _slaFilter = StateProvider<String?>((ref) => null);
final _bulkModeProvider = StateProvider<bool>((ref) => false);
final _selectedTicketsProvider = StateProvider<Set<String>>((ref) => Set<String>());

final _searchQueryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final client = ref.watch(supabaseClientProvider);
  final search = '%$query%';
  final data = await client
      .from('repair_tickets')
      .select('*, customers(full_name, phone_number), profiles!repair_tickets_assigned_technician_id_fkey(full_name)')
      .or('client_name_temp.ilike.$search,device_name.ilike.$search,qr_code_hash.ilike.$search')
      .order('created_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(data);
});

// ─── Repairs Screen (Responsive) ────────────────────────────────────────

class RepairsScreen extends ConsumerStatefulWidget {
  const RepairsScreen({super.key});

  @override
  ConsumerState<RepairsScreen> createState() => _RepairsScreenState();
}

class _RepairsScreenState extends ConsumerState<RepairsScreen> {
  final _scanFocus = FocusNode();
  final _scanStopwatch = Stopwatch();
  String _scanBuffer = '';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isScannerActive = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scanFocus.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleScanResult(String raw) {
    if (raw.isEmpty) return;
    final trimmed = raw.trim();

    // Check if it's a LAIDANI:TICKET:... QR format
    final ticketMatch = RegExp(r'LAIDANI:TICKET:([a-f0-9\-]+):').firstMatch(trimmed);
    if (ticketMatch != null) {
      final uuid = ticketMatch.group(1)!;
      context.push('/repair-details/$uuid');
      return;
    }

    // Try as raw hash or UUID
    if (trimmed.length >= 8) {
      ref.read(supabaseClientProvider).from('repair_tickets')
          .select('id')
          .eq('qr_code_hash', trimmed)
          .maybeSingle()
          .then((ticket) {
        if (ticket != null && mounted) {
          context.push('/repair-details/${ticket['id']}');
        } else {
          _searchCtrl.text = trimmed;
          ref.read(_searchQueryProvider.notifier).state = trimmed;
        }
      });
      return;
    }

    _searchCtrl.text = trimmed;
    ref.read(_searchQueryProvider.notifier).state = trimmed;
  }

  void _showQrScanner() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 400,
          height: 300,
          child: MobileScanner(
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull?.rawValue;
              if (barcode == null || barcode.isEmpty) return;
              Navigator.pop(ctx);
              _handleScanResult(barcode);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _submitDesktopScan() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner, color: _neonCyan),
            const SizedBox(width: 8),
            const Text('Scanner / Saisir code', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Collez ou scannez un code QR / ticket...',
                hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                filled: true,
                fillColor: _bgCarbon.withOpacity(0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
              ),
              onSubmitted: (v) {
                Navigator.pop(ctx);
                _handleScanResult(v);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Ouvrir caméra'),
              style: OutlinedButton.styleFrom(foregroundColor: _neonCyan),
              onPressed: () {
                Navigator.pop(ctx);
                _showQrScanner();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: _textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
            onPressed: () {
              Navigator.pop(ctx);
              _handleScanResult(ctrl.text);
            },
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(_ticketsProvider);
    final searchQuery = ref.watch(_searchQueryProvider);
    final searchAsync = ref.watch(_searchResultsProvider);
    final statusF = ref.watch(_statusFilter);
    final slaF = ref.watch(_slaFilter);
    final bulkMode = ref.watch(_bulkModeProvider);
    final selectedTickets = ref.watch(_selectedTicketsProvider);

    ref.listen(newTicketRequestProvider, (_, __) {
      _showNewTicketDialog(context, ref);
    });

    final isDesktop = MediaQuery.of(context).size.width >= 850;
    final isSearching = searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: _bgCarbon,
      floatingActionButton: isDesktop ? null : FloatingActionButton(
        backgroundColor: _neonCyan,
        foregroundColor: _bgCarbon,
        onPressed: () => _showNewTicketDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          // --- Hidden HID scanner listener (desktop only) ---
          if (isDesktop && _isScannerActive)
            Positioned(
              left: -9999,
              child: SizedBox(
                width: 1, height: 1,
                  child: TextField(
                    focusNode: _scanFocus,
                    onChanged: (v) {
                    if (!_scanStopwatch.isRunning) _scanStopwatch.start();
                    _scanBuffer = v;
                  },
                  onSubmitted: (v) {
                    _scanStopwatch.stop();
                    final elapsed = _scanStopwatch.elapsedMilliseconds;
                    _scanStopwatch.reset();
                    _scanBuffer = '';
                    if (elapsed < 150 && v.trim().isNotEmpty) {
                      _handleScanResult(v);
                    }
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted && _isScannerActive) _scanFocus.requestFocus();
                    });
                  },
                ),
              ),
            ),
          // --- Visible UI ---
          Column(
            children: [
              // Header & Search
              Container(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                decoration: const BoxDecoration(
                  color: _panelDark,
                  border: Border(bottom: BorderSide(color: _glassBorder, width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar row
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Rechercher client, appareil, ticket...',
                              hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                              prefixIcon: IconButton(
                                icon: const Icon(Icons.search, color: _textMuted, size: 20),
                                onPressed: () {
                                  _debounce?.cancel();
                                  ref.read(_searchQueryProvider.notifier).state = _searchCtrl.text.trim();
                                },
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner, color: _neonCyan, size: 20),
                                    tooltip: 'Scanner QR',
                                    onPressed: isDesktop ? _submitDesktopScan : _showQrScanner,
                                  ),
                                  if (searchQuery.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear, color: _textMuted, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        ref.read(_searchQueryProvider.notifier).state = '';
                                      },
                                    ),
                                ],
                              ),
                              filled: true,
                              fillColor: _bgCarbon.withOpacity(0.6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _glassBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _glassBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _neonCyan)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (v) {
                              _debounce?.cancel();
                              _debounce = Timer(const Duration(milliseconds: 300), () {
                                ref.read(_searchQueryProvider.notifier).state = v.trim();
                              });
                            },
                            onSubmitted: (v) {
                              _debounce?.cancel();
                              ref.read(_searchQueryProvider.notifier).state = v.trim();
                            },
                          ),
                        ),
                        if (isDesktop) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              Icons.qr_code,
                              color: _isScannerActive ? _neonEmerald : _textMuted,
                              size: 20,
                            ),
                            tooltip: _isScannerActive ? 'Scanner HID actif' : 'Scanner HID désactivé',
                            onPressed: () {
                              setState(() {
                                _isScannerActive = !_isScannerActive;
                                if (_isScannerActive) {
                                  _scanFocus.requestFocus();
                                } else {
                                  _scanFocus.unfocus();
                                }
                              });
                            },
                          ),
                        ],
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: _textMuted, size: 20),
                          onPressed: () {
                            ref.invalidate(_ticketsProvider);
                            ref.invalidate(_searchResultsProvider);
                          },
                          tooltip: 'Rafraîchir',
                        ),
                        IconButton(
                          icon: Icon(bulkMode ? Icons.checklist : Icons.checklist_outlined, color: bulkMode ? _neonCyan : _textMuted, size: 20),
                          onPressed: () {
                            ref.read(_bulkModeProvider.notifier).state = !bulkMode;
                            ref.read(_selectedTicketsProvider.notifier).state = {};
                          },
                          tooltip: 'Mode sélection multiple',
                        ),
                        if (isDesktop) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showNewTicketDialog(context, ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _neonCyan.withOpacity(0.1),
                              foregroundColor: _neonCyan,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              side: BorderSide(color: _neonCyan.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add_box_outlined, size: 18),
                            label: const Text('NOUVEAU', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                    if (!isSearching) ...[
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _StatusChip(label: 'Tous', value: null, current: statusF, ref: ref),
                            _StatusChip(label: 'En attente', value: 'En attente', current: statusF, ref: ref),
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
                  ],
                ),
              ),

              // Body: search results or normal list
              Expanded(
                child: isSearching
                    ? searchAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
                        error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
                        data: (searchTickets) {
                          if (searchTickets.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off, size: 48, color: _textMuted),
                                  const SizedBox(height: 12),
                                  Text('Aucun résultat pour "$searchQuery"', style: const TextStyle(color: _textMuted)),
                                ],
                              ),
                            );
                          }
                          return _buildTicketList(context, ref, searchTickets, statusF, slaF, bulkMode, selectedTickets, isDesktop, false);
                        },
                      )
                    : ticketsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
                        error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
                        data: (tickets) => _buildTicketList(context, ref, tickets, statusF, slaF, bulkMode, selectedTickets, isDesktop, true),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketList(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> tickets,
      String? statusF, String? slaF, bool bulkMode, Set<String> selectedTickets, bool isDesktop, bool applyFilters) {
    final filtered = !applyFilters
        ? tickets
        : statusF == null
            ? tickets
            : statusF == '__history__'
                ? tickets.where((t) => t['status'] == 'Terminé' || t['status'] == 'Livré').toList()
                : tickets.where((t) => t['status'] == statusF).toList();

    List<Map<String, dynamic>> slaFiltered = filtered;
    if (applyFilters && slaF != null) {
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
                    if (isSelected) { set.remove(ticketId); } else { set.add(ticketId); }
                    ref.read(_selectedTicketsProvider.notifier).state = set;
                  },
                  child: isDesktop
                      ? _CyberTableRow.withCheckbox(ticket: ticket, ref: ref, selected: isSelected)
                      : _MobileTicketCard.withCheckbox(ticket: ticket, ref: ref, selected: isSelected),
                );
              }
              return isDesktop
                  ? _CyberTableRow(ticket: ticket, ref: ref)
                  : _MobileTicketCard(ticket: ticket, ref: ref);
            },
          ),
        ),
      ],
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
                    itemBuilder: (_) => ['En attente', 'Terminé', 'Livré']
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
                    itemBuilder: (_) => ['En attente', 'Terminé', 'Livré']
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
    case 'Terminé': return Colors.greenAccent;
    case 'Livré': return Colors.purpleAccent;
    default: return _neonCyan;
  }
}

IconData _statusIcon(String? status) {
  switch (status) {
    case 'En attente': return Icons.hourglass_empty;
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
  final statuses = ['En attente', 'Terminé', 'Livré'];
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

  String _deviceLockType = 'Aucun';
  final _lockCodeCtrl = TextEditingController();
  bool _lockCodeVisible = false;
  final Set<String> _conditionChecklist = {};
  int _currentStep = 0;
  final Map<String, String?> _fieldErrors = {};

  bool _isLoading = false;
  bool _showDetails = false;
  String _billingType = 'parts_and_labor';
  final List<Map<String, dynamic>> _preSelectedParts = [];
  bool _showPartsSearch = false;
  String _partsSearchQuery = '';
  List<Map<String, dynamic>> _partsSearchResults = [];
  bool _partsSearchLoading = false;

  static const _brandSuggestions = [
    'Samsung', 'Apple', 'Huawei', 'Xiaomi', 'Oppo', 'Vivo',
    'Realme', 'Tecno', 'Infinix', 'Nokia', 'Autre',
  ];

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
              child: isDesktop
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildClientSection()),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildSectionTitle('2. L\'appareil', Icons.smartphone),
                                    _buildTextField(_deviceCtrl, 'Modèle de l\'appareil * (ex: Galaxy S23)', icon: Icons.phone_android, errorKey: 'device_name'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(child: _buildProblemSection()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildBillingTypeSelector(),
                          if (_billingType != 'labor_only') ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => setState(() {}),
                              icon: const Icon(Icons.add_shopping_cart, size: 16),
                              label: const Text('Ajouter pièce(s)'),
                              style: OutlinedButton.styleFrom(foregroundColor: _neonCyan, side: const BorderSide(color: _neonCyan)),
                            ),
                            _buildPreSelectedPartsList(),
                          ],
                          const SizedBox(height: 12),
                          _buildFinancialSection(),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => setState(() => _showDetails = !_showDetails),
                              icon: Icon(_showDetails ? Icons.expand_less : Icons.expand_more, color: _neonCyan),
                              label: Text(_showDetails ? 'إخفاء التفاصيل ▲' : 'تفاصيل إضافية ▼', style: const TextStyle(color: _neonCyan)),
                            ),
                          ),
                          if (_showDetails) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      _buildDeviceExtrasSection(),
                                      const SizedBox(height: 16),
                                      _buildSecuritySection(),
                                    ],
                                  ),
                                ),
                                Container(width: 1, color: _glassBorder),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      _buildConditionSection(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                   : Stepper(
                      type: StepperType.vertical,
                      currentStep: _currentStep,
                      onStepContinue: () {
                        final maxStep = _showDetails ? 6 : 4;
                        if (_currentStep < maxStep) {
                          setState(() => _currentStep += 1);
                        } else {
                          _submit();
                        }
                      },
                      onStepCancel: () {
                        if (_currentStep > 0) {
                          setState(() => _currentStep -= 1);
                        }
                      },
                      onStepTapped: (step) => setState(() => _currentStep = step),
                      controlsBuilder: (context, details) => Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            if (_currentStep > 0)
                              TextButton(
                                onPressed: details.onStepCancel,
                                child: const Text('Précédent', style: TextStyle(color: _textMuted)),
                              ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: details.onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _neonCyan,
                                foregroundColor: _bgCarbon,
                              ),
                              child: Text(_currentStep == (_showDetails ? 6 : 4) ? 'Terminer' : 'Suivant'),
                            ),
                          ],
                        ),
                      ),
                      steps: <Step>[
                        Step(
                          title: const Text('Client', style: TextStyle(color: Colors.white, fontSize: 11)),
                          content: Column(
                            children: [
                              _buildClientSection(),
                              if (!_showDetails)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Center(
                                    child: TextButton.icon(
                                      onPressed: () => setState(() => _showDetails = true),
                                      icon: const Icon(Icons.expand_more, color: _neonCyan, size: 18),
                                      label: const Text('تفاصيل إضافية ▼', style: TextStyle(color: _neonCyan, fontSize: 12)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          isActive: _currentStep >= 0,
                        ),
                        Step(
                          title: const Text('Facturation', style: TextStyle(color: Colors.white, fontSize: 11)),
                          content: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                _buildBillingTypeSelector(),
                                if (_billingType != 'labor_only') ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() {}),
                                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                                    label: const Text('Ajouter pièce(s)'),
                                    style: OutlinedButton.styleFrom(foregroundColor: _neonCyan, side: const BorderSide(color: _neonCyan)),
                                  ),
                                  _buildPreSelectedPartsList(),
                                ],
                              ],
                            ),
                          ),
                          isActive: _currentStep >= 1,
                        ),
                        Step(
                          title: const Text('Appareil', style: TextStyle(color: Colors.white, fontSize: 11)),
                          content: _showDetails
                              ? _buildDeviceSection()
                              : _buildTextField(_deviceCtrl, 'Modèle de l\'appareil * (ex: Galaxy S23)', icon: Icons.phone_android, errorKey: 'device_name'),
                          isActive: _currentStep >= 2,
                        ),
                        if (_showDetails)
                          Step(
                            title: const Text('Sécurité', style: TextStyle(color: Colors.white, fontSize: 11)),
                            content: _buildSecuritySection(),
                            isActive: _currentStep >= 3,
                          ),
                        if (_showDetails)
                          Step(
                            title: const Text('État', style: TextStyle(color: Colors.white, fontSize: 11)),
                            content: _buildConditionSection(),
                            isActive: _currentStep >= 4,
                          ),
                        Step(
                          title: const Text('Problème', style: TextStyle(color: Colors.white, fontSize: 11)),
                          content: _buildProblemSection(),
                          isActive: _currentStep >= (_showDetails ? 5 : 3),
                        ),
                        Step(
                          title: const Text('Finances', style: TextStyle(color: Colors.white, fontSize: 11)),
                          content: _buildFinancialSection(),
                          isActive: _currentStep >= (_showDetails ? 6 : 4),
                        ),
                      ],
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

  // --- Billing Type Selector ---
  Widget _buildBillingTypeSelector() {
    final options = [
      {'value': 'labor_only',      'label': 'Main d\'œuvre', 'icon': Icons.build},
      {'value': 'parts_only',       'label': 'Pièces',        'icon': Icons.inventory_2},
      {'value': 'parts_and_labor',  'label': 'Pièces + M.O',  'icon': Icons.handyman},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type de facturation', style: TextStyle(color: _textMuted, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final selected = _billingType == opt['value'];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _billingType = opt['value'] as String),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? _neonCyan.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                      border: Border.all(color: selected ? _neonCyan : Colors.white24, width: selected ? 1.5 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(opt['icon'] as IconData, color: selected ? _neonCyan : Colors.white54, size: 18),
                        const SizedBox(height: 4),
                        Text(opt['label'] as String, textAlign: TextAlign.center, style: TextStyle(color: selected ? _neonCyan : Colors.white70, fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Pre-selected Parts ---
  Widget _buildPreSelectedPartsList() {
    if (_preSelectedParts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Pièces pré-sélectionnées (${_preSelectedParts.length})', style: const TextStyle(color: _textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        ..._preSelectedParts.asMap().entries.map((entry) {
          final i = entry.key;
          final part = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white12)),
            child: Row(
              children: [
                Expanded(child: Text('${part['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 13))),
                Text('×${part['qty']}  ${part['price']} DA', style: const TextStyle(color: _neonCyan, fontSize: 12)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _preSelectedParts.removeAt(i)),
                  child: const Icon(Icons.close, size: 16, color: Colors.white38),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _searchPartsInline(String query) async {
    setState(() => _partsSearchLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('products')
          .select('id, product_name, reference_price, purchase_price, stock_quantity')
          .ilike('product_name', '%$query%')
          .gt('stock_quantity', 0)
          .limit(10);
      if (mounted) setState(() { _partsSearchResults = List<Map<String, dynamic>>.from(res); _partsSearchLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _partsSearchResults = []; _partsSearchLoading = false; });
    }
  }

  void _addPartToPreSelected(Map<String, dynamic> product) {
    final existing = _preSelectedParts.indexWhere((p) => p['product_id'] == product['id']);
    setState(() {
      if (existing >= 0) {
        _preSelectedParts[existing]['qty'] = (_preSelectedParts[existing]['qty'] as int) + 1;
      } else {
        _preSelectedParts.add({
          'product_id': product['id'],
          'name': product['product_name']?.toString() ?? 'Pièce',
          'qty': 1,
          'price': (product['reference_price'] as num?)?.toDouble() ?? 0,
          'shop_cost_price': (product['purchase_price'] as num?)?.toDouble() ?? 0,
        });
      }
      _partsSearchResults = [];
      _partsSearchQuery = '';
    });
  }

  Widget _buildInlinePartsSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher une pièce...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          onChanged: (v) {
            setState(() => _partsSearchQuery = v);
            if (v.length >= 2) { _searchPartsInline(v); } else { setState(() => _partsSearchResults = []); }
          },
        ),
        if (_partsSearchLoading)
          const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _neonCyan)))
        else if (_partsSearchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _partsSearchResults.length,
              itemBuilder: (context, index) {
                final product = _partsSearchResults[index];
                final stock = product['stock_quantity'] ?? 0;
                final price = (product['reference_price'] as num?)?.toDouble() ?? 0;
                return ListTile(
                  dense: true,
                  title: Text(product['product_name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text('Stock: $stock  •  Prix: ${price.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: IconButton(icon: const Icon(Icons.add_circle_outline, color: _neonCyan, size: 20), onPressed: () => _addPartToPreSelected(product)),
                );
              },
            ),
          ),
      ],
    );
  }

  // --- Section Builders ---
  Widget _buildClientSection() {
    return Column(
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
              final custError = _fieldErrors['customer'];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCustomerId,
                    dropdownColor: _panelDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Sélectionner un client *', Icons.people, error: custError != null),
                    items: custs.map((c) => DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Text('${c['full_name']} — ${c['phone_number'] ?? ''}'),
                    )).toList(),
                    onChanged: (v) => setState(() {
                      _selectedCustomerId = v;
                      _fieldErrors.remove('customer');
                    }),
                  ),
                  if (custError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 12),
                      child: Text(custError, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDeviceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('2. L\'appareil', Icons.smartphone),
        _buildTextField(_deviceCtrl, 'Modèle de l\'appareil * (ex: Galaxy S23)', icon: Icons.phone_android, errorKey: 'device_name'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _deviceType,
          dropdownColor: _panelDark,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Type d\'appareil', Icons.devices),
          items: ['Smartphone', 'Tablette', 'PC Portable', 'PC Bureau', 'Console', 'Montre connectée', 'Autre']
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _deviceType = v),
        ),
        const SizedBox(height: 12),
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return _brandSuggestions;
            return _brandSuggestions.where((b) => b.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
            _brandCtrl.text = ctrl.text;
            return _buildTextField(ctrl, 'Marque (ex: Samsung, Apple)', icon: Icons.badge);
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _imeiCtrl,
                maxLength: 15,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration('IMEI', Icons.qr_code).copyWith(
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: _textMuted, size: 18),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _imeiCtrl.text = data!.text!.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 15);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField(_serialCtrl, 'N° de série', icon: Icons.confirmation_number)),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceExtrasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _deviceType,
          dropdownColor: _panelDark,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Type d\'appareil', Icons.devices),
          items: ['Smartphone', 'Tablette', 'PC Portable', 'PC Bureau', 'Console', 'Montre connectée', 'Autre']
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _deviceType = v),
        ),
        const SizedBox(height: 12),
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return _brandSuggestions;
            return _brandSuggestions.where((b) => b.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
            _brandCtrl.text = ctrl.text;
            return _buildTextField(ctrl, 'Marque (ex: Samsung, Apple)', icon: Icons.badge);
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _imeiCtrl,
                maxLength: 15,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration('IMEI', Icons.qr_code).copyWith(
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: _textMuted, size: 18),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _imeiCtrl.text = data!.text!.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 15);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField(_serialCtrl, 'N° de série', icon: Icons.confirmation_number)),
          ],
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('3. Sécurité de l\'appareil', Icons.lock_outline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['Aucun', 'PIN', 'Schéma', 'Mot de passe', 'Empreinte'].map((type) {
            final selected = _deviceLockType == type;
            return ChoiceChip(
              label: Text(type, style: TextStyle(color: selected ? _bgCarbon : _textMuted, fontSize: 12)),
              selected: selected,
              selectedColor: _neonCyan,
              backgroundColor: _panelDark,
              side: BorderSide(color: selected ? _neonCyan : _glassBorder),
              onSelected: (v) => setState(() {
                _deviceLockType = type;
                if (type == 'Aucun' || type == 'Empreinte') _lockCodeCtrl.clear();
              }),
            );
          }).toList(),
        ),
        if (_deviceLockType != 'Aucun' && _deviceLockType != 'Empreinte') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _lockCodeCtrl,
            obscureText: !_lockCodeVisible,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration('Code / Schéma / Mot de passe', Icons.vpn_key).copyWith(
              helperText: 'Confidentiel — visible uniquement par le personnel autorisé',
              helperStyle: const TextStyle(color: _textMuted, fontSize: 10),
              suffixIcon: IconButton(
                icon: Icon(_lockCodeVisible ? Icons.visibility : Icons.visibility_off, color: _textMuted, size: 18),
                onPressed: () => setState(() => _lockCodeVisible = !_lockCodeVisible),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConditionSection() {
    const conditions = [
      ('Écran intact', Icons.smartphone),
      ('Caméra fonctionne', Icons.camera_alt),
      ('Boutons OK', Icons.touch_app),
      ('Chargeur inclus', Icons.cable),
      ('Coque incluse', Icons.cases_outlined),
      ('Batterie OK', Icons.battery_std),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('4. État & Accessoires', Icons.checklist),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: conditions.map((c) {
            final checked = _conditionChecklist.contains(c.$1);
            return FilterChip(
              label: Text(c.$1, style: TextStyle(color: checked ? _bgCarbon : _textMuted, fontSize: 11)),
              selected: checked,
              selectedColor: _neonEmerald.withOpacity(0.3),
              backgroundColor: _panelDark,
              checkmarkColor: _neonEmerald,
              side: BorderSide(color: checked ? _neonEmerald.withOpacity(0.5) : _glassBorder),
              avatar: Icon(c.$2, size: 16, color: checked ? _neonEmerald : _textMuted),
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _conditionChecklist.add(c.$1);
                  } else {
                    _conditionChecklist.remove(c.$1);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildTextField(_accessoriesCtrl, 'Accessoires fournis (détails)', icon: Icons.backpack, maxLines: 2),
      ],
    );
  }

  Widget _buildProblemSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('5. Problème & Diagnostic', Icons.warning_amber_rounded),
        _buildTextField(_issueCtrl, 'Problème signalé par le client *', icon: Icons.report_problem, maxLines: 2, errorKey: 'issue_description'),
        const SizedBox(height: 12),
        _buildDiagnosticAIButton(),
        const SizedBox(height: 12),
        _buildTextField(_diagCtrl, 'Bilan visuel / État initial', icon: Icons.visibility_outlined, maxLines: 2),
      ],
    );
  }

  Widget _buildFinancialSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('6. Finances', Icons.attach_money),
        _buildTextField(_costCtrl, 'Coût estimé (Pièces incluses)', icon: Icons.calculate, isNumber: true, suffix: 'DA'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField(_advanceCtrl, 'Acompte (Avance)', icon: Icons.payments_outlined, isNumber: true, suffix: 'DA')),
            if (_billingType != 'parts_only') ...[
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(_laborCtrl, 'Main d\'œuvre (M.O)', icon: Icons.handyman_outlined, isNumber: true, suffix: 'DA')),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _buildPriceEstimatorButton(),
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

  Widget _buildTextField(TextEditingController ctrl, String label, {required IconData icon, int maxLines = 1, bool isNumber = false, String? suffix, String? errorKey}) {
    final error = errorKey != null ? _fieldErrors[errorKey] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : null,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(label, icon, error: error != null).copyWith(
            suffixText: suffix, 
            suffixStyle: const TextStyle(color: _textMuted),
          ),
          onChanged: error != null ? (_) => setState(() => _fieldErrors.remove(errorKey)) : null,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool error = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: error ? Colors.redAccent : _textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: error ? Colors.redAccent : _textMuted, size: 18),
      filled: true,
      fillColor: _bgCarbon.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: error ? Colors.redAccent : _glassBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: error ? Colors.redAccent : _glassBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: error ? Colors.redAccent : _neonCyan)),
    );
  }

  Future<void> _submit() async {
    final device = _deviceCtrl.text.trim();
    final issue = _issueCtrl.text.trim();
    final isAnon = _isAnonymous || _selectedCustomerId == null;

    _fieldErrors.clear();

    if (!_isAnonymous && _selectedCustomerId == null) {
      _fieldErrors['customer'] = 'Sélectionnez un client';
    }
    if (device.isEmpty) {
      _fieldErrors['device_name'] = 'Modèle obligatoire';
    }
    if (issue.isEmpty) {
      _fieldErrors['issue_description'] = 'Problème obligatoire';
    }

    if (_fieldErrors.isNotEmpty) {
      setState(() {});
      if (!isAnon) return;
    }

    if (_fieldErrors.isNotEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final client = widget.ref.read(supabaseClientProvider);
      final user = Supabase.instance.client.auth.currentUser;
      final qrHash = 'LR-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999).toString().padLeft(4, '0')}';
      
      final cost = double.tryParse(_costCtrl.text) ?? 0;
      final advance = double.tryParse(_advanceCtrl.text) ?? 0;
      final labor = double.tryParse(_laborCtrl.text) ?? 0;

      final newTicket = await client.from('repair_tickets').insert({
        'customer_id': _isAnonymous ? null : _selectedCustomerId,
        'client_name_temp': _isAnonymous ? _anonNameCtrl.text.trim() : null,
        'client_phone_temp': _isAnonymous ? _anonPhoneCtrl.text.trim() : null,
        'worker_id': user?.id,
        'device_type': _deviceType,
        'device_brand': _brandCtrl.text.trim(),
        'device_name': device,
        'issue_description': issue,
        'imei': _imeiCtrl.text.trim(),
        'serial_number': _serialCtrl.text.trim(),
        'device_lock_type': _deviceLockType,
        'device_lock_code': _lockCodeCtrl.text.trim().isEmpty ? null : _lockCodeCtrl.text.trim(),
        'device_password': _passwordCtrl.text.trim(),
        'accessories_included': _accessoriesCtrl.text.trim().isEmpty ? null : _accessoriesCtrl.text.trim(),
        'pre_diagnostic': _diagCtrl.text.trim(),
        'billing_type': _billingType,
        'estimated_cost': cost,
        'final_cost': cost,
        'advance_payment': advance,
        'labor_cost': _billingType == 'parts_only' ? 0.0 : labor,
        'qr_code_hash': qrHash,
        'status': 'En attente',
        'payment_status': 'Non payé',
        'paid_amount': 0,
        'estimated_completion_date': _estimatedCompletionDate?.toIso8601String().substring(0, 10),
      }).select().single();

      // Batch insert pre-selected parts
      if (_preSelectedParts.isNotEmpty) {
        final ticketId = newTicket['id'] as String;
        for (final part in _preSelectedParts) {
          await client.from('repair_parts').insert({
            'ticket_id': ticketId,
            'product_id': part['product_id'],
            'quantity': part['qty'],
            'charged_price': part['price'],
            'shop_cost_price': part['shop_cost_price'],
            'part_status': 'Utilisé',
          });
        }
      }
      
      widget.ref.invalidate(_ticketsProvider);
      if (mounted) {
        Navigator.pop(context);
        _showReceiptDialog(Map<String, dynamic>.from(newTicket), _isAnonymous ? _anonNameCtrl.text.trim() : null, _isAnonymous ? _anonPhoneCtrl.text.trim() : null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReceiptDialog(Map<String, dynamic> ticket, String? anonName, String? anonPhone) {
    final isAnon = ticket['customer_id'] == null;
    final clientName = isAnon ? (anonName?.isNotEmpty == true ? anonName! : 'Client Anonyme') : 'Client';
    final qrData = 'LAIDANI:TICKET:${ticket['id']}:${ticket['qr_code_hash'] ?? ''}';
    final estimatedCost = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
    final advance = (ticket['advance_payment'] as num?)?.toDouble() ?? 0;
    final remaining = estimatedCost - advance - ((ticket['discount'] as num?)?.toDouble() ?? 0);
    final createdAt = ticket['created_at']?.toString().substring(0, 16) ?? '';
    final estimatedDate = ticket['estimated_completion_date']?.toString() ?? '';
    final deviceName = ticket['device_name'] ?? '';
    final imei = ticket['imei'] ?? '';
    final issue = ticket['issue_description'] ?? '';
    final ticketId = ticket['qr_code_hash']?.toString().substring(0, 8) ?? ticket['id']?.toString().substring(0, 8) ?? '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 1.5)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: _neonCyan),
            const SizedBox(width: 12),
            const Expanded(child: Text('Bon de dépôt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            IconButton(
              icon: const Icon(Icons.close, color: _textMuted),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('N° Ticket', style: TextStyle(color: _textMuted, fontSize: 11)),
                          Text('#$ticketId', style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Date', style: TextStyle(color: _textMuted, fontSize: 11)),
                          Text(createdAt, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _receiptRow('Client', clientName),
                if (!isAnon) ...[
                  _receiptRow('Téléphone', anonPhone ?? ''),
                ],
                _receiptRow('Appareil', deviceName),
                if (imei.isNotEmpty) _receiptRow('IMEI', imei),
                if (issue.isNotEmpty) _receiptRow('Problème', issue),
                const Divider(color: _glassBorder, height: 24),
                _receiptRow('Coût estimé', '${estimatedCost.toStringAsFixed(0)} DA'),
                if (advance > 0) _receiptRow('Avance', '${advance.toStringAsFixed(0)} DA'),
                _receiptRow('Reste à payer', '${remaining.toStringAsFixed(0)} DA'),
                if (estimatedDate.isNotEmpty) _receiptRow('Délai estimé', estimatedDate),
                const SizedBox(height: 16),
                Center(
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 120,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(color: _bgCarbon),
                    dataModuleStyle: const QrDataModuleStyle(color: _bgCarbon),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 14),
                      SizedBox(width: 8),
                      Expanded(child: Text('Nous ne sommes pas responsables des données personnelles sur l\'appareil.', style: TextStyle(color: Colors.orangeAccent, fontSize: 10))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Imprimer / PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _neonCyan,
              side: const BorderSide(color: _neonCyan),
            ),
            onPressed: () => _showPrintOptions(ticket, anonName, anonPhone),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer', style: TextStyle(color: _textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _textMuted, fontSize: 11)),
          Flexible(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  void _showPrintOptions(Map<String, dynamic> ticket, String? anonName, String? anonPhone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan)),
        title: const Text('Imprimer', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _printOption(ctx, Icons.receipt_long, 'Bon client seul (A4)', 'Reçu détaillé pour le client', () {
              Navigator.pop(ctx);
              _printDocument(ticket, anonName, anonPhone, includeSticker: false);
            }),
            const SizedBox(height: 8),
            _printOption(ctx, Icons.label_outline, 'Étiquette appareil seule (50mm)', 'Autocollant à coller au dos du téléphone', () {
              Navigator.pop(ctx);
              _printDocument(ticket, anonName, anonPhone, includeSticker: true, stickerOnly: true);
            }),
            const SizedBox(height: 8),
            _printOption(ctx, Icons.copy_all, 'Imprimer les deux (A4 + Étiquette)', 'Bon client + étiquette appareil', () {
              Navigator.pop(ctx);
              _printDocument(ticket, anonName, anonPhone, includeSticker: true);
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: _textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _printOption(BuildContext ctx, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bgCarbon.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: _neonCyan, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: _textMuted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _printDocument(Map<String, dynamic> ticket, String? anonName, String? anonPhone, {required bool includeSticker, bool stickerOnly = false}) async {
    final pdf = pw.Document();
    final isAnon = ticket['customer_id'] == null;
    final clientName = isAnon ? (anonName?.isNotEmpty == true ? anonName! : 'Client Anonyme') : 'Client';
    final createdAt = ticket['created_at']?.toString().substring(0, 16) ?? '';
    final ticketId = ticket['qr_code_hash']?.toString().substring(0, 8) ?? ticket['id']?.toString().substring(0, 8) ?? '';
    final deviceName = ticket['device_name'] ?? '';
    final imei = ticket['imei'] ?? '';
    final issue = ticket['issue_description'] ?? '';
    final estimatedCost = (ticket['estimated_cost'] as num?)?.toDouble() ?? 0;
    final advance = (ticket['advance_payment'] as num?)?.toDouble() ?? 0;
    final discount = (ticket['discount'] as num?)?.toDouble() ?? 0;
    final remaining = estimatedCost - advance - discount;
    final estimatedDate = ticket['estimated_completion_date']?.toString() ?? '';
    final qrData = 'LAIDANI:TICKET:${ticket['id']}:${ticket['qr_code_hash'] ?? ''}';
    final phone = isAnon ? (anonPhone ?? '') : '';

    if (!stickerOnly) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('LaidaniRepair', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('Bon de dépôt', style: pw.TextStyle(fontSize: 14))),
              pw.SizedBox(height: 16),
              _pdfRow('N° Ticket', '#$ticketId'),
              _pdfRow('Date', createdAt),
              _pdfRow('Client', clientName),
              if (phone.isNotEmpty) _pdfRow('Téléphone', phone),
              _pdfRow('Appareil', deviceName),
              if (imei.isNotEmpty) _pdfRow('IMEI', imei),
              if (issue.isNotEmpty) _pdfRow('Problème', issue),
              pw.Divider(),
              _pdfRow('Coût estimé', '${estimatedCost.toStringAsFixed(0)} DA'),
              if (advance > 0) _pdfRow('Avance', '${advance.toStringAsFixed(0)} DA'),
              _pdfRow('Reste à payer', '${remaining.toStringAsFixed(0)} DA'),
              if (estimatedDate.isNotEmpty) _pdfRow('Délai estimé', estimatedDate),
              pw.SizedBox(height: 16),
              pw.Center(child: pw.BarcodeWidget(data: qrData, barcode: pw.Barcode.qrCode(), width: 150, height: 150)),
              pw.SizedBox(height: 12),
              pw.Center(child: pw.Text('⚠ Nous ne sommes pas responsables des données\npersonnelles présentes sur l\'appareil.', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
              pw.SizedBox(height: 20),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Signature client :', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 150, child: pw.Divider()),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Date : __/__/____', style: pw.TextStyle(fontSize: 10)),
                ]),
              ]),
            ],
          ),
        ),
      );
    }

    if (includeSticker) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(141.7, 85.0), // 50mm x 30mm
          margin: pw.EdgeInsets.all(4),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('🔧 LAIDANI REPAIR', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(clientName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text('$deviceName — ${phone.isNotEmpty ? phone : ''}', style: pw.TextStyle(fontSize: 6)),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.BarcodeWidget(
                    data: qrData,
                    barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.low),
                    width: 70, height: 70,
                  ),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('N° #$ticketId', style: pw.TextStyle(fontSize: 5, font: pw.Font.courier())),
                        pw.Text('Date: ${createdAt.substring(0, 10)}', style: pw.TextStyle(fontSize: 5)),
                        pw.SizedBox(height: 4),
                        pw.Text('⚠ Conserver', style: pw.TextStyle(fontSize: 5)),
                        pw.Text('ce ticket pour', style: pw.TextStyle(fontSize: 5)),
                        pw.Text('le suivi.', style: pw.TextStyle(fontSize: 5)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await Printing.layoutPdf(onLayout: (_) => pdf.save());
      } else {
        await Printing.sharePdf(bytes: await pdf.save(), filename: 'depot_$ticketId.pdf');
      }
    } catch (_) {}
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}