import 'package:activefriends/src/app/theme/app_palette.dart';
import 'package:activefriends/src/features/profile/presentation/profile_service.dart';
import 'package:activefriends/src/models/event.dart';
import 'package:activefriends/src/models/event_route.dart';
import 'package:activefriends/src/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final ProfileService _service = ProfileService();
  EventRoute? _route;
  Profile? _organizer;
  List<Map<String, dynamic>> _participants = [];
  String _fullAddress = "Ładowanie adresu...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Pobieramy trasę, dane organizatora, uczestników i adres równolegle
      final results = await Future.wait([
        _service.fetchEventRoute(widget.event.id),
        _service.fetchProfileById(widget.event.organizerId),
        _service.fetchParticipantsWithProfiles(widget.event.id),
        _service.getAddressFromCoords(widget.event.lat, widget.event.lng),
      ]);

      if (mounted) {
        setState(() {
          _route = results[0] as EventRoute?;
          _organizer = results[1] as Profile?;
          _participants = results[2] as List<Map<String, dynamic>>;
          _fullAddress = results[3] as String;
        });
      }
    } catch (e) {
      debugPrint('Błąd ładowania danych: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń wydarzenie'),
        content: const Text(
            'Czy na pewno chcesz usunąć to wydarzenie? Wszystkie dane uczestników oraz trasa zostaną bezpowrotnie usunięte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń wszystko'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.deleteEvent(widget.event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wydarzenie zostało usunięte.')),
          );
          Navigator.of(context).pop(true); // Wraca do listy i informuje o zmianie
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd podczas usuwania: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final event = widget.event;

    // Sprawdzamy, czy aktualny użytkownik jest organizatorem
    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isOrganizer = currentUserId == event.organizerId;

    return Scaffold(
      body: _isLoading && _organizer == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildAppBar(event, isOrganizer),
                SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- TYTUŁ I SUBTYTUŁ ---
                          Text(
                      event.title,
                             
                      style: theme.textTheme.headlineMedium
                                  ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                          if (event.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                        event.subtitle!,
                               
                        style: theme.textTheme.titleMedium
                                    ?.copyWith(
                          color: cs.secondary,
                        ),
                      ),
                          ],
                          const SizedBox(height: 16),

                    // --- STATUSY (CHIPY) ---
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildBadge(
                          event.scenario.name,
                          AppPalette.scenarioColorByName(event.scenario.name),
                        ),
                        _buildBadge(
                          event.status.name,
                          event.status == EventStatus.open
                              ? AppPalette.success
                              : cs.error,
                        ),
                      ],
                    ),
                    const Divider(height: 40),

                    // --- CZAS TRWANIA ---
                    _buildSectionTitle('Kiedy i gdzie?'),
                    _InfoTile(
                      icon: Icons.calendar_today,
                      title: 'Początek',
                      value: event.startsAt != null
                          ? DateFormat(
                              'EEEE, d MMMM HH:mm',
                              'pl',
                            ).format(event.startsAt!)
                          : 'Nieustalony',
                    ),
                    if (event.endsAt != null)
                      _InfoTile(
                        icon: Icons.event_busy,
                        title: 'Koniec',
                        value: DateFormat(
                          'EEEE, d MMMM HH:mm',
                          'pl',
                        ).format(event.endsAt!),
                      ),

                    // TUTAJ WSTAWIONY ADRES:
                    _InfoTile(
                      icon: Icons.location_on_outlined,
                      title: 'Dokładny adres',
                      value:
                          _fullAddress, // Ta zmienna, którą ładujemy w _loadData
                    ),

                    // Możesz zostawić miasto jako dodatkową informację:
                    _InfoTile(
                      icon: Icons.location_city,
                      title: 'Miasto',
                      value: event.city,
                    ),

                    const Divider(height: 40),

                    // --- TRASA (Z EventRoute) ---
                    if (_route != null) ...[
                      _buildSectionTitle('Parametry trasy'),
                      Row(
                        children: [
                          _StatBox(
                            label: 'Dystans',
                            value:
                                '${((_route!.distanceM ?? 0) / 1000).toStringAsFixed(1)} km',
                            icon: Icons.map,
                          ),
                          _StatBox(
                            label: 'Czas',
                            value:
                                '${((_route!.durationS ?? 0) / 60).round()} min',
                            icon: Icons.timer,
                          ),
                        ],
                      ),
                      const Divider(height: 40),
                    ],

                    // --- OPIS ---
                    _buildSectionTitle('Opis wydarzenia'),
                    Text(
                      event.description ?? 'Brak szczegółowego opisu.',
                      style: theme.textTheme.bodyLarge,
                    ),

                    const Divider(height: 40),

                    // --- ORGANIZATOR ---
                    if (_organizer != null) ...[
                      _buildSectionTitle('Organizator'),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: _organizer!.avatarUrl != null
                              ? NetworkImage(_organizer!.avatarUrl!)
                              : null,
                          child: _organizer!.avatarUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(_organizer!.displayName),
                        subtitle: Text(
                          'Poziom weryfikacji: ${_organizer!.verificationLevel}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () {},
                        ),
                      ),
                    ],

                          const Divider(height: 40),

                          // --- UCZESTNICY ---
                          _buildSectionTitle(
                              'Uczestnicy (${_participants.length})'),
                          const SizedBox(height: 12),

                    if (_participants.isEmpty)
                      Text(
                        'Nikt jeszcze nie dołączył. Bądź pierwszy!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.outline,
                        ),
                      )
                    else
                      SizedBox(
                        height: 90, // Wysokość dla awatara i podpisu
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _participants.length,
                          itemBuilder: (context, index) {
                            final pData = _participants[index];
                            final profile = Profile.fromJson(pData['profiles']);
                            final roleName = pData['role'] as String;

                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: cs.primaryContainer,
                                        backgroundImage:
                                            profile.avatarUrl != null
                                            ? NetworkImage(profile.avatarUrl!)
                                            : null,
                                        child: profile.avatarUrl == null
                                            ? Icon(
                                                Icons.person,
                                                color: cs.onPrimaryContainer,
                                              )
                                            : null,
                                      ),
                                      // Badge dla specjalnych ról (organizator/pomocnik)
                                      if (roleName != 'member')
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: roleName == 'organizer'
                                                ? AppPalette.warning
                                                : cs.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: cs.surface,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            roleName == 'organizer'
                                                ? Icons.star
                                                : Icons.medical_services,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    profile.displayName.split(' ')[0],
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    // --- METADANE ---
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Utworzono: ${DateFormat('dd.MM.yyyy').format(event.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // --- HELPERY UI ---

  Widget _buildAppBar(Event event, bool isOrganizer) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      actions: [
        if (isOrganizer)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Usuń wydarzenie',
            onPressed: _confirmDelete,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: event.photoUrl != null
            ? Image.network(event.photoUrl!, fit: BoxFit.cover)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppPalette.scenarioColorByName(event.scenario.name),
                      AppPalette.scenarioColorByName(
                        event.scenario.name,
                      ).withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.event,
                  size: 80,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
