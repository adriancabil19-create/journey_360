import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication over Supabase (MD section 8). When [client] is null the app is
/// running in offline mode and these calls are unavailable.
class AuthRepository {
  const AuthRepository(this.client);

  final SupabaseClient? client;

  bool get isEnabled => client != null;
  User? get currentUser => client?.auth.currentUser;
  Session? get session => client?.auth.currentSession;

  Stream<AuthState> authChanges() =>
      client?.auth.onAuthStateChange ?? const Stream.empty();

  Future<void> signIn({required String email, required String password}) async {
    final c = _require();
    await c.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<String?> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final c = _require();
    final res = await c.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'username': username.trim()},
    );
    // With email confirmation on, session is null until the link is clicked.
    return res.session == null
        ? 'Check your email to confirm your account.'
        : null;
  }

  Future<void> sendPasswordReset(String email) async {
    final c = _require();
    await c.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async => client?.auth.signOut();

  SupabaseClient _require() {
    final c = client;
    if (c == null) {
      throw StateError('Connect a Supabase project to use accounts.');
    }
    return c;
  }
}
