import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:laidani_repair/core/constants/app_constants.dart';

const Color _bgCarbon = Color(0xFF050914);
const Color _panelDark = Color(0xFF0A0F1A);
const Color _glassBorder = Color(0x1AFFFFFF);
const Color _textMuted = Color(0xFF8A9BB4);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonEmerald = Color(0xFF10B981);
const Color _neonAmber = Color(0xFFFFB74D);

class ShopWebsiteScreen extends StatefulWidget {
  const ShopWebsiteScreen({super.key});

  @override
  State<ShopWebsiteScreen> createState() => _ShopWebsiteScreenState();
}

class _ShopWebsiteScreenState extends State<ShopWebsiteScreen> {
  final _trackingController = TextEditingController();
  String? _trackingError;

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  void _trackRepair() async {
    final code = _trackingController.text.trim();
    if (code.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      final exists = await client.from('repair_tickets').select('id').eq('qr_code_hash', code).maybeSingle();
      if (exists != null) {
        context.go('/track/$code');
      } else {
        setState(() => _trackingError = 'Code introuvable');
      }
    } catch (_) {
      setState(() => _trackingError = 'Erreur de recherche');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHero(isDesktop),
            _buildServices(isDesktop),
            _buildHowItWorks(isDesktop),
            _buildTrackRepair(isDesktop),
            _buildContactAndHours(isDesktop),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: isDesktop ? 100 : 60),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_panelDark, _bgCarbon, _panelDark],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _neonCyan.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.15), blurRadius: 30)],
            ),
            child: const Icon(Icons.memory, color: _neonCyan, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            'LaidaniRepair',
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 48 : 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Réparation professionnelle de smartphones & tablettes',
            style: TextStyle(
              color: _textMuted,
              fontSize: isDesktop ? 20 : 16,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Diagnostic gratuit • Pièces de qualité • Garantie sur toutes nos réparations',
            style: TextStyle(
              color: _neonCyan,
              fontSize: isDesktop ? 14 : 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go(AppConstants.routeLogin),
            icon: const Icon(Icons.lock_outline, size: 18),
            label: const Text('ESPACE PRO — CONNEXION',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonCyan,
              foregroundColor: _bgCarbon,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _heroStat('5000+', 'Réparations', _neonCyan),
              _heroStat('15+', 'Ans d\'expérience', _neonEmerald),
              _heroStat('98%', 'Satisfaction', _neonAmber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _panelDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildServices(bool isDesktop) {
    final services = [
      _ServiceItem(Icons.smartphone_rounded, 'Écran & Digitizer', 'Remplacement écran cassé, tactile HS, verre trempé'),
      _ServiceItem(Icons.battery_charging_full_rounded, 'Batterie', 'Remplacement batterie, problème de charge, autonomie'),
      _ServiceItem(Icons.water_damage_rounded, 'Oxydation / Eau', 'Nettoyage carte mère, réparation après immersion'),
      _ServiceItem(Icons.usb_rounded, 'Connecteur Charge', 'Remplacement connecteur, réparation port USB-C / Lightning'),
      _ServiceItem(Icons.camera_alt_rounded, 'Appareil Photo', 'Remplacement caméra avant/arrière, problème focus'),
      _ServiceItem(Icons.volume_up_rounded, 'Haut-parleur / Micro', 'Remplacement HP, micro, problème audio'),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 60),
      color: _panelDark,
      child: Column(
        children: [
          Text('NOS SERVICES', style: TextStyle(color: _neonCyan, fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text('Des réparations rapides et fiables pour tous vos appareils', style: TextStyle(color: _textMuted, fontSize: isDesktop ? 16 : 14)),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 400 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.3,
                ),
                itemCount: services.length,
                itemBuilder: (_, i) => _buildServiceCard(services[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(_ServiceItem service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCarbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _neonCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(service.icon, color: _neonCyan, size: 28),
          ),
          const SizedBox(height: 12),
          Text(service.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(service.desc, style: const TextStyle(color: _textMuted, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(bool isDesktop) {
    final steps = [
      _HowStep(Icons.comment_rounded, '1. Déposez votre appareil', 'Apportez votre téléphone en magasin. Diagnostic gratuit et immédiat.'),
      _HowStep(Icons.build_circle_rounded, '2. On vous donne un devis', 'Devis transparent et sans engagement. Pièces de qualité garanties.'),
      _HowStep(Icons.check_circle_rounded, '3. Récupérez-le réparé', 'Réparation rapide (souvent le jour même). Garantie incluse.'),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 60),
      color: _bgCarbon,
      child: Column(
        children: [
          Text('COMMENT ÇA MARCHE', style: TextStyle(color: _neonCyan, fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final isRow = constraints.maxWidth > 600;
              return isRow
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: steps.map((s) => Expanded(child: _buildStepCard(s))).toList(),
                    )
                  : Column(
                      children: steps.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildStepCard(s),
                      )).toList(),
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(_HowStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _neonEmerald.withOpacity(0.3), width: 2),
              color: _neonEmerald.withOpacity(0.05),
            ),
            child: Icon(step.icon, color: _neonEmerald, size: 36),
          ),
          const SizedBox(height: 16),
          Text(step.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(step.desc, style: const TextStyle(color: _textMuted, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTrackRepair(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 60),
      color: _panelDark,
      child: Column(
        children: [
          Icon(Icons.track_changes_rounded, color: _neonAmber, size: 40),
          const SizedBox(height: 16),
          Text('SUIVEZ VOTRE RÉPARATION', style: TextStyle(color: _neonAmber, fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text('Entrez votre code de suivi pour connaître l\'état de votre appareil', style: TextStyle(color: _textMuted, fontSize: isDesktop ? 16 : 14)),
          const SizedBox(height: 24),
          SizedBox(
            width: isDesktop ? 500 : double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _trackingController,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Code de suivi...',
                      hintStyle: const TextStyle(color: _textMuted),
                      filled: true,
                      fillColor: _bgCarbon,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _neonAmber),
                      ),
                    ),
                    onSubmitted: (_) => _trackRepair(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _trackRepair,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonAmber,
                    foregroundColor: _bgCarbon,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SUIVRE', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          if (_trackingError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_trackingError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildContactAndHours(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 24, vertical: 60),
      color: _bgCarbon,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isRow = constraints.maxWidth > 600;
          return isRow
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildContactInfo()),
                    const SizedBox(width: 40),
                    Expanded(child: _buildHours()),
                  ],
                )
              : Column(
                  children: [
                    _buildContactInfo(),
                    const SizedBox(height: 40),
                    _buildHours(),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONTACT', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1)),
        const SizedBox(height: 20),
        _contactRow(Icons.location_on_rounded, '123 Rue de la Réparation, Alger', 'Adresse'),
        _contactRow(Icons.phone_rounded, '+213 555 12 34 56', 'Téléphone'),
        _contactRow(Icons.email_rounded, 'contact@laidanirepair.dz', 'Email'),
        _contactRow(Icons.language_rounded, 'www.laidanirepair.dz', 'Site web'),
      ],
    );
  }

  Widget _contactRow(IconData icon, String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _neonCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _neonCyan, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _textMuted, fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHours() {
    final hours = [
      ('Lundi - Jeudi', '09:00 - 18:00'),
      ('Vendredi', '09:00 - 12:00 / 14:00 - 18:00'),
      ('Samedi', '09:00 - 17:00'),
      ('Dimanche', 'Fermé'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HORAIRES', style: TextStyle(color: _neonEmerald, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1)),
        const SizedBox(height: 20),
        ...hours.map((h) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(h.$1, style: const TextStyle(color: Colors.white, fontSize: 13)),
              Text(h.$2, style: TextStyle(color: h.$2 == 'Fermé' ? Colors.redAccent : _neonEmerald, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _panelDark,
        border: Border(top: BorderSide(color: _neonCyan.withOpacity(0.2))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.memory, color: _neonCyan, size: 20),
              const SizedBox(width: 8),
              const Text('LaidaniRepair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('© 2026 LaidaniRepair — Tous droits réservés', style: TextStyle(color: _textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final String title;
  final String desc;
  const _ServiceItem(this.icon, this.title, this.desc);
}

class _HowStep {
  final IconData icon;
  final String title;
  final String desc;
  const _HowStep(this.icon, this.title, this.desc);
}
