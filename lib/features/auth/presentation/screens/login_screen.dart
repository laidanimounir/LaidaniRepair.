import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:laidani_repair/core/constants/app_constants.dart';
import 'package:laidani_repair/core/router/app_router.dart';
import 'package:laidani_repair/features/auth/presentation/providers/auth_provider.dart';

enum _ScreenState { form, loading, success, error }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool         _obscurePassword     = true;
  String       _errorMessage        = '';
  _ScreenState _screenState         = _ScreenState.form;

  late final AnimationController _animController;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _scaleAnim;

  static const Color _bgCarbon     = Color(0xFF050914);
  static const Color _neonIce      = Color(0xFF00E5FF);
  static const Color _glassWhite   = Color(0x0AFFFFFF);
  static const Color _glassBorder  = Color(0x1AFFFFFF);
  static const Color _textMuted    = Color(0xFF8A9BB4);
  static const Color _errorRed     = Color(0xFFFF4C4C);
  static const Color _successGreen = Color(0xFF00C47A);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

 
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _screenState  = _ScreenState.loading;
      _errorMessage = '';
    });

    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    final state = ref.read(authNotifierProvider);
    state.whenOrNull(
      error: (e, _) {
        String message = 'Une erreur est survenue. Veuillez réessayer.';
        if (e is AuthException) {
          if (e.message.contains('Invalid login credentials') ||
              e.message.contains('invalid_credentials')) {
            message = 'E-mail ou mot de passe incorrect.';
          } else if (e.message.contains('Email not confirmed')) {
            message = 'Veuillez confirmer votre e-mail avant de vous connecter.';
          } else {
            message = e.message;
          }
        }
        setState(() {
          _screenState  = _ScreenState.error;
          _errorMessage = message;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _screenState = _ScreenState.form);
        });
      },
      data: (_) async {
        if (!mounted) return;

        ref.read(routerRefreshProvider).lockForAnimation();
        setState(() => _screenState = _ScreenState.success);
        
        await Future.delayed(const Duration(milliseconds: 1800));
        if (!mounted) return;
      
        ref.read(routerRefreshProvider).unlockAndNotify();
      },
    );
  }
 

  void _handleForgotPassword() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
       
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _neonIce.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_reset_outlined, color: _neonIce, size: 36),
                const SizedBox(height: 16),
                const Text(
                  'Accès restreint',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Contactez l\'administrateur (Lounis)\npour réinitialiser votre accès.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _neonIce,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: _neonIce.withOpacity(0.3)),
                      ),
                    ),
                    child: const Text('Compris'),
                  ),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.of(context).size;
    final isDesktop = size.width >= 850;

    return Scaffold(
      backgroundColor: _bgCarbon,
      body: Stack(
        children: [
          Positioned(
            top: -150, left: -150,
            child: _glowCircle(_neonIce, 500, 0.08, 0.15),
          ),
          Positioned(
            bottom: -200, right: -100,
            child: _glowCircle(const Color(0xFF0033FF), 600, 0.05, 0.10),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        width: isDesktop ? 900 : 450,
                        constraints: BoxConstraints(
                          minHeight: isDesktop ? 550 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: _glassWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _glassBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: isDesktop
                            ? Row(
                                children: [
                                  Expanded(flex: 5, child: _buildBrandingSide()),
                                  Container(width: 1, height: 420, color: _glassBorder),
                                  Expanded(flex: 5, child: _buildFormSide()),
                                ],
                              )
                            : _buildFormSide(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(Color color, double size, double op, double glowOp) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(op),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(glowOp),
            blurRadius: 150,
            spreadRadius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingSide() {
    return Container(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bgCarbon.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _neonIce.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: _neonIce.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.phonelink_setup, color: _neonIce, size: 48),
          ),
          const SizedBox(height: 32),
          const Text(
            'LAIDANI\nREPAIR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Réparation  •  Devis  •  Suivi',
            style: TextStyle(
              color: _neonIce.withOpacity(0.8),
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 28),
          _buildStatusChip(Icons.shield_outlined,             'Connexion sécurisée'),
          const SizedBox(height: 10),
          _buildStatusChip(Icons.desktop_windows_outlined,    'Application bureau'),
          const SizedBox(height: 10),
          _buildStatusChip(Icons.supervisor_account_outlined, 'Réservé au personnel'),
        ],
      ),
    );
  }

  Widget _buildStatusChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: _neonIce, size: 14),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: _neonIce.withOpacity(0.65),
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFormSide() {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: _buildStateContent(),
      ),
    );
  }

  Widget _buildStateContent() {
    switch (_screenState) {
      case _ScreenState.success:
        return _buildResultCircle(
          key: const ValueKey('success'),
          color: _successGreen,
          icon: Icons.check_rounded,
          message: 'Connexion réussie',
        );
      case _ScreenState.error:
        return _buildResultCircle(
          key: const ValueKey('error'),
          color: _errorRed,
          icon: Icons.close_rounded,
          message: _errorMessage,
        );
      case _ScreenState.loading:
      case _ScreenState.form:
        return _buildForm(key: const ValueKey('form'));
    }
  }

  Widget _buildResultCircle({
    required Key key,
    required Color color,
    required IconData icon,
    required String message,
  }) {
    return SizedBox(
      key: key,
      height: 380,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.6), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          if (_screenState == _ScreenState.error) ...[
            const SizedBox(height: 16),
            Text(
              'Nouvelle tentative dans quelques instants...',
              style: TextStyle(color: _textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm({required Key key}) {
    final isLoading = _screenState == _ScreenState.loading;

    return SizedBox(
      key: key,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Connexion',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Connectez-vous à votre espace de travail.',
              style: TextStyle(color: _textMuted, fontSize: 13),
            ),
            const SizedBox(height: 32),

            _buildCyberTextField(
              controller: _emailController,
              label: 'Adresse e-mail',
              icon: Icons.person_outline,
              isEmail: true,
            ),
            const SizedBox(height: 18),

            _buildCyberTextField(
              controller: _passwordController,
              label: 'Mot de passe',
              icon: Icons.lock_outline,
              isPassword: true,
              isObscured: _obscurePassword,
              onToggleVisibility: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              onSubmit: isLoading ? null : _submit,
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _errorMessage.isNotEmpty && _screenState == _ScreenState.form
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: _errorRed, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: _errorRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: _textMuted,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 28),

            Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _neonIce.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonIce,
                  foregroundColor: _bgCarbon,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: _bgCarbon, strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Se connecter',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '© 2026 LAIDANI.DZ',
                  style: TextStyle(
                    color: _textMuted.withOpacity(0.45),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: _neonIce.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: _neonIce,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyberTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isEmail    = false,
    bool? isObscured,
    VoidCallback? onToggleVisibility,
    VoidCallback? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? isObscured! : false,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
      textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: onSubmit != null ? (_) => onSubmit() : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: _neonIce, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscured!
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _textMuted,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: _bgCarbon.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _neonIce, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _errorRed.withOpacity(0.6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1.8),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Donnée manquante.';
        if (isEmail && !v.contains('@')) return 'Format invalide.';
        return null;
      },
    );
  }
}