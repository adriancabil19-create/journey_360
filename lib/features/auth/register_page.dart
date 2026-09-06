import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/components.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_fullName.text.trim().isEmpty || _username.text.trim().isEmpty) {
      setState(() => _message = 'Enter your name and a username.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _message = 'Password must be at least 6 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _message = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final note = await ref.read(authRepositoryProvider).register(
            fullName: _fullName.text,
            username: _username.text,
            email: _email.text,
            password: _password.text,
          );
      if (!mounted) return;
      if (note != null) {
        setState(() => _message = note);
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _message = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('AuthException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NeoScaffold(
      title: 'Create account',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeoTextField(
            controller: _fullName,
            label: 'Full name',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          NeoTextField(
            controller: _username,
            label: 'Username',
            icon: Icons.alternate_email,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
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
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          NeoTextField(
            controller: _confirm,
            label: 'Confirm password',
            icon: Icons.lock_reset_outlined,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          NeoButton(
            label: 'Create account',
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
