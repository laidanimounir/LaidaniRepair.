import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

final _employeesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client.from('profiles')
      .select('*, roles(role_name)')
      .order('created_at', ascending: false);
});

final _rolesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client.from('roles').select();
});

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(_employeesProvider);
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
                  child: const Icon(Icons.badge_outlined, color: _neonCyan, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text('GESTION DES EMPLOYÉS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5))),
                if (isDesktop)
                  ElevatedButton.icon(
                    onPressed: () => _showEmployeeDialog(context, ref, null),
                    style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    icon: const Icon(Icons.person_add, size: 20),
                    label: const Text('AJOUTER', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (employees) {
                if (employees.isEmpty) {
                  return Center(child: Text('Aucun employé.', style: const TextStyle(color: _textMuted)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: employees.length,
                  itemBuilder: (context, index) => _EmployeeCard(employee: employees[index], ref: ref),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEmployeeDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    final nameCtrl = TextEditingController(text: existing?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone_number'] ?? '');
    int? selectedRoleId = existing?['role_id'] as int?;
    bool isActive = existing?['is_active'] as bool? ?? true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        title: Text(existing != null ? 'MODIFIER EMPLOYÉ' : 'AJOUTER EMPLOYÉ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nom complet', labelStyle: TextStyle(color: _textMuted))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Téléphone', labelStyle: TextStyle(color: _textMuted))),
              const SizedBox(height: 12),
              FutureBuilder(
                future: ref.read(_rolesProvider.future),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const CircularProgressIndicator();
                  final roles = snap.data as List;
                  return DropdownButtonFormField<int>(
                    value: selectedRoleId,
                    dropdownColor: _panelDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Rôle', labelStyle: TextStyle(color: _textMuted)),
                    items: roles.map((r) => DropdownMenuItem(value: r['id'] as int, child: Text(r['role_name'] ?? ''))).toList(),
                    onChanged: (v) => selectedRoleId = v,
                  );
                },
              ),
              if (existing != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Actif', style: TextStyle(color: Colors.white)),
                  value: isActive,
                  activeColor: _neonEmerald,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => isActive = v,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon),
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              final data = <String, dynamic>{
                'full_name': nameCtrl.text.trim(),
                'phone_number': phoneCtrl.text.trim(),
                'role_id': selectedRoleId,
              };
              if (existing == null) {
                // Creating a new employee requires the auth user to exist first - not implemented in UI
              } else {
                data['is_active'] = isActive;
                await client.from('profiles').update(data).eq('id', existing['id']);
              }
              ref.invalidate(_employeesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing != null ? 'MODIFIER' : 'AJOUTER', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final WidgetRef ref;
  const _EmployeeCard({required this.employee, required this.ref});

  @override
  Widget build(BuildContext context) {
    final name = employee['full_name'] ?? '';
    final phone = employee['phone_number'] ?? '';
    final role = employee['roles']?['role_name'] ?? '';
    final isActive = employee['is_active'] as bool? ?? true;
    final initial = name.toString().isNotEmpty ? name.toString().substring(0, 1).toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _glassBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: (isActive ? _neonCyan : _textMuted).withOpacity(0.15),
            child: Text(initial, style: TextStyle(color: isActive ? _neonCyan : _textMuted, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(role, style: TextStyle(color: _neonCyan, fontSize: 12)),
                    if (phone.toString().isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text(phone, style: const TextStyle(color: _textMuted, fontSize: 12)),
                    ],
                    if (!isActive) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Inactif', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _textMuted),
            color: _panelDark,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Modifier', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Désactiver' : 'Activer', style: TextStyle(color: Colors.white))),
            ],
            onSelected: (action) async {
              final client = ref.read(supabaseClientProvider);
              if (action == 'toggle') {
                await client.from('profiles').update({'is_active': !isActive}).eq('id', employee['id']);
                ref.invalidate(_employeesProvider);
              } else if (action == 'edit') {
                // Would need to show edit dialog here
              }
            },
          ),
        ],
      ),
    );
  }
}
