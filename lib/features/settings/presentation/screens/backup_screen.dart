import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'dart:io';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);

final _lastBackupProvider = FutureProvider<Map<String, String?>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'date': prefs.getString('last_backup_date'),
    'status': prefs.getString('last_backup_status') ?? 'Aucune sauvegarde',
    'filename': prefs.getString('last_backup_filename'),
    'size': prefs.getString('last_backup_size'),
  };
});

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastBackup = ref.watch(_lastBackupProvider);

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.backup, color: _neonCyan, size: 28),
                const SizedBox(width: 12),
                const Text('SAUVEGARDE & RESTAURATION', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _neonCyan.withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dernière sauvegarde', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  lastBackup.when(
                    loading: () => const CircularProgressIndicator(color: _neonCyan),
                    error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: Colors.redAccent)),
                    data: (info) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Date', info['date'] ?? 'Jamais'),
                        _infoRow('Statut', info['status'] ?? 'Inconnu'),
                        if (info['filename'] != null) _infoRow('Fichier', info['filename']!),
                        if (info['size'] != null) _infoRow('Taille', info['size']!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.cloud_upload,
                    title: 'Sauvegarde Locale',
                    subtitle: 'Exporte toutes les données chiffrées (AES-256) sur cet appareil',
                    color: _neonCyan,
                    onTap: () => _showPasswordDialog(context, ref),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.cloud_done,
                    title: 'Google Drive',
                    subtitle: 'Sauvegarde cloud (connexion Google requise)',
                    color: const Color(0xFF4285F4),
                    onTap: () => _showGoogleDrivePlaceholder(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TABLES SAUVEGARDÉES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  _tableRow('products', 'Produits'),
                  _tableRow('customers', 'Clients'),
                  _tableRow('repair_tickets', 'Tickets de réparation'),
                  _tableRow('repair_parts', 'Pièces de réparation'),
                  _tableRow('repair_payments', 'Paiements'),
                  _tableRow('sales_invoices', 'Factures de vente'),
                  _tableRow('purchase_invoices', 'Factures d\'achat'),
                  _tableRow('expenses', 'Dépenses'),
                  _tableRow('profiles', 'Employés'),
                  _tableRow('suppliers', 'Fournisseurs'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: _textMuted, fontSize: 13))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tableRow(String table, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.table_chart, color: _textMuted, size: 14),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _neonEmerald.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: const Text('✓', style: TextStyle(color: _neonEmerald, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _panelDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: _textMuted, fontSize: 12, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

Future<void> _showPasswordDialog(BuildContext context, WidgetRef ref) {
  final passwordCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _panelDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _glassBorder),
      ),
      title: const Row(
        children: [
          Icon(Icons.lock, color: _neonCyan),
          SizedBox(width: 12),
          Text('Mot de passe de sauvegarde', style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Définissez un mot de passe pour chiffrer la sauvegarde.\nVous en aurez besoin pour la restaurer.',
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                labelStyle: TextStyle(color: _textMuted),
                filled: true,
                fillColor: Color(0xFF050914),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.length < 4) ? '4 caractères minimum' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Confirmer',
                labelStyle: TextStyle(color: _textMuted),
                filled: true,
                fillColor: Color(0xFF050914),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v != passwordCtrl.text ? 'Les mots de passe ne correspondent pas' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler', style: TextStyle(color: _textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: const Color(0xFF050914)),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx);
              _performBackup(context, ref, passwordCtrl.text);
            }
          },
          child: const Text('Sauvegarder', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

Future<void> _performBackup(BuildContext context, WidgetRef ref, String password) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      backgroundColor: _panelDark,
      content: Row(children: [CircularProgressIndicator(color: _neonCyan), SizedBox(width: 16), Text('Sauvegarde en cours...', style: TextStyle(color: Colors.white))]),
    ),
  );

  try {
    final client = Supabase.instance.client;
    final backup = <String, dynamic>{};
    backup['backup_date'] = DateTime.now().toIso8601String();
    backup['version'] = '1.0';

    final tables = ['products', 'customers', 'repair_tickets', 'repair_parts', 'repair_payments', 'sales_invoices', 'purchase_invoices', 'expenses', 'profiles', 'suppliers', 'categories'];
    for (var table in tables) {
      try {
        final data = await client.from(table).select();
        backup[table] = data;
      } catch (_) {
        backup[table] = [];
      }
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);

    // Derive a 32-byte AES key from the password using SHA-256
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final key = enc.Key(keyBytes.sublist(0, 32));
    final iv = enc.IV(List.generate(16, (_) => Random.secure().nextInt(256)));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(jsonStr, iv: iv);

    // Write IV + ciphertext to file
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/laidani_backup_$timestamp.enc');
    final output = iv.bytes + encrypted.bytes;
    await file.writeAsBytes(output);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_backup_date', DateTime.now().toString().substring(0, 19));
    await prefs.setString('last_backup_status', 'Réussi (chiffré)');
    await prefs.setString('last_backup_filename', file.path);
    await prefs.setString('last_backup_size', '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB');

    if (context.mounted) {
      Navigator.pop(context);
      ref.invalidate(_lastBackupProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sauvegarde chiffrée! ${file.path}'),
          backgroundColor: _neonEmerald,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de sauvegarde: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}

void _showGoogleDrivePlaceholder(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _panelDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
      title: const Row(children: [Icon(Icons.cloud_done, color: Color(0xFF4285F4)), SizedBox(width: 12), Text('Google Drive Backup', style: TextStyle(color: Colors.white))]),
      content: const Text('La connexion Google Drive sera disponible dans une prochaine mise à jour.\n\nPour le moment, utilisez la sauvegarde locale et importez le fichier JSON manuellement.', style: TextStyle(color: _textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK', style: TextStyle(color: _neonCyan)),
        ),
      ],
    ),
  );
}
