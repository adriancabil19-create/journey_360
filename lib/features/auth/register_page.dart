import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/page_transition.dart';
import '../settings/feature_pages.dart';
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

  final _fullNameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _busy = false;
  bool _consentGiven = false;
  String? _message;

  // Per-field validation messages, keyed by field name.
  final Map<String, String?> _errors = {};

  @override
  void dispose() {
    for (final ctrl in [_fullName, _username, _email, _password, _confirm]) {
      ctrl.dispose();
    }
    for (final node in [
      _fullNameFocus,
      _usernameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  bool _validate() {
    final errors = <String, String?>{};
    if (_fullName.text.trim().isEmpty) {
      errors['fullName'] = 'Enter your full name.';
    }
    if (_username.text.trim().isEmpty) {
      errors['username'] = 'Choose a username.';
    }
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      errors['email'] = 'Enter a valid email address.';
    }
    if (_password.text.length < 6) {
      errors['password'] = 'Use at least 6 characters.';
    }
    if (_confirm.text != _password.text) {
      errors['confirm'] = 'Passwords do not match.';
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _message = _consentGiven
          ? null
          : 'Accept the Terms of Use and Privacy Notice to continue.';
    });
    // Move focus to the first field with an error so keyboard / screen-reader
    // users are taken straight to what needs fixing.
    const order = ['fullName', 'username', 'email', 'password', 'confirm'];
    for (final key in order) {
      if (errors[key] != null) {
        _focusFor(key).requestFocus();
        break;
      }
    }
    return errors.isEmpty && _consentGiven;
  }

  FocusNode _focusFor(String key) => switch (key) {
        'fullName' => _fullNameFocus,
        'username' => _usernameFocus,
        'email' => _emailFocus,
        'password' => _passwordFocus,
        _ => _confirmFocus,
      };

  Future<void> _submit() async {
    if (!_validate()) return;
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
            consentedAt: DateTime.now().toUtc().toIso8601String(),
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
      body: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeoTextField(
              controller: _fullName,
              focusNode: _fullNameFocus,
              label: 'Full name',
              icon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              errorText: _errors['fullName'],
              enabled: !_busy,
              onSubmitted: (_) => _usernameFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            NeoTextField(
              controller: _username,
              focusNode: _usernameFocus,
              label: 'Username',
              icon: Icons.alternate_email,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              errorText: _errors['username'],
              enabled: !_busy,
              onSubmitted: (_) => _emailFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            NeoTextField(
              controller: _email,
              focusNode: _emailFocus,
              label: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              errorText: _errors['email'],
              enabled: !_busy,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            NeoTextField(
              controller: _password,
              focusNode: _passwordFocus,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _errors['password'],
              enabled: !_busy,
              onSubmitted: (_) => _confirmFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            NeoTextField(
              controller: _confirm,
              focusNode: _confirmFocus,
              label: 'Confirm password',
              icon: Icons.lock_reset_outlined,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _errors['confirm'],
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Semantics(
              container: true,
              checked: _consentGiven,
              label: 'I agree to the Terms of Use and Privacy Notice',
              child: CheckboxListTile(
                value: _consentGiven,
                onChanged: _busy
                    ? null
                    : (value) =>
                        setState(() => _consentGiven = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('I agree to the '),
                    _InlineLink(
                      text: 'Terms of Use',
                      onTap: () => context.pushJourney(const TermsPage()),
                    ),
                    const Text(' and '),
                    _InlineLink(
                      text: 'Privacy Notice',
                      onTap: () => context.pushJourney(const PrivacyPage()),
                    ),
                    const Text('.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            NeoButton(
              label: 'Create account',
              busy: _busy,
              onPressed: _busy ? null : _submit,
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: c.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Text(
          text,
          style: TextStyle(color: c.accent, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
