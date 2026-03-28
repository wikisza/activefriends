import 'package:activefriends/src/app/theme/app_palette.dart';
import 'package:activefriends/src/app/ui/app_transitions.dart';
import 'package:activefriends/src/features/chat/data/chat_repository.dart';
import 'package:activefriends/src/features/chat/presentation/chat_thread_screen.dart';
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
  final ChatRepository _chatRepo = ChatRepository();
  final SupabaseClient _client = Supabase.instance.client;

  EventRoute? _route;
  Profile? _organizer;
  bool _isLoading = true;
  bool _chatBusy = false;
  List<Map<String, dynamic>> _participants = <Map<String, dynamic>>[];
  String _fullAddress = 'Ładowanie adresu...';

  String? get _myId => _client.auth.currentUser?.id;
  bool get _isOrganizer => _myId == widget.event.organizerId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait(<Future<Object?>>[
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

  Future<void> _openGroupChat() async {
    setState(() => _chatBusy = true);
    try {
      final String convId =
          await _chatRepo.getOrCreateEventGroupConversation(widget.event.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        AppRoute<void>(
          builder: (BuildContext context) => ChatThreadScreen(
            peerUserId: '',
            peerDisplayName: '',
            conversationId: convId,
            isGroup: true,
            groupTitle: widget.event.title,
            eventId: widget.event.id,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _chatBusy = false);
    }
  }

  Future<void> _removeParticipant(Map<String, dynamic> pData) async {
    final profile = Profile.fromJson(pData['profiles'] as Map<String, dynamic>);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Usuń uczestnika'),
        content: Text(
          'Czy na pewno chcesz usunąć ${profile.displayName} z wydarzenia i czatu grupowego?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _client.rpc(
        'remove_event_participant',
        params: <String, dynamic>{
          'p_event_id': widget.event.id,
          'p_profile_id': profile.id,
        },
      );
      if (mounted) {
        setState(() {
          _participants =
              _participants.where((p) => p['profile_id'] != profile.id).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${profile.displayName} został(a) usunięty(a).'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Usuń wydarzenie'),
        content: const Text(
          'Czy na pewno chcesz usunąć to wydarzenie? Wszystkie dane uczestników oraz trasa zostaną bezpowrotnie usunięte.',
        ),
        actions: <Widget>[
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
          Navigator.of(context).pop(true);
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

    return Scaffold(
      body: _isLoading && _organizer == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: <Widget>[
                _buildAppBar(event),
                SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            event.title,
                            style: theme.textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (event.subtitle != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              event.subtitle!,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: cs.secondary),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: <Widget>[
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

                          _buildSectionTitle('Kiedy i gdzie?'),
                          _InfoTile(
                            icon: Icons.calendar_today,
                            title: 'Początek',
                            value: event.startsAt != null
                                ? DateFormat('EEEE, d MMMM HH:mm', 'pl')
                                    .format(event.startsAt!)
                                : 'Nieustalony',
                          ),
                          if (event.endsAt != null)
                            _InfoTile(
                              icon: Icons.event_busy,
                              title: 'Koniec',
                              value: DateFormat('EEEE, d MMMM HH:mm', 'pl')
                                  .format(event.endsAt!),
                            ),
                          _InfoTile(
                            icon: Icons.location_on_outlined,
                            title: 'Dokładny adres',
                            value: _fullAddress,
                          ),
                          _InfoTile(
                            icon: Icons.location_city,
                            title: 'Miasto',
                            value: event.city,
                          ),
                          const Divider(height: 40),

                          if (_route != null) ...<Widget>[
                            _buildSectionTitle('Parametry trasy'),
                            Row(
                              children: <Widget>[
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

                          _buildSectionTitle('Opis wydarzenia'),
                          Text(
                            event.description ?? 'Brak szczegółowego opisu.',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const Divider(height: 40),

                          if (_organizer != null) ...<Widget>[
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

                          // ── Uczestnicy ──────────────────────────────────
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _buildSectionTitle(
                                  'Uczestnicy (${_participants.length})',
                                ),
                              ),
                              // Przycisk czatu grupowego — tylko dla organizatora
                              if (_isOrganizer && _participants.isNotEmpty)
                                FilledButton.tonalIcon(
                                  onPressed: _chatBusy ? null : _openGroupChat,
                                  icon: _chatBusy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.group_rounded, size: 18),
                                  label: const Text('Czat grupowy'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_participants.isEmpty)
                            Text(
                              'Nikt jeszcze nie dołączył. Bądź pierwszy!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.outline,
                              ),
                            )
                          else
                            SizedBox(
                              height: 110,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _participants.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final pData = _participants[index];
                                  final profile = Profile.fromJson(
                                    pData['profiles'] as Map<String, dynamic>,
                                  );
                                  final roleName = pData['role'] as String;
                                  final bool canRemove = _isOrganizer &&
                                      profile.id != widget.event.organizerId;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Stack(
                                          alignment: Alignment.bottomRight,
                                          children: <Widget>[
                                            GestureDetector(
                                              onLongPress: canRemove
                                                  ? () => _removeParticipant(pData)
                                                  : null,
                                              child: CircleAvatar(
                                                radius: 28,
                                                backgroundColor:
                                                    cs.primaryContainer,
                                                backgroundImage:
                                                    profile.avatarUrl != null
                                                        ? NetworkImage(
                                                            profile.avatarUrl!)
                                                        : null,
                                                child: profile.avatarUrl == null
                                                    ? Icon(
                                                        Icons.person,
                                                        color:
                                                            cs.onPrimaryContainer,
                                                      )
                                                    : null,
                                              ),
                                            ),
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
                                            if (canRemove)
                                              Positioned(
                                                top: 0,
                                                left: 0,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _removeParticipant(pData),
                                                  child: Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      color: cs.error,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: cs.surface,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      size: 11,
                                                      color: Colors.white,
                                                    ),
                                                  ),
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

  Widget _buildAppBar(Event event) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      actions: <Widget>[
        if (_isOrganizer)
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
                      AppPalette.scenarioColorByName(event.scenario.name)
                          .withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.event,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.3),
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
        color: color.withValues(alpha: 0.1),
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: <Widget>[
          Icon(icon, color: cs.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
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
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
