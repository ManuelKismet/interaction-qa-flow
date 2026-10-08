import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

final guidedRepositoryProvider = Provider<GuidedRepository>((ref) {
  return GuidedRepository(ref.watch(apiClientProvider));
});

class GuidedRepository {
  const GuidedRepository(this._client);

  final Dio _client;

  Options get _options => Options();

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<GuidedSessionSummary>> listSessions({String? status}) {
    return _request(() async {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/guided/sessions',
        queryParameters: {'status': ?status},
        options: _options,
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
      );
      return GuidedSessionDetail.fromJson(response.data!);
    });
  }

  Future<void> transition(String sessionId, String action) {
    return _request(() async {
      await _client.post<void>('/api/v1/guided/sessions/$sessionId/$action', options: _options);
    });
  }

  Future<GuidedParticipant> addParticipant(String sessionId, String name) {
    return _request(() async {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/guided/sessions/$sessionId/participants',
        data: {'name': name},
        options: _options,
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
      );
    });
  }

  Future<void> updateQuestion(String questionId, String text) {
    return _request(() async {
      await _client.patch<void>(
        '/api/v1/guided/questions/$questionId',
        data: {'text': text},
        options: _options,
      );
    });
  }

  Future<void> setQuestionDeleted(String questionId, bool deleted) {
    return _request(() async {
      if (deleted) {
        await _client.delete<void>('/api/v1/guided/questions/$questionId', options: _options);
      } else {
        await _client.post<void>('/api/v1/guided/questions/$questionId/restore', options: _options);
      }
    });
  }

  Future<void> saveAnswer({
    required String questionId,
    required String participantId,
    required String body,
    bool branchesCollapsed = false,
  }) {
    return _request(() async {
      await _client.post<void>(
        '/api/v1/guided/questions/$questionId/answers',
        data: {
          'participant_id': participantId,
          'body': body,
          'branches_collapsed': branchesCollapsed,
        },
        options: _options,
      );
    });
  }

  Future<void> updateAnswer(
    String answerId, {
    String? body,
    bool? branchesCollapsed,
  }) {
    return _request(() async {
      await _client.patch<void>(
        '/api/v1/guided/answers/$answerId',
        data: {
          'body': ?body,
          'branches_collapsed': ?branchesCollapsed,
        },
        options: _options,
      );
    });
  }

  Future<void> addFollowUp(String answerId, String text) {
    return _request(() async {
      await _client.post<void>(
        '/api/v1/guided/answers/$answerId/follow-ups',
        data: {'text': text},
        options: _options,
      );
    });
  }

  Future<List<GuidedTemplate>> listTemplates() {
    return _request(() async {
      final response = await _client.get<List<dynamic>>('/api/v1/guided/templates', options: _options);
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
      );
    });
  }

  Future<void> archiveTemplate(String id) {
    return _request(() async {
      await _client.post<void>('/api/v1/guided/templates/$id/archive', options: _options);
    });
  }

  Future<void> duplicateTemplate(String id) {
    return _request(() async {
      await _client.post<void>('/api/v1/guided/templates/$id/duplicate', options: _options);
    });
  }

  Future<String> exportTemplates() {
    return _request(() async {
      final response = await _client.get<String>(
        '/api/v1/guided/templates/export/all',
        options: _options.copyWith(responseType: ResponseType.plain),
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
      );
    });
  }

  Future<GuidedSessionDetail> importLegacy(String jsonText) {
    return _request(() async {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/guided/import/legacy',
        data: {'payload': jsonDecode(jsonText)},
        options: _options,
      );
      return GuidedSessionDetail.fromJson(response.data!['session'] as Map<String, dynamic>);
    });
  }

  Future<String> exportSession(String sessionId, String format) {
    return _request(() async {
      final response = await _client.get<String>(
        '/api/v1/guided/sessions/$sessionId/export/$format',
        options: _options.copyWith(responseType: ResponseType.plain),
      );
      return response.data ?? '';
    });
  }

  Future<List<GuidedRevision>> revisions(String sessionId) {
    return _request(() async {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/guided/sessions/$sessionId/revisions',
        options: _options,
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
      );
    });
  }

  Future<List<KnowledgeProposal>> listKnowledgeProposals() {
    return _request(() async {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/guided/knowledge-proposals',
        options: _options,
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
      );
    });
  }
}