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
    final knowledge = _maps(json['knowledge']);
    final sessions = _maps(json['sessions']);
    final templates = _maps(json['templates']);
    for (final item in knowledge) {
      _validateStrings(item, const ['id', 'title', 'body', 'answer']);
    }
    for (final session in sessions) {
      _validateStrings(session, const ['id', 'title', 'visibility']);
      _validateMapList(session, 'participants', const ['id', 'name']);
      _validateQuestions(session['questions']);
    }
    for (final template in templates) {
      _validateStrings(template, const ['id', 'name']);
      _validateMapList(
        template,
        'participant_slots',
        const ['id', 'label'],
      );
      _validateQuestions(template['questions'], template: true);
    }
    return GuestWorkspaceData(
      knowledge: knowledge,
      sessions: sessions,
      templates: templates,
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

  static List<Map<String, dynamic>> _maps(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('Guest backup collections must be lists.');
    }
    return [
      for (final item in value)
        if (item is Map<String, dynamic>) item else
          throw const FormatException('Guest backup entries must be objects.'),
    ];
  }

  static void _validateStrings(
    Map<String, dynamic> item,
    List<String> fields,
  ) {
    for (final field in fields) {
      final value = item[field];
      if (value != null && value is! String) {
        throw FormatException('Guest backup field "$field" must be text.');
      }
    }
  }

  static void _validateMapList(
    Map<String, dynamic> item,
    String field,
    List<String> stringFields,
  ) {
    final value = item[field];
    if (value == null) return;
    if (value is! List ||
        value.any((entry) => entry is! Map<String, dynamic>)) {
      throw FormatException(
        'Guest backup field "$field" must be a list of objects.',
      );
    }
    for (final entry in value.cast<Map<String, dynamic>>()) {
      _validateStrings(entry, stringFields);
    }
  }

  static void _validateQuestions(Object? value, {bool template = false}) {
    if (value == null) return;
    if (value is! List) {
      throw const FormatException('Guest questions must be a list.');
    }
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Guest questions must contain objects.');
      }
      _validateStrings(item, [
        'id',
        'text',
        if (template) 'target_participant_slot' else 'target_participant_id',
        'scope',
      ]);
      _validateQuestions(item['follow_ups'], template: template);
      final answers = item['answers'];
      if (answers == null) continue;
      if (answers is! List) {
        throw const FormatException('Guest answers must be a list.');
      }
      for (final answer in answers) {
        if (answer is! Map<String, dynamic>) {
          throw const FormatException('Guest answers must contain objects.');
        }
        _validateStrings(answer, const [
          'participant_id',
          'participant_slot',
          'body',
        ]);
        _validateQuestions(answer['follow_ups'], template: template);
      }
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
