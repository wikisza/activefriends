import 'package:activefriends/src/features/profile/presentation/profile_service.dart';
import 'package:activefriends/src/models/event.dart';
import 'package:activefriends/src/models/event_route.dart';
import 'package:activefriends/src/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Pobieramy trasę i dane organizatora równolegle
      final results = await Future.wait([
        _service.fetchEventRoute(widget.event.id),
        _service.fetchProfileById(widget.event.organizerId),
      ]);
      if (mounted) {
        setState(() {
          _route = results[0] as EventRoute?;
          _organizer = results[1] as Profile?;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final event = widget.event;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(event),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- TYTUŁ I SUBTYTUŁ ---
                    Text(event.title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    if (event.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(event.subtitle!, style: theme.textTheme.titleMedium?.copyWith(color: cs.secondary)),
                    ],
                    const SizedBox(height: 16),

                    // --- STATUSY (CHIPY) ---
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildBadge(event.scenario.name, _getScenarioColor(event.scenario)),
                        _buildBadge(event.status.name, event.status == EventStatus.open ? Colors.green : Colors.red),
                      ],
                    ),
                    const Divider(height: 40),

                    // --- CZAS TRWANIA ---
                    _buildSectionTitle('Kiedy i gdzie?'),
                    _InfoTile(
                      icon: Icons.calendar_today,
                      title: 'Początek',
                      value: event.startsAt != null ? DateFormat('EEEE, d MMMM HH:mm', 'pl').format(event.startsAt!) : 'Nieustalony',
                    ),
                    if (event.endsAt != null)
                      _InfoTile(
                        icon: Icons.event_busy,
                        title: 'Koniec',
                        value: DateFormat('EEEE, d MMMM HH:mm', 'pl').format(event.endsAt!),
                      ),
                    _InfoTile(icon: Icons.location_city, title: 'Miasto', value: event.city),
                    
                    const Divider(height: 40),

                    // --- TRASA (Z EventRoute) ---
                    if (_route != null) ...[
                      _buildSectionTitle('Parametry trasy'),
                      Row(
                        children: [
                          _StatBox(label: 'Dystans', value: '${((_route!.distanceM ?? 0) / 1000).toStringAsFixed(1)} km', icon: Icons.map),
                          _StatBox(label: 'Czas', value: '${((_route!.durationS ?? 0) / 60).round()} min', icon: Icons.timer),
                        ],
                      ),
                      const Divider(height: 40),
                    ],

                    // --- OPIS ---
                    _buildSectionTitle('Opis wydarzenia'),
                    Text(event.description ?? 'Brak szczegółowego opisu.', style: theme.textTheme.bodyLarge),
                    
                    const Divider(height: 40),

                    // --- ORGANIZATOR ---
                    if (_organizer != null) ...[
                      _buildSectionTitle('Organizator'),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: _organizer!.avatarUrl != null ? NetworkImage(_organizer!.avatarUrl!) : null,
                          child: _organizer!.avatarUrl == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(_organizer!.displayName),
                        subtitle: Text('Poziom weryfikacji: ${_organizer!.verificationLevel}'),
                        trailing: IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () {}),
                      ),
                    ],

                    // --- METADANE ---
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Utworzono: ${DateFormat('dd.MM.yyyy').format(event.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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

  Widget _buildAppBar(Event event) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: event.photoUrl != null
            ? Image.network(event.photoUrl!, fit: BoxFit.cover)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_getScenarioColor(event.scenario), _getScenarioColor(event.scenario).withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(Icons.event, size: 80, color: Colors.white.withOpacity(0.3)),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _getScenarioColor(EventScenario s) {
    switch (s) {
      case EventScenario.bikeRide: return const Color(0xFF0F7D31);
      case EventScenario.emergency: return const Color(0xFFD14343);
      case EventScenario.social: return const Color(0xFF7B4AC8);
    }
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
  const _StatBox({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}