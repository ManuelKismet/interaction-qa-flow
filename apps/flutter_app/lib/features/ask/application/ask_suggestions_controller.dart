import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

final askSuggestionsProvider = AsyncNotifierProvider.autoDispose<
    AskSuggestionsController, List<SemanticSearchResult>>(
  AskSuggestionsController.new,
);

class AskSuggestionsController
  extends AsyncNotifier<List<SemanticSearchResult>> {
  Timer? _debounce;
  String _latestQuery = '';

  @override
  Future<List<SemanticSearchResult>> build() async {
    ref.onDispose(() => _debounce?.cancel());
    return const [];
  }

  void queryChanged(String query) {
    _debounce?.cancel();
    _latestQuery = query.trim();
    if (_latestQuery.length < 3) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    final requestedQuery = _latestQuery;
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(requestedQuery),
    );
  }

  Future<void> _search(String query) async {
    final result = await AsyncValue.guard(
      () => ref.read(questionsRepositoryProvider).searchQuestions(query),
    );
    if (_latestQuery == query) state = result;
  }
}