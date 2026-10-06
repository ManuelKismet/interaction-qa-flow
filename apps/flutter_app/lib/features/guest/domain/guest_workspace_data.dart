import 'dart:convert';
import 'dart:math';

final _secureRandom = Random.secure();
final _defaultGuestItemIdGenerator = GuestItemIdGenerator();

class GuestItemIdGenerator {
  GuestItemIdGenerator() : _namespace = _randomNamespace();

  GuestItemIdGenerator.forTesting({required String namespace})
    : _namespace = namespace;

  final String _namespace;
  var _counter = 0;

  String next() => 'guest-v2-$_namespace-${(_counter++).toRadixString(36)}';
}

String _randomNamespace() => List.generate(
  8,
  (_) => _secureRandom.nextInt(1 << 16).toRadixString(16).padLeft(4, '0'),
).join();

class GuestWorkspaceData {
  const GuestWorkspaceData({
    this.knowledge = const [],
    this.sessions = const [],
    this.templates = const [],
  });

  factory GuestWorkspaceData.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1) {
      throw const FormatException('Unsupported guest backup version.');
    }
    return GuestWorkspaceData(
      knowledge: _maps(json['knowledge'], _validateKnowledge),
      sessions: _maps(json['sessions'], _validateSession),
      templates: _maps(json['templates'], _validateTemplate),
    );
  }

  final List<Map<String, dynamic>> knowledge;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> templates;

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'knowledge': knowledge,
    'sessions': sessions,
    'templates': templates,
  };

  String encodeBackup() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory GuestWorkspaceData.decodeBackup(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Guest backup must contain a JSON object.');
    }
    return GuestWorkspaceData.fromJson(decoded);
  }

  GuestWorkspaceData copyWith({
    List<Map<String, dynamic>>? knowledge,
    List<Map<String, dynamic>>? sessions,
    List<Map<String, dynamic>>? templates,
  }) => GuestWorkspaceData(
    knowledge: knowledge ?? this.knowledge,
    sessions: sessions ?? this.sessions,
    templates: templates ?? this.templates,
  );

  static List<Map<String, dynamic>> _maps(
    Object? value,
    void Function(Map<String, dynamic>) validate,
  ) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('Guest backup collections must be lists.');
    }
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Guest backup entries must be objects.');
      }
      _requiredString(item, 'id');
      validate(item);
      result.add(item);
    }
    return result;
  }

  static void _validateKnowledge(Map<String, dynamic> item) {
    _optionalStrings(item, const ['title', 'body', 'answer']);
  }

  static void _validateSession(Map<String, dynamic> session) {
    _optionalString(session, 'title');
    _validateObjects(session, 'participants', _validateParticipant);
    _validateObjects(session, 'questions', _validateQuestion);
  }

  static void _validateTemplate(Map<String, dynamic> template) {
    _optionalString(template, 'name');
    _validateObjects(template, 'participant_slots', _validateParticipantSlot);
    _validateObjects(template, 'questions', _validateQuestion);
  }

  static void _validateParticipant(Map<String, dynamic> participant) {
    _requiredString(participant, 'id');
    _optionalString(participant, 'name');
  }

  static void _validateParticipantSlot(Map<String, dynamic> slot) {
    _optionalStrings(slot, const ['id', 'label']);
  }

  static void _validateQuestion(Map<String, dynamic> question) {
    _requiredString(question, 'id');
    _optionalStrings(question, const [
      'text',
      'scope',
      'target_participant_id',
      'target_participant_slot',
    ]);
    _validateObjects(question, 'answers', _validateAnswer);
    _validateObjects(question, 'follow_ups', _validateQuestion);
  }

  static void _validateAnswer(Map<String, dynamic> answer) {
    _optionalStrings(answer, const [
      'participant_id',
      'participant_slot',
      'body',
    ]);
    final collapsed = answer['branches_collapsed'];
    if (collapsed != null && collapsed is! bool) {
      throw const FormatException('Guest backup answer fields are invalid.');
    }
    _validateObjects(answer, 'follow_ups', _validateQuestion);
  }

  static void _validateObjects(
    Map<String, dynamic> parent,
    String key,
    void Function(Map<String, dynamic>) validate,
  ) {
    final value = parent[key];
    if (value == null) return;
    if (value is! List) {
      throw const FormatException(
        'Guest backup nested collections are invalid.',
      );
    }
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Guest backup nested entries must be objects.',
        );
      }
      validate(item);
    }
  }

  static void _requiredString(Map<String, dynamic> object, String key) {
    if (object[key] is! String || (object[key] as String).isEmpty) {
      throw const FormatException(
        'Guest backup entry identifiers are invalid.',
      );
    }
  }

  static void _optionalStrings(Map<String, dynamic> object, List<String> keys) {
    for (final key in keys) {
      _optionalString(object, key);
    }
  }

  static void _optionalString(Map<String, dynamic> object, String key) {
    final value = object[key];
    if (value != null && value is! String) {
      throw const FormatException('Guest backup entry fields are invalid.');
    }
  }
}

Set<String> duplicateGuestParticipantIds(Map<String, dynamic> session) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final participant in session['participants'] as List? ?? const []) {
    if (participant is! Map || participant['id'] is! String) continue;
    final id = participant['id'] as String;
    if (!seen.add(id)) duplicates.add(id);
  }
  return duplicates;
}

bool matchesGuestKeywordOrPrefix(
  String query,
  Map<String, dynamic> knowledgeItem,
) {
  final tokens = query.toLowerCase().trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty || tokens.first.isEmpty) return true;
  final searchable = [
    knowledgeItem['title'],
    knowledgeItem['body'],
    knowledgeItem['answer'],
  ].whereType<String>().join(' ').toLowerCase();
  final words = searchable.split(RegExp(r'[^a-z0-9_-]+'));
  return tokens.every(
    (token) =>
        searchable.contains(token) || words.any((word) => word.startsWith(token)),
  );
}

List<Map<String, dynamic>> mergeSelectedGuestItems({
  required List<Map<String, dynamic>> existing,
  required List<Map<String, dynamic>> imported,
  required Set<String> selectedIds,
}) {
  final merged = [...existing];
  final knownIds = existing.map((item) => item['id']).whereType<String>().toSet();
  for (final item in imported) {
    final id = item['id'];
    if (id is String && selectedIds.contains(id) && knownIds.add(id)) {
      merged.add(item);
    }
  }
  return merged;
}

String newGuestItemId() {
  return _defaultGuestItemIdGenerator.next();
}
