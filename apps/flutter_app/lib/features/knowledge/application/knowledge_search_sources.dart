import 'package:int_qa_flow/features/questions/domain/question_models.dart';

typedef OrganisationKnowledgeSearch =
    Future<List<SemanticSearchResult>> Function(String query);
typedef PrivateKnowledgeSearch =
    Future<Map<String, dynamic>> Function(String query);
typedef GroupKnowledgeSearch =
    Future<Map<String, dynamic>> Function(String query);

class KnowledgeSearchSources {
  const KnowledgeSearchSources({
    this.organisation = const [],
    this.privateAccount = const [],
    this.groups = const [],
    this.interact = const [],
    this.failedSources = const {},
    this.partialSources = const {},
  });

  final List<SemanticSearchResult> organisation;
  final List<Map<String, dynamic>> privateAccount;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> interact;
  final Set<String> failedSources;
  final Set<String> partialSources;
}

Future<KnowledgeSearchSources> searchKnowledgeSources(
  String query, {
  OrganisationKnowledgeSearch? searchOrganisation,
  PrivateKnowledgeSearch? searchPrivateAccount,
  GroupKnowledgeSearch? searchGroups,
  PrivateKnowledgeSearch? searchPrivateInteract,
  PrivateKnowledgeSearch? searchOrganisationInteract,
}) async {
  List<SemanticSearchResult> organisation = [];
  List<Map<String, dynamic>> privateAccount = [];
  List<Map<String, dynamic>> groups = [];
  final interact = <Map<String, dynamic>>[];
  final failed = <String>{};
  final partial = <String>{};

  Future<void> interactSource(
    String name,
    PrivateKnowledgeSearch search,
  ) async {
    try {
      final response = await search(query);
      interact.addAll(
        (response['results'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>(),
      );
      if (response['partial'] == true) partial.add(name);
    } on Object {
      failed.add(name);
    }
  }

  await Future.wait<void>([
    if (searchPrivateInteract != null)
      interactSource('Private and Group Interact', searchPrivateInteract),
    if (searchOrganisationInteract != null)
      interactSource('Organisation Interact', searchOrganisationInteract),
    if (searchOrganisation != null)
      (() async {
        try {
          organisation = await searchOrganisation(query);
          if (organisation.length >= 10) partial.add('Organisation');
        } on Object {
          failed.add('Organisation');
        }
      })(),
    if (searchPrivateAccount != null)
      (() async {
        try {
          final response = await searchPrivateAccount(query);
          privateAccount = (response['results'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
          if (response['partial'] == true) partial.add('Private');
        } on Object {
          failed.add('Private');
        }
      })(),
    if (searchGroups != null)
      (() async {
        try {
          final response = await searchGroups(query);
          groups = (response['results'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
          if (response['partial'] == true) partial.add('Groups');
        } on Object {
          failed.add('Groups');
        }
      })(),
  ]);

  return KnowledgeSearchSources(
    organisation: organisation,
    privateAccount: privateAccount,
    groups: groups,
    interact: interact,
    failedSources: failed,
    partialSources: partial,
  );
}

double localKnowledgeRelevance(String query, Map<String, dynamic> item) {
  final foldedQuery = query.toLowerCase().trim();
  final title = (item['title'] as String? ?? '').toLowerCase();
  if (title == foldedQuery) return 1.9;
  if (title.startsWith(foldedQuery)) return 1.7;
  if (title.contains(foldedQuery)) return 1.5;
  final answerAndBody = [
    item['answer'],
    item['body'],
  ].whereType<String>().join(' ').toLowerCase();
  if (answerAndBody.contains(foldedQuery)) return 2.5;
  final terms = foldedQuery
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty);
  if (terms.isNotEmpty && terms.every(answerAndBody.contains)) return 1.6;
  return 0.9;
}
