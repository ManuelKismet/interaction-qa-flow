import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/ask/application/ask_suggestions_controller.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/data/personal_workspace_repository.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

class _MemoryGuestStorage implements GuestStorage {
  String? value;

  @override
  String? read() => value;

  @override
  void write(String value) => this.value = value;

  @override
  void remove() => value = null;
}

class _QuestionsRepository extends QuestionsRepository {
  _QuestionsRepository(this.results) : super(Dio());

  final List<SemanticSearchResult> results;
  final requests = <String>[];
  final pending = <Completer<List<SemanticSearchResult>>>[];

  @override
  Future<List<SemanticSearchResult>> searchQuestions(
    String query, {
    int limit = 5,
  }) {
    requests.add(query);
    if (pending.isNotEmpty) return pending.removeAt(0).future;
    return Future.value(results);
  }
}

class _PersonalRepository extends PersonalWorkspaceRepository {
  _PersonalRepository(this.results) : super(Dio());

  final List<Map<String, dynamic>> results;
  final requests = <String>[];
  String? expectedUid;
  bool failSearch = false;

  @override
  Future<Map<String, dynamic>> searchKnowledge(
    String query, {
    required String expectedUid,
  }) async {
    requests.add(query);
    this.expectedUid = expectedUid;
    if (failSearch) throw StateError('Private source unavailable');
    return {'results': results, 'partial': false};
  }
}

class _GroupRepository extends GuestGroupRepository {
  _GroupRepository(this.results) : super(Dio());

  final List<Map<String, dynamic>> results;
  final requests = <String>[];
  bool failSearch = false;

  @override
  Future<Map<String, dynamic>> searchKnowledge(String query) async {
    requests.add(query);
    if (failSearch) throw StateError('Group source unavailable');
    return {'results': results, 'partial': false};
  }
}

final _testAskIdentityProvider =
    NotifierProvider<_TestAskIdentityController, AskSearchIdentity>(
      _TestAskIdentityController.new,
    );

class _TestAskIdentityController extends Notifier<AskSearchIdentity> {
  @override
  AskSearchIdentity build() => const AskSearchIdentity(
    verifiedUid: 'verified-uid',
    membershipState: 'active',
    organisationId: 'first-organisation',
  );

  void setIdentity(AskSearchIdentity identity) => state = identity;
}

const _activeIdentity = AskSearchIdentity(
  verifiedUid: 'verified-uid',
  membershipState: 'active',
  organisationId: 'organisation-id',
);

SemanticSearchResult _organisationResult({
  required String id,
  required double relevance,
}) => SemanticSearchResult(
  questionId: id,
  title: 'Password rotation guidance',
  acceptedAnswerBody: 'Rotate credentials every 90 days.',
  similarity: relevance,
  confidence: 'high_confidence',
  answerStatus: 'verified',
  answerId: 'answer-$id',
  challengeCount: 0,
  hasOpenChallenge: false,
  canonicalQuestionId: id,
  canonicalTitle: 'Password rotation guidance',
  matchedQuestionId: id,
  matchedQuestionIds: [id],
  matchedText: 'Rotate credentials every 90 days.',
  matchSource: 'canonical',
  matchMethod: 'hybrid',
  canonicalBody: 'Password credentials are rotated on schedule.',
  department: const DepartmentSummary(id: 'dept', name: 'Security'),
  team: const TeamSummary(id: 'team', name: 'Identity'),
  organisationName: 'Northwind',
  relevanceScore: relevance,
);

void main() {
  test('searches and ranks local, private, group, and organisation Knowledge', () async {
    final questions = _QuestionsRepository([
      _organisationResult(id: 'org-question', relevance: 1.4),
    ]);
    final personal = _PersonalRepository([
      {
        'source_id': 'private-item',
        'title': 'Private password checklist',
        'data': {'id': 'private-item', 'answer': 'Change default passwords.'},
        'snippet': 'Change default passwords.',
        'match_method': 'keyword',
        'relevance_score': 1.7,
      },
    ]);
    final groups = _GroupRepository([
      {
        'id': 'group-entry',
        'group_id': 'group-id',
        'group_name': 'Platform operations',
        'title': 'Group password notes',
        'data': {'answer': 'Use the team vault.'},
        'snippet': 'Use the team vault.',
        'match_method': 'keyword',
        'relevance_score': 1.6,
      },
    ]);
    final storage = _MemoryGuestStorage();
    await GuestWorkspaceStore(storage).save(
      const GuestWorkspaceData(
        knowledge: [
          {
            'id': 'local-item',
            'title': 'Password rotation guidance',
            'answer': 'Rotate local test credentials.',
          },
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((ref) => questions),
        personalWorkspaceRepositoryProvider.overrideWithValue(personal),
        guestGroupRepositoryProvider.overrideWithValue(groups),
        guestWorkspaceStoreProvider.overrideWithValue(
          GuestWorkspaceStore(storage),
        ),
        askSearchIdentityProvider.overrideWithValue(
          _activeIdentity,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    final controller = container.read(askSuggestionsProvider.notifier);

    controller.queryChanged('password');
    await Future<void>.delayed(const Duration(milliseconds: 380));
    await Future<void>.delayed(Duration.zero);

    final suggestions = container.read(askSuggestionsProvider).value!;
    expect(suggestions.hits.map((hit) => hit.source), [
      'Local',
      'Private',
      'Group: Platform operations',
      'Organisation: Northwind',
    ]);
    expect(suggestions.hits.first.destination, 'personal');
    expect(suggestions.hits[1].destination, 'personal');
    expect(suggestions.hits[2].groupId, 'group-id');
    expect(suggestions.hits[2].destination, 'group');
    expect(suggestions.hits.last.destination, 'organisation');
    expect(suggestions.hits.last.attribution, [
      'Department: Security',
      'Team: Identity',
    ]);
    expect(suggestions.hits.last.matchMethod, 'Keyword and meaning match');
    expect(suggestions.hits.last.status, 'Verified answer');
    expect(suggestions.hits.last.snippet, contains('Password credentials'));
    expect(personal.expectedUid, 'verified-uid');
    expect(questions.requests, ['password']);
    expect(personal.requests, ['password']);
    expect(groups.requests, ['password']);
  });

  test('does not call remote sources for an empty or too-short query', () async {
    final questions = _QuestionsRepository([]);
    final personal = _PersonalRepository([]);
    final groups = _GroupRepository([]);
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((ref) => questions),
        personalWorkspaceRepositoryProvider.overrideWithValue(personal),
        guestGroupRepositoryProvider.overrideWithValue(groups),
        askSearchIdentityProvider.overrideWithValue(
          _activeIdentity,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    final controller = container.read(askSuggestionsProvider.notifier);

    controller.queryChanged('');
    controller.queryChanged('p');
    await Future<void>.delayed(const Duration(milliseconds: 380));

    expect(questions.requests, isEmpty);
    expect(personal.requests, isEmpty);
    expect(groups.requests, isEmpty);
    expect(container.read(askSuggestionsProvider).value!.hits, isEmpty);

    controller.queryChanged('xy');
    await Future<void>.delayed(const Duration(milliseconds: 380));
    expect(questions.requests, ['xy']);
    expect(personal.requests, ['xy']);
    expect(groups.requests, ['xy']);
    expect(
      container.read(askSuggestionsProvider).value!.hasSearched,
      isTrue,
    );
  });

  test('unverified users search local Knowledge only', () async {
    final questions = _QuestionsRepository([]);
    final personal = _PersonalRepository([]);
    final groups = _GroupRepository([]);
    final storage = _MemoryGuestStorage();
    await GuestWorkspaceStore(storage).save(
      const GuestWorkspaceData(
        knowledge: [
          {
            'id': 'local-item',
            'title': 'Password rotation notes',
            'answer': 'Use a strong password.',
          },
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((ref) => questions),
        personalWorkspaceRepositoryProvider.overrideWithValue(personal),
        guestGroupRepositoryProvider.overrideWithValue(groups),
        guestWorkspaceStoreProvider.overrideWithValue(
          GuestWorkspaceStore(storage),
        ),
        askSearchIdentityProvider.overrideWithValue(
          const AskSearchIdentity(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    container.read(askSuggestionsProvider.notifier).queryChanged('password');
    await Future<void>.delayed(const Duration(milliseconds: 380));

    final suggestions = container.read(askSuggestionsProvider).value!;
    expect(suggestions.hits.single.source, 'Local');
    expect(questions.requests, isEmpty);
    expect(personal.requests, isEmpty);
    expect(groups.requests, isEmpty);
  });

  test('long queries retain local results without remote requests', () async {
    final questions = _QuestionsRepository([]);
    final personal = _PersonalRepository([]);
    final groups = _GroupRepository([]);
    final storage = _MemoryGuestStorage();
    await GuestWorkspaceStore(storage).save(
      const GuestWorkspaceData(
        knowledge: [
          {
            'id': 'local-item',
            'title': 'Password rotation notes',
            'answer': 'Use a strong password.',
          },
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((ref) => questions),
        personalWorkspaceRepositoryProvider.overrideWithValue(personal),
        guestGroupRepositoryProvider.overrideWithValue(groups),
        guestWorkspaceStoreProvider.overrideWithValue(
          GuestWorkspaceStore(storage),
        ),
        askSearchIdentityProvider.overrideWithValue(
          _activeIdentity,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    final query = List.filled(51, 'password').join(' ');
    container.read(askSuggestionsProvider.notifier).queryChanged(query);
    await Future<void>.delayed(const Duration(milliseconds: 380));

    final suggestions = container.read(askSuggestionsProvider).value!;
    expect(suggestions.hits.single.source, 'Local');
    expect(suggestions.notice, contains('100 characters'));
    expect(questions.requests, isEmpty);
    expect(personal.requests, isEmpty);
    expect(groups.requests, isEmpty);
  });

  test('ignores an older response for a repeated query', () async {
    final repository = _QuestionsRepository([]);
    final first = Completer<List<SemanticSearchResult>>();
    final second = Completer<List<SemanticSearchResult>>();
    repository.pending.addAll([first, second]);
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((ref) => repository),
        personalWorkspaceRepositoryProvider.overrideWithValue(
          _PersonalRepository([]),
        ),
        guestGroupRepositoryProvider.overrideWithValue(_GroupRepository([])),
        guestWorkspaceStoreProvider.overrideWithValue(
          GuestWorkspaceStore(_MemoryGuestStorage()),
        ),
        askSearchIdentityProvider.overrideWithValue(
          _activeIdentity,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    final controller = container.read(askSuggestionsProvider.notifier);

    controller.queryChanged('password');
    await Future<void>.delayed(const Duration(milliseconds: 380));
    expect(repository.requests, hasLength(1));

    controller.queryChanged('password');
    await Future<void>.delayed(const Duration(milliseconds: 380));
    expect(repository.requests, hasLength(2));

    second.complete([_organisationResult(id: 'new', relevance: 1)]);
    await Future<void>.delayed(Duration.zero);
    first.complete([_organisationResult(id: 'old', relevance: 1)]);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(askSuggestionsProvider).value!.hits.single.id,
      'new',
    );
  });

  test('keeps answer phrase matches above semantic-only organisation hits', () async {
    final storage = _MemoryGuestStorage();
    await GuestWorkspaceStore(storage).save(
      const GuestWorkspaceData(
        knowledge: [
          {
            'id': 'local-answer',
            'title': 'Account recovery notes',
            'answer': 'Recover account access with the security desk.',
          },
          {
            'id': 'local-body',
            'title': 'Recovery checklist',
            'body': 'Recover account access before resetting credentials.',
          },
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith(
          (ref) => _QuestionsRepository([
            _organisationResult(id: 'semantic-only', relevance: 1),
          ]),
        ),
        personalWorkspaceRepositoryProvider.overrideWithValue(
          _PersonalRepository([]),
        ),
        guestGroupRepositoryProvider.overrideWithValue(_GroupRepository([])),
        guestWorkspaceStoreProvider.overrideWithValue(
          GuestWorkspaceStore(storage),
        ),
        askSearchIdentityProvider.overrideWithValue(_activeIdentity),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    container
        .read(askSuggestionsProvider.notifier)
        .queryChanged('recover account access');
    await Future<void>.delayed(const Duration(milliseconds: 380));

    final hits = container.read(askSuggestionsProvider).value!.hits;
    expect(hits.take(2).map((hit) => hit.id), [
      'local-answer',
      'local-body',
    ]);
    expect(
      hits.take(2).every(
        (hit) => hit.snippet!.contains('Recover account access'),
      ),
      isTrue,
    );
    expect(hits.last.id, 'semantic-only');
  });

  test('scopes deduplication and rejects other-owner or inaccessible hits', () async {
    final questions = _QuestionsRepository([
      _organisationResult(id: 'same-id', relevance: 0.8),
    ]);
    final personal = _PersonalRepository([
      {
        'source_id': 'same-id',
        'owner_uid': 'someone-else',
        'title': 'Other owner secret',
        'data': {'answer': 'Do not show this.'},
        'relevance_score': 2,
      },
      {
        'source_id': 'private-duplicate',
        'owner_uid': 'verified-uid',
        'title': 'Private result',
        'data': {'answer': 'Owner-only answer.'},
        'relevance_score': 1,
      },
      {
        'source_id': 'private-duplicate',
        'owner_uid': 'verified-uid',
        'title': 'Duplicate private result',
        'data': {'answer': 'Duplicate payload.'},
        'relevance_score': 0.9,
      },
    ]);
    final groups = _GroupRepository([
      {
        'id': 'same-id',
        'group_id': 'inaccessible-group',
        'group_name': 'Inaccessible group',
        'title': 'Inaccessible result',
        'accessible': false,
        'data': {'answer': 'Do not show group content.'},
      },
      {
        'id': 'same-id',
        'group_id': 'member-group',
        'group_name': 'Member group',
        'title': 'Group result',
        'data': {'answer': 'Visible group answer.'},
      },
    ]);
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((ref) => questions),
        personalWorkspaceRepositoryProvider.overrideWithValue(personal),
        guestGroupRepositoryProvider.overrideWithValue(groups),
        guestWorkspaceStoreProvider.overrideWithValue(
          GuestWorkspaceStore(_MemoryGuestStorage()),
        ),
        askSearchIdentityProvider.overrideWithValue(_activeIdentity),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    container.read(askSuggestionsProvider.notifier).queryChanged('password');
    await Future<void>.delayed(const Duration(milliseconds: 380));

    final hits = container.read(askSuggestionsProvider).value!.hits;
    expect(hits.where((hit) => hit.id == 'same-id'), hasLength(2));
    expect(hits.where((hit) => hit.source == 'Private'), hasLength(1));
    expect(hits.any((hit) => hit.title == 'Other owner secret'), isFalse);
    expect(hits.any((hit) => hit.title == 'Inaccessible result'), isFalse);
    expect(hits.any((hit) => hit.title == 'Duplicate private result'), isFalse);
    expect(
      hits.map((hit) => '${hit.destination}:${hit.groupId ?? ''}:${hit.id}').toSet(),
      hasLength(hits.length),
    );
    expect(personal.expectedUid, 'verified-uid');
  });

  test('partial retry keeps the query and successful results while refreshing', () async {
    final questions = _QuestionsRepository([
      _organisationResult(id: 'organisation-hit', relevance: 1.4),
    ]);
    final personal = _PersonalRepository([
      {
        'source_id': 'private-hit',
        'title': 'Private password notes',
        'data': {'answer': 'Owner-only notes.'},
        'relevance_score': 1,
      },
    ])..failSearch = true;
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((ref) => questions),
        personalWorkspaceRepositoryProvider.overrideWithValue(personal),
        guestGroupRepositoryProvider.overrideWithValue(_GroupRepository([])),
        guestWorkspaceStoreProvider.overrideWithValue(
          GuestWorkspaceStore(_MemoryGuestStorage()),
        ),
        askSearchIdentityProvider.overrideWithValue(_activeIdentity),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    final controller = container.read(askSuggestionsProvider.notifier);
    controller.queryChanged('password');
    await Future<void>.delayed(const Duration(milliseconds: 380));

    final partial = container.read(askSuggestionsProvider).value!;
    expect(partial.failedSources, contains('Private'));
    expect(partial.hits.map((hit) => hit.id), ['organisation-hit']);

    personal.failSearch = false;
    controller.retry();
    final refreshing = container.read(askSuggestionsProvider).value!;
    expect(refreshing.isRefreshing, isTrue);
    expect(refreshing.hits.map((hit) => hit.id), ['organisation-hit']);
    await Future<void>.delayed(const Duration(milliseconds: 380));

    final retried = container.read(askSuggestionsProvider).value!;
    expect(retried.failedSources, isEmpty);
    expect(retried.hits.map((hit) => hit.id), [
      'organisation-hit',
      'private-hit',
    ]);
    expect(personal.requests, ['password', 'password']);
    expect(questions.requests, ['password', 'password']);
  });

  test('discards old results across account, membership, and organisation changes', () async {
    final questions = _QuestionsRepository([]);
    final first = Completer<List<SemanticSearchResult>>();
    final second = Completer<List<SemanticSearchResult>>();
    final third = Completer<List<SemanticSearchResult>>();
    questions.pending.addAll([first, second, third]);
    final personal = _PersonalRepository([]);
    final storage = _MemoryGuestStorage();
    await GuestWorkspaceStore(storage).save(
      const GuestWorkspaceData(
        knowledge: [
          {
            'id': 'local-hit',
            'title': 'Password help',
            'answer': 'Local account recovery.',
          },
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((ref) => questions),
        personalWorkspaceRepositoryProvider.overrideWithValue(personal),
        guestGroupRepositoryProvider.overrideWithValue(_GroupRepository([])),
        guestWorkspaceStoreProvider.overrideWithValue(
          GuestWorkspaceStore(storage),
        ),
        askSearchIdentityProvider.overrideWith(
          (ref) => ref.watch(_testAskIdentityProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    final controller = container.read(askSuggestionsProvider.notifier);
    final identityController = container.read(
      _testAskIdentityProvider.notifier,
    );

    controller.queryChanged('password');
    await Future<void>.delayed(const Duration(milliseconds: 380));
    identityController.setIdentity(
      const AskSearchIdentity(
        verifiedUid: 'verified-uid',
        membershipState: 'active',
        organisationId: 'second-organisation',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 380));
    second.complete([_organisationResult(id: 'current-org-hit', relevance: 1)]);
    await Future<void>.delayed(Duration.zero);
    first.complete([_organisationResult(id: 'old-org-hit', relevance: 1)]);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(askSuggestionsProvider).value!.hits.map((hit) => hit.id),
      contains('current-org-hit'),
    );
    expect(
      container.read(askSuggestionsProvider).value!.hits.any(
        (hit) => hit.id == 'old-org-hit',
      ),
      isFalse,
    );

    identityController.setIdentity(
      const AskSearchIdentity(
        verifiedUid: 'verified-uid',
        membershipState: 'noMembership',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 380));
    expect(
      container.read(askSuggestionsProvider).value!.hits.map((hit) => hit.id),
      ['local-hit'],
    );

    identityController.setIdentity(
      const AskSearchIdentity(
        verifiedUid: 'next-uid',
        membershipState: 'active',
        organisationId: 'second-organisation',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 380));
    expect(personal.expectedUid, 'next-uid');
    identityController.setIdentity(const AskSearchIdentity());
    await Future<void>.delayed(const Duration(milliseconds: 380));
    third.complete([_organisationResult(id: 'signed-out-hit', relevance: 1)]);
    await Future<void>.delayed(Duration.zero);
    final signedOut = container.read(askSuggestionsProvider).value!;
    expect(signedOut.hits.map((hit) => hit.id), ['local-hit']);
    expect(questions.requests, ['password', 'password', 'password']);
    expect(personal.requests, ['password', 'password', 'password']);
  });
}
