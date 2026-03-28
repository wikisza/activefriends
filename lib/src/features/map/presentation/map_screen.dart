import 'package:activefriends/src/features/auth/data/auth_service.dart';
import 'package:activefriends/src/features/chat/data/chat_repository.dart';
import 'package:activefriends/src/features/chat/presentation/chat_thread_screen.dart';
import 'dart:ui' as ui;

import 'package:activefriends/src/features/map/data/event_repository.dart';
import 'package:activefriends/src/features/map/data/route_service.dart';
import 'package:activefriends/src/features/map/domain/event_models.dart';
import 'package:activefriends/src/features/map/presentation/widgets/add_event_sheet.dart';
import 'package:activefriends/src/features/map/presentation/widgets/event_preview_panel.dart';
import 'package:activefriends/src/features/profile/presentation/profile_service.dart';
import 'package:activefriends/src/models/topic_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  static const LatLng _bydgoszcz = LatLng(53.1235, 18.0084);
  static const LatLng _gdansk = LatLng(54.352, 18.6466);

  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  late final http.Client _httpClient;
  late final EventRepository _repository;
  late final RouteService _routeService;
  late final AnimationController _dropPinController;
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  final List<String> _availableTopics = kSupportedTopics;
  Set<String> _subscribedTopics = <String>{};
  Set<String> _selectedTopics = <String>{};

  List<EventPin> _pins = <EventPin>[];
  List<LatLng> _bikeRoute = <LatLng>[];
  EventPin? _selectedEvent;
  LatLng? _tappedLocation;
  bool _isLoading = false;
  bool _isActionBusy = false;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _routeService = RouteService(httpClient: _httpClient);

    _dropPinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _repository = SupabaseEventRepository();
    _loadProfileTopics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dropPinController.dispose();
    _httpClient.close();
    super.dispose();
  }

  bool get _isNightMode => _selectedEvent?.scenario == EventScenario.emergency;

  Future<void> _loadProfileTopics() async {
    try {
      final profile = await _profileService.fetchProfile();
      if (!mounted) {
        return;
      }

      final Set<String> subscribedTopics =
          profile?.subscribedTopics
              .where((String item) => _availableTopics.contains(item))
              .toSet() ??
          <String>{};

      setState(() {
        _subscribedTopics = subscribedTopics;
        _selectedTopics = <String>{};
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _subscribedTopics = <String>{};
        _selectedTopics = <String>{};
      });
    }

    await _loadPins();
  }

  List<String> get _orderedSelectedTopics => orderedTopics(_selectedTopics);

  List<String> get _orderedSubscribedTopics => orderedTopics(_subscribedTopics);

  String get _filterSummary {
    if (_selectedTopics.isEmpty ||
        _selectedTopics.length == _availableTopics.length) {
      return 'Wszystkie aktywnosci';
    }

    final List<String> selected = _orderedSelectedTopics;
    if (selected.length <= 2) {
      return selected.join(', ');
    }

    return '${selected.length} filtry aktywnosci';
  }

  String get _subscriptionSummary {
    final List<String> subscribed = _orderedSubscribedTopics;
    if (subscribed.isEmpty) {
      return 'Brak subskrypcji';
    }
    if (subscribed.length <= 3) {
      return subscribed.join(', ');
    }
    return '${subscribed.length} subskrypcji';
  }

  Widget _buildTopicLabel(String topic, {required bool isSubscribed}) {
    return Row(
      children: <Widget>[
        Icon(
          isSubscribed ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: isSubscribed
              ? const Color(0xFFF1B500)
              : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(topic)),
      ],
    );
  }

  Future<void> _saveSubscribedTopics(Set<String> topics) async {
    final Set<String> nextTopics = topics.intersection(
      _availableTopics.toSet(),
    );
    try {
      await _profileService.updateSubscribedTopics(
        nextTopics.toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      setState(() => _subscribedTopics = nextTopics);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udalo sie zapisac subskrypcji.')),
        );
      }
    }
  }

  Future<void> _loadPins() async {
    setState(() => _isLoading = true);
    try {
      final List<EventPin> items = await _repository.fetchPins(
        query: _searchController.text,
        topics: _selectedTopics.toList(growable: false),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pins = items;
        if (_selectedEvent != null) {
          _selectedEvent = items
              .where((EventPin item) => item.id == _selectedEvent!.id)
              .firstOrNull;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectEvent(EventPin event) async {
    setState(() {
      _selectedEvent = event;
      _bikeRoute = <LatLng>[];
    });

    _mapController.move(event.location, 12.4);

    if (event.scenario == EventScenario.bikeRide) {
      final List<LatLng> route = await _routeService.fetchBikeRoute(
        start: _bydgoszcz,
        end: _gdansk,
      );
      if (!mounted) {
        return;
      }
      setState(() => _bikeRoute = route);
    }
  }

  Future<void> _joinEvent({String role = 'member'}) async {
    final EventPin? event = _selectedEvent;
    if (event == null) {
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      await _repository.joinEvent(event.id, role: role);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            role == 'helper'
                ? 'Zgłoszono Cię jako osobę do pomocy.'
                : 'Dołączyłeś do wydarzenia.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _reportLocal() async {
    final EventPin? event = _selectedEvent;
    if (event == null) {
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      await _repository.reportLocal(event.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zgloszenie lokalne wyslane.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  void _openOrganizerChat() {
    final EventPin? event = _selectedEvent;
    if (event == null) {
      return;
    }

    final String? myId = _authService.currentUser?.id;
    if (myId != null && myId == event.organizer.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie możesz napisać do samego siebie.')),
      );
      return;
    }

    if (!ChatRepository.isUuid(event.organizer.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ten organizator nie ma poprawnego konta w aplikacji — czat jest niedostępny.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ChatThreadScreen(
          peerUserId: event.organizer.id,
          peerDisplayName: event.organizer.displayName,
          contextEventTitle: event.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _bydgoszcz,
              initialZoom: 12,
              minZoom: 10,
              maxZoom: 17,
              onTap: (TapPosition tapPosition, LatLng point) {
                setState(() {
                  _selectedEvent = null;
                  _bikeRoute = <LatLng>[];
                  _tappedLocation = null;
                });
              },
              onLongPress: (TapPosition tapPosition, LatLng point) {
                setState(() {
                  _selectedEvent = null;
                  _bikeRoute = <LatLng>[];
                  _tappedLocation = point;
                });
                _dropPinController.forward(from: 0);
                _showAddEventSheet();
              },
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: _isNightMode
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const <String>['a', 'b', 'c', 'd'],
                userAgentPackageName: 'pl.activefriends.app',
              ),
              if (_bikeRoute.isNotEmpty)
                PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: _bikeRoute,
                      strokeWidth: 5,
                      color: const Color(0xFF0F7D31),
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers()),
              if (_tappedLocation != null)
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      width: 48,
                      height: 64,
                      point: _tappedLocation!,
                      alignment: Alignment.topCenter,
                      child: _DropPinMarker(animation: _dropPinController),
                    ),
                  ],
                ),
            ],
          ),
          _buildTopOverlay(),
          if (_isLoading)
            const Align(
              alignment: Alignment.center,
              child: CircularProgressIndicator(),
            ),
          if (_selectedEvent != null)
            EventPreviewPanel(
              event: _selectedEvent!,
              bottomPadding: _selectedEvent!.scenario == EventScenario.emergency
                  ? 120
                  : 98,
              isBusy: _isActionBusy,
              onClose: () => setState(() {
                _selectedEvent = null;
                _bikeRoute = <LatLng>[];
              }),
              onJoin: _joinEvent,
              onHelp: () => _joinEvent(role: 'helper'),
              onReportLocal: _reportLocal,
              onChatWithOrganizer: _openOrganizerChat,
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: 74,
        height: 74,
        child: FloatingActionButton(
          heroTag: 'map_add_event_fab',
          backgroundColor: const Color(0xFF1E8E3E),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: _showAddEventSheet,
          child: const Icon(Icons.add, size: 40),
        ),
      ),
    );
  }

  Future<void> _showAddEventSheet() async {
    final bool? created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddEventSheet(
        location: _tappedLocation,
        repository: SupabaseEventRepository(),
      ),
    );
    if (mounted) {
      setState(() => _tappedLocation = null);
    }
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wydarzenie zostało dodane!')),
      );
      _loadPins();
    }
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              decoration: _overlayDecoration(),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _loadPins(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Szukaj aktywnosci w Bydgoszczy',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _loadPins,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    decoration: _overlayDecoration(),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _showTopicSelector,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.filter_alt_outlined, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'Filtry aktywnosci',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                    Text(
                                      _filterSummary,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 168),
                  child: Container(
                    decoration: _overlayDecoration(),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _showSubscriptionsSheet,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                _subscribedTopics.isEmpty
                                    ? Icons.star_border_rounded
                                    : Icons.star_rounded,
                                color: _subscribedTopics.isEmpty
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : const Color(0xFFF1B500),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'Subskrypcje',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                    Text(
                                      _subscriptionSummary,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _overlayDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    return _pins
        .map((EventPin item) {
          final bool selected = _selectedEvent?.id == item.id;
          final Color color = switch (item.scenario) {
            EventScenario.bikeRide => const Color(0xFF0F7D31),
            EventScenario.emergency => const Color(0xFFD14343),
            EventScenario.social => const Color(0xFF7B4AC8),
          };

          return Marker(
            width: 58,
            height: 58,
            point: item.location,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _selectEvent(item),
              child: item.scenario == EventScenario.emergency
                  ? _PulsingPin(color: color, selected: selected)
                  : _PinIcon(color: color, selected: selected),
            ),
          );
        })
        .toList(growable: false);
  }

  Future<void> _showTopicSelector() async {
    final Set<String> draft = Set<String>.from(_selectedTopics);

    final Set<String>? result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setBottomState) {
            return FractionallySizedBox(
              heightFactor: 0.82,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Filtry aktywnosci',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Subskrypcje sa osobne. Filtry decyduja, co teraz widzisz na mapie.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Twoje subskrypcje',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (_orderedSubscribedTopics.isEmpty)
                        Text(
                          'Brak subskrypcji. Dodaj je gwiazdka obok paska filtrow.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _orderedSubscribedTopics
                              .map((String topic) {
                                return FilterChip(
                                  label: Text(topic),
                                  avatar: const Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                  ),
                                  selected: draft.contains(topic),
                                  onSelected: (bool selected) {
                                    setBottomState(() {
                                      if (selected) {
                                        draft.add(topic);
                                      } else {
                                        draft.remove(topic);
                                      }
                                    });
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      const Text(
                        'Wszystkie aktywnosci',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(right: 12),
                          children: _availableTopics
                              .map((String topic) {
                                final bool isSubscribed = _subscribedTopics
                                    .contains(topic);
                                return CheckboxListTile(
                                  value: draft.contains(topic),
                                  contentPadding: EdgeInsets.zero,
                                  title: _buildTopicLabel(
                                    topic,
                                    isSubscribed: isSubscribed,
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: (bool? checked) {
                                    setBottomState(() {
                                      if (checked == true) {
                                        draft.add(topic);
                                      } else {
                                        draft.remove(topic);
                                      }
                                    });
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop(<String>{});
                              },
                              child: const Text('Wyczysc filtry'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(draft),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E8E3E),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Zastosuj filtry'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() => _selectedTopics = result);
    await _loadPins();
  }

  Future<void> _showSubscriptionsSheet() async {
    final Set<String> draft = Set<String>.from(_subscribedTopics);

    final Set<String>? result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setBottomState) {
            return FractionallySizedBox(
              heightFactor: 0.78,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Twoje subskrypcje',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Subskrypcje pokazuja Twoje ulubione aktywnosci. Nie zmieniaja filtrow mapy, dopoki sam ich nie zaznaczysz.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(right: 12),
                          children: _availableTopics
                              .map((String topic) {
                                final bool isSubscribed = draft.contains(topic);
                                return CheckboxListTile(
                                  value: isSubscribed,
                                  contentPadding: EdgeInsets.zero,
                                  title: _buildTopicLabel(
                                    topic,
                                    isSubscribed: isSubscribed,
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: (bool? checked) {
                                    setBottomState(() {
                                      if (checked == true) {
                                        draft.add(topic);
                                      } else {
                                        draft.remove(topic);
                                      }
                                    });
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(draft),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1B500),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Zapisz subskrypcje'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    await _saveSubscribedTopics(result);
  }
}

class _PinIcon extends StatelessWidget {
  const _PinIcon({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: selected ? 58 : 52,
      height: selected ? 58 : 52,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 9,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.place, color: Colors.white, size: 26),
    );
  }
}

class _PulsingPin extends StatefulWidget {
  const _PulsingPin({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  State<_PulsingPin> createState() => _PulsingPinState();
}

class _PulsingPinState extends State<_PulsingPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        final double pulse = 1 + (t * 0.42);
        final double opacity = (1 - t) * 0.35;

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: 52 * pulse,
              height: 52 * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: opacity),
              ),
            ),
            _PinIcon(color: widget.color, selected: widget.selected),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Drop-pin marker – animacja "upuszczenia" pinezki przy long-press
// ---------------------------------------------------------------------------

class _DropPinMarker extends AnimatedWidget {
  const _DropPinMarker({required AnimationController animation})
    : super(listenable: animation);

  static const Color _pinColor = Color(0xFF1E8E3E);

  @override
  Widget build(BuildContext context) {
    final AnimationController ctrl = listenable as AnimationController;

    // Pinezka spada z -40 px do 0 (translacja Y), a cień rośnie
    final Animation<double> drop = CurvedAnimation(
      parent: ctrl,
      curve: Curves.bounceOut,
    );
    final Animation<double> shadow = CurvedAnimation(
      parent: ctrl,
      curve: Curves.easeOut,
    );

    final double offsetY = (1 - drop.value) * -40;
    final double shadowScale = shadow.value;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: <Widget>[
        // Cień pod pinezką
        Positioned(
          bottom: -4,
          child: Transform.scale(
            scale: shadowScale,
            child: Container(
              width: 18,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0x44000000),
                borderRadius: BorderRadius.all(Radius.elliptical(9, 3)),
              ),
            ),
          ),
        ),
        // Pinezka
        Transform.translate(
          offset: Offset(0, offsetY),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _pinColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_location_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              // Ogon pinezki
              CustomPaint(
                size: const Size(14, 10),
                painter: _PinTailPainter(color: _pinColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  const _PinTailPainter({required this.color});
  final Color color;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final ui.Paint paint = ui.Paint()..color = color;
    final ui.Path path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}
