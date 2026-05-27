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

final _attendanceHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  final isOwner = ref.watch(isOwnerProvider);
  if (user == null) return [];
  var sel = client.from('attendance').select('*, profiles(full_name)');
  if (!isOwner) sel = sel.eq('worker_id', user.id);
  final data = await sel.order('check_in', ascending: false).limit(100);
  return List<Map<String, dynamic>>.from(data);
});

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(_activeAttendanceProvider);
    final historyAsync = ref.watch(_attendanceHistoryProvider);
    final isOwner = ref.watch(isOwnerProvider);
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
                IconButton(icon: const Icon(Icons.refresh, color: _textMuted), onPressed: () { ref.invalidate(_activeAttendanceProvider); ref.invalidate(_attendanceHistoryProvider); }),
              ],
            ),
          ),
          activeAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Container(),
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('HISTORIQUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                const Spacer(),
                if (isOwner)
                  Text('Tous les employés', style: const TextStyle(color: _textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (rows) {
                if (rows.isEmpty) return Center(child: Text('Aucun pointage.', style: const TextStyle(color: _textMuted)));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final r = rows[index];
                    final checkIn = DateTime.tryParse(r['check_in'] ?? '');
                    final checkOut = DateTime.tryParse(r['check_out'] ?? '');
                    final duration = checkIn != null && checkOut != null
                        ? checkOut.difference(checkIn)
                        : null;
                    final workerName = r['profiles']?['full_name'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _panelDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _glassBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(checkOut != null ? Icons.check_circle : Icons.access_time, color: checkOut != null ? _neonEmerald : Colors.orangeAccent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (workerName.isNotEmpty)
                                  Text(workerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  'Entrée: ${checkIn?.toString().substring(0, 16) ?? ''}',
                                  style: const TextStyle(color: _textMuted, fontSize: 11),
                                ),
                                if (checkOut != null)
                                  Text('Sortie: ${checkOut.toString().substring(0, 16)}', style: const TextStyle(color: _textMuted, fontSize: 11)),
                                if (duration != null)
                                  Text('Durée: ${duration.inHours}h ${duration.inMinutes % 60}min', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Future<void> _handleAttendance(WidgetRef ref, String type) async {
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      if (type == 'check_in') {
        await client.from('attendance').insert({'worker_id': user.id, 'check_in': DateTime.now().toIso8601String()});
      } else {
        final rows = await client.from('attendance')
            .select('id')
            .eq('worker_id', user.id)
            .filter('check_out', 'is', null)
            .order('check_in', ascending: false)
            .limit(1);
        if (rows.isNotEmpty) {
          await client.from('attendance').update({'check_out': DateTime.now().toIso8601String()}).eq('id', rows.first['id']);
        }
      }
      ref.invalidate(_activeAttendanceProvider);
      ref.invalidate(_attendanceHistoryProvider);
    } catch (e) {
      // ignore
    }
  }
}
