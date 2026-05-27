import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laidani_repair/core/providers/theme_provider.dart';
import 'package:laidani_repair/core/providers/locale_provider.dart';
import 'package:laidani_repair/core/constants/app_constants.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: _neonCyan, size: 28),
                SizedBox(width: 12),
                Text('PARAMÈTRES', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection('APPARENCE', Icons.palette_outlined, [
              _buildSwitchTile(
                'Mode sombre',
                'Basculer entre le thème clair et sombre',
                Icons.dark_mode,
                themeMode == ThemeMode.dark,
                (v) => ref.read(themeProvider.notifier).toggle(),
              ),
              const SizedBox(height: 8),
              _buildLanguageTile(locale, ref),
            ]),
            const SizedBox(height: 24),
            _buildSection('SÉCURITÉ', Icons.security_outlined, [
              _buildInfoTile(Icons.lock_outline, 'Authentification à 2 facteurs', 'Non configurée', onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('2FA sera disponible prochainement'), backgroundColor: Colors.orangeAccent),
                );
              }),
              const Divider(color: _glassBorder),
              _buildInfoTile(Icons.password, 'Changer le mot de passe', 'Modifier votre mot de passe Supabase', onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Utilisez la console Supabase pour changer votre mot de passe'), backgroundColor: _neonCyan),
                );
              }),
            ]),
            const SizedBox(height: 24),
            _buildSection('SAUVEGARDE', Icons.backup_outlined, [
              _buildInfoTile(Icons.cloud_upload, 'Sauvegarde & Restauration', 'Gérer les sauvegardes locales et cloud', onTap: () => context.push(AppConstants.routeBackup)),
            ]),
            const SizedBox(height: 24),
            _buildSection('À PROPOS', Icons.info_outline, [
              _buildAboutTile('Version', '1.0.0+1'),
              _buildAboutTile('SDK', 'Flutter >=3.3.0'),
              _buildAboutTile('Backend', 'Supabase PostgreSQL'),
              _buildAboutTile('Licence', 'Tous droits réservés'),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _showLicenses(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: _bgCarbon, borderRadius: BorderRadius.circular(8), border: Border.all(color: _glassBorder)),
                  child: const Row(
                    children: [
                      Icon(Icons.article_outlined, color: _textMuted, size: 20),
                      SizedBox(width: 12),
                      Text('Licences open source', style: TextStyle(color: _neonCyan, fontSize: 14)),
                      Spacer(),
                      Icon(Icons.chevron_right, color: _textMuted),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '${AppConstants.appName} © ${DateTime.now().year}',
                style: const TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _neonCyan, size: 18),
            const SizedBox(width: 8),
            Text(title.toUpperCase(), style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _panelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: _textMuted, fontSize: 12)),
      secondary: Icon(icon, color: _textMuted),
      value: value,
      activeColor: _neonCyan,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildLanguageTile(Locale locale, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.language, color: _textMuted, size: 24),
      title: const Text('Langue', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(locale.languageCode == 'fr' ? 'Français' : locale.languageCode == 'ar' ? 'العربية' : 'English', style: const TextStyle(color: _textMuted, fontSize: 12)),
      trailing: DropdownButton<String>(
        value: locale.languageCode,
        dropdownColor: _panelDark,
        style: const TextStyle(color: Colors.white),
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'fr', child: Text('Français')),
          DropdownMenuItem(value: 'ar', child: Text('العربية')),
          DropdownMenuItem(value: 'en', child: Text('English')),
        ],
        onChanged: (v) {
          if (v != null) ref.read(localeProvider.notifier).setLocale(Locale(v));
        },
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _textMuted, size: 24),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: _textMuted, fontSize: 12)),
      trailing: onTap != null ? const Icon(Icons.chevron_right, color: _textMuted) : null,
      onTap: onTap,
    );
  }

  Widget _buildAboutTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: _textMuted, fontSize: 13))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showLicenses(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _glassBorder)),
        title: const Text('Licences', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LicenseItem('Flutter', 'BSD 3-Clause', 'Google'),
              _LicenseItem('Supabase Flutter', 'MIT', 'Supabase'),
              _LicenseItem('Riverpod', 'MIT', 'Remi Rousselet'),
              _LicenseItem('go_router', 'MIT', 'Flutter Dev Team'),
              _LicenseItem('fl_chart', 'MIT', 'Iman Khoshabi'),
              _LicenseItem('qr_flutter', 'MIT', 'Luke Freeman'),
              _LicenseItem('printing', 'Apache 2.0', 'David PHAM-VAN'),
              _LicenseItem('pdf', 'Apache 2.0', 'David PHAM-VAN'),
              _LicenseItem('url_launcher', 'MIT', 'Flutter Dev Team'),
              _LicenseItem('image_picker', 'MIT', 'Flutter Dev Team'),
              _LicenseItem('shared_preferences', 'BSD 3-Clause', 'Flutter Dev Team'),
              _LicenseItem('intl', 'Apache 2.0', 'Dart Dev Team'),
              _LicenseItem('google_fonts', 'Apache 2.0', 'Material Foundation'),
              _LicenseItem('window_manager', 'MIT', 'LiJianying'),
              _LicenseItem('http', 'BSD 3-Clause', 'Dart Dev Team'),
              _LicenseItem('csv', 'MIT', 'Richard Sheets'),
              _LicenseItem('path_provider', 'MIT', 'Flutter Dev Team'),
              _LicenseItem('mobile_scanner', 'MIT', 'Julian Steenbakker'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: _neonCyan)))],
      ),
    );
  }
}

class _LicenseItem extends StatelessWidget {
  final String name;
  final String license;
  final String author;
  const _LicenseItem(this.name, this.license, this.author);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.code, color: _textMuted, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12))),
          Text(license, style: const TextStyle(color: _neonCyan, fontSize: 10)),
          const SizedBox(width: 8),
          Text(author, style: const TextStyle(color: _textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
