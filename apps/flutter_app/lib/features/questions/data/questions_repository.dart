import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

final questionsRepositoryProvider = Provider<QuestionsRepository>((ref) {
  return QuestionsRepository(ref.watch(apiClientProvider));
});

class QuestionsRepository {
  const QuestionsRepository(this._client);

  final Dio _client;

  Future<List<DepartmentSummary>> listDepartments() async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/departments',
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
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/teams',
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
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/questions',
        queryParameters: {
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
    try {
      final response = await _client.post<List<dynamic>>(
        '/api/v1/questions/search',
        data: {'query': query, 'limit': limit, 'include_unanswered': true},
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
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/questions/$questionId',
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
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/questions',
        data: {
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
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/answers',
        data: {
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
    await _request(
      () => _client.patch<void>(
        '/api/v1/questions/$questionId',
        data: {
          'title': title,
          'body': body,
          'department_id': departmentId,
          'team_id': teamId,
        },
      ),
    );
  }

  Future<void> archiveQuestion(String questionId) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/archive',
      ),
    );
  }

  Future<void> resolve(String questionId, String answerId) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/resolve',
        data: {'answer_id': answerId},
      ),
    );
  }

  Future<void> reopen(String questionId) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/reopen',
      ),
    );
  }

  Future<void> react(String answerId, String reaction) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/answers/$answerId/reaction',
        data: {'reaction': reaction},
      ),
    );
  }

  Future<List<CommentDetail>> listComments(String questionId) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/questions/$questionId/comments',
      );
      return (response.data ?? const [])
          .map((item) => CommentDetail.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> createComment(String questionId, String body) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/questions/$questionId/comments',
        data: {
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
