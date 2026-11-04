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
    this.additionalFields = const {},
  });

  factory GuestWorkspaceData.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1) {
      throw const FormatException('Unsupported guest backup version.');
    }
    final knowledge = _maps(json['knowledge']);
    final sessions = _maps(json['sessions']);
    final templates = _maps(json['templates']);
    for (final item in knowledge) {
      _validateStrings(
        item,
        const ['id', 'title', 'body', 'answer'],
        required: const ['id', 'title'],
      );
    }
    for (final session in sessions) {
      _validateStrings(
        session,
        const ['id', 'title', 'visibility'],
        required: const ['id'],
      );
      _validateMapList(
        session,
        'participants',
        const ['id', 'name'],
        required: true,
        requiredStringFields: const ['id'],
      );
      _validateQuestions(session['questions'], required: true);
    }
    for (final template in templates) {
      _validateStrings(
        template,
        const ['id', 'name'],
        required: const ['id', 'name'],
      );
      _validateMapList(
        template,
        'participant_slots',
        const ['id', 'label'],
        requiredStringFields: const ['id'],
      );
      _validateQuestions(template['questions'], template: true, required: true);
    }
    return GuestWorkspaceData(
      knowledge: knowledge,
      sessions: sessions,
      templates: templates,
      additionalFields: {
        for (final entry in json.entries)
          if (!const [
            'schema_version',
            'knowledge',
            'sessions',
            'templates',
          ].contains(entry.key))
            entry.key: entry.value,
      },
    );
  }

  final List<Map<String, dynamic>> knowledge;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> templates;
  final Map<String, dynamic> additionalFields;

  Map<String, dynamic> toJson() => {
    ...additionalFields,
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
    if (decoded['schema_version'] is! int || decoded['schema_version'] != 1) {
      throw const FormatException('Unsupported guest backup version.');
    }
    for (final field in const ['knowledge', 'sessions', 'templates']) {
      if (decoded[field] is! List) {
        throw FormatException('Local backup must include a "$field" list.');
      }
    }
    final data = GuestWorkspaceData.fromJson(decoded);
    data.validateImport();
    return data;
  }

  void validateImport() {
    _uniqueIds(knowledge, 'Knowledge');
    _uniqueIds(sessions, 'sessions');
    _uniqueIds(templates, 'templates');
    for (final session in sessions) {
      final participants = _maps(session['participants']);
      final ids = _uniqueIds(participants, 'participants');
      _validateReferences(session['questions'], ids, <String>{});
    }
    for (final template in templates) {
      final slots = _uniqueIds(
        _maps(template['participant_slots']),
        'participant slots',
      );
      _validateReferences(
        template['questions'],
        slots,
        <String>{},
        template: true,
      );
    }
  }

  static Set<String> _uniqueIds(
    List<Map<String, dynamic>> items,
    String collection,
  ) {
    final ids = <String>{};
    for (final item in items) {
      final id = item['id'];
      if (id is! String || id.trim().isEmpty || !ids.add(id)) {
        throw FormatException(
          'Local backup $collection must have unique, non-empty IDs.',
        );
      }
    }
    return ids;
  }

  static void _validateReferences(
    Object? value,
    Set<String> participants,
    Set<String> questionIds, {
    bool template = false,
    String? answerOwner,
  }) {
    final targetField = template
        ? 'target_participant_slot'
        : 'target_participant_id';
    final ownerField = template ? 'participant_slot' : 'participant_id';
    for (final question in _maps(value)) {
      final id = question['id'] as String;
      if (id.trim().isEmpty || !questionIds.add(id)) {
        throw const FormatException(
          'Local backup question IDs must be unique.',
        );
      }
      if ((question['text'] as String).trim().isEmpty) {
        throw const FormatException(
          'Local backup question titles cannot be blank.',
        );
      }
      final scope = question['scope'];
      if (scope != null && scope != 'shared' && scope != 'participant') {
        throw const FormatException('Unsupported local question scope.');
      }
      final target = question[targetField];
      if ((target != null && !participants.contains(target)) ||
          (scope == 'shared' && target != null) ||
          (scope == 'participant' && target == null && answerOwner == null) ||
          (answerOwner != null && target != null && target != answerOwner)) {
        throw const FormatException('Local backup question target is invalid.');
      }
      _validateReferences(
        question['follow_ups'],
        participants,
        questionIds,
        template: template,
        answerOwner: answerOwner,
      );
      final owners = <String>{};
      for (final answer in _maps(question['answers'])) {
        final owner = answer[ownerField] as String;
        if (!participants.contains(owner) ||
            !owners.add(owner) ||
            (answerOwner != null && owner != answerOwner) ||
            (scope == 'participant' && target != null && owner != target)) {
          throw const FormatException(
            'Local backup answer ownership is invalid.',
          );
        }
        _validateReferences(
          answer['follow_ups'],
          participants,
          questionIds,
          template: template,
          answerOwner: owner,
        );
      }
    }
  }

  GuestWorkspaceData copyWith({
    List<Map<String, dynamic>>? knowledge,
    List<Map<String, dynamic>>? sessions,
    List<Map<String, dynamic>>? templates,
  }) => GuestWorkspaceData(
    knowledge: knowledge ?? this.knowledge,
    sessions: sessions ?? this.sessions,
    templates: templates ?? this.templates,
    additionalFields: additionalFields,
  );

  static List<Map<String, dynamic>> _maps(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('Guest backup collections must be lists.');
    }
    return [
      for (final item in value)
        if (item is Map<String, dynamic>)
          item
        else
          throw const FormatException('Guest backup entries must be objects.'),
    ];
  }

  static void _validateStrings(
    Map<String, dynamic> item,
    List<String> fields, {
    List<String> required = const [],
  }) {
    for (final field in fields) {
      final value = item[field];
      if (required.contains(field) && (value is! String || value.isEmpty)) {
        throw FormatException(
          'Guest backup field "$field" must be non-empty text.',
        );
      }
      if (value != null && value is! String) {
        throw FormatException('Guest backup field "$field" must be text.');
      }
    }
  }

  static void _validateMapList(
    Map<String, dynamic> item,
    String field,
    List<String> stringFields, {
    bool required = false,
    List<String> requiredStringFields = const [],
  }) {
    final value = item[field];
    if (value == null && !required) return;
    if (value is! List ||
        value.any((entry) => entry is! Map<String, dynamic>)) {
      throw FormatException(
        'Guest backup field "$field" must be a list of objects.',
      );
    }
    for (final entry in value.cast<Map<String, dynamic>>()) {
      _validateStrings(entry, stringFields, required: requiredStringFields);
    }
  }

  static void _validateQuestions(
    Object? value, {
    bool template = false,
    bool required = false,
  }) {
    if (value == null && !required) return;
    if (value is! List) {
      throw const FormatException('Guest questions must be a list.');
    }
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Guest questions must contain objects.');
      }
      _validateStrings(
        item,
        [
          'id',
          'text',
          if (template) 'target_participant_slot' else 'target_participant_id',
          'scope',
        ],
        required: const ['id', 'text'],
      );
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
        _validateStrings(
          answer,
          const ['participant_id', 'participant_slot', 'body'],
          required: [template ? 'participant_slot' : 'participant_id'],
        );
        final branchesCollapsed = answer['branches_collapsed'];
        if (branchesCollapsed != null && branchesCollapsed is! bool) {
          throw const FormatException(
            'Guest answer field "branches_collapsed" must be a boolean.',
          );
        }
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
        searchable.contains(token) ||
        words.any(
          (word) =>
              word.startsWith(token) ||
              (token.length >= 4 &&
                  (word.length - token.length).abs() <= 1 &&
                  _guestWordsOneEditApart(word, token)),
        ),
  );
}

bool _guestWordsOneEditApart(String left, String right) {
  if ((left.length - right.length).abs() > 1) return false;
  if (left.length == right.length) {
    final mismatches = <int>[
      for (var index = 0; index < left.length; index++)
        if (left.codeUnitAt(index) != right.codeUnitAt(index)) index,
    ];
    if (mismatches.length == 2 &&
        mismatches[1] == mismatches[0] + 1 &&
        left.codeUnitAt(mismatches[0]) == right.codeUnitAt(mismatches[1]) &&
        left.codeUnitAt(mismatches[1]) == right.codeUnitAt(mismatches[0])) {
      return true;
    }
  }
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var row = 1; row <= left.length; row++) {
    final current = <int>[row];
    for (var column = 1; column <= right.length; column++) {
      current.add(
        [
          current.last + 1,
          previous[column] + 1,
          previous[column - 1] +
              (left.codeUnitAt(row - 1) == right.codeUnitAt(column - 1)
                  ? 0
                  : 1),
        ].reduce((a, b) => a < b ? a : b),
      );
    }
    if (current.reduce((a, b) => a < b ? a : b) > 1) return false;
    previous = current;
  }
  return previous.last <= 1;
}

List<Map<String, dynamic>> mergeSelectedGuestItems({
  required List<Map<String, dynamic>> existing,
  required List<Map<String, dynamic>> imported,
  required Set<String> selectedIds,
}) {
  final merged = [...existing];
  final knownIds = existing
      .map((item) => item['id'])
      .whereType<String>()
      .toSet();
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
