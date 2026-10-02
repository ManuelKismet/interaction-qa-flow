import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/features/governance/domain/governance_models.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

final governanceRepositoryProvider = Provider<GovernanceRepository>((ref) {
  return GovernanceRepository(ref.watch(apiClientProvider));
});

class GovernanceRepository {
  const GovernanceRepository(this._client);

  final Dio _client;

  Future<void> verify(String answerId, {int? reviewDays}) => _mutate(
        '/api/v1/answers/$answerId/verify',
        {'review_days': ?reviewDays},
      );

  Future<void> unverify(String answerId) =>
      _mutate('/api/v1/answers/$answerId/unverify', const {});

  Future<void> review(String answerId, {int? reviewDays}) => _mutate(
        '/api/v1/answers/$answerId/review',
        {'review_days': ?reviewDays},
      );

  Future<void> challenge({
    required String answerId,
    required String type,
    required String reason,
    String? suggestedAnswer,
  }) =>
      _mutate('/api/v1/answers/$answerId/challenges', {
        'type': type,
        'reason': reason,
        if (suggestedAnswer != null && suggestedAnswer.isNotEmpty)
          'suggested_answer': suggestedAnswer,
      });

  Future<List<AnswerChallenge>> challenges(String answerId) => _list(
        '/api/v1/answers/$answerId/challenges',
        AnswerChallenge.fromJson,
      );

  Future<List<AnswerVersion>> versions(String answerId) => _list(
        '/api/v1/answers/$answerId/versions',
        AnswerVersion.fromJson,
      );

  Future<void> decideChallenge(
    String challengeId, {
    required bool accept,
    String? reviewerNote,
    String? replacementBody,
  }) =>
      _mutate(
        '/api/v1/challenges/$challengeId/${accept ? 'accept' : 'reject'}',
        {
          if (reviewerNote != null && reviewerNote.isNotEmpty)
            'reviewer_note': reviewerNote,
          if (replacementBody != null && replacementBody.isNotEmpty)
            'replacement_body': replacementBody,
        },
      );

  Future<List<ReviewQueueItem>> reviewQueue({
    String? departmentId,
    String? type,
    String? status,
  }) =>
      _list(
        '/api/v1/review-queue',
        ReviewQueueItem.fromJson,
        query: {
          'department_id': ?departmentId,
          'type': ?type,
          'status': ?status,
        },
      );

  Future<List<DepartmentAnswerOwner>> departmentOwners() => _list(
        '/api/v1/department-answer-owners',
        DepartmentAnswerOwner.fromJson,
      );

  Future<void> assignOwner(String departmentId, String userId) => _mutate(
        '/api/v1/departments/$departmentId/answer-owners',
        {'user_id': userId},
      );

  Future<void> removeOwner(String departmentId, String userId) async {
    try {
      await _client.delete<void>(
        '/api/v1/departments/$departmentId/answer-owners/$userId',
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> createTeam({
    required String name,
    String? departmentId,
    String? description,
  }) => _mutate('/api/v1/teams', {
        'name': name,
        'department_id': ?departmentId,
        if (description != null && description.isNotEmpty)
          'description': description,
      });

  Future<List<TeamMembership>> teamMembers(String teamId) => _list(
        '/api/v1/teams/$teamId/members',
        TeamMembership.fromJson,
      );

  Future<void> addTeamMember(String teamId, String userId) => _mutate(
        '/api/v1/teams/$teamId/members',
        {'user_id': userId},
      );

  Future<void> removeTeamMember(String teamId, String userId) async {
    try {
      await _client.delete<void>(
        '/api/v1/teams/$teamId/members/$userId',
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<SemanticSearchResult>> duplicateCandidates(String questionId) =>
      _list(
        '/api/v1/questions/$questionId/duplicate-candidates',
        SemanticSearchResult.fromJson,
      );

  Future<void> merge({
    required String canonicalQuestionId,
    required List<String> duplicateQuestionIds,
    required String reason,
    String? canonicalAnswerId,
  }) =>
      _mutate('/api/v1/questions/$canonicalQuestionId/merge', {
        'duplicate_question_ids': duplicateQuestionIds,
        'reason': reason,
        'canonical_answer_id': ?canonicalAnswerId,
      });

  Future<void> unmerge(String questionId, String reason) => _mutate(
        '/api/v1/questions/$questionId/unmerge',
        {'reason': reason},
      );

  Future<void> suggestDuplicate({
    required String questionId,
    required String canonicalQuestionId,
    String? reason,
  }) =>
      _mutate('/api/v1/questions/$questionId/duplicate-suggestions', {
        'suggested_canonical_question_id': canonicalQuestionId,
        'reason': ?reason,
      });

  Future<void> decideDuplicateSuggestion(
    String suggestionId, {
    required bool accept,
    String? reason,
    String? canonicalAnswerId,
  }) =>
      _mutate(
        '/api/v1/duplicate-suggestions/$suggestionId/${accept ? 'accept' : 'reject'}',
        {
          'reason': ?reason,
          'canonical_answer_id': ?canonicalAnswerId,
        },
      );

  Future<void> _mutate(String path, Map<String, dynamic> data) async {
    try {
      await _client.post<void>(path, data: data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _client.get<List<dynamic>>(
        path,
        queryParameters: query,
      );
      return (response.data ?? const [])
          .map((item) => parse(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}