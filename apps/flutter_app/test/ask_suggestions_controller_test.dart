import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/ask/application/ask_suggestions_controller.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

class _PendingQuestionsRepository extends QuestionsRepository {
  _PendingQuestionsRepository() : super(Dio());

  final requests = <Completer<List<SemanticSearchResult>>>[];

  @override
  Future<List<SemanticSearchResult>> searchQuestions(
    String query, {
    int limit = 5,
  }) {
    final request = Completer<List<SemanticSearchResult>>();
    requests.add(request);
    return request.future;
  }
}

SemanticSearchResult _result(String id) => SemanticSearchResult(
      questionId: id,
      title: id,
      acceptedAnswerBody: null,
      similarity: 0,
      confidence: 'low_confidence',
      answerStatus: null,
      answerId: null,
      challengeCount: 0,
      hasOpenChallenge: false,
      canonicalQuestionId: id,
      canonicalTitle: id,
      matchedQuestionId: id,
      matchedQuestionIds: [id],
      matchedText: id,
      matchSource: 'canonical',
      matchMethod: 'keyword',
    );

void main() {
  test('ignores an older response for a repeated query', () async {
    final repository = _PendingQuestionsRepository();
    final container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(askSuggestionsProvider, (_, _) {});
    final controller = container.read(askSuggestionsProvider.notifier);

    controller.queryChanged('password');
    await Future<void>.delayed(const Duration(milliseconds: 360));
    expect(repository.requests, hasLength(1));

    controller.queryChanged('password');
    await Future<void>.delayed(const Duration(milliseconds: 360));
    expect(repository.requests, hasLength(2));

    repository.requests[1].complete([_result('new')]);
    await Future<void>.delayed(Duration.zero);
    repository.requests[0].complete([_result('old')]);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(askSuggestionsProvider).value!.single.questionId,
      'new',
    );
  });
}
