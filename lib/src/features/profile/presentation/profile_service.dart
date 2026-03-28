import 'dart:io';
import 'package:activefriends/src/models/event.dart';
import 'package:activefriends/src/models/event_route.dart';
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

  Future<List<Event>> fetchMyEvents() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('events') // nazwa Twojej tabeli w Supabase
        .select()
        .eq('organizer_id', user.id)
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    return data.map((json) => Event.fromJson(json)).toList();
  }

  Future<Profile?> fetchProfileById(String id) async {
    final response = await _client.from('profiles').select().eq('id', id).maybeSingle();
    return response != null ? Profile.fromJson(response) : null;
  }

  Future<EventRoute?> fetchEventRoute(String eventId) async {
    final response = await _client
        .from('event_routes') // nazwa Twojej tabeli tras
        .select()
        .eq('event_id', eventId)
        .maybeSingle();

    if (response == null) return null;
    return EventRoute.fromJson(response);
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