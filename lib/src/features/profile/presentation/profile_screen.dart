import 'package:activefriends/src/features/auth/data/auth_service.dart';
import 'package:activefriends/src/models/profile.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  Profile? _profile;
  bool _isLoading = true;
  String? _email;
  File? _localImageFile; // Zmienna trzymająca wybrane zdjęcie
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _email = _authService.currentUser?.email;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final Profile? p = await _authService.fetchProfile();
      if (mounted) setState(() => _profile = p);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    // Możesz też użyć ImageSource.camera, żeby zrobić zdjęcie
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _localImageFile = File(pickedFile.path);
      });
      
      // TODO: Tutaj wyślij zdjęcie na swój serwer/Firebase za pomocą _authService
      // _authService.uploadProfilePicture(_localImageFile!);
    }
  }

  Future<void> _editDisplayName() async {
    final TextEditingController ctrl =
        TextEditingController(text: _profile?.displayName ?? '');
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Zmień pseudonim'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Pseudonim',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    try {
      await _authService.updateDisplayName(newName);
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pseudonim zaktualizowany.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się zapisać zmian.')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: <Widget>[
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Wyloguj',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector( // Pozwala kliknąć w cały avatar
                    onTap: _pickImage,
                    child: Stack( // Odpowiednik FrameLayout
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: cs.primaryContainer,
                          // Jeśli mamy lokalne zdjęcie, pokazujemy je. Jeśli nie, sprawdzamy URL w profilu. 
                          // Jeśli URL też jest pusty, pokazujemy ikonę domyślną.
                          backgroundImage: _localImageFile != null
                              ? FileImage(_localImageFile!)
                              : (_profile?.avatarUrl != null 
                                  ? NetworkImage(_profile!.avatarUrl!) 
                                  : null) as ImageProvider?,
                          child: _localImageFile == null && _profile?.avatarUrl == null
                              ? Icon(Icons.person, size: 48, color: cs.onPrimaryContainer)
                              : null,
                        ),
                        // Mała ikonka aparatu w rogu
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: cs.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _profile?.displayName ?? '—',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _editDisplayName,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edytuj pseudonim',
                      ),
                    ],
                  ),
                ),
                if (_email != null)
                  Center(
                    child: Text(
                      _email!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 8),
                Center(
                  child: Chip(
                    label: Text(
                      'Weryfikacja: poziom ${_profile?.verificationLevel ?? 1}',
                    ),
                    avatar: const Icon(Icons.verified_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 30),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('E-mail'),
                        subtitle: Text(_email ?? '—'),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Pseudonim'),
                        subtitle: Text(_profile?.displayName ?? '—'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _editDisplayName,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Icon(Icons.logout, color: cs.error),
                        title:
                            Text('Wyloguj', style: TextStyle(color: cs.error)),
                        onTap: _signOut,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
