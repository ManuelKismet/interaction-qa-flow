import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';
import 'package:int_qa_flow/features/organisation/domain/organisation_models.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

typedef _GuidedScopeKey = (
  String?,
  bool?,
  (String?, String?, String?),
  String?,
);

final _guidedScopeKeyProvider =
    NotifierProvider<_GuidedScopeKeyController, _GuidedScopeKey>(
      _GuidedScopeKeyController.new,
    );

class _GuidedScopeKeyController extends Notifier<_GuidedScopeKey> {
  _GuidedScopeKey? _previous;

  @override
  bool updateShouldNotify(_GuidedScopeKey previous, _GuidedScopeKey next) =>
      previous != next;

  @override
  _GuidedScopeKey build() {
    final auth = ref.watch(authStateProvider);
    final membership = ref.watch(currentMembershipProvider);
    final authority = ref.watch(organisationProfileProvider);
    final uid = auth.value?.uid ?? (auth.isLoading ? _previous?.$1 : null);
    final anonymous = auth.value?.isAnonymous ??
        (auth.isLoading ? _previous?.$2 : null);
    final sameIdentity = uid != null &&
        _previous?.$1 == uid && _previous?.$2 == anonymous;
    // Keep the original namespace while authority is unknown; requests pause.
    final membershipKey = membership.hasValue
        ? _membershipKey(membership)
        : sameIdentity && (membership.isLoading || membership.hasError)
        ? _previous!.$3
        : (null, null, null);
    final authorityKey = authority.hasValue
        ? _authorityKey(authority)
        : sameIdentity && (authority.isLoading || authority.hasError)
        ? _previous!.$4
        : null;
    final key = (uid, anonymous, membershipKey, authorityKey);
    _previous = key;
    return key;
  }
}

final guidedRepositoryProvider = Provider<GuidedRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final scope = ref.watch(_guidedScopeKeyProvider);
  final uid = scope.$1;
  final membershipKey = scope.$3;
  final authorityKey = scope.$4;
  final token = CancelToken();
  ref.onDispose(() => token.cancel('Interact authority changed.'));
  return GuidedRepository(
    client,
    expectedUid: uid,
    cancelToken: token,
    isCurrent: () {
      if (!ref.mounted || uid == null || scope.$2 != false) return false;
      final auth = ref.read(authStateProvider);
      final user = auth.value;
      final membership = ref.read(currentMembershipProvider);
      final authority = ref.read(organisationProfileProvider);
      return user != null && auth.hasValue && !auth.isLoading && !auth.hasError &&
          membership.hasValue && !membership.isLoading && !membership.hasError &&
          authority.hasValue && !authority.isLoading && !authority.hasError &&
          user.uid == uid &&
          !user.isAnonymous &&
          _membershipKey(membership) == membershipKey &&
          _authorityKey(authority) == authorityKey &&
          authority.requireValue.userId == membership.requireValue.userId &&
          authority.requireValue.organisationId == membership.requireValue.organisationId;
    },
  );
});

(String?, String?, String?) _membershipKey(AsyncValue<ActiveMembership> state) =>
    (state.value?.userId, state.value?.organisationId, state.value?.role);

String? _authorityKey(AsyncValue<OrganisationProfile> state) {
  final profile = state.value;
  if (profile == null) return null;
  return jsonEncode([
    profile.organisationId,
    profile.userId,
    profile.role,
    profile.isOwner,
    profile.primaryDepartment,
    profile.teams.toList()..sort(),
    profile.permissions.toList()..sort(),
    profile.permissionScopes.map((scope) =>
        jsonEncode([scope.permission, scope.scopeType, scope.scopeId])).toList()..sort(),
    profile.assignmentManagers.toList()..sort(),
  ]);
}

class GuidedConflict implements Exception {
  const GuidedConflict();

  @override
  String toString() => 'This session changed. Review the server version before retrying.';
}

class GuidedImportResult {
  const GuidedImportResult({required this.session, required this.warnings});
  final GuidedSessionDetail session;
  final List<String> warnings;
}

class GuidedRepository {
  const GuidedRepository(
    this._client, {
    this.expectedUid,
    this.cancelToken,
    this.isCurrent,
  });

  final Dio _client;
  final String? expectedUid;
  final CancelToken? cancelToken;
  final bool Function()? isCurrent;

  Options get _options =>
      Options(extra: {'expectedFirebaseUid': ?expectedUid});

  void ensureCurrent() {
    if (isCurrent?.call() == false) {
      throw StateError('The account, organisation or permissions changed. Reopen Interact.');
    }
  }

  Future<T> _request<T>(Future<T> Function() operation) async {
    ensureCurrent();
    try {
      final result = await operation();
      ensureCurrent();
      return result;
    } on DioException catch (error) {
      ensureCurrent();
      if (error.response?.statusCode == 409) throw const GuidedConflict();
      throw ApiException.fromDio(error);
    }
  }

  Future<List<GuidedSessionSummary>> listSessions({String? status}) {
    return _request(() async {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/guided/sessions',
        queryParameters: {'status': ?status},
        options: _options,
        cancelToken: cancelToken,
      );
      return (response.data ?? const [])
          .map((item) => GuidedSessionSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<GuidedSessionDetail> getSession(
    String id, {
    String? participantId,
    GuidedViewMode mode = GuidedViewMode.allRelevant,
  }) {
    return _request(() async {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/guided/sessions/$id',
        queryParameters: {
          'participant_id': ?participantId,
          'view_mode': mode.apiValue,
        },
        options: _options,
        cancelToken: cancelToken,
      );
      return GuidedSessionDetail.fromJson(response.data!);
    });
  }

  Future<GuidedSessionDetail> createSession({
    required String title,
    String? owner,
    String? contextReference,
    String? departmentId,
    String? teamId,
    String visibility = 'private',
    String? templateId,
  }) {
    return _request(() async {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/guided/sessions',
        data: {
          'title': title,
          'owner_text': owner,
          'context_reference': contextReference,
          'department_id': departmentId,
          'team_id': teamId,
          'visibility': visibility,
          'template_id': templateId,
        },
        options: _options,
        cancelToken: cancelToken,
      );
      return GuidedSessionDetail.fromJson(response.data!);
    });
  }

  Future<void> transition(String sessionId, String action) {
    return _request(() async {
      await _client.post<void>('/api/v1/guided/sessions/$sessionId/$action', options: _options, cancelToken: cancelToken);
    });
  }

  Future<GuidedParticipant> addParticipant(String sessionId, String name) {
    return _request(() async {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/guided/sessions/$sessionId/participants',
        data: {'name': name},
        options: _options,
        cancelToken: cancelToken,
      );
      return GuidedParticipant.fromJson(response.data!);
    });
  }

  Future<void> addQuestion(
    String sessionId,
    String text, {
    required String scope,
    String? participantId,
  }) {
    return _request(() async {
      await _client.post<void>(
        '/api/v1/guided/sessions/$sessionId/questions',
        data: {
          'text': text,
          'scope': scope,
          'target_participant_id': participantId,
        },
        options: _options,
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> updateQuestion(String questionId, String text, {
    int? expectedRevision,
    void Function(int)? onRevision,
  }) {
    return _request(() async {
      final response = await _client.patch<Map<String, dynamic>>(
        '/api/v1/guided/questions/$questionId',
        data: {'text': text, 'expected_revision': ?expectedRevision},
        options: _options,
        cancelToken: cancelToken,
      );
      _acknowledgeRevision(response.data, onRevision);
    });
  }

  Future<void> setQuestionDeleted(String questionId, bool deleted) {
    return _request(() async {
      if (deleted) {
        await _client.delete<void>('/api/v1/guided/questions/$questionId', options: _options, cancelToken: cancelToken);
      } else {
        await _client.post<void>('/api/v1/guided/questions/$questionId/restore', options: _options, cancelToken: cancelToken);
      }
    });
  }

  Future<void> saveAnswer({
    required String questionId,
    required String participantId,
    required String body,
    bool branchesCollapsed = false,
    int? expectedRevision,
    void Function(int)? onRevision,
  }) {
    return _request(() async {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/guided/questions/$questionId/answers',
        data: {
          'participant_id': participantId,
          'body': body,
          'branches_collapsed': branchesCollapsed,
          'expected_revision': ?expectedRevision,
        },
        options: _options,
        cancelToken: cancelToken,
      );
      _acknowledgeRevision(response.data, onRevision);
    });
  }

  Future<void> updateAnswer(
    String answerId, {
    String? body,
    bool? branchesCollapsed,
    int? expectedRevision,
    void Function(int)? onRevision,
  }) {
    return _request(() async {
      final response = await _client.patch<Map<String, dynamic>>(
        '/api/v1/guided/answers/$answerId',
        data: {
          'body': ?body,
          'branches_collapsed': ?branchesCollapsed,
          'expected_revision': ?expectedRevision,
        },
        options: _options,
        cancelToken: cancelToken,
      );
      _acknowledgeRevision(response.data, onRevision);
    });
  }

  void _acknowledgeRevision(
    Map<String, dynamic>? response,
    void Function(int)? onRevision,
  ) {
    ensureCurrent();
    final revision = response?['session_revision'];
    if (revision is int && revision >= 1) onRevision?.call(revision);
  }

  Future<void> addFollowUp(String answerId, String text) {
    return _request(() async {
      await _client.post<void>(
        '/api/v1/guided/answers/$answerId/follow-ups',
        data: {'text': text},
        options: _options,
        cancelToken: cancelToken,
      );
    });
  }

  Future<List<GuidedTemplate>> listTemplates() {
    return _request(() async {
      final response = await _client.get<List<dynamic>>('/api/v1/guided/templates', options: _options, cancelToken: cancelToken);
      return (response.data ?? const [])
          .map((item) => GuidedTemplate.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> createTemplate(String name, List<String> questions) {
    return _request(() async {
      await _client.post<void>(
        '/api/v1/guided/templates',
        data: {
          'name': name,
          'questions': [
            for (final (index, text) in questions.indexed)
              {'text': text, 'scope': 'shared', 'order_index': index},
          ],
        },
        options: _options,
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> versionTemplate(String id, List<GuidedTemplateQuestion> questions) {
    return _request(() async {
      await _client.post<void>(
        '/api/v1/guided/templates/$id/versions',
        data: {
          'questions': [
            for (final question in questions)
              {
                'text': question.text,
                'scope': question.scope,
                'order_index': question.orderIndex,
                'participant_reference': question.participantReference,
                'reference': question.id,
                'parent_reference': question.parentTemplateQuestionId,
              },
          ],
        },
        options: _options,
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> archiveTemplate(String id) {
    return _request(() async {
      await _client.post<void>('/api/v1/guided/templates/$id/archive', options: _options, cancelToken: cancelToken);
    });
  }

  Future<void> restoreTemplate(String id) {
    return _request(() async {
      await _client.post<void>('/api/v1/guided/templates/$id/restore', options: _options, cancelToken: cancelToken);
    });
  }

  Future<void> duplicateTemplate(String id) {
    return _request(() async {
      await _client.post<void>('/api/v1/guided/templates/$id/duplicate', options: _options, cancelToken: cancelToken);
    });
  }

  Future<String> exportTemplates() {
    return _request(() async {
      final response = await _client.get<String>(
        '/api/v1/guided/templates/export/all',
        options: _options.copyWith(responseType: ResponseType.plain),
        cancelToken: cancelToken,
      );
      return response.data ?? '';
    });
  }

  Future<void> importTemplates(String jsonText) {
    return _request(() async {
      await _client.post<void>(
        '/api/v1/guided/templates/import',
        data: {'payload': jsonDecode(jsonText)},
        options: _options,
        cancelToken: cancelToken,
      );
    });
  }

  Future<GuidedImportResult> importLegacy(String jsonText) {
    return _request(() async {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/guided/import/legacy',
        data: {'payload': jsonDecode(jsonText)},
        options: _options,
        cancelToken: cancelToken,
      );
      return GuidedImportResult(
        session: GuidedSessionDetail.fromJson(response.data!['session'] as Map<String, dynamic>),
        warnings: (response.data!['warnings'] as List<dynamic>? ?? const []).cast<String>(),
      );
    });
  }

  Future<String> exportSession(String sessionId, String format) {
    return _request(() async {
      final response = await _client.get<String>(
        '/api/v1/guided/sessions/$sessionId/export/$format',
        options: _options.copyWith(responseType: ResponseType.plain),
        cancelToken: cancelToken,
      );
      return response.data ?? '';
    });
  }

  Future<List<GuidedRevision>> revisions(String sessionId) {
    return _request(() async {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/guided/sessions/$sessionId/revisions',
        options: _options,
        cancelToken: cancelToken,
      );
      return (response.data ?? const [])
          .map((item) => GuidedRevision.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<SemanticSearchResult>> searchKnowledge(String questionId) {
    return _request(() async {
      final response = await _client.post<List<dynamic>>(
        '/api/v1/guided/questions/$questionId/knowledge-search',
        data: {'limit': 5},
        options: _options,
        cancelToken: cancelToken,
      );
      return (response.data ?? const [])
          .map((item) => SemanticSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> proposeKnowledge(GuidedQuestion question, GuidedAnswer answer) {
    return _request(() async {
      await _client.post<void>(
        '/api/v1/guided/knowledge-proposals',
        data: {
          'guided_question_id': question.id,
          'guided_answer_id': answer.id,
        },
        options: _options,
        cancelToken: cancelToken,
      );
    });
  }

  Future<List<KnowledgeProposal>> listKnowledgeProposals() {
    return _request(() async {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/guided/knowledge-proposals',
        options: _options,
        cancelToken: cancelToken,
      );
      return (response.data ?? const [])
          .map((item) => KnowledgeProposal.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<SemanticSearchResult>> proposalDuplicates(String proposalId) {
    return _request(() async {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/guided/knowledge-proposals/$proposalId/duplicates',
        options: _options,
        cancelToken: cancelToken,
      );
      return (response.data ?? const [])
          .map((item) => SemanticSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> decideKnowledgeProposal(
    String proposalId,
    String action, {
    String? existingQuestionId,
  }) {
    return _request(() async {
      await _client.post<void>(
        '/api/v1/guided/knowledge-proposals/$proposalId',
        data: {
          'action': action,
          'existing_question_id': existingQuestionId,
        },
        options: _options,
        cancelToken: cancelToken,
      );
    });
  }
}