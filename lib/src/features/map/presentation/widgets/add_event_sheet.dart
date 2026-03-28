import 'package:activefriends/src/features/map/data/event_repository.dart';
import 'package:activefriends/src/models/event.dart' as model;
import 'package:flutter/material.dart';
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
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  _ActivityType _activityType = _ActivityType.sport;
  bool _tylkoZweryfikowani = false;
  bool _pilne = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _latController.text = widget.location!.latitude.toStringAsFixed(6);
      _lngController.text = widget.location!.longitude.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _meetingPointController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  // "Pilne" forces emergency scenario regardless of selected type.
  model.EventScenario get _resolvedScenario =>
      _pilne ? model.EventScenario.emergency : _activityType.scenario;

  List<String> get _badges => <String>[
        if (_pilne) 'PILNE',
        if (_tylkoZweryfikowani) 'TYLKO ZWERYFIKOWANI',
      ];

  LatLng? _resolveLocationFromForm() {
    if (widget.location != null) {
      return widget.location;
    }

    final String latRaw = _latController.text.trim().replaceAll(',', '.');
    final String lngRaw = _lngController.text.trim().replaceAll(',', '.');
    final double? lat = double.tryParse(latRaw);
    final double? lng = double.tryParse(lngRaw);
    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final LatLng? resolvedLocation = _resolveLocationFromForm();
    if (resolvedLocation == null) {
      setState(() {
        _errorMessage =
            'Podaj poprawna lokalizacje (latitude i longitude), jesli nie wybrales punktu na mapie.';
      });
      return;
    }

    final String? userId =
        Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() =>
          _errorMessage = 'Musisz być zalogowany, aby dodać wydarzenie.');
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
        subtitle: _meetingPointController.text.trim().isEmpty
            ? null
            : _meetingPointController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        scenario: _resolvedScenario,
        status: model.EventStatus.open,
        organizerId: userId,
        lat: resolvedLocation.latitude,
        lng: resolvedLocation.longitude,
        city: 'Bydgoszcz',
        createdAt: DateTime.now(),
      );

      await widget.repository.createEvent(event, badges: _badges);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      // Push content above keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
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
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                // Location info
                if (widget.location != null)
                  Row(
                    children: <Widget>[
                      Icon(Icons.location_on_outlined,
                          size: 16, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.location!.latitude.toStringAsFixed(5)}, '
                        '${widget.location!.longitude.toStringAsFixed(5)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  )
                else
                  Row(
                    children: <Widget>[
                      Icon(Icons.location_searching,
                          size: 16, color: cs.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Nie wybrano punktu na mapie. Podaj lokalizacje recznie.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),

                TextFormField(
                  controller: _meetingPointController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Miejsce zbiorki',
                    hintText: 'np. Stary Rynek, wejscie glowne',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                if (widget.location == null) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude *',
                            prefixIcon: Icon(Icons.my_location),
                            border: OutlineInputBorder(),
                          ),
                          validator: (String? v) {
                            final double? d = double.tryParse(
                              (v ?? '').trim().replaceAll(',', '.'),
                            );
                            if (d == null || d < -90 || d > 90) {
                              return 'Zakres -90..90';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude *',
                            prefixIcon: Icon(Icons.explore_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (String? v) {
                            final double? d = double.tryParse(
                              (v ?? '').trim().replaceAll(',', '.'),
                            );
                            if (d == null || d < -180 || d > 180) {
                              return 'Zakres -180..180';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

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
                    backgroundColor:
                        _pilne ? cs.error : cs.primary,
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
                              strokeWidth: 2, color: Colors.white),
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
