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

  final LatLng location;
  final EventRepository repository;

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  _ActivityType _activityType = _ActivityType.sport;
  bool _tylkoZweryfikowani = false;
  bool _pilne = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // "Pilne" forces emergency scenario regardless of selected type.
  model.EventScenario get _resolvedScenario =>
      _pilne ? model.EventScenario.emergency : _activityType.scenario;

  List<String> get _badges => <String>[
        if (_pilne) 'PILNE',
        if (_tylkoZweryfikowani) 'TYLKO ZWERYFIKOWANI',
      ];

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        scenario: _resolvedScenario,
        status: model.EventStatus.open,
        organizerId: userId,
        lat: widget.location.latitude,
        lng: widget.location.longitude,
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
                Row(
                  children: <Widget>[
                    Icon(Icons.location_on_outlined,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.location.latitude.toStringAsFixed(5)}, '
                      '${widget.location.longitude.toStringAsFixed(5)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

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
