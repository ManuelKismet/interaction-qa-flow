import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

enum QuestionFilter {
  open('Open', 'open'),
  resolved('Resolved', 'resolved'),
  all('All', null);

  const QuestionFilter(this.label, this.apiValue);

  final String label;
  final String? apiValue;
}

class QuestionFilterController extends Notifier<QuestionFilter> {
  @override
  QuestionFilter build() => QuestionFilter.open;

  void select(QuestionFilter filter) => state = filter;
}

final questionFilterProvider =
    NotifierProvider<QuestionFilterController, QuestionFilter>(
      QuestionFilterController.new,
    );

typedef QuestionScopeFilter = ({String? departmentId, String? teamId});

class QuestionScopeFilterController extends Notifier<QuestionScopeFilter> {
  @override
  QuestionScopeFilter build() => (departmentId: null, teamId: null);

  void select({String? departmentId, String? teamId}) =>
      state = (departmentId: departmentId, teamId: teamId);
}

final questionScopeFilterProvider =
    NotifierProvider<QuestionScopeFilterController, QuestionScopeFilter>(
      QuestionScopeFilterController.new,
    );

final questionsProvider = FutureProvider.autoDispose<List<QuestionSummary>>((
  ref,
) {
  final filter = ref.watch(questionFilterProvider);
  final scope = ref.watch(questionScopeFilterProvider);
  final repository = ref.watch(questionsRepositoryProvider);
  if (filter == QuestionFilter.open) {
    return Future.wait([
      repository.listQuestions(
        'open',
        departmentId: scope.departmentId,
        teamId: scope.teamId,
      ),
      repository.listQuestions(
        'answered',
        departmentId: scope.departmentId,
        teamId: scope.teamId,
      ),
      repository.listQuestions(
        'under_review',
        departmentId: scope.departmentId,
        teamId: scope.teamId,
      ),
    ]).then((groups) {
      final questions = groups.expand((group) => group).toList()
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return questions;
    });
  }
  return repository.listQuestions(
    filter.apiValue,
    departmentId: scope.departmentId,
    teamId: scope.teamId,
  );
});

final questionDetailProvider = FutureProvider.autoDispose
    .family<QuestionDetail, String>((ref, questionId) {
      return ref.watch(questionsRepositoryProvider).getQuestion(questionId);
    }, retry: _retryQuestionLoad);

Duration? _retryQuestionLoad(int count, Object error) {
  if (error is ApiException &&
      (error.statusCode == 403 || error.statusCode == 404))
    return null;
  return ProviderContainer.defaultRetry(count, error);
}

final questionChangeRequestsProvider =
    FutureProvider.autoDispose<List<QuestionChangeRequest>>((ref) {
      return ref.watch(questionsRepositoryProvider).listChangeRequests();
    });

final commentsProvider = FutureProvider.autoDispose
    .family<List<CommentDetail>, String>((ref, questionId) {
      return ref.watch(questionsRepositoryProvider).listComments(questionId);
    });
