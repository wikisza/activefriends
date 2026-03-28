import 'dart:typed_data';

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

  Future<Profile?> fetchProfile() async {
    final User? user = currentUser;
    if (user == null) return null;
    final Map<String, dynamic>? row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  Future<void> updateDisplayName(String displayName) async {
    final User? user = currentUser;
    if (user == null) return;
    await _client
        .from('profiles')
        .update(<String, dynamic>{'display_name': displayName})
        .eq('id', user.id);
  }

  Future<String> uploadProfileAvatar({
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('Musisz być zalogowany, aby dodać zdjęcie profilowe.');
    }

    final String normalizedExt =
        fileExt.toLowerCase().replaceAll('.', '').trim().isEmpty
            ? 'jpg'
            : fileExt.toLowerCase().replaceAll('.', '').trim();

    final String path = 'avatars/${user.id}/avatar.$normalizedExt';
    final String contentType = switch (normalizedExt) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    try {
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );

      final String publicUrl = _client.storage.from('avatars').getPublicUrl(path);

      await _client
          .from('profiles')
          .update(<String, dynamic>{'avatar_url': publicUrl}).eq('id', user.id);

      return publicUrl;
    } on StorageException catch (e) {
      throw Exception('Błąd Storage: ${e.message}');
    } on PostgrestException catch (e) {
      throw Exception('Błąd bazy danych: ${e.message}');
    } catch (_) {
      throw Exception('Nie udało się wgrać zdjęcia profilowego.');
    }
  }
}
