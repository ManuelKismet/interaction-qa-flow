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
  int _queryGeneration = 0;

  @override
  Future<List<SemanticSearchResult>> build() async {
    ref.onDispose(() {
      _debounce?.cancel();
      _queryGeneration++;
    });
    return const [];
  }

  void queryChanged(String query) {
    _debounce?.cancel();
    final generation = ++_queryGeneration;
    _latestQuery = query.trim();
    if (_latestQuery.length < 3) {
      state = const AsyncData([]);
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
    final result = await AsyncValue.guard(
      () => ref.read(questionsRepositoryProvider).searchQuestions(query),
    );
    if (_queryGeneration == generation && _latestQuery == query) {
      state = result;
    }
  }
}