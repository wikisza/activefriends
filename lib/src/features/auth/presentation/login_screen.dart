import 'package:activefriends/src/features/auth/data/auth_service.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
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
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: cs.secondary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: cs.secondaryContainer,
                      child: Icon(
                        Icons.groups_2_outlined,
                        size: 42,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Active Friends',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ludzie, hobby i wydarzenia blisko Ciebie.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                _isRegistering ? 'Utwórz konto' : 'Zaloguj się',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 20),
                              if (_isRegistering) ...<Widget>[
                                TextFormField(
                                  controller: _displayNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Pseudonim',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (String? v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Podaj pseudonim';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'E-mail',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (String? v) {
                                  if (v == null || !v.contains('@')) {
                                    return 'Podaj poprawny e-mail';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
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
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (String? v) {
                                  if (v == null || v.length < 6) {
                                    return 'Hasło musi mieć co najmniej 6 znaków';
                                  }
                                  return null;
                                },
                              ),
                              if (_errorMessage != null) ...<Widget>[
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: cs.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: _isLoading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _isRegistering
                                            ? 'Zarejestruj się'
                                            : 'Zaloguj się',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                              ),
                            ],
                          ),
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
