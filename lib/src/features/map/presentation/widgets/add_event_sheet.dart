import 'dart:convert';

import 'package:activefriends/src/features/map/data/event_repository.dart';
import 'package:activefriends/src/models/event.dart' as model;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Activity type enum
// ---------------------------------------------------------------------------

enum _ActivityType {
  sport('Sport', model.EventScenario.bikeRide),
  pomoc('Pomoc', model.EventScenario.emergency),
  spotkanie('Spotkanie towarzyskie', model.EventScenario.social),
  dyskusja('Dyskusja', model.EventScenario.social);

  const _ActivityType(this.label, this.scenario);

  final String label;
  final model.EventScenario scenario;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Dolny panel do tworzenia nowego wydarzenia.
///
/// Przyjmuje [location] (punkt wybrany na mapie) oraz [repository] do zapisu.
/// Zamyka się z wynikiem `true` gdy wydarzenie zostało dodane.
class AddEventSheet extends StatefulWidget {
  const AddEventSheet({
    super.key,
    required this.location,
    required this.repository,
  });

  final LatLng? location;
  final EventRepository repository;

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _meetingPointController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  _ActivityType _activityType = _ActivityType.sport;
  bool _tylkoZweryfikowani = false;
  bool _pilne = false;
  bool _isLoading = false;
  bool _isLocating = false;
  bool _isGeocoding = false;
  String? _errorMessage;
  LatLng? _resolvedLocation;
  String? _locationLabel;
  DateTime? _startsAt;
  DateTime? _endsAt;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _resolveAddressFromCoordinates(widget.location!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _meetingPointController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // "Pilne" forces emergency scenario regardless of selected type.
  model.EventScenario get _resolvedScenario =>
      _pilne ? model.EventScenario.emergency : _activityType.scenario;

  List<String> get _badges => <String>[
    if (_pilne) 'PILNE',
    if (_tylkoZweryfikowani) 'TYLKO ZWERYFIKOWANI',
  ];

  LatLng? get _effectiveLocation => widget.location ?? _resolvedLocation;

  Future<void> _useMyLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = 'Usługi lokalizacji są wyłączone.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(
            () => _errorMessage = 'Brak zgody na dostęp do lokalizacji.',
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(
          () => _errorMessage =
              'Dostęp do lokalizacji jest zablokowany. Zmień uprawnienia w ustawieniach przeglądarki.',
        );
        return;
      }
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final LatLng nextLocation = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _resolvedLocation = nextLocation;
      });
      await _resolveAddressFromCoordinates(nextLocation);
    } catch (e) {
      setState(() => _errorMessage = 'Nie udało się pobrać lokalizacji.');
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _resolveAddressFromCoordinates(LatLng location) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isEmpty || !mounted) {
        return;
      }
      final Placemark p = placemarks.first;
      final String street = (p.street ?? '').trim();
      final String subLocality = (p.subLocality ?? '').trim();
      final String locality = (p.locality ?? '').trim();
      final String postalCode = (p.postalCode ?? '').trim();

      final String address = <String>[
        if (street.isNotEmpty) street,
        if (subLocality.isNotEmpty) subLocality,
        if (postalCode.isNotEmpty || locality.isNotEmpty)
          '${postalCode.isNotEmpty ? '$postalCode ' : ''}$locality'.trim(),
      ].where((String item) => item.isNotEmpty).join(', ');

      if (address.isNotEmpty) {
        setState(() => _locationLabel = address);
      }
    } catch (_) {
      // Keep existing label when reverse geocoding fails.
    }
  }

  Future<void> _searchAddress() async {
    final String query = _addressController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isGeocoding = true;
      _errorMessage = null;
    });
    try {
      final Uri uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        <String, String>{
          'q': query,
          'format': 'json',
          'limit': '1',
          'accept-language': 'pl',
        },
      );
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{'User-Agent': 'activefriends-app/1.0'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final Map<String, dynamic> item = data.first as Map<String, dynamic>;
          final double lat = double.parse(item['lat'] as String);
          final double lon = double.parse(item['lon'] as String);
          setState(() {
            _resolvedLocation = LatLng(lat, lon);
            _locationLabel = item['display_name'] as String;
          });
        } else {
          setState(
            () => _errorMessage =
                'Nie znaleziono adresu. Spróbuj inaczej sformułować zapytanie.',
          );
        }
      } else {
        setState(
          () => _errorMessage =
              'Błąd wyszukiwania adresu (${response.statusCode}).',
        );
      }
    } catch (e) {
      setState(
        () => _errorMessage = 'Błąd połączenia podczas wyszukiwania adresu.',
      );
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final LatLng? resolvedLocation = _effectiveLocation;
    if (resolvedLocation == null) {
      setState(() {
        _errorMessage = 'Podaj lokalizację: użyj GPS lub wyszukaj adres.';
      });
      return;
    }

    final String? userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(
        () => _errorMessage = 'Musisz być zalogowany, aby dodać wydarzenie.',
      );
      return;
    }

    if (_startsAt != null && _endsAt != null && _endsAt!.isBefore(_startsAt!)) {
      setState(() {
        _errorMessage =
            'Data zakończenia nie może być wcześniejsza niż data rozpoczęcia.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final model.Event event = model.Event(
        id: '',
        title: _titleController.text.trim(),
        subtitle: _meetingPointController.text.trim().isNotEmpty
            ? _meetingPointController.text.trim()
            : (_locationLabel?.trim().isNotEmpty == true
                  ? _locationLabel!.trim()
                  : null),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        scenario: _resolvedScenario,
        status: model.EventStatus.open,
        organizerId: userId,
        lat: resolvedLocation.latitude,
        lng: resolvedLocation.longitude,
        city: 'Bydgoszcz',
        startsAt: _startsAt,
        endsAt: _endsAt,
        createdAt: DateTime.now(),
      );

      await widget.repository.createEvent(event, badges: _badges);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(DateTime value) {
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    final DateTime local = value.toLocal();
    final TimeOfDay tod = TimeOfDay.fromDateTime(local);
    return '${loc.formatMediumDate(local)} ${loc.formatTimeOfDay(tod)}';
  }

  Future<DateTime?> _pickDateTime({DateTime? initialValue}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = initialValue ?? now;

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Wybierz datę',
    );
    if (date == null) {
      return null;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Wybierz godzinę',
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Termin wydarzenia',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final DateTime? picked = await _pickDateTime(
                    initialValue: _startsAt,
                  );
                  if (picked == null || !mounted) {
                    return;
                  }
                  setState(() {
                    _startsAt = picked;
                    if (_endsAt != null && _endsAt!.isBefore(picked)) {
                      _endsAt = picked;
                    }
                  });
                },
                icon: const Icon(Icons.event_available_outlined),
                label: Text(
                  _startsAt == null
                      ? 'Data od'
                      : 'Od: ${_formatDateTime(_startsAt!)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final DateTime? picked = await _pickDateTime(
                    initialValue: _endsAt ?? _startsAt,
                  );
                  if (picked == null || !mounted) {
                    return;
                  }
                  setState(() {
                    _endsAt = picked;
                    if (_startsAt != null && _endsAt!.isBefore(_startsAt!)) {
                      _errorMessage =
                          'Data zakończenia nie może być wcześniejsza niż data rozpoczęcia.';
                    } else {
                      _errorMessage = null;
                    }
                  });
                },
                icon: const Icon(Icons.event_busy_outlined),
                label: Text(
                  _endsAt == null
                      ? 'Data do'
                      : 'Do: ${_formatDateTime(_endsAt!)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (_startsAt != null || _endsAt != null) ...<Widget>[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _startsAt = null;
                    _endsAt = null;
                    _errorMessage = null;
                  });
                },
                tooltip: 'Wyczyść daty',
                icon: const Icon(Icons.clear),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ---------- location UI helpers ----------

  Widget _buildLocationChip(
    BuildContext context, {
    required String label,
    required VoidCallback? onClear,
    required ColorScheme cs,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.location_on, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onPrimaryContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 18, color: cs.onPrimaryContainer),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationPicker(ColorScheme cs, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: _isLocating ? null : _useMyLocation,
          icon: _isLocating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          label: const Text('Użyj mojej lokalizacji (GPS)'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'lub podaj adres',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Adres',
                  hintText: 'np. Stary Rynek, Poznań',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => _searchAddress(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: FilledButton.tonal(
                onPressed: _isGeocoding ? null : _searchAddress,
                child: _isGeocoding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      // Push content above keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Nowe wydarzenie',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                // Location section
                if (widget.location != null)
                  _buildLocationChip(
                    context,
                    label: _locationLabel ?? 'Pobieranie dokładnego adresu...',
                    onClear: null,
                    cs: cs,
                    theme: theme,
                  )
                else if (_resolvedLocation != null)
                  _buildLocationChip(
                    context,
                    label:
                        _locationLabel ??
                        '${_resolvedLocation!.latitude.toStringAsFixed(5)}, '
                            '${_resolvedLocation!.longitude.toStringAsFixed(5)}',
                    onClear: () => setState(() {
                      _resolvedLocation = null;
                      _locationLabel = null;
                      _addressController.clear();
                    }),
                    cs: cs,
                    theme: theme,
                  )
                else
                  _buildLocationPicker(cs, theme),
                const SizedBox(height: 18),

                TextFormField(
                  controller: _meetingPointController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Miejsce zbiórki',
                    hintText: 'np. Stary Rynek, wejście główne',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                _buildDateRangePicker(),
                const SizedBox(height: 14),

                // Title
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tytuł *',
                    hintText: 'np. Wspólna wycieczka rowerowa',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Podaj tytuł wydarzenia';
                    }
                    if (v.trim().length < 3) {
                      return 'Tytuł jest za krótki';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Opis',
                    hintText: 'Opcjonalny opis wydarzeenia…',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Activity type dropdown
                DropdownButtonFormField<_ActivityType>(
                  value: _activityType,
                  decoration: const InputDecoration(
                    labelText: 'Typ aktywności',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _ActivityType.values
                      .map(
                        (_ActivityType t) => DropdownMenuItem<_ActivityType>(
                          value: t,
                          child: Text(t.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (_ActivityType? v) {
                    if (v != null) setState(() => _activityType = v);
                  },
                ),
                const SizedBox(height: 16),

                const Divider(),

                // Switch: Tylko zweryfikowani
                SwitchListTile(
                  value: _tylkoZweryfikowani,
                  onChanged: (bool v) =>
                      setState(() => _tylkoZweryfikowani = v),
                  title: const Text('Tylko zweryfikowani'),
                  subtitle: const Text(
                    'Dostęp tylko dla użytkowników z weryfikacją',
                  ),
                  secondary: const Icon(Icons.verified_outlined),
                  contentPadding: EdgeInsets.zero,
                ),

                // Switch: Pilne
                SwitchListTile(
                  value: _pilne,
                  activeColor: cs.error,
                  onChanged: (bool v) => setState(() => _pilne = v),
                  title: Text(
                    'Pilne',
                    style: _pilne ? TextStyle(color: cs.error) : null,
                  ),
                  subtitle: const Text('Oznacza wydarzenie jako pilne/nagłe'),
                  secondary: Icon(
                    Icons.warning_amber_outlined,
                    color: _pilne ? cs.error : null,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                const Divider(),
                const SizedBox(height: 8),

                // Error
                if (_errorMessage != null) ...<Widget>[
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                ],

                // Submit button
                FilledButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _pilne ? cs.error : cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_location_alt_outlined),
                  label: Text(
                    _pilne ? 'Dodaj pilne wydarzenie' : 'Dodaj wydarzenie',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
