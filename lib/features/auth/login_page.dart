import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/page_transition.dart';
import '../../shared/components.dart';
import 'auth_gate.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _email.text,
            password: _password.text,
          );
    } catch (e) {
      setState(() => _message = _readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _message = 'Enter your email first.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      setState(() => _message = 'Password reset email sent.');
    } catch (e) {
      setState(() => _message = _readable(e));
    }
  }

  String _readable(Object e) {
    final s = e.toString();
    return s.replaceFirst('Exception: ', '').replaceFirst('AuthException: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final backend = ref.watch(backendEnabledProvider);

    return GlassScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: GlassSurface(
                      radius: 26,
                      blur: 20,
                      padding: const EdgeInsets.all(19),
                      child: Icon(Icons.explore_rounded,
                          color: c.accent, size: 38),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Journey360',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Safety for your circle. Power for your next effort.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.onSurfaceMuted),
                  ),
                  const SizedBox(height: 28),
                  NeoCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          backend
                              ? 'Welcome back to Journey360.'
                              : 'Connect a Supabase project (see the README) '
                                  'to enable accounts and circles.',
                          style: TextStyle(
                              color: c.onSurfaceMuted, fontSize: 12.5),
                        ),
                        const SizedBox(height: 18),
                        NeoTextField(
                          controller: _email,
                          label: 'Email',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        NeoTextField(
                          controller: _password,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => backend ? _signIn() : null,
                        ),
                        const SizedBox(height: 18),
                        NeoButton(
                          label: 'Sign in',
                          busy: _busy,
                          onPressed: (_busy || !backend) ? null : _signIn,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: backend ? _reset : null,
                              child: const Text('Forgot password?'),
                            ),
                            TextButton(
                              onPressed: backend
                                  ? () => context
                                      .pushJourney(const RegisterPage())
                                  : null,
                              child: const Text('Create account'),
                            ),
                          ],
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: c.accent,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeoButton(
                    label: backend
                        ? 'Continue without an account'
                        : 'Get started',
                    icon: Icons.arrow_forward_rounded,
                    tone: NeoButtonTone.neutral,
                    onPressed: () => ref
                        .read(offlineEnteredProvider.notifier)
                        .state = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
