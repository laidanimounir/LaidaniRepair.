import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

// ─── Month data provider ────────────────────────────────────────────────────
final _attendanceMonthProvider = FutureProvider.family<Map<String, List<Map<String, dynamic>>>, (int, int)>((ref, args) async {
  final (year, month) = args;
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  final isOwner = ref.watch(isOwnerProvider);
  if (user == null) return {};

  final start = DateTime(year, month, 1);
  final end = DateTime(year, month + 1, 1);
  var query = client.from('attendance').select('*, profiles(full_name)');
  if (!isOwner) query = query.eq('worker_id', user.id);
  final rows = List<Map<String, dynamic>>.from(await query
      .gte('check_in', start.toIso8601String())
      .lt('check_in', end.toIso8601String())
      .order('check_in', ascending: true));
  final byDay = <String, List<Map<String, dynamic>>>{};
  for (final r in rows) {
    final d = DateTime.tryParse(r['check_in']?.toString() ?? '');
    if (d != null) {
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(r);
    }
  }
  return byDay;
});

// ─── Year data provider ─────────────────────────────────────────────────────
final _attendanceYearProvider = FutureProvider.family<Map<String, double>, int>((ref, year) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  final isOwner = ref.watch(isOwnerProvider);
  if (user == null) return {};

  final start = DateTime(year, 1, 1);
  final end = DateTime(year + 1, 1, 1);
  var query = client.from('attendance').select('check_in, check_out');
  if (!isOwner) query = query.eq('worker_id', user.id);
  final rows = await query
      .gte('check_in', start.toIso8601String())
      .lt('check_in', end.toIso8601String());
  final byDay = <String, double>{};
  for (final r in rows) {
    final cin = DateTime.tryParse(r['check_in']?.toString() ?? '');
    final cout = DateTime.tryParse(r['check_out']?.toString() ?? '');
    if (cin != null) {
      final key = '${cin.year}-${cin.month.toString().padLeft(2, '0')}-${cin.day.toString().padLeft(2, '0')}';
      final dur = cout != null ? cout.difference(cin).inMinutes / 60.0 : 0;
      byDay[key] = (byDay[key] ?? 0) + dur;
    }
  }
  return byDay;
});

// ─── Week Gantt provider ────────────────────────────────────────────────────
final _ganttWeekProvider = FutureProvider.family<List<Map<String, dynamic>>, DateTime>((ref, monday) async {
  final client = ref.watch(supabaseClientProvider);
  final isOwner = ref.watch(isOwnerProvider);
  final user = ref.watch(currentUserProvider);
  final sunday = monday.add(const Duration(days: 7));

  var query = client.from('attendance').select('*, profiles(full_name)');
  if (!isOwner && user != null) query = query.eq('worker_id', user.id);
  return List<Map<String, dynamic>>.from(await query
      .gte('check_in', monday.toIso8601String())
      .lt('check_in', sunday.toIso8601String())
      .order('check_in', ascending: true));
});

// ─── Tab controller ─────────────────────────────────────────────────────────
enum AttendanceView { calendar, timeline, weekly, heatmap, today, gantt }

// ─── Main views widget ──────────────────────────────────────────────────────
class AttendanceViewsWidget extends ConsumerStatefulWidget {
  final String? workerFilter;
  final bool isOwner;
  const AttendanceViewsWidget({super.key, this.workerFilter, required this.isOwner});

  @override
  ConsumerState<AttendanceViewsWidget> createState() => _AttendanceViewsWidgetState();
}

class _AttendanceViewsWidgetState extends ConsumerState<AttendanceViewsWidget> {
  AttendanceView _view = AttendanceView.calendar;
  late DateTime _calendarDate = DateTime.now();
  late DateTime _heatmapYear = DateTime(DateTime.now().year);
  late DateTime _ganttMonday;
  Timer? _todayTimer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _ganttMonday = now.subtract(Duration(days: now.weekday - 1));
    _ganttMonday = DateTime(_ganttMonday.year, _ganttMonday.month, _ganttMonday.day);
    _todayTimer = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _todayTimer?.cancel();
    super.dispose();
  }

  String _viewLabel(AttendanceView v) {
    switch (v) {
      case AttendanceView.calendar: return 'Calendrier';
      case AttendanceView.timeline: return 'Chrono';
      case AttendanceView.weekly: return 'Semaines';
      case AttendanceView.heatmap: return 'Année';
      case AttendanceView.today: return "Aujourd'hui";
      case AttendanceView.gantt: return 'Gantt';
    }
  }

  IconData _viewIcon(AttendanceView v) {
    switch (v) {
      case AttendanceView.calendar: return Icons.calendar_month;
      case AttendanceView.timeline: return Icons.timeline;
      case AttendanceView.weekly: return Icons.view_week;
      case AttendanceView.heatmap: return Icons.grid_on;
      case AttendanceView.today: return Icons.today;
      case AttendanceView.gantt: return Icons.bar_chart;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: AttendanceView.values.map((v) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_viewIcon(v), size: 14, color: _view == v ? _bgCarbon : _textMuted), const SizedBox(width: 4), Text(_viewLabel(v), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _view == v ? _bgCarbon : _textMuted))]),
                selected: _view == v,
                selectedColor: _neonCyan,
                backgroundColor: _panelDark,
                side: BorderSide(color: _view == v ? _neonCyan : _glassBorder),
                onSelected: (_) => setState(() => _view = v),
                visualDensity: VisualDensity.compact,
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildCurrentView()),
      ],
    );
  }

  Widget _buildCurrentView() {
    switch (_view) {
      case AttendanceView.calendar: return _buildCalendar();
      case AttendanceView.timeline: return _buildTimeline();
      case AttendanceView.weekly: return _buildWeeklyCards();
      case AttendanceView.heatmap: return _buildHeatmap();
      case AttendanceView.today: return _buildTodayView();
      case AttendanceView.gantt: return _buildGantt();
    }
  }

  // ═══ 1. CALENDAR GRID ═════════════════════════════════════════════════════
  Widget _buildCalendar() {
    final year = _calendarDate.year;
    final month = _calendarDate.month;
    final dataAsync = ref.watch(_attendanceMonthProvider((year, month)));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: _textMuted), onPressed: () => setState(() => _calendarDate = DateTime(year, month - 1, 1))),
            Text('${_monthName(month)} $year', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: const Icon(Icons.chevron_right, color: _textMuted), onPressed: () => setState(() => _calendarDate = DateTime(year, month + 1, 1))),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))))).toList(),
          ),
        ),
        Expanded(
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2)),
            error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
            data: (dayData) {
              final firstDay = DateTime(year, month, 1);
              final lastDay = DateTime(year, month + 1, 0);
              final startOffset = (firstDay.weekday - 1) % 7;
              final totalCells = startOffset + lastDay.day;

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1),
                itemCount: (totalCells / 7).ceil() * 7,
                itemBuilder: (_, i) {
                  if (i < startOffset || i - startOffset >= lastDay.day) return const SizedBox.shrink();
                  final day = i - startOffset + 1;
                  final date = DateTime(year, month, day);
                  final key = '${year}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final entries = dayData[key] ?? [];
                  final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;
                  final isFuture = date.isAfter(DateTime.now());
                  final hasEntries = entries.isNotEmpty;

                  Color bg;
                  if (isFuture) {
                    bg = _panelDark.withOpacity(0.3);
                  } else if (hasEntries) {
                    final allCheckedOut = entries.every((e) => e['check_out'] != null);
                    bg = allCheckedOut ? _neonEmerald.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2);
                  } else {
                    bg = Colors.redAccent.withOpacity(0.1);
                  }

                  return GestureDetector(
                    onTap: hasEntries ? () => _showDayDetails(context, date, entries) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(isToday ? 10 : 6),
                        border: isToday ? Border.all(color: _neonCyan, width: 2) : Border.all(color: _glassBorder.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$day', style: TextStyle(color: isFuture ? _textMuted.withOpacity(0.4) : Colors.white, fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                          if (hasEntries && !isFuture) ...[
                            const SizedBox(height: 2),
                            Text(_dayHours(entries), style: TextStyle(color: _neonCyan, fontSize: 8, fontWeight: FontWeight.w600)),
                          ],
                          if (!hasEntries && !isFuture) ...[
                            const SizedBox(height: 2),
                            Icon(Icons.close, size: 10, color: Colors.redAccent.withOpacity(0.7)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══ 2. VERTICAL TIMELINE ═════════════════════════════════════════════════
  Widget _buildTimeline() {
    final year = _calendarDate.year;
    final month = _calendarDate.month;
    final dataAsync = ref.watch(_attendanceMonthProvider((year, month)));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
      data: (dayData) {
        final sortedKeys = dayData.keys.toList()..sort((a, b) => b.compareTo(a));
        if (sortedKeys.isEmpty) return const Center(child: Text('Aucune donnée ce mois', style: TextStyle(color: _textMuted)));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: sortedKeys.length,
          itemBuilder: (_, i) {
            final key = sortedKeys[i];
            final entries = dayData[key]!;
            final d = DateTime.parse(key);
            final totalMins = entries.fold<double>(0, (s, e) {
              final cin = DateTime.tryParse(e['check_in']?.toString() ?? '');
              final cout = DateTime.tryParse(e['check_out']?.toString() ?? '');
              return s + (cin != null && cout != null ? cout.difference(cin).inMinutes.toDouble() : 0);
            });
            final hrs = totalMins / 60;
            final hasOpen = entries.any((e) => e['check_out'] == null);
            final color = hasOpen ? Colors.orangeAccent : (hrs >= 8 ? _neonEmerald : _neonCyan);

            return IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                      if (i < sortedKeys.length - 1) Expanded(child: Container(width: 1.5, color: _glassBorder)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _glassBorder)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_dayName(d.weekday)} ${d.day} ${_monthName(d.month)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          ...entries.map((e) {
                            final cin = DateTime.tryParse(e['check_in']?.toString() ?? '');
                            final cout = DateTime.tryParse(e['check_out']?.toString() ?? '');
                            final dur = cin != null && cout != null ? cout.difference(cin) : null;
                            return Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${_fmtTime(cin)} → ${cout != null ? _fmtTime(cout) : 'En cours...'}${dur != null ? ' (${dur.inHours}h${dur.inMinutes % 60}m)' : ''}',
                                style: TextStyle(color: cout != null ? _textMuted : Colors.orangeAccent, fontSize: 11),
                              ),
                            );
                          }),
                          if (hrs > 0) Text('Total: ${hrs.toStringAsFixed(1)}h', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══ 3. WEEKLY CARDS ══════════════════════════════════════════════════════
  Widget _buildWeeklyCards() {
    final year = _calendarDate.year;
    final month = _calendarDate.month;
    final dataAsync = ref.watch(_attendanceMonthProvider((year, month)));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
      data: (dayData) {
        final firstDay = DateTime(year, month, 1);
        final lastDay = DateTime(year, month + 1, 0);
        final weeks = <List<int>>[];
        var currentWeek = <int>[];
        for (var d = 1; d <= lastDay.day; d++) {
          final date = DateTime(year, month, d);
          if (date.weekday == 1 && currentWeek.isNotEmpty) { weeks.add(currentWeek); currentWeek = []; }
          currentWeek.add(d);
        }
        if (currentWeek.isNotEmpty) weeks.add(currentWeek);

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: weeks.length,
          itemBuilder: (_, wi) {
            final week = weeks[wi];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Semaine du ${week.first}/${month}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: week.map((d) {
                      final key = '${year}-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
                      final entries = dayData[key] ?? [];
                      final hrs = entries.fold<double>(0, (s, e) {
                        final cin = DateTime.tryParse(e['check_in']?.toString() ?? '');
                        final cout = DateTime.tryParse(e['check_out']?.toString() ?? '');
                        return s + (cin != null && cout != null ? cout.difference(cin).inMinutes.toDouble() : 0);
                      }) / 60;
                      final hasOpen = entries.any((e) => e['check_out'] == null);
                      final date = DateTime(year, month, d);
                      final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;
                      Color bg;
                      if (entries.isEmpty) bg = Colors.redAccent.withOpacity(0.1);
                      else if (hasOpen) bg = Colors.orangeAccent.withOpacity(0.2);
                      else bg = _neonEmerald.withOpacity(0.2);

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: isToday ? Border.all(color: _neonCyan, width: 1.5) : null),
                          child: Column(
                            children: [
                              Text('${_dayShort(d)}', style: const TextStyle(color: _textMuted, fontSize: 9)),
                              Text('$d', style: TextStyle(color: isToday ? _neonCyan : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              if (hrs > 0) Text('${hrs.toStringAsFixed(1)}h', style: TextStyle(color: _neonCyan, fontSize: 8)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══ 4. HEATMAP ═══════════════════════════════════════════════════════════
  Widget _buildHeatmap() {
    final year = _heatmapYear.year;
    final dataAsync = ref.watch(_attendanceYearProvider(year));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: _textMuted), onPressed: () => setState(() => _heatmapYear = DateTime(_heatmapYear.year - 1))),
            Text('${_heatmapYear.year}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: const Icon(Icons.chevron_right, color: _textMuted), onPressed: () => setState(() => _heatmapYear = DateTime(_heatmapYear.year + 1))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Moins', style: TextStyle(color: _textMuted, fontSize: 9)),
            ...['0A1F0A', '144A14', '1E7A1E', '32A832', '3FB950'].map((c) => Container(width: 10, height: 10, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: Color(int.parse('0xFF$c')), borderRadius: BorderRadius.circular(2)))),
            const Text('Plus', style: TextStyle(color: _textMuted, fontSize: 9)),
          ],
        ),
        Expanded(
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2)),
            error: (_, __) => const SizedBox.shrink(),
            data: (hoursByDay) => LayoutBuilder(
              builder: (_, constraints) {
                final start = DateTime(year, 1, 1);
                final cellW = (constraints.maxWidth - 24) / 53;
                final cellH = (constraints.maxHeight - 20) / 7;
                final sz = cellW < cellH ? cellW : cellH;
                final maxH = hoursByDay.values.isEmpty ? 1.0 : hoursByDay.values.reduce((a, b) => a > b ? a : b);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    direction: Axis.vertical,
                    children: List.generate(365, (i) {
                      final d = start.add(Duration(days: i));
                      if (d.year != year) return SizedBox(width: sz, height: sz);
                      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                      final hrs = hoursByDay[key] ?? 0;
                      final intensity = maxH > 0 ? (hrs / maxH).clamp(0.0, 1.0) : 0.0;
                      Color c;
                      if (hrs == 0 && d.isAfter(DateTime.now())) {
                        c = _panelDark.withOpacity(0.3);
                      } else if (hrs == 0) {
                        c = Colors.redAccent.withOpacity(0.2);
                      } else if (intensity < 0.25) {
                        c = const Color(0xFF144A14);
                      } else if (intensity < 0.5) {
                        c = const Color(0xFF1E7A1E);
                      } else if (intensity < 0.75) {
                        c = const Color(0xFF32A832);
                      } else {
                        c = const Color(0xFF3FB950);
                      }
                      return Tooltip(
                        message: '${_dayShort(d.weekday)} ${d.day}/${d.month}: ${hrs.toStringAsFixed(1)}h',
                        child: Container(width: sz, height: sz, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ═══ 5. TODAY VIEW ════════════════════════════════════════════════════════
  Widget _buildTodayView() {
    final today = DateTime.now();
    final key = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final dataAsync = ref.watch(_attendanceMonthProvider((today.year, today.month)));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2)),
      error: (_, __) => const SizedBox.shrink(),
      data: (dayData) {
        final entries = dayData[key] ?? [];
        if (entries.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.bedtime, color: _textMuted, size: 64), const SizedBox(height: 12), const Text('Aucun pointage aujourd\'hui', style: TextStyle(color: _textMuted, fontSize: 14)), const SizedBox(height: 4), const Text('Revenez quand un employé aura pointé', style: TextStyle(color: _textMuted, fontSize: 11))]));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: entries.map((e) {
            final cin = DateTime.tryParse(e['check_in']?.toString() ?? '');
            final cout = DateTime.tryParse(e['check_out']?.toString() ?? '');
            final isActive = cout == null;
            final elapsed = cin != null ? DateTime.now().difference(cin) : Duration.zero;
            final dur = cin != null && cout != null ? cout.difference(cin) : elapsed;
            final wName = e['profiles']?['full_name'] ?? 'Employé';
            final lat = e['check_in_lat'];
            final lng = e['check_in_lng'];
            final warned = isActive && elapsed.inHours >= 8;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panelDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isActive ? Colors.orangeAccent.withOpacity(0.5) : _neonEmerald.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.orangeAccent : _neonEmerald)),
                      const SizedBox(width: 8),
                      Text(wName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      if (isActive) _buildLiveTimer(elapsed),
                      if (!isActive) Icon(Icons.check_circle, color: _neonEmerald, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Entrée', _fmtTime(cin)),
                  if (cout != null) _infoRow('Sortie', _fmtTime(cout)),
                  _infoRow('Durée', '${dur.inHours}h ${dur.inMinutes % 60}min${isActive ? " (en cours)" : ""}'),
                  if (lat != null && lng != null)
                    _infoRow('Position', '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'),
                  if (warned)
                    Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: const Row(children: [Icon(Icons.warning_amber, color: Colors.redAccent, size: 16), SizedBox(width: 6), Expanded(child: Text('Attention: plus de 8h sans pointage de sortie', style: TextStyle(color: Colors.redAccent, fontSize: 11)))])),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLiveTimer(Duration elapsed) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orangeAccent.withOpacity(0.4))),
        child: Text('${elapsed.inHours}h ${elapsed.inMinutes % 60}m ${elapsed.inSeconds % 60}s', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(color: _textMuted, fontSize: 10))),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );
  }

  // ═══ 6. WEEKLY GANTT ══════════════════════════════════════════════════════
  Widget _buildGantt() {
    final dataAsync = ref.watch(_ganttWeekProvider(_ganttMonday));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: _textMuted), onPressed: () => setState(() => _ganttMonday = _ganttMonday.subtract(const Duration(days: 7)))),
            Text('Semaine du ${_ganttMonday.day}/${_ganttMonday.month}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            IconButton(icon: const Icon(Icons.chevron_right, color: _textMuted), onPressed: () => setState(() => _ganttMonday = _ganttMonday.add(const Duration(days: 7)))),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: List.generate(7, (i) {
              final d = _ganttMonday.add(Duration(days: i));
              final isToday = d.day == DateTime.now().day && d.month == DateTime.now().month && d.year == DateTime.now().year;
              return Expanded(child: Center(child: Text('${_dayShort(d.weekday)} ${d.day}', style: TextStyle(color: isToday ? _neonCyan : _textMuted, fontSize: 10, fontWeight: isToday ? FontWeight.bold : FontWeight.normal))));
            }),
          ),
        ),
        Expanded(
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan, strokeWidth: 2)),
            error: (_, __) => const SizedBox.shrink(),
            data: (entries) {
              if (entries.isEmpty) return const Center(child: Text('Aucun pointage cette semaine', style: TextStyle(color: _textMuted)));
              final grouped = <String, List<Map<String, dynamic>>>{};
              for (final e in entries) {
                final name = e['profiles']?['full_name'] ?? 'Employé';
                grouped.putIfAbsent(name, () => []).add(e);
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: grouped.entries.map((g) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(g.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      SizedBox(
                        height: 40,
                        child: LayoutBuilder(
                          builder: (_, constraints) {
                            final dayW = (constraints.maxWidth - 60) / 7;
                            return Row(
                              children: [
                                SizedBox(width: 60, child: const Text('', style: TextStyle(color: _textMuted, fontSize: 8))),
                                ...List.generate(7, (i) {
                                  final d = _ganttMonday.add(Duration(days: i));
                                  final dayEntries = g.value.where((e) {
                                    final cin = DateTime.tryParse(e['check_in']?.toString() ?? '');
                                    return cin != null && cin.day == d.day && cin.month == d.month && cin.year == d.year;
                                  }).toList();

                                  return Container(
                                    width: dayW,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: dayEntries.map((e) {
                                        final cin = DateTime.tryParse(e['check_in']?.toString() ?? '');
                                        final cout = DateTime.tryParse(e['check_out']?.toString() ?? '');
                                        final dur = cin != null && cout != null ? cout.difference(cin) : null;
                                        final isActive = cout == null;
                                        return Container(
                                          height: 36,
                                          margin: const EdgeInsets.only(bottom: 2),
                                          decoration: BoxDecoration(
                                            color: isActive ? Colors.orangeAccent.withOpacity(0.3) : _neonEmerald.withOpacity(0.25),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: isActive ? Colors.orangeAccent.withOpacity(0.5) : _neonEmerald.withOpacity(0.4)),
                                          ),
                                          child: Center(
                                            child: Text(dur != null ? '${dur.inHours}h${dur.inMinutes % 60}m' : 'En cours', style: TextStyle(color: isActive ? Colors.orangeAccent : _neonEmerald, fontSize: 7, fontWeight: FontWeight.w600)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══ HELPERS ══════════════════════════════════════════════════════════════
  String _monthName(int m) {
    const names = ['Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juill.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'];
    return names[m - 1];
  }

  String _dayName(int wd) {
    const names = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
    return names[wd - 1];
  }

  String _dayShort(int wd) {
    const names = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];
    return names[wd - 1];
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _dayHours(List<Map<String, dynamic>> entries) {
    double total = 0;
    for (final e in entries) {
      final cin = DateTime.tryParse(e['check_in']?.toString() ?? '');
      final cout = DateTime.tryParse(e['check_out']?.toString() ?? '');
      if (cin != null && cout != null) total += cout.difference(cin).inMinutes / 60.0;
      else if (cin != null) return '...';
    }
    return '${total.toStringAsFixed(1)}h';
  }

  void _showDayDetails(BuildContext ctx, DateTime date, List<Map<String, dynamic>> entries) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${_dayName(date.weekday)} ${date.day} ${_monthName(date.month)} ${date.year}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) {
              final cin = DateTime.tryParse(e['check_in']?.toString() ?? '');
              final cout = DateTime.tryParse(e['check_out']?.toString() ?? '');
              final dur = cin != null && cout != null ? cout.difference(cin) : null;
              final wName = e['profiles']?['full_name'] ?? 'Employé';
              final lat = e['check_in_lat'];
              final lng = e['check_in_lng'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(wName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Entrée: ${_fmtTime(cin)}', style: const TextStyle(color: _textMuted, fontSize: 11)),
                    Text('Sortie: ${cout != null ? _fmtTime(cout) : 'En cours...'}', style: TextStyle(color: cout != null ? _textMuted : Colors.orangeAccent, fontSize: 11)),
                    if (dur != null) Text('Durée: ${dur.inHours}h ${dur.inMinutes % 60}min', style: const TextStyle(color: _neonCyan, fontSize: 11)),
                    if (lat != null) Text('📍 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}', style: const TextStyle(color: _textMuted, fontSize: 10)),
                    if (e['notes'] != null) Text('Note: ${e['notes']}', style: const TextStyle(color: _textMuted, fontSize: 10, fontStyle: FontStyle.italic)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: _textMuted)))],
      ),
    );
  }
}
