import 'package:activefriends/src/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SignUpResult {
  signedIn,
  confirmationEmailSent,
}

class AuthService {
  AuthService() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final AuthResponse response =
        await _client.auth.signInWithPassword(email: email, password: password);
    final User? user = response.user;
    if (user != null) {
      final String fallbackName = _emailPrefix(user.email);
      await _ensureProfileExists(displayNameFallback: fallbackName);
    }
  }

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final AuthResponse response = await _client.auth.signUp(
      email: email,
      password: password,
      data: <String, dynamic>{
        'display_name': displayName,
      },
    );

    // If email confirmation is enabled, there is no session yet.
    // Profile is created after first successful sign-in.
    if (response.session == null) {
      return SignUpResult.confirmationEmailSent;
    }

    await _ensureProfileExists(displayNameFallback: displayName);
    return SignUpResult.signedIn;
  }

  Future<void> _ensureProfileExists({required String displayNameFallback}) async {
    final User? user = currentUser;
    if (user == null) {
      return;
    }

    final String displayNameFromMeta =
        (user.userMetadata?['display_name'] as String?)?.trim() ?? '';
    final String displayName =
        displayNameFromMeta.isNotEmpty ? displayNameFromMeta : displayNameFallback;

    await _client.from('profiles').upsert(
      <String, dynamic>{
        'id': user.id,
        'display_name': displayName,
      },
      onConflict: 'id',
    );
  }

  String _emailPrefix(String? email) {
    if (email == null || email.isEmpty) {
      return 'Uzytkownik';
    }
    final int atIndex = email.indexOf('@');
    if (atIndex <= 0) {
      return email;
    }
    return email.substring(0, atIndex);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
