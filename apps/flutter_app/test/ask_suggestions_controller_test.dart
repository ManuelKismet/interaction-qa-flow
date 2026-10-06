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

  @override
  Future<Map<String, dynamic>> searchKnowledge(
    String query, {
    required String expectedUid,
  }) async {
    requests.add(query);
    this.expectedUid = expectedUid;
    return {'results': results, 'partial': false};
  }
}

class _GroupRepository extends GuestGroupRepository {
  _GroupRepository(this.results) : super(Dio());

  final List<Map<String, dynamic>> results;
  final requests = <String>[];

  @override
  Future<Map<String, dynamic>> searchKnowledge(String query) async {
    requests.add(query);
    return {'results': results, 'partial': false};
  }
}

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
          const AskSearchIdentity(verifiedUid: 'verified-uid'),
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
          const AskSearchIdentity(verifiedUid: 'verified-uid'),
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
          const AskSearchIdentity(verifiedUid: 'verified-uid'),
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
          const AskSearchIdentity(verifiedUid: 'verified-uid'),
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
}
