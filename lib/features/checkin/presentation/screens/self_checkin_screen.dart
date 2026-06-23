import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laidani_repair/core/providers/supabase_provider.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

class SelfCheckinScreen extends ConsumerStatefulWidget {
  const SelfCheckinScreen({super.key});

  @override
  ConsumerState<SelfCheckinScreen> createState() => _SelfCheckinScreenState();
}

class _SelfCheckinScreenState extends ConsumerState<SelfCheckinScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deviceCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  String? _deviceType;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _deviceCtrl.dispose();
    _problemCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty || _problemCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final qrHash = 'CK${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999).toString().padLeft(3, '0')}';

      await client.from('repair_tickets').insert({
        'client_name_temp': _nameCtrl.text.trim(),
        'client_phone_temp': _phoneCtrl.text.trim(),
        'device_name': _deviceCtrl.text.trim().isEmpty ? 'Non spécifié' : _deviceCtrl.text.trim(),
        'device_type': _deviceType,
        'issue_description': _problemCtrl.text.trim(),
        'status': 'En attente',
        'qr_code_hash': qrHash,
      });

      _showSuccessDialog();
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _deviceCtrl.clear();
      _problemCtrl.clear();
      _deviceType = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(shape: BoxShape.circle, color: _neonEmerald.withOpacity(0.1), boxShadow: [BoxShadow(color: _neonEmerald.withOpacity(0.3), blurRadius: 40)]),
              child: const Icon(Icons.check_circle, color: _neonEmerald, size: 60),
            ),
            const SizedBox(height: 20),
            const Text('Déposé avec succès !', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Un technicien va prendre en charge votre appareil. Vous recevrez un QR code pour suivre la réparation.', style: TextStyle(color: _textMuted, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _panelDark.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _glassBorder, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.qr_code_scanner, color: _neonCyan, size: 48),
                const SizedBox(height: 16),
                const Text('DÉPOSEZ VOTRE APPAREIL', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Remplissez ce formulaire pour enregistrer votre appareil. Un technicien vous contactera.', textAlign: TextAlign.center, style: TextStyle(color: _textMuted, fontSize: 13)),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Votre nom complet *', Icons.person),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Votre numéro de téléphone *', Icons.phone),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _deviceCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Modèle de l\'appareil (ex: iPhone 14)', Icons.phone_android),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _deviceType,
                  dropdownColor: _panelDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Type d\'appareil', Icons.devices),
                  items: ['Téléphone', 'Tablette', 'Ordinateur', 'Console', 'Montre', 'Autre'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _deviceType = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _problemCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Décrivez le problème *', Icons.warning_amber_rounded),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    foregroundColor: _bgCarbon,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _bgCarbon, strokeWidth: 2))
                      : const Text('DÉPOSER MON APPAREIL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                ),
                const SizedBox(height: 16),
                Text('LaidaniRepair © ${DateTime.now().year}', textAlign: TextAlign.center, style: const TextStyle(color: _textMuted, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: _textMuted, size: 20),
      filled: true,
      fillColor: _bgCarbon.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _glassBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _glassBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _neonCyan)),
    );
  }
}
