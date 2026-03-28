import 'package:flutter/material.dart';

/// Lista rozmów — na razie placeholder; real-time i tworzenie konwersacji dodamy później.
class ChatConversationsScreen extends StatelessWidget {
  const ChatConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Czat'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 72,
                color: cs.primary.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 20),
              Text(
                'Brak rozmów',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Tutaj zobaczysz wszystkie konwersacje. '
                'Czat na żywo i zapraszanie osób do rozmowy dodamy w kolejnym kroku.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
