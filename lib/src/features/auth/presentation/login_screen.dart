import 'dart:ui';

import 'package:activefriends/src/app/theme/app_palette.dart';
import 'package:activefriends/src/app/ui/premium_widgets.dart';
import 'package:activefriends/src/features/auth/data/auth_service.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late final AnimationController _auroraCtrl;

  @override
  void initState() {
    super.initState();
    _auroraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _auroraCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isRegistering) {
        final SignUpResult result = await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
        );
        if (mounted && result == SignUpResult.confirmationEmailSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Konto utworzone. Potwierdź e-mail, a potem zaloguj się.',
              ),
            ),
          );
          setState(() {
            _isRegistering = false;
            _passwordController.clear();
          });
        }
      } else {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid login credentials')) {
      return 'Nieprawidłowy e-mail lub hasło.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Potwierdź e-mail i spróbuj ponownie.';
    }
    if (raw.contains('User already registered')) {
      return 'Konto z tym adresem już istnieje.';
    }
    if (raw.contains('429') || raw.contains('Too Many Requests')) {
      return 'Za dużo prób. Odczekaj chwilę i spróbuj ponownie.';
    }
    if (raw.contains('Password should be')) {
      return 'Hasło musi mieć co najmniej 6 znaków.';
    }
    return 'Coś poszło nie tak. Spróbuj ponownie.';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppPalette.dark0,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ── Dark fire aurora ─────────────────────────────────
          _AuroraBackground(animation: _auroraCtrl),

          // ── Content ──────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _LogoSection(tt: tt),
                    const SizedBox(height: 36),

                    // Dark glass form card
                    _GlassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Align(
                                key: ValueKey<bool>(_isRegistering),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _isRegistering
                                      ? 'Utwórz konto'
                                      : 'Zaloguj się',
                                  style: tt.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),

                            if (_isRegistering) ...<Widget>[
                              TextFormField(
                                controller: _displayNameController,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Pseudonim',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (String? v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Podaj pseudonim'
                                        : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (String? v) =>
                                  (v == null || !v.contains('@'))
                                      ? 'Podaj poprawny e-mail'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Hasło',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (String? v) =>
                                  (v == null || v.length < 6)
                                      ? 'Hasło musi mieć co najmniej 6 znaków'
                                      : null,
                            ),

                            if (_errorMessage != null) ...<Widget>[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppPalette.emergency
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppPalette.emergency
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.error_outline,
                                      size: 16,
                                      color: AppPalette.emergency,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: AppPalette.emergency,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            GradientButton(
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Text(
                                      _isRegistering
                                          ? 'Zarejestruj się'
                                          : 'Zaloguj się',
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() {
                        _isRegistering = !_isRegistering;
                        _errorMessage = null;
                      }),
                      child: Text(
                        _isRegistering
                            ? 'Masz już konto? Zaloguj się'
                            : 'Nie masz konta? Zarejestruj się',
                        style: const TextStyle(
                          color: AppPalette.brandEnd,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dark fire aurora background ─────────────────────────────────────────────

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        final double t = animation.value;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Deep black base
            const ColoredBox(color: AppPalette.dark0),
            // Top-right: deep orange
            Positioned(
              top: -80 + t * 30,
              right: -60 + t * 20,
              child: _Blob(
                size: 380,
                color: AppPalette.brandStart,
                opacity: 0.28 + t * 0.10,
              ),
            ),
            // Bottom-left: amber
            Positioned(
              bottom: -100 - t * 40,
              left: -80 + t * 15,
              child: _Blob(
                size: 320,
                color: AppPalette.brandEnd,
                opacity: 0.20 + t * 0.08,
              ),
            ),
            // Mid: red-orange accent
            Positioned(
              top: 220 + t * 60,
              right: 20 - t * 30,
              child: _Blob(
                size: 200,
                color: const Color(0xFFFF3D00),
                opacity: 0.14 + t * 0.06,
              ),
            ),
            // Heavy blur — fuses into smooth glow
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.expand(),
            ),
          ],
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.color,
    required this.opacity,
  });
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      );
}

// ─── Logo section ─────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection({required this.tt});
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // Proximity-signal logo — matches launcher icon
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppPalette.dark1,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppPalette.brandStart.withValues(alpha: 0.40),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CustomPaint(painter: _SignalPainter()),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (Rect rect) =>
              AppPalette.brandGradient.createShader(rect),
          child: Text(
            'Blisko',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ludzie, hobby i wydarzenia blisko Ciebie.',
          style: tt.bodyMedium?.copyWith(color: AppPalette.darkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SignalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.36;
    final double cy = size.height * 0.64;

    // Three arcs: deep → mid → bright green
    final List<(double radius, Color color, double strokeW)> arcs = <(double, Color, double)>[
      (size.width * 0.52, const Color(0xFF166534), 5.0),
      (size.width * 0.35, const Color(0xFF16A34A), 5.5),
      (size.width * 0.19, const Color(0xFF4ADE80), 6.0),
    ];

    for (final (double r, Color color, double sw) in arcs) {
      final Paint p = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.93, // ~225° in radians
        -1.57, // –90° sweep → top-right
        false,
        p,
      );
    }

    // Center dot
    canvas.drawCircle(
      Offset(cx, cy),
      5.5,
      Paint()..color = const Color(0xFF4ADE80),
    );
    // Dot glow
    canvas.drawCircle(
      Offset(cx, cy),
      9,
      Paint()
        ..color = const Color(0xFF4ADE80).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Dark glass card ──────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppPalette.dark1.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppPalette.brandStart.withValues(alpha: 0.08),
                blurRadius: 48,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}
