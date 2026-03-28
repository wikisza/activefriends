import 'package:activefriends/src/app/theme/app_palette.dart';
import 'package:activefriends/src/features/map/domain/event_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventPreviewPanel extends StatelessWidget {
  const EventPreviewPanel({
    super.key,
    required this.event,
    required this.onClose,
    required this.onJoin,
    required this.onHelp,
    required this.onReportLocal,
    required this.onChatWithOrganizer,
    this.bottomPadding = 98,
    this.isBusy = false,
  });

  final EventPin event;
  final VoidCallback onClose;
  final VoidCallback onJoin;
  final VoidCallback onHelp;
  final VoidCallback onReportLocal;
  final VoidCallback onChatWithOrganizer;
  final double bottomPadding;
  final bool isBusy;

  bool get _isEmergency => event.scenario == EventScenario.emergency;
  bool get _isJoined => event.participationRole != null;
  bool get _isHelper => event.participationRole == 'helper';
  bool get _isOrganizer => event.participationRole == 'organizer';

  String _dateRangeLabel() {
    if (event.startsAt == null && event.endsAt == null) {
      return 'Termin nieustalony';
    }

    final DateFormat formatter = DateFormat('dd.MM.yyyy • HH:mm');
    if (event.startsAt != null && event.endsAt != null) {
      return '${formatter.format(event.startsAt!.toLocal())} - ${formatter.format(event.endsAt!.toLocal())}';
    }
    if (event.startsAt != null) {
      return formatter.format(event.startsAt!.toLocal());
    }
    return 'Do: ${formatter.format(event.endsAt!.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPadding),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        event.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    _avatar(event.organizer.displayName),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${event.organizer.displayName}  |  ${event.organizer.verificationLevel.label}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: isBusy ? null : onChatWithOrganizer,
                      icon: const Icon(Icons.chat_bubble_outline),
                      tooltip: 'Napisz do organizatora',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.calendar_today, size: 16),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _dateRangeLabel(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.location_on_outlined, size: 16),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.subtitle,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _photoPlaceholder(
                  context,
                  event.photoLabel ?? 'Podglad wydarzenia',
                ),
                if (event.badges.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: event.badges
                        .map((String badge) => _badge(context, badge))
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 14),
                ..._actionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actionButtons(BuildContext context) {
    return switch (event.scenario) {
      EventScenario.bikeRide => <Widget>[
        _primaryButton(
          context,
          _isOrganizer
              ? 'TO TWOJE WYDARZENIE'
              : _isJoined
              ? 'DOLACZYLES'
              : 'DOLACZ',
          onJoin,
          enabled: !_isJoined,
        ),
      ],
      EventScenario.emergency => <Widget>[
        _primaryButton(
          context,
          _isOrganizer
              ? 'TO TWOJE ZGLOSZENIE'
              : _isHelper
              ? 'POMAGASZ'
              : _isJoined
              ? 'DOLACZYLES'
              : 'MOGE POMOC',
          onHelp,
          enabled: !_isJoined,
        ),
        const SizedBox(height: 10),
        _secondaryButton(context, 'Zglos lokalnie', onReportLocal),
      ],
      EventScenario.social => <Widget>[
        _primaryButton(
          context,
          _isOrganizer
              ? 'TO TWOJA GRUPA'
              : _isJoined
              ? 'JUZ W GRUPIE'
              : 'DOLACZ DO GRUPY',
          onJoin,
          enabled: !_isJoined,
        ),
      ],
    };
  }

  Widget _primaryButton(
    BuildContext context,
    String label,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isBusy || !enabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _secondaryButton(
    BuildContext context,
    String label,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: isBusy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: _isEmergency
              ? Theme.of(context).colorScheme.surfaceContainerLowest
              : Theme.of(context).colorScheme.surface,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _avatar(String name) {
    final String initials = name.isNotEmpty ? name.characters.first : '?';
    return CircleAvatar(
      backgroundColor: AppPalette.successSoft,
      foregroundColor: AppPalette.success,
      radius: 18,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _photoPlaceholder(BuildContext context, String label) {
    return Container(
      width: double.infinity,
      height: 94,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.secondaryContainer,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.photo_outlined,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
