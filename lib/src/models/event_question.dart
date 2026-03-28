class EventQuestion {
  final String id;
  final String eventId;
  final String authorId;
  final String question;
  final String? answer;
  final DateTime createdAt;

  const EventQuestion({
    required this.id,
    required this.eventId,
    required this.authorId,
    required this.question,
    this.answer,
    required this.createdAt,
  });

  factory EventQuestion.fromJson(Map<String, dynamic> json) => EventQuestion(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        authorId: json['author_id'] as String,
        question: json['question'] as String,
        answer: json['answer'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'author_id': authorId,
        'question': question,
        'answer': answer,
        'created_at': createdAt.toIso8601String(),
      };
}
