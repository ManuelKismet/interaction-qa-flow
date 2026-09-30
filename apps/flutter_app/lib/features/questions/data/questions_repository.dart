import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/core/config/app_config.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

final questionsRepositoryProvider = Provider<QuestionsRepository>((ref) {
  return QuestionsRepository(ref.watch(apiClientProvider));
});

class QuestionsRepository {
  const QuestionsRepository(this._client);

  final Dio _client;

  Map<String, String> get _identity => {
    'organisation_id': AppConfig.developmentOrganisationId,
    'user_id': AppConfig.developmentUserId,
  };

  void _requireIdentity() {
    if (AppConfig.developmentOrganisationId.isEmpty ||
        AppConfig.developmentUserId.isEmpty) {
      throw const ApiException('Development identity is not configured.');
    }
  }

  Future<List<DepartmentSummary>> listDepartments() async {
    _requireIdentity();
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/departments',
        queryParameters: {
          'organisation_id': AppConfig.developmentOrganisationId,
        },
      );
      return (response.data ?? const [])
          .map(
            (item) => DepartmentSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<TeamSummary>> listTeams() async {
    _requireIdentity();
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/teams',
        options: Options(
          headers: {
            'X-Organisation-ID': AppConfig.developmentOrganisationId,
            'X-User-ID': AppConfig.developmentUserId,
          },
        ),
      );
      return (response.data ?? const [])
          .map((item) => TeamSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<QuestionSummary>> listQuestions(
    String? status, {
    String? departmentId,
    String? teamId,
  }) async {
    _requireIdentity();
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/questions',
        queryParameters: {
          'organisation_id': AppConfig.developmentOrganisationId,
          'status': ?status,
          'department_id': ?departmentId,
          'team_id': ?teamId,
        },
      );
      return (response.data ?? const [])
          .map((item) => QuestionSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<SemanticSearchResult>> searchQuestions(
    String query, {
    int limit = 5,
  }) async {
    _requireIdentity();
    try {
      final response = await _client.post<List<dynamic>>(
        '/api/v1/questions/search',
        data: {'query': query, 'limit': limit, 'include_unanswered': true},
        options: Options(
          headers: {
            'X-Organisation-ID': AppConfig.developmentOrganisationId,
            'X-User-ID': AppConfig.developmentUserId,
          },
        ),
      );
      return (response.data ?? const [])
          .map(
            (item) =>
                SemanticSearchResult.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<QuestionDetail> getQuestion(String questionId) async {
    _requireIdentity();
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/questions/$questionId',
        queryParameters: {
          'organisation_id': AppConfig.developmentOrganisationId,
        },
      );
      return QuestionDetail.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<String> createQuestion({
    required String title,
    String? body,
    String? departmentId,
    String? teamId,
  }) async {
    _requireIdentity();
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/questions',
        data: {
          'organisation_id': AppConfig.developmentOrganisationId,
          'author_id': AppConfig.developmentUserId,
          'title': title,
          if (body != null && body.isNotEmpty) 'body': body,
          'department_id': ?departmentId,
          'team_id': ?teamId,
        },
      );
      return response.data!['id'] as String;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> createAnswer(String questionId, String body) async {
    _requireIdentity();
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/answers',
        data: {
          'organisation_id': AppConfig.developmentOrganisationId,
          'author_id': AppConfig.developmentUserId,
          'body': body,
        },
      ),
    );
  }

  Future<void> updateQuestion(
    String questionId, {
    required String title,
    String? body,
    String? departmentId,
    String? teamId,
  }) async {
    _requireIdentity();
    await _request(
      () => _client.patch<void>(
        '/api/v1/questions/$questionId',
        data: {
          ..._identity,
          'title': title,
          'body': body,
          'department_id': departmentId,
          'team_id': teamId,
        },
      ),
    );
  }

  Future<void> archiveQuestion(String questionId) async {
    _requireIdentity();
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/archive',
        data: _identity,
      ),
    );
  }

  Future<void> resolve(String questionId, String answerId) async {
    _requireIdentity();
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/resolve',
        data: {..._identity, 'answer_id': answerId},
      ),
    );
  }

  Future<void> reopen(String questionId) async {
    _requireIdentity();
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/reopen',
        data: _identity,
      ),
    );
  }

  Future<void> react(String answerId, String reaction) async {
    _requireIdentity();
    await _request(
      () => _client.post<void>(
        '/api/v1/answers/$answerId/reaction',
        data: {..._identity, 'reaction': reaction},
      ),
    );
  }

  Future<List<CommentDetail>> listComments(String questionId) async {
    _requireIdentity();
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/questions/$questionId/comments',
        queryParameters: {
          'organisation_id': AppConfig.developmentOrganisationId,
        },
      );
      return (response.data ?? const [])
          .map((item) => CommentDetail.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> createComment(String questionId, String body) async {
    _requireIdentity();
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/comments',
        data: {
          'organisation_id': AppConfig.developmentOrganisationId,
          'author_id': AppConfig.developmentUserId,
          'body': body,
        },
      ),
    );
  }

  Future<void> _request(Future<void> Function() operation) async {
    try {
      await operation();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
