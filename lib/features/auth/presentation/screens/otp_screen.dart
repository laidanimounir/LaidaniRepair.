import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laidani_repair/core/services/totp_service.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String userId;
  const OtpScreen({super.key, required this.userId});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _error = 'Code incomplet');
      return;
    }
    try {
      final client = Supabase.instance.client;
      final profile = await client.from('profiles').select('totp_secret').eq('id', widget.userId).single();
      final secret = profile['totp_secret'] as String?;
      if (secret == null) {
        setState(() => _error = 'TOTP non configuré');
        return;
      }
      if (TotpService.verifyTotp(secret, code)) {
        if (mounted) context.go('/shell/dashboard');
      } else {
        setState(() => _error = 'Code invalide');
      }
    } catch (e) {
      setState(() => _error = 'Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person, size: 64, color: Color(0xFF00E5FF)),
              const SizedBox(height: 16),
              const Text('VÉRIFICATION TOTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('Entrez le code à 6 chiffres', style: TextStyle(color: Color(0xFF8A9BB4))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                  width: 45, height: 55, margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFF1E1E36),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _error != null ? Colors.redAccent : const Color(0xFF00E5FF))),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                      if (i == 5 && v.isNotEmpty) _verify();
                    },
                  ),
                )),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verify,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: const Color(0xFF050914), padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('VÉRIFIER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
