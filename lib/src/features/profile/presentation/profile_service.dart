import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:activefriends/src/models/profile.dart';

class ProfileService {
  ProfileService() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  // Pobieranie profilu
  Future<Profile?> fetchProfile() async {
    final User? user = _client.auth.currentUser;
    if (user == null) return null;

    final Map<String, dynamic>? row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;
    return Profile.fromJson(row);
  }

  // Aktualizacja pseudonimu
  Future<void> updateDisplayName(String displayName) async {
    final User? user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('profiles')
        .update(<String, dynamic>{'display_name': displayName})
        .eq('id', user.id);
  }

  // Wgrywanie zdjęcia do Storage
  Future<void> uploadProfilePicture(File imageFile) async {
    final User? user = _client.auth.currentUser;
    if (user == null) throw Exception('Użytkownik niezalogowany');

    final String fileExtension = imageFile.path.split('.').last;
    final String fileName = '${user.id}/profile.$fileExtension';
    const String bucketName = 'avatars'; // Nazwa bucketa w Supabase

    // Wgrywamy plik
    await _client.storage.from(bucketName).upload(
          fileName,
          imageFile,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true, // Nadpisuje istniejące zdjęcie
          ),
        );

    // Pobieramy publiczny URL
    final String imageUrl = _client.storage.from(bucketName).getPublicUrl(fileName);

    // Aktualizujemy tabelę profiles
    await _client
        .from('profiles')
        .update(<String, dynamic>{'avatar_url': imageUrl})
        .eq('id', user.id);
  }
}