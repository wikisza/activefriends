import 'package:activefriends/src/features/map/data/event_api_client.dart';
import 'package:activefriends/src/features/map/data/event_repository.dart';
import 'package:activefriends/src/features/map/data/mock_event_repository.dart';
import 'package:activefriends/src/features/map/data/route_service.dart';
import 'package:activefriends/src/features/map/domain/event_models.dart';
import 'package:activefriends/src/features/map/presentation/widgets/event_preview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _bydgoszcz = LatLng(53.1235, 18.0084);
  static const LatLng _gdansk = LatLng(54.352, 18.6466);

  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  late final http.Client _httpClient;
  late final EventRepository _repository;
  late final RouteService _routeService;

  final List<String> _availableTopics = const <String>['Rower', 'Ceramika', 'Pomoc'];
  Set<String> _selectedTopics = <String>{'Rower', 'Ceramika', 'Pomoc'};

  List<EventPin> _pins = <EventPin>[];
  List<LatLng> _bikeRoute = <LatLng>[];
  EventPin? _selectedEvent;
  bool _isLoading = false;
  bool _isActionBusy = false;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _routeService = RouteService(httpClient: _httpClient);

    const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const bool useApi = bool.fromEnvironment('USE_API', defaultValue: false);

    _repository = (useApi && baseUrl.isNotEmpty)
        ? ApiEventRepository(
            apiClient: EventApiClient(baseUrl: baseUrl, httpClient: _httpClient),
          )
        : MockEventRepository();

    _loadPins();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _httpClient.close();
    super.dispose();
  }

  bool get _isNightMode => _selectedEvent?.scenario == EventScenario.emergency;

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

  Future<void> _joinEvent() async {
    final EventPin? event = _selectedEvent;
    if (event == null) {
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      await _repository.joinEvent(event.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dolaczenie zapisane.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _askQuestion() async {
    final EventPin? event = _selectedEvent;
    if (event == null) {
      return;
    }

    setState(() => _isActionBusy = true);
    try {
      await _repository.askQuestion(event.id, 'Czy sa wolne miejsca?');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pytanie wyslane.')),
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
                });
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
              onAskQuestion: _askQuestion,
              onHelp: _joinEvent,
              onReportLocal: _reportLocal,
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: 74,
        height: 74,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF1E8E3E),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Szybkie dodawanie wydarzenia.')),
            );
          },
          child: const Icon(Icons.add, size: 40),
        ),
      ),
    );
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
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: 'Subskrybowane tematy',
                        isExpanded: true,
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'Subskrybowane tematy',
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.directions_bike, size: 18),
                                const SizedBox(width: 6),
                                const Icon(Icons.palette_outlined, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedTopics.isEmpty
                                        ? 'Subskrybowane tematy'
                                        : _selectedTopics.join(', '),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (_) {},
                        onTap: _showTopicSelector,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: _overlayDecoration(),
                  child: IconButton(
                    onPressed: _showTopicSelector,
                    icon: const Icon(Icons.filter_alt_outlined),
                    tooltip: 'Filtr',
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
    return _pins.map((EventPin item) {
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
    }).toList(growable: false);
  }

  Future<void> _showTopicSelector() async {
    final Set<String> draft = Set<String>.from(_selectedTopics);

    final Set<String>? result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setBottomState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Subskrybowane tematy',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ..._availableTopics.map((String topic) {
                      return CheckboxListTile(
                        value: draft.contains(topic),
                        contentPadding: EdgeInsets.zero,
                        title: Text(topic),
                        controlAffinity: ListTileControlAffinity.leading,
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
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(draft),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E8E3E),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Zastosuj filtr'),
                      ),
                    ),
                  ],
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
          BoxShadow(color: Color(0x44000000), blurRadius: 9, offset: Offset(0, 4)),
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
