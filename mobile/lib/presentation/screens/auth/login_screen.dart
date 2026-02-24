import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/auth_service.dart';
import '../../../config/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;

  Future<void> _login(Future<void> Function() loginFn) async {
    setState(() => _loading = true);
    try {
      await loginFn();
      if (mounted) context.go('/map');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao entrar: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              const Icon(Icons.location_on, size: 72, color: AppTheme.primary),
              const SizedBox(height: 8),
              Text('MinhaTurma', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),

              // E-mail e senha
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email))),
              const SizedBox(height: 12),
              TextField(controller: _passCtrl,  decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock)), obscureText: true),
              const SizedBox(height: 20),

              if (_loading)
                const CircularProgressIndicator()
              else ...[
                FilledButton.icon(
                  onPressed: () => _login(() => _authService.loginWithEmail(_emailCtrl.text, _passCtrl.text)),
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 16),

                // Divisor
                const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('ou entre com')), Expanded(child: Divider())]),
                const SizedBox(height: 16),

                // Botões sociais
                _SocialButton(label: 'Google',    icon: Icons.g_mobiledata, onTap: () => _login(_authService.loginWithGoogle)),
                const SizedBox(height: 8),
                _SocialButton(label: 'Facebook',  icon: Icons.facebook,     onTap: () => _login(_authService.loginWithFacebook)),
                const SizedBox(height: 8),
                _SocialButton(label: 'Apple',     icon: Icons.apple,        onTap: () => _login(_authService.loginWithApple)),
                const SizedBox(height: 24),

                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Não tem conta? Cadastre-se'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text('Continuar com $label'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
    );
  }
}
