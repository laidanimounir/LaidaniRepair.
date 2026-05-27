import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);

final _branchesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client.from('branches').select().order('created_at', ascending: false);
});

class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(_branchesProvider);

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
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
                  child: const Icon(Icons.business, color: _neonCyan, size: 24),
                ),
                const SizedBox(width: 16),
                const Text('SUCCURSALES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showBranchDialog(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan.withOpacity(0.1),
                    foregroundColor: _neonCyan,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    side: BorderSide(color: _neonCyan.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('NOUVELLE SUCCURSALE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ),
          ),
          Expanded(
            child: branchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _neonCyan)),
              error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (branches) {
                if (branches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_outlined, size: 64, color: _textMuted.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        const Text('Aucune succursale enregistrée.', style: TextStyle(color: _textMuted)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: branches.length,
                  itemBuilder: (context, index) {
                    final branch = branches[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _panelDark.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _glassBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _neonCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.store, color: _neonCyan, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(branch['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                if (branch['address'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(branch['address'] as String, style: const TextStyle(color: _textMuted, fontSize: 12)),
                                  ),
                                if (branch['phone'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(branch['phone'] as String, style: const TextStyle(color: _textMuted, fontSize: 12)),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: _textMuted, size: 20),
                            onPressed: () => _showBranchDialog(context, ref, existing: branch),
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
}

void _showBranchDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existing}) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: _BranchFormDialog(ref: ref, existing: existing),
    ),
  );
}

class _BranchFormDialog extends StatefulWidget {
  final WidgetRef ref;
  final Map<String, dynamic>? existing;
  const _BranchFormDialog({required this.ref, this.existing});
  @override State<_BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends State<_BranchFormDialog> {
  late final TextEditingController _nameCtrl, _addressCtrl, _phoneCtrl;
  bool _isLoading = false;

  @override void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?['name'] ?? '');
    _addressCtrl = TextEditingController(text: widget.existing?['address'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?['phone'] ?? '');
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
    prefixIcon: Icon(icon, color: _textMuted, size: 18),
    filled: true, fillColor: _bgCarbon.withOpacity(0.5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _glassBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _neonCyan)),
  );

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le nom est obligatoire'), backgroundColor: Colors.redAccent));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final client = widget.ref.read(supabaseClientProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      };
      if (widget.existing != null) {
        await client.from('branches').update(data).eq('id', widget.existing!['id']);
      } else {
        await client.from('branches').insert(data);
      }
      widget.ref.invalidate(_branchesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.existing != null ? 'Succursale mise à jour' : 'Succursale ajoutée'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _panelDark.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder, width: 1.5)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.store, color: _neonCyan), SizedBox(width: 12), Text('NOUVELLE SUCCURSALE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 24),
            TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Nom de la succursale *', Icons.business)),
            const SizedBox(height: 16),
            TextField(controller: _addressCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Adresse', Icons.location_on), maxLines: 2),
            const SizedBox(height: 16),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Téléphone', Icons.phone)),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: _textMuted))),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: _bgCarbon, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _bgCarbon, strokeWidth: 2)) : const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
