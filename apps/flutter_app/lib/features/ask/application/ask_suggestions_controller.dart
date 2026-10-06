import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/data/personal_workspace_repository.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/knowledge/application/knowledge_search_sources.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

final askSuggestionsProvider =
    AsyncNotifierProvider.autoDispose<AskSuggestionsController, AskSuggestions>(
      AskSuggestionsController.new,
    );

class AskKnowledgeHit {
  const AskKnowledgeHit({
    required this.id,
    required this.title,
    required this.source,
    required this.attribution,
    required this.matchMethod,
    required this.relevance,
    required this.snippet,
    required this.status,
    required this.destination,
    this.groupId,
  });

  final String id;
  final String title;
  final String source;
  final List<String> attribution;
  final String matchMethod;
  final double relevance;
  final String? snippet;
  final String status;
  final String destination;
  final String? groupId;
}

class AskSuggestions {
  const AskSuggestions({
    this.hits = const [],
    this.failedSources = const {},
    this.partialSources = const {},
    this.hasSearched = false,
    this.notice,
  });

  final List<AskKnowledgeHit> hits;
  final Set<String> failedSources;
  final Set<String> partialSources;
  final bool hasSearched;
  final String? notice;
}

class AskSearchIdentity {
  const AskSearchIdentity({this.verifiedUid});

  final String? verifiedUid;
}

final askSearchIdentityProvider = Provider<AskSearchIdentity>((ref) {
  try {
    final user =
        ref.watch(authStateProvider).value ??
        ref.watch(firebaseAuthProvider).currentUser;
    return AskSearchIdentity(
      verifiedUid: isVerifiedRegisteredFirebaseUser(user) ? user!.uid : null,
    );
  } on Object {
    return const AskSearchIdentity();
  }
});

class AskSuggestionsController extends AsyncNotifier<AskSuggestions> {
  Timer? _debounce;
  String _latestQuery = '';
  int _queryGeneration = 0;

  @override
  Future<AskSuggestions> build() async {
    ref.listen(askSearchIdentityProvider, (previous, next) {
      if (previous?.verifiedUid != next.verifiedUid &&
          _latestQuery.isNotEmpty) {
        queryChanged(_latestQuery);
      }
    });
    ref.onDispose(() {
      _debounce?.cancel();
      _queryGeneration++;
    });
    return const AskSuggestions();
  }

  void queryChanged(String query) {
    _debounce?.cancel();
    final generation = ++_queryGeneration;
    _latestQuery = query.trim();
    if (_latestQuery.length < 2) {
      state = const AsyncData(AskSuggestions());
      return;
    }

    state = const AsyncLoading();
    final requestedQuery = _latestQuery;
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(requestedQuery, generation),
    );
  }

  Future<void> _search(String query, int generation) async {
    final identity = ref.read(askSearchIdentityProvider);
    GuestWorkspaceData local;
    var localFailed = false;
    try {
      local = await ref.read(guestWorkspaceStoreProvider).load();
    } on Object {
      local = const GuestWorkspaceData();
      localFailed = true;
    }

    if (_queryGeneration != generation ||
        _latestQuery != query ||
        ref.read(askSearchIdentityProvider).verifiedUid !=
            identity.verifiedUid) {
      return;
    }
    final sources = query.length > 100
        ? const KnowledgeSearchSources()
        : await searchKnowledgeSources(
            query,
            searchOrganisation: identity.verifiedUid == null
                ? null
                : (value) => ref
                      .read(questionsRepositoryProvider)
                      .searchQuestions(value, limit: 10),
            searchPrivateAccount: identity.verifiedUid == null
                ? null
                : (value) => ref
                      .read(personalWorkspaceRepositoryProvider)
                      .searchKnowledge(
                        value,
                        expectedUid: identity.verifiedUid!,
                      ),
            searchGroups: identity.verifiedUid == null
                ? null
                : (value) => ref
                      .read(guestGroupRepositoryProvider)
                      .searchKnowledge(value),
          );
    if (_queryGeneration != generation ||
        _latestQuery != query ||
        ref.read(askSearchIdentityProvider).verifiedUid !=
            identity.verifiedUid) {
      return;
    }

    final hits = <AskKnowledgeHit>[];
    final privateById = {
      for (final item in sources.privateAccount)
        if (item['source_id'] is String)
          item['source_id'] as String: item,
    };
    final localIds = <String>{};
    for (final item in local.knowledge) {
      if (!matchesGuestKeywordOrPrefix(query, item)) continue;
      final id = item['id'] as String? ?? '';
      if (id.isEmpty) continue;
      localIds.add(id);
      final account = privateById[id];
      final privateData = account?['data'] is Map
          ? Map<String, dynamic>.from(account!['data'] as Map)
          : const <String, dynamic>{};
      final isPrivate = account != null;
      hits.add(
        AskKnowledgeHit(
          id: id,
          title: item['title'] as String? ?? '',
          source: isPrivate ? 'Private' : 'Local',
          attribution: const [],
          matchMethod: isPrivate
              ? _matchMethod(account['match_method'] as String?)
              : 'Keyword or prefix match',
          relevance: [
            localKnowledgeRelevance(query, item),
            (account?['relevance_score'] as num?)?.toDouble() ?? 0,
          ].reduce((left, right) => left > right ? left : right),
          snippet: _snippet(
            query,
            [
              _string(account?['snippet']),
              _string(item['answer']),
              _string(item['body']),
              _string(privateData['answer']),
              _string(privateData['body']),
            ],
          ),
          status: 'Knowledge',
          destination: 'personal',
        ),
      );
    }
    for (final result in sources.privateAccount) {
      final id = result['source_id'] as String? ?? '';
      if (id.isEmpty || localIds.contains(id)) continue;
      final data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map)
          : const <String, dynamic>{};
      hits.add(
        AskKnowledgeHit(
          id: id,
          title: result['title'] as String? ?? '',
          source: 'Private',
          attribution: const [],
          matchMethod: _matchMethod(result['match_method'] as String?),
          relevance: (result['relevance_score'] as num?)?.toDouble() ?? 0,
          snippet: _snippet(query, [
            _string(result['snippet']),
            _string(data['answer']),
            _string(data['body']),
          ]),
          status: 'Knowledge',
          destination: 'personal',
        ),
      );
    }
    for (final result in sources.groups) {
      final id = result['id'] as String? ?? '';
      final groupId = result['group_id'] as String?;
      if (id.isEmpty || groupId == null) continue;
      final data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map)
          : const <String, dynamic>{};
      hits.add(
        AskKnowledgeHit(
          id: id,
          title: result['title'] as String? ?? '',
          source: 'Group: ${result['group_name'] as String? ?? 'Group'}',
          attribution: const [],
          matchMethod: _matchMethod(result['match_method'] as String?),
          relevance: (result['relevance_score'] as num?)?.toDouble() ?? 0,
          snippet: _snippet(query, [
            _string(result['snippet']),
            _string(data['answer']),
            _string(data['body']),
          ]),
          status: 'Knowledge',
          destination: 'group',
          groupId: groupId,
        ),
      );
    }
    for (final result in sources.organisation) {
      hits.add(
        AskKnowledgeHit(
          id: result.questionId,
          title: result.title,
          source: 'Organisation: ${result.organisationName}',
          attribution: [
            if (result.department != null)
              'Department: ${result.department!.name}',
            if (result.team != null) 'Team: ${result.team!.name}',
          ],
          matchMethod: _matchMethod(result.matchMethod),
          relevance: result.relevanceScore,
          snippet: _snippet(query, [
            result.canonicalBody,
            result.acceptedAnswerBody,
            result.matchedText,
          ]),
          status: result.answerStatus == 'verified'
              ? 'Verified answer'
              : result.acceptedAnswerBody != null
              ? 'Existing answer'
              : 'Open question',
          destination: 'organisation',
        ),
      );
    }
    hits.sort((left, right) {
      final byScore = right.relevance.compareTo(left.relevance);
      if (byScore != 0) return byScore;
      final byTitle = left.title.toLowerCase().compareTo(
        right.title.toLowerCase(),
      );
      if (byTitle != 0) return byTitle;
      final byId = left.id.compareTo(right.id);
      return byId != 0 ? byId : left.source.compareTo(right.source);
    });
    final errors = {...sources.failedSources};
    if (localFailed) errors.add('Local');
    state = AsyncData(
      AskSuggestions(
        hits: hits.take(10).toList(),
        failedSources: errors,
        partialSources: sources.partialSources,
        hasSearched: true,
        notice: query.length > 100
            ? 'Shorten the query to 100 characters to search other accessible '
                'Knowledge sources. Local Knowledge was searched.'
            : null,
      ),
    );
  }

  static String _matchMethod(String? method) => switch (method) {
    'semantic' => 'Meaning-based match',
    'hybrid' => 'Keyword and meaning match',
    _ => 'Keyword or prefix match',
  };

  static String? _string(Object? value) => value is String ? value : null;

  static String? _snippet(String query, List<String?> candidates) {
    final terms = query.toLowerCase().split(RegExp(r'\s+'));
    for (final candidate in candidates.whereType<String>()) {
      final folded = candidate.toLowerCase();
      final positions = terms
          .where((term) => term.isNotEmpty)
          .map(folded.indexOf)
          .where((index) => index >= 0)
          .toList();
      if (positions.isEmpty) continue;
      final start = (positions.reduce((a, b) => a < b ? a : b) - 50)
          .clamp(0, candidate.length)
          .toInt();
      final end = (start + 220).clamp(0, candidate.length).toInt();
      return '${start > 0 ? '…' : ''}${candidate.substring(start, end)}'
          '${end < candidate.length ? '…' : ''}';
    }
    final fallback = candidates.whereType<String>().firstOrNull;
    if (fallback == null) return null;
    return fallback.length <= 220 ? fallback : '${fallback.substring(0, 220)}…';
  }
}
