import 'dart:typed_data';

import 'package:activefriends/src/features/auth/data/auth_service.dart';
import 'package:activefriends/src/models/profile.dart';
import 'package:activefriends/src/models/topic_catalog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:activefriends/src/features/profile/presentation/profile_service.dart';
import 'package:activefriends/src/features/profile/presentation/my_events_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  Profile? _profile;
  bool _isLoading = true;
  String? _email;
  Uint8List? _localImageBytes;
  bool _isUploadingAvatar = false;
  bool _isSavingTopics = false;
  final ImagePicker _picker = ImagePicker();
  bool _isTopicsExpanded = false;

  @override
  void initState() {
    super.initState();
    _email = _authService.currentUser?.email;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final Profile? p = await _profileService.fetchProfile();
      if (mounted) setState(() => _profile = p);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _extractExt(String filename) {
    final int dot = filename.lastIndexOf('.');
    if (dot == -1 || dot == filename.length - 1) {
      return 'jpg';
    }
    return filename.substring(dot + 1).toLowerCase();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (pickedFile == null) {
      return;
    }

    final Uint8List bytes = await pickedFile.readAsBytes();
    final String ext = _extractExt(pickedFile.name);

    setState(() {
      _localImageBytes = bytes;
      _isUploadingAvatar = true;
    });

    try {
      await _authService.uploadProfileAvatar(bytes: bytes, fileExt: ext);
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zdjęcie profilowe zaktualizowane.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _editDisplayName() async {
    final TextEditingController ctrl = TextEditingController(
      text: _profile?.displayName ?? '',
    );
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
      await _profileService.updateDisplayName(newName);
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

  Future<void> _saveSubscribedTopics(Set<String> topics) async {
    setState(() => _isSavingTopics = true);
    try {
      final List<String> nextTopics = topics.toList(growable: false);
      await _profileService.updateSubscribedTopics(nextTopics);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = _profile?.copyWith(subscribedTopics: nextTopics);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subskrypcje tematów zapisane.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się zapisać subskrypcji.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingTopics = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Set<String> subscribedTopics =
        (_profile?.subscribedTopics ?? const <String>[]).toSet();

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
                  child: GestureDetector(
                    // Pozwala kliknąć w cały avatar
                    onTap: _pickImage,
                    child: Stack(
                      // Odpowiednik FrameLayout
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: cs.primaryContainer,
                          backgroundImage: _localImageBytes != null
                              ? MemoryImage(_localImageBytes!)
                              : (_profile?.avatarUrl != null &&
                                        _profile!.avatarUrl!.trim().isNotEmpty
                                    ? NetworkImage(_profile!.avatarUrl!)
                                    : null),
                          child:
                              (_localImageBytes == null &&
                                  (_profile?.avatarUrl == null ||
                                      _profile!.avatarUrl!.trim().isEmpty))
                              ? Icon(
                                  Icons.person,
                                  size: 48,
                                  color: cs.onPrimaryContainer,
                                )
                              : null,
                        ),
                        // Mała ikonka aparatu w rogu
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: _isUploadingAvatar
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : Icon(
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
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
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
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.interests_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Subskrybowane tematy i hobby',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_isSavingTopics)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...(_isTopicsExpanded 
                                    ? kSupportedTopics 
                                    : kSupportedTopics.take(5))
                                .map((String topic) {
                              final bool isSelected = subscribedTopics.contains(topic);
                              return FilterChip(
                                label: Text(topic),
                                selected: isSelected,
                                onSelected: _isSavingTopics
                                    ? null
                                    : (bool selected) {
                                        final Set<String> next = Set<String>.from(subscribedTopics);
                                        if (selected) {
                                          next.add(topic);
                                        } else {
                                          next.remove(topic);
                                        }
                                        _saveSubscribedTopics(next);
                                      },
                              );
                            }),
                          ],
                        ),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isTopicsExpanded = !_isTopicsExpanded;
                              });
                            },
                            icon: Icon(
                              _isTopicsExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                            ),
                            label: Text(
                              _isTopicsExpanded ? 'Pokaż mniej' : 'Pokaż wszystkie tematy',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
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
                      leading: const Icon(Icons.event_note_outlined),
                      title: const Text('Moje wydarzenia'),
                      subtitle: const Text('Lista Twoich aktywności'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const MyEventsScreen()),
                        );
                      },
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
                        title: Text(
                          'Wyloguj',
                          style: TextStyle(color: cs.error),
                        ),
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
