import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/data/personal_workspace_repository.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/knowledge/application/knowledge_search_sources.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';

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
    this.isRefreshing = false,
  });

  final List<AskKnowledgeHit> hits;
  final Set<String> failedSources;
  final Set<String> partialSources;
  final bool hasSearched;
  final String? notice;
  final bool isRefreshing;
}

class AskSearchIdentity {
  const AskSearchIdentity({
    this.verifiedUid,
    this.membershipState,
    this.organisationId,
  });

  final String? verifiedUid;
  final String? membershipState;
  final String? organisationId;

  bool sameScopeAs(AskSearchIdentity other) =>
      verifiedUid == other.verifiedUid &&
      membershipState == other.membershipState &&
      organisationId == other.organisationId;
}

final askSearchIdentityProvider = Provider<AskSearchIdentity>((ref) {
  try {
    final authState = ref.watch(authStateProvider);
    final user = authState.hasValue
        ? authState.requireValue
        : ref.watch(firebaseAuthProvider).currentUser;
    if (!isVerifiedRegisteredFirebaseUser(user)) {
      return const AskSearchIdentity();
    }
    final uid = user!.uid;
    final membershipStatus = ref.watch(accountMembershipStatusProvider);
    if (membershipStatus.isLoading) {
      return AskSearchIdentity(verifiedUid: uid, membershipState: 'checking');
    }
    if (membershipStatus.hasError || !membershipStatus.hasValue) {
      return AskSearchIdentity(
        verifiedUid: uid,
        membershipState: 'unavailable',
      );
    }
    final status = membershipStatus.requireValue;
    if (status != AccountMembershipStatus.active) {
      return AskSearchIdentity(
        verifiedUid: uid,
        membershipState: status.name,
      );
    }
    final membership = ref.watch(currentMembershipProvider);
    if (membership.isLoading) {
      return AskSearchIdentity(verifiedUid: uid, membershipState: 'checking');
    }
    if (membership.hasError ||
        !membership.hasValue ||
        membership.requireValue.userId != uid) {
      return AskSearchIdentity(
        verifiedUid: uid,
        membershipState: 'unavailable',
      );
    }
    return AskSearchIdentity(
      verifiedUid: uid,
      membershipState: status.name,
      organisationId: membership.requireValue.organisationId,
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
      if (previous != null &&
          !previous.sameScopeAs(next) &&
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
    _scheduleQuery(query, preserveResults: false);
  }

  void retry() {
    final previous = state.value;
    if (previous == null || _latestQuery.length < 2) return;
    _scheduleQuery(_latestQuery, preserveResults: true);
  }

  void _scheduleQuery(String query, {required bool preserveResults}) {
    _debounce?.cancel();
    final generation = ++_queryGeneration;
    _latestQuery = query.trim();
    if (_latestQuery.length < 2) {
      state = const AsyncData(AskSuggestions());
      return;
    }

    final previous = preserveResults ? state.value : null;
    state = preserveResults && previous != null
        ? AsyncData(
            AskSuggestions(
              hits: previous.hits,
              failedSources: previous.failedSources,
              partialSources: previous.partialSources,
              hasSearched: previous.hasSearched,
              notice: previous.notice,
              isRefreshing: true,
            ),
          )
        : const AsyncLoading();
    final requestedQuery = _latestQuery;
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(
        requestedQuery,
        generation,
        previousResults: previous,
      ),
    );
  }

  Future<void> _search(
    String query,
    int generation, {
    AskSuggestions? previousResults,
  }) async {
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
        !_sameCurrentScope(identity)) {
      return;
    }
    final sources = query.length > 100
        ? const KnowledgeSearchSources()
        : await searchKnowledgeSources(
            query,
            searchOrganisation: identity.organisationId == null
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
        !_sameCurrentScope(identity)) {
      return;
    }

    final hits = <AskKnowledgeHit>[];
    final privateById = {
      for (final item in sources.privateAccount)
        if (item['source_id'] is String &&
            (item['owner_uid'] == null ||
                item['owner_uid'] == identity.verifiedUid))
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
      if (result['owner_uid'] != null &&
          result['owner_uid'] != identity.verifiedUid) {
        continue;
      }
      final data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map)
          : const <String, dynamic>{};
      hits.add(
        AskKnowledgeHit(
          id: id,
          title: result['title'] as String? ?? '',
          source: 'Private',
          attribution: _attribution(result),
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
      if (result['accessible'] == false || result['is_accessible'] == false) {
        continue;
      }
      final data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map)
          : const <String, dynamic>{};
      hits.add(
        AskKnowledgeHit(
          id: id,
          title: result['title'] as String? ?? '',
          source: 'Group: ${result['group_name'] as String? ?? 'Group'}',
          attribution: _attribution(result),
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
    final errors = {...sources.failedSources};
    if (localFailed) errors.add('Local');
    if (previousResults != null) {
      for (final source in errors) {
        for (final oldHit in previousResults.hits.where(
          (hit) => _sourceName(hit.source) == source,
        )) {
          if (!hits.any((hit) => _scopeKey(hit) == _scopeKey(oldHit))) {
            hits.add(oldHit);
          }
        }
      }
    }
    final uniqueHits = <String, AskKnowledgeHit>{};
    for (final hit in hits) {
      uniqueHits.putIfAbsent(_scopeKey(hit), () => hit);
    }
    hits
      ..clear()
      ..addAll(uniqueHits.values);
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
    state = AsyncData(
      AskSuggestions(
        hits: hits.take(10).toList(),
        failedSources: errors,
        partialSources: sources.partialSources,
        hasSearched: true,
        isRefreshing: false,
        notice: query.length > 100
            ? 'Shorten the query to 100 characters to search other accessible '
                'Knowledge sources. Local Knowledge was searched.'
            : null,
      ),
    );
  }

  bool _sameCurrentScope(AskSearchIdentity identity) =>
      identity.sameScopeAs(ref.read(askSearchIdentityProvider));

  static String _sourceName(String source) {
    if (source.startsWith('Organisation:')) return 'Organisation';
    if (source.startsWith('Group:')) return 'Groups';
    return source;
  }

  static String _scopeKey(AskKnowledgeHit hit) =>
      '${_sourceName(hit.source)}:${hit.groupId ?? ''}:${hit.id}';

  static List<String> _attribution(Map<String, dynamic> result) => [
    if (result['department'] is Map &&
        (result['department'] as Map)['name'] is String)
      'Department: ${(result['department'] as Map)['name']}',
    if (result['team'] is Map && (result['team'] as Map)['name'] is String)
      'Team: ${(result['team'] as Map)['name']}',
  ];

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
