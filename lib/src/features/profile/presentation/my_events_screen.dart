import 'package:activefriends/src/features/profile/presentation/event_details_screen.dart';
import 'package:activefriends/src/features/profile/presentation/profile_service.dart';
import 'package:activefriends/src/models/event.dart'; // upewnij się, że ścieżka jest poprawna
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // opcjonalnie do formatowania dat: flutter pub add intl

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final ProfileService _profileService = ProfileService();
  List<Event> _myEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final events = await _profileService.fetchMyEvents();
      setState(() => _myEvents = events);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd ładowania: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Moje wydarzenia')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEvents,
              child: _myEvents.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _myEvents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = _myEvents[index];
                        return _EventTile(event: event);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      // ListView potrzebny, żeby RefreshIndicator działał
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(Icons.event_busy, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        const Center(child: Text('Nie stworzyłeś jeszcze żadnych wydarzeń.')),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final Event event;
  const _EventTile({required this.event});

  String _formatDateRange() {
    final DateFormat fmt = DateFormat('dd.MM.yyyy • HH:mm');
    if (event.startsAt == null && event.endsAt == null) {
      return 'Termin nieustalony';
    }
    if (event.startsAt != null && event.endsAt != null) {
      return '${fmt.format(event.startsAt!.toLocal())} - ${fmt.format(event.endsAt!.toLocal())}';
    }
    if (event.startsAt != null) {
      return fmt.format(event.startsAt!.toLocal());
    }
    return 'Do: ${fmt.format(event.endsAt!.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Logika koloru i ikony zależnie od scenariusza (taka jak na mapie)
    final Color scenarioColor = switch (event.scenario) {
      EventScenario.bikeRide => const Color(0xFF0F7D31),
      EventScenario.emergency => const Color(0xFFD14343),
      EventScenario.social => const Color(0xFF7B4AC8),
    };

    final IconData scenarioIcon = switch (event.scenario) {
      EventScenario.bikeRide => Icons.directions_bike,
      EventScenario.emergency => Icons.warning_amber_rounded,
      EventScenario.social => Icons.people_outline,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scenarioColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(scenarioIcon, color: scenarioColor),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.subtitle?.trim().isNotEmpty == true
                        ? event.subtitle!
                        : event.city,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(_formatDateRange(), style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: _StatusBadge(status: event.status),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(event: event),
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final EventStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == EventStatus.open ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
