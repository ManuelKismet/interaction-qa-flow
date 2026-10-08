import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';

Map<String, dynamic> createGuestTemplateFromSession({
  required Map<String, dynamic> session,
  required String id,
  required String name,
  String Function()? makeId,
}) {
  final nextId = makeId ?? newGuestItemId;
  final participants = (session['participants'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  final participantSlots = <String, String>{
    for (final (index, participant) in participants.indexed)
      if (participant['id'] is String)
        participant['id'] as String: 'slot-${index + 1}',
  };
  final slots = [
    for (var index = 0; index < participants.length; index++)
      {'id': 'slot-${index + 1}', 'label': 'Participant ${index + 1}'},
  ];
  if (slots.isEmpty) {
    slots.add({'id': 'slot-1', 'label': 'Participant 1'});
  }
  return {
    'id': id,
    'name': name,
    'participant_slots': slots,
    'questions': [
      for (final question in session['questions'] as List? ?? const [])
        if (question is Map)
          _templateQuestion(
            Map<String, dynamic>.from(question),
            participantSlots,
            makeId: nextId,
          ),
    ],
  };
}

Map<String, dynamic> createGuestSessionFromTemplate({
  required Map<String, dynamic> template,
  required String id,
  required String title,
  required String firstParticipantName,
  String Function()? makeId,
}) {
  final nextId = makeId ?? newGuestItemId;
  final slots = _templateSlots(template);
  final participantIds = <String, String>{
    for (final slot in slots)
      slot['id']!: nextId(),
  };
  final participants = [
    for (final (index, slot) in slots.indexed)
      {
        'id': participantIds[slot['id']],
        'name': index == 0
            ? firstParticipantName
            : 'Participant ${index + 1}',
      },
  ];
  final fallbackSlot = slots.first['id']!;
  return {
    'id': id,
    'title': title,
    'visibility': 'private_local',
    'participants': participants,
    'questions': [
      for (final question in template['questions'] as List? ?? const [])
        if (question is Map)
          _sessionQuestion(
            Map<String, dynamic>.from(question),
            participantIds,
            fallbackSlot,
            makeId: nextId,
          ),
    ],
  };
}

Map<String, dynamic> _templateQuestion(
  Map<String, dynamic> question,
  Map<String, String> participantSlots, {
  String? answerOwnerSlot,
  required String Function() makeId,
}) {
  final nested = answerOwnerSlot != null;
  final scope = nested
      ? 'participant'
      : question['scope'] == 'participant'
      ? 'participant'
      : 'shared';
  final targetId = question['target_participant_id'];
  final targetSlot = nested
      ? answerOwnerSlot
      : targetId is String
      ? participantSlots[targetId]
      : null;
  final allSlots = participantSlots.values.toList();
  if (allSlots.isEmpty) allSlots.add('slot-1');
  final targetSlots = scope == 'participant'
      ? [targetSlot ?? allSlots.first]
      : allSlots;
  final existingAnswers = (question['answers'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  final answersBySlot = {
    for (final answer in existingAnswers)
      if (answer['participant_id'] is String &&
          participantSlots.containsKey(answer['participant_id']))
        participantSlots[answer['participant_id'] as String]!: answer,
  };
  return {
    'id': makeId(),
    'text': question['text'] as String? ?? '',
    'scope': scope,
    if (scope == 'participant') 'target_participant_slot': targetSlots.first,
    'answers': [
      for (final slot in targetSlots)
        _templateAnswer(
          answersBySlot[slot],
          slot,
          participantSlots,
          makeId: makeId,
        ),
    ],
  };
}

Map<String, dynamic> _templateAnswer(
  Map<String, dynamic>? answer,
  String slot,
  Map<String, String> participantSlots, {
  required String Function() makeId,
}) => {
  'participant_slot': slot,
  'follow_ups': [
    for (final followUp in answer?['follow_ups'] as List? ?? const [])
      if (followUp is Map)
        _templateQuestion(
          Map<String, dynamic>.from(followUp),
          participantSlots,
          answerOwnerSlot: slot,
          makeId: makeId,
        ),
  ],
};

Map<String, dynamic> _sessionQuestion(
  Map<String, dynamic> question,
  Map<String, String> participantIds,
  String fallbackSlot, {
  String? answerOwnerSlot,
  required String Function() makeId,
}) {
  final nested = answerOwnerSlot != null;
  final scope = nested
      ? 'participant'
      : question['scope'] == 'participant'
      ? 'participant'
      : 'shared';
  final requestedTarget = question['target_participant_slot'];
  final targetSlot = answerOwnerSlot ??
      (requestedTarget is String && participantIds.containsKey(requestedTarget)
          ? requestedTarget
          : fallbackSlot);
  final answerSlots = scope == 'participant'
      ? [targetSlot]
      : participantIds.keys.toList();
  final answersBySlot = {
    for (final answer in question['answers'] as List? ?? const [])
      if (answer is Map && answer['participant_slot'] is String)
        answer['participant_slot'] as String: Map<String, dynamic>.from(answer),
  };
  final directFollowUps = question['follow_ups'] as List? ?? const [];
  return {
    'id': makeId(),
    'text': question['text'] as String? ?? '',
    'scope': scope,
    if (scope == 'participant')
      'target_participant_id': participantIds[targetSlot],
    'answers': [
      for (final slot in answerSlots)
        _sessionAnswer(
          answersBySlot[slot],
          slot,
          participantIds,
          fallbackSlot,
          directFollowUps,
          makeId,
        ),
    ],
  };
}

Map<String, dynamic> _sessionAnswer(
  Map<String, dynamic>? answer,
  String slot,
  Map<String, String> participantIds,
  String fallbackSlot,
  List directFollowUps,
  String Function() makeId,
) => {
  'participant_id': participantIds[slot] ?? participantIds[fallbackSlot],
  'body': '',
  'branches_collapsed': false,
  'follow_ups': [
    for (final followUp in answer?['follow_ups'] as List? ?? directFollowUps)
      if (followUp is Map)
        _sessionQuestion(
          Map<String, dynamic>.from(followUp),
          participantIds,
          fallbackSlot,
          answerOwnerSlot: slot,
          makeId: makeId,
        ),
  ],
};

List<Map<String, String>> _templateSlots(Map<String, dynamic> template) {
  final slots = (template['participant_slots'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, String>.fromEntries(
            item.entries.where((entry) => entry.value is String).map(
                  (entry) => MapEntry(entry.key.toString(), entry.value as String),
                ),
          ))
      .where((slot) => slot['id']?.isNotEmpty == true)
      .toList();
  final references = <String>{};
  void collect(Map<String, dynamic> question) {
    final target = question['target_participant_slot'];
    if (target is String) references.add(target);
    for (final answer in question['answers'] as List? ?? const []) {
      if (answer is! Map) continue;
      final slot = answer['participant_slot'];
      if (slot is String) references.add(slot);
      for (final followUp in answer['follow_ups'] as List? ?? const []) {
        if (followUp is Map) collect(Map<String, dynamic>.from(followUp));
      }
    }
  }

  for (final question in template['questions'] as List? ?? const []) {
    if (question is Map) collect(Map<String, dynamic>.from(question));
  }
  if (slots.isEmpty) {
    slots.addAll([
      for (final (index, id) in references.indexed)
        {'id': id, 'label': 'Participant ${index + 1}'},
    ]);
  } else {
    for (final id in references) {
      if (slots.any((slot) => slot['id'] == id)) continue;
      slots.add({
        'id': id,
        'label': 'Participant ${slots.length + 1}',
      });
    }
  }
  if (slots.isEmpty) {
    slots.add({'id': 'slot-1', 'label': 'Participant 1'});
  }
  return slots;
}

/// Whether [participantId] owns any recorded content in [session]: a
/// non-blank answer, an answer-owned follow-up, or a question targeted at them.
bool guestParticipantHasContent(
  Map<String, dynamic> session,
  String participantId,
) => _questionsHaveParticipantContent(
  session['questions'] as List? ?? const [],
  participantId,
);

bool _questionsHaveParticipantContent(List questions, String participantId) {
  for (final question in questions) {
    if (question is! Map) continue;
    if (question['scope'] == 'participant' &&
        question['target_participant_id'] == participantId) {
      return true;
    }
    for (final answer in question['answers'] as List? ?? const []) {
      if (answer is! Map) continue;
      final followUps = answer['follow_ups'] as List? ?? const [];
      if (answer['participant_id'] == participantId &&
          ((answer['body'] as String? ?? '').trim().isNotEmpty ||
              followUps.isNotEmpty)) {
        return true;
      }
      if (_questionsHaveParticipantContent(followUps, participantId)) {
        return true;
      }
    }
  }
  return false;
}

/// Removes a participant that has no content (see
/// [guestParticipantHasContent]) together with their empty answer stubs.
/// Other participants' answers and branches are left unchanged.
void removeGuestParticipantWithoutContent(
  Map<String, dynamic> session,
  String participantId,
) {
  if (guestParticipantHasContent(session, participantId)) {
    throw StateError('Participant has recorded content.');
  }
  (session['participants'] as List? ?? []).removeWhere(
    (item) => item is Map && item['id'] == participantId,
  );
  _removeEmptyAnswers(session['questions'] as List? ?? [], participantId);
}

void _removeEmptyAnswers(List questions, String participantId) {
  for (final question in questions) {
    if (question is! Map) continue;
    final answers = question['answers'] as List?;
    if (answers == null) continue;
    answers.removeWhere(
      (answer) => answer is Map && answer['participant_id'] == participantId,
    );
    for (final answer in answers) {
      if (answer is Map) {
        _removeEmptyAnswers(
          answer['follow_ups'] as List? ?? const [],
          participantId,
        );
      }
    }
  }
}
