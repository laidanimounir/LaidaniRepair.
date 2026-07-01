import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

const _pageSize = 30;

final _profilesListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('profiles').select('id, full_name').order('full_name');
  return List<Map<String, dynamic>>.from(data);
});

final _activeAttendanceProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final rows = await client.from('attendance')
      .select('*')
      .eq('worker_id', user.id)
      .filter('check_out', 'is', null)
      .order('check_in', ascending: false)
      .limit(1);
  return rows.isNotEmpty ? rows.first : null;
});

final _dateFilterProvider = StateProvider<String?>((ref) => '__this_month__');
final _workerFilterProvider = StateProvider<String?>((ref) => null);
final _attendancePageProvider = StateProvider<int>((ref) => 0);

final _attendanceHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(_dateFilterProvider);
  ref.watch(_workerFilterProvider);
  ref.watch(_attendancePageProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  final isOwner = ref.watch(isOwnerProvider);
  if (user == null) return [];
  final dateFilter = ref.watch(_dateFilterProvider);
  final workerFilter = ref.watch(_workerFilterProvider);
  final page = ref.watch(_attendancePageProvider);

  var sel = client.from('attendance').select('*, profiles(full_name)');
  if (!isOwner) {
    sel = sel.eq('worker_id', user.id);
  } else if (workerFilter != null && workerFilter.isNotEmpty) {
    sel = sel.eq('worker_id', workerFilter);
  }
  if (dateFilter != null) {
    final now = DateTime.now();
    DateTime start;
    switch (dateFilter) {
      case '__today__':
        start = DateTime(now.year, now.month, now.day);
        break;
      case '__yesterday__':
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        sel = sel.gte('check_in', start.toIso8601String()).lt('check_in', DateTime(now.year, now.month, now.day).toIso8601String());
        final data = await sel.order('check_in', ascending: false).range(page * _pageSize, (page + 1) * _pageSize - 1);
        return List<Map<String, dynamic>>.from(data);
      case '__this_week__':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case '__this_month__':
        start = DateTime(now.year, now.month, 1);
        break;
      case '__last_month__':
        start = DateTime(now.year, now.month - 1, 1);
        sel = sel.gte('check_in', start.toIso8601String()).lt('check_in', DateTime(now.year, now.month, 1).toIso8601String());
        final data = await sel.order('check_in', ascending: false).range(page * _pageSize, (page + 1) * _pageSize - 1);
        return List<Map<String, dynamic>>.from(data);
      default:
        start = DateTime(now.year, now.month, 1);
    }
    sel = sel.gte('check_in', start.toIso8601String());
  }
  final data = await sel.order('check_in', ascending: false).range(page * _pageSize, (page + 1) * _pageSize - 1);
  return List<Map<String, dynamic>>.from(data);
});

final _activeWorkersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('attendance')
      .select('*, profiles(full_name)')
      .filter('check_out', 'is', null)
      .order('check_in', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});

final _attendanceStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final isOwner = ref.watch(isOwnerProvider);
  final user = ref.watch(currentUserProvider);
  final dateFilter = ref.watch(_dateFilterProvider);
  final workerFilter = ref.watch(_workerFilterProvider);
  if (user == null) return {};

  final now = DateTime.now();
  DateTime start;
  switch (dateFilter ?? '__this_month__') {
    case '__today__':
      start = DateTime(now.year, now.month, now.day);
      break;
    case '__this_week__':
      final monday = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(monday.year, monday.month, monday.day);
      break;
    default:
      start = DateTime(now.year, now.month, 1);
  }

  var sel = client.from('attendance').select('*, profiles(full_name)').gte('check_in', start.toIso8601String());
  if (!isOwner) {
    sel = sel.eq('worker_id', user.id);
  } else if (workerFilter != null && workerFilter.isNotEmpty) {
    sel = sel.eq('worker_id', workerFilter);
  }

  final rows = await sel;
  int totalEntries = rows.length;
  int totalCheckouts = rows.where((r) => r['check_out'] != null).length;
  int currentlyWorking = rows.where((r) => r['check_out'] == null).length;
  double totalHours = 0;
  final perWorker = <String, Map<String, dynamic>>{};

  for (final r in rows) {
    final wId = r['worker_id'] as String;
    final wName = r['profiles']?['full_name'] ?? wId.substring(0, 8);
    final cin = DateTime.tryParse(r['check_in']?.toString() ?? '');
    final cout = DateTime.tryParse(r['check_out']?.toString() ?? '');
    final dur = cin != null && cout != null ? cout.difference(cin).inMinutes / 60.0 : 0;
    totalHours += dur;

    perWorker.putIfAbsent(wName, () => {'entries': 0, 'hours': 0.0, 'open': 0});
    perWorker[wName]!['entries'] = (perWorker[wName]!['entries'] as int) + 1;
    perWorker[wName]!['hours'] = (perWorker[wName]!['hours'] as double) + dur;
    if (cout == null) perWorker[wName]!['open'] = (perWorker[wName]!['open'] as int) + 1;
  }

  return {
    'totalEntries': totalEntries,
    'totalCheckouts': totalCheckouts,
    'currentlyWorking': currentlyWorking,
    'totalHours': totalHours,
    'perWorker': perWorker.entries.map((e) => {
      'name': e.key,
      'entries': e.value['entries'],
      'hours': e.value['hours'],
      'open': e.value['open'],
    }).toList(),
  };
});

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final _scrollCtrl = ScrollController();
  bool _showStats = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 && !_isLoadingMore) {
      _loadMore();
    }
  }

  void _loadMore() {
    _isLoadingMore = true;
    ref.read(_attendancePageProvider.notifier).state++;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isLoadingMore = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(_activeAttendanceProvider);
    final historyAsync = ref.watch(_attendanceHistoryProvider);
    final activeWorkersAsync = ref.watch(_activeWorkersProvider);
    final statsAsync = ref.watch(_attendanceStatsProvider);
    final isOwner = ref.watch(isOwnerProvider);
    final dateFilter = ref.watch(_dateFilterProvider);
    final workerFilter = ref.watch(_workerFilterProvider);
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
                  child: const Icon(Icons.access_time, color: _neonCyan, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text('POINTAGE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5))),
                IconButton(icon: Icon(_showStats ? Icons.list : Icons.bar_chart, color: _textMuted), onPressed: () => setState(() => _showStats = !_showStats), tooltip: _showStats ? 'Historique' : 'Statistiques'),
                IconButton(icon: const Icon(Icons.refresh, color: _textMuted), onPressed: () { ref.invalidate(_activeAttendanceProvider); ref.invalidate(_attendanceHistoryProvider); ref.invalidate(_activeWorkersProvider); ref.invalidate(_attendanceStatsProvider); }),
              ],
            ),
          ),
          activeAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (active) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                onPressed: () => _handleAttendance(ref, active == null ? 'check_in' : 'check_out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: active == null ? _neonEmerald : Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(active == null ? Icons.login : Icons.logout, size: 28),
                label: Text(active == null ? 'POINTAGE ENTRÉE' : 'POINTAGE SORTIE', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
              ),
            ),
          ),
          _buildFilters(dateFilter, workerFilter, isOwner),
          if (_showStats)
            Expanded(child: _buildStats(statsAsync))
          else ...[
            if (isOwner)
              _buildActiveWorkers(activeWorkersAsync),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Text('HISTORIQUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.add, size: 18, color: _neonCyan), onPressed: () => _showManualEntryDialog(), tooltip: 'Ajouter manuellement'),
                  IconButton(icon: const Icon(Icons.file_download, size: 18, color: _textMuted), onPressed: () => _exportCsv(ref), tooltip: 'Exporter CSV'),
                ],
              ),
            ),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
                error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
                data: (rows) {
                  if (rows.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.hourglass_empty, color: _textMuted, size: 48), const SizedBox(height: 12), const Text('Aucun pointage.', style: TextStyle(color: _textMuted))]));
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: rows.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= rows.length) return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2)));
                      final r = rows[index];
                      final cin = DateTime.tryParse(r['check_in']?.toString() ?? '');
                      final cout = DateTime.tryParse(r['check_out']?.toString() ?? '');
                      final dur = cin != null && cout != null ? cout.difference(cin) : null;
                      final wName = r['profiles']?['full_name'] ?? '';
                      return Dismissible(
                        key: Key(r['id'].toString()),
                        direction: isOwner ? DismissDirection.endToStart : DismissDirection.none,
                        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.redAccent, child: const Icon(Icons.delete, color: Colors.white)),
                        confirmDismiss: (_) async => await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: _panelDark, title: const Text('Supprimer ?', style: TextStyle(color: Colors.redAccent)), content: const Text('Supprimer ce pointage définitivement ?', style: TextStyle(color: Colors.white)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer'))])),
                        onDismissed: (_) => _deleteEntry(r['id'] as String),
                        child: GestureDetector(
                          onLongPress: isOwner ? () => _showEditEntryDialog(r) : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
                            child: Row(
                              children: [
                                Icon(cout != null ? Icons.check_circle : Icons.access_time, color: cout != null ? _neonEmerald : Colors.orangeAccent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (wName.isNotEmpty) Text(wName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Entrée: ${_fmtDt(cin)}', style: const TextStyle(color: _textMuted, fontSize: 11)),
                                      if (cout != null) Text('Sortie: ${_fmtDt(cout)}', style: const TextStyle(color: _textMuted, fontSize: 11)),
                                      if (dur != null) Text('Durée: ${dur.inHours}h ${dur.inMinutes % 60}min', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.w600)),
                                      if (r['notes'] != null) Text('Note: ${r['notes']}', style: const TextStyle(color: _textMuted, fontSize: 10, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),
                                if (isOwner) IconButton(icon: const Icon(Icons.edit, size: 16, color: _textMuted), onPressed: () => _showEditEntryDialog(r), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters(String? dateFilter, String? workerFilter, bool isOwner) {
    final filters = {
      '__today__': "Aujourd'hui",
      '__yesterday__': 'Hier',
      '__this_week__': 'Cette semaine',
      '__this_month__': 'Ce mois',
      '__last_month__': 'Mois dernier',
      null: 'Tout',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: filters.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(e.value, style: TextStyle(color: dateFilter == e.key ? _bgCarbon : _textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                    selected: dateFilter == e.key,
                    selectedColor: _neonCyan,
                    backgroundColor: _panelDark,
                    side: BorderSide(color: dateFilter == e.key ? _neonCyan : _glassBorder),
                    onSelected: (_) {
                      ref.read(_dateFilterProvider.notifier).state = e.key;
                      ref.read(_attendancePageProvider.notifier).state = 0;
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                )).toList(),
              ),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(width: 8),
            _buildWorkerDropdown(workerFilter),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkerDropdown(String? workerFilter) {
    final profilesAsync = ref.watch(_profilesListProvider);
    return SizedBox(
      width: 150,
      child: profilesAsync.when(
        data: (profiles) => DropdownButtonFormField<String>(
          value: workerFilter,
          isDense: true,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), border: OutlineInputBorder()),
          dropdownColor: _panelDark,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          hint: const Text('Employé', style: TextStyle(color: _textMuted, fontSize: 12)),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(color: _textMuted))),
            ...profiles.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['full_name'] ?? '', style: const TextStyle(color: Colors.white)))),
          ],
          onChanged: (v) {
            ref.read(_workerFilterProvider.notifier).state = v;
            ref.read(_attendancePageProvider.notifier).state = 0;
          },
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildStats(AsyncValue<Map<String, dynamic>> statsAsync) {
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
      data: (stats) {
        if (stats.isEmpty) return Center(child: const Text('Aucune donnée.', style: TextStyle(color: _textMuted)));
        final perWorker = stats['perWorker'] as List<dynamic>? ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                _statCard('Entrées', '${stats['totalEntries']}', Icons.login, _neonCyan),
                const SizedBox(width: 12),
                _statCard('Sorties', '${stats['totalCheckouts']}', Icons.logout, _neonEmerald),
                const SizedBox(width: 12),
                _statCard('Présents', '${stats['currentlyWorking']}', Icons.person, Colors.orangeAccent),
                const SizedBox(width: 12),
                _statCard('Heures', '${(stats['totalHours'] as num).toStringAsFixed(1)}h', Icons.timer, Colors.purpleAccent),
              ],
            ),
            const SizedBox(height: 20),
            const Text('PAR EMPLOYÉ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...perWorker.map((w) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
              child: Row(
                children: [
                  Expanded(child: Text(w['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                  Text('${w['entries']} entrées', style: const TextStyle(color: _textMuted, fontSize: 11)),
                  const SizedBox(width: 12),
                  Text('${(w['hours'] as num).toStringAsFixed(1)}h', style: TextStyle(color: _neonCyan, fontSize: 13, fontWeight: FontWeight.bold)),
                  if ((w['open'] as int) > 0) ...[
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text('EN LIGNE', style: TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold))),
                  ],
                ],
              ),
            )),
          ],
        );
      },
    );
  }

  Widget _buildActiveWorkers(AsyncValue<List<Map<String, dynamic>>> async) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (workers) {
        if (workers.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: _neonEmerald.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _neonEmerald.withOpacity(0.3))),
          child: Row(
            children: [
              const Icon(Icons.groups, color: _neonEmerald, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${workers.length} présent(s): ${workers.map((w) => w['profiles']?['full_name'] ?? '?').join(', ')}',
                  style: const TextStyle(color: _neonEmerald, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Expanded _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _glassBorder)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAttendance(WidgetRef ref, String type) async {
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      if (type == 'check_in') {
        final activeRows = await client.from('attendance')
            .select('id')
            .eq('worker_id', user.id)
            .filter('check_out', 'is', null)
            .limit(1);
        if (activeRows.isNotEmpty) {
          if (mounted) _showSnack('Vous êtes déjà pointé. Terminez d\'abord le pointage actuel.', Colors.orangeAccent);
          return;
        }
        await client.from('attendance').insert({'worker_id': user.id, 'check_in': DateTime.now().toIso8601String()});
        if (mounted) _showSnack('Pointage entrée enregistré', _neonEmerald);
      } else {
        final rows = await client.from('attendance')
            .select('id')
            .eq('worker_id', user.id)
            .filter('check_out', 'is', null)
            .order('check_in', ascending: false)
            .limit(1);
        if (rows.isNotEmpty) {
          await client.from('attendance').update({'check_out': DateTime.now().toIso8601String()}).eq('id', rows.first['id']);
          if (mounted) _showSnack('Pointage sortie enregistré', Colors.redAccent);
        } else {
          if (mounted) _showSnack('Aucun pointage actif trouvé.', Colors.orangeAccent);
        }
      }
      ref.invalidate(_activeAttendanceProvider);
      ref.invalidate(_attendanceHistoryProvider);
      ref.invalidate(_activeWorkersProvider);
      ref.invalidate(_attendanceStatsProvider);
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', Colors.redAccent);
    }
  }

  Future<void> _showManualEntryDialog() async {
    final isOwner = ref.read(isOwnerProvider);
    if (!isOwner && mounted) {
      _showSnack('Réservé au propriétaire', Colors.orangeAccent);
      return;
    }
    final wCtrl = TextEditingController();
    final wNameCtrl = TextEditingController();
    String? selectedWorkerId;
    DateTime? cinDate = DateTime.now().subtract(const Duration(hours: 8));
    DateTime? coutDate = DateTime.now().subtract(const Duration(hours: 1));
    final notesCtrl = TextEditingController();
    final profilesAsync = ref.read(_profilesListProvider);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ajouter un pointage', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                profilesAsync.when(
                  data: (profiles) => DropdownButtonFormField<String>(
                    value: selectedWorkerId,
                    decoration: const InputDecoration(labelText: 'Employé', labelStyle: TextStyle(color: _textMuted)),
                    dropdownColor: _panelDark,
                    style: const TextStyle(color: Colors.white),
                    items: profiles.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['full_name'] ?? '', style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setDlg(() => selectedWorkerId = v),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                _dateTimePicker(ctx, 'Entrée', cinDate, (d) => setDlg(() => cinDate = d)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _dateTimePicker(ctx, 'Sortie', coutDate, (d) => setDlg(() => coutDate = d))),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => setDlg(() => coutDate = null), child: const Text('Sans sortie', style: TextStyle(color: _textMuted, fontSize: 11))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Notes', labelStyle: TextStyle(color: _textMuted)), maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, {'worker_id': selectedWorkerId, 'check_in': cinDate?.toIso8601String(), 'check_out': coutDate?.toIso8601String(), 'notes': notesCtrl.text.trim()}), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (result == null || result['worker_id'] == null) return;
    if (result['check_in'] == null && mounted) { _showSnack('Veuillez sélectionner une date d\'entrée.', Colors.orangeAccent); return; }

    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('attendance').insert({
        'worker_id': result['worker_id'],
        'check_in': result['check_in'],
        if (result['check_out'] != null) 'check_out': result['check_out'],
        if ((result['notes'] as String).isNotEmpty) 'notes': result['notes'],
      });
      ref.invalidate(_attendanceHistoryProvider);
      ref.invalidate(_attendanceStatsProvider);
      if (mounted) _showSnack('Pointage ajouté', _neonEmerald);
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', Colors.redAccent);
    }
  }

  void _showEditEntryDialog(Map<String, dynamic> r) async {
    final cinDate = DateTime.tryParse(r['check_in']?.toString() ?? '');
    final coutDate = DateTime.tryParse(r['check_out']?.toString() ?? '');
    DateTime? newCin = cinDate;
    DateTime? newCout = coutDate;
    final nCtrl = TextEditingController(text: r['notes'] ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _panelDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Modifier le pointage', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dateTimePicker(ctx, 'Entrée', newCin, (d) => setDlg(() => newCin = d)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _dateTimePicker(ctx, 'Sortie', newCout, (d) => setDlg(() => newCout = d))),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => setDlg(() => newCout = null), child: const Text('Sans sortie', style: TextStyle(color: _textMuted, fontSize: 11))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: nCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Notes', labelStyle: TextStyle(color: _textMuted)), maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, {'check_in': newCin?.toIso8601String(), 'check_out': newCout?.toIso8601String(), 'notes': nCtrl.text.trim()}), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (result == null) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('attendance').update({
        'check_in': result['check_in'],
        'check_out': result['check_out'],
        'notes': result['notes'],
      }).eq('id', r['id']);
      ref.invalidate(_attendanceHistoryProvider);
      ref.invalidate(_attendanceStatsProvider);
      if (mounted) _showSnack('Pointage modifié', _neonEmerald);
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', Colors.redAccent);
    }
  }

  Future<void> _deleteEntry(String id) async {
    try {
      await ref.read(supabaseClientProvider).from('attendance').delete().match({'id': id});
      ref.invalidate(_attendanceHistoryProvider);
      ref.invalidate(_attendanceStatsProvider);
      if (mounted) _showSnack('Pointage supprimé', Colors.redAccent);
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', Colors.redAccent);
    }
  }

  void _exportCsv(WidgetRef ref) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final user = ref.read(currentUserProvider);
      final isOwner = ref.read(isOwnerProvider);
      if (user == null) return;
      var sel = client.from('attendance').select('*, profiles(full_name)');
      if (!isOwner) sel = sel.eq('worker_id', user.id);
      final rows = await sel.order('check_in', ascending: false);

      final buf = StringBuffer('Employé,Entrée,Sortie,Durée (heures),Notes\n');
      for (final r in rows) {
        final cin = DateTime.tryParse(r['check_in']?.toString() ?? '');
        final cout = DateTime.tryParse(r['check_out']?.toString() ?? '');
        final dur = cin != null && cout != null ? (cout.difference(cin).inMinutes / 60.0).toStringAsFixed(2) : '';
        buf.writeln('"${r['profiles']?['full_name'] ?? ''}","${_fmtDt(cin)}","${_fmtDt(cout)}",$dur,"${r['notes'] ?? ''}"');
      }

      final downloadsDir = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
      final file = File('$downloadsDir\\Downloads\\pointage_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.csv');
      await file.writeAsString(buf.toString());
      if (mounted) _showSnack('Exporté vers ${file.path}', _neonEmerald);
    } catch (e) {
      if (mounted) _showSnack('Erreur export: $e', Colors.redAccent);
    }
  }

  Widget _dateTimePicker(BuildContext ctx, String label, DateTime? date, void Function(DateTime?) onChanged) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: ctx, initialDate: date ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
        if (d == null) return;
        final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()));
        if (t == null) return;
        onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: _textMuted), border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today, color: _textMuted, size: 16)),
        child: Text(date != null ? _fmtDt(date) : 'Non défini', style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }

  String _fmtDt(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: color, duration: const Duration(seconds: 2)));
  }
}
