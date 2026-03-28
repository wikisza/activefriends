const List<String> kSportTopics = <String>[
  'Rower',
  'Bieganie',
  'Spacer',
  'Nordic walking',
  'Trekking',
  'Rolki',
  'Deskorolka',
  'Silownia',
  'Joga',
  'Pilates',
  'Plywanie',
  'Tenis',
  'Badminton',
  'Pilka nozna',
  'Koszykowka',
  'Siatkowka',
  'Wspinaczka',
  'Kajaki',
];

const List<String> kSocialTopics = <String>[
  'Ceramika',
  'Szachy',
  'Planszowki',
  'Fotografia',
  'Malarstwo',
  'Rysunek',
  'Taniec',
  'Gotowanie',
  'Pieczenie',
  'Kawa i rozmowa',
  'Nauka jezykow',
  'Programowanie',
  'Robotyka',
  'Majsterkowanie',
  'Ogrodnictwo',
  'Muzyka',
  'Spiew',
  'Teatr',
  'Kino',
  'Czytanie',
  'Startupy',
];

const List<String> kHelpTopics = <String>[
  'Pomoc',
  'Wolontariat',
  'Opieka nad zwierzetami',
  'Wsparcie seniora',
  'Pomoc sasiedzka',
  'Transport pomocy',
  'Zbiorka rzeczy',
];

const List<String> kSupportedTopics = <String>[
  ...kSportTopics,
  ...kSocialTopics,
  ...kHelpTopics,
];

List<String> orderedTopics(Iterable<String> topics) {
  final Set<String> topicSet = topics
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toSet();

  return kSupportedTopics.where(topicSet.contains).toList(growable: false);
}

List<String> topicsForScenarioKey(String scenarioKey) {
  return switch (scenarioKey) {
    'emergency' => kHelpTopics,
    'social' => kSocialTopics,
    _ => kSportTopics,
  };
}

String primaryTopicForScenarioKey(String scenarioKey) {
  return switch (scenarioKey) {
    'emergency' => kHelpTopics.first,
    'social' => kSocialTopics.first,
    _ => kSportTopics.first,
  };
}

bool matchesTopicFilters({
  required Iterable<String> selectedTopics,
  required String scenarioKey,
  String? fallbackTopic,
}) {
  final Set<String> normalizedFilters = selectedTopics
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toSet();

  if (normalizedFilters.isEmpty) {
    return true;
  }

  final Set<String> scenarioTopics = <String>{
    ...topicsForScenarioKey(scenarioKey),
    if (fallbackTopic != null && fallbackTopic.trim().isNotEmpty)
      fallbackTopic.trim(),
  };

  return normalizedFilters.any(scenarioTopics.contains);
}
