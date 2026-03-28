import 'package:activefriends/src/features/map/domain/event_models.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPadding),
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
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
                Text(event.subtitle, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 10),
                _photoPlaceholder(event.photoLabel ?? 'Podglad wydarzenia'),
                if (event.badges.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: event.badges
                        .map((String badge) => _badge(badge))
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 14),
                ..._actionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actionButtons() {
    return switch (event.scenario) {
      EventScenario.bikeRide => <Widget>[
        _primaryButton(
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
        _secondaryButton('Zglos lokalnie', onReportLocal),
      ],
      EventScenario.social => <Widget>[
        _primaryButton(
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
          backgroundColor: const Color(0xFF1E8E3E),
          foregroundColor: Colors.white,
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

  Widget _secondaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: isBusy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Color(0xFFCCD3DB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: _isEmergency
              ? const Color(0xFFF6F8FA)
              : Colors.white,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _avatar(String name) {
    final String initials = name.isNotEmpty ? name.characters.first : '?';
    return CircleAvatar(
      backgroundColor: const Color(0xFFE4F2E7),
      foregroundColor: const Color(0xFF1E8E3E),
      radius: 18,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _photoPlaceholder(String label) {
    return Container(
      width: double.infinity,
      height: 94,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFE9F1F8), Color(0xFFD3E4F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.photo_outlined, color: Color(0xFF335A75)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF335A75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
