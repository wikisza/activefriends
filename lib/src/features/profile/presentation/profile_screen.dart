import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFFE5F2E8),
            child: Icon(Icons.person, size: 40, color: Color(0xFF1E8E3E)),
          ),
          const SizedBox(height: 12),
          Text(
            'Uzytkownik ActiveFriends',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Poziom weryfikacji: 2',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Dostep do bazy danych',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aplikacja jest przygotowana pod backend API oparty o PostgreSQL (np. Supabase).\n'
                    'Podaj API_BASE_URL, a dane wydarzen beda pobierane z bazy.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const SelectableText(
                      'flutter run --dart-define=USE_API=true --dart-define=API_BASE_URL=https://twoj-backend/api',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
