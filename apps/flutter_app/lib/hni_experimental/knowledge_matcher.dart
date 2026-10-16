/// HNI experimental knowledge matching: pure Dart, no network or AI dependency.
class HniKnowledgeSuggestion {
  final String id;
  final double score;
  final String reason;
  const HniKnowledgeSuggestion(this.id, this.score, this.reason);
}

class HniKnowledgeCandidate {
  final String id;
  final String question;
  const HniKnowledgeCandidate(this.id, this.question);
}

class HniKnowledgeMatcher {
  const HniKnowledgeMatcher();

  static final RegExp _terms = RegExp(r"[a-z0-9]+");
  static const Set<String> _noise = {
    'a', 'an', 'and', 'are', 'for', 'how', 'i', 'in', 'is', 'of',
    'on', 'or', 'the', 'to', 'what', 'when', 'where', 'with',
  };

  Set<String> _tokens(String value) => _terms
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .where((token) => token.length > 1 && !_noise.contains(token))
      .toSet();

  List<HniKnowledgeSuggestion> suggest(
    String query,
    Iterable<HniKnowledgeCandidate> authorisedCandidates, {
    double minimumScore = 0.2,
  }) {
    final requested = _tokens(query);
    if (requested.isEmpty) return const [];
    final results = <HniKnowledgeSuggestion>[];
    for (final candidate in authorisedCandidates) {
      final offered = _tokens(candidate.question);
      if (offered.isEmpty) continue;
      final overlap = requested.intersection(offered);
      if (overlap.isEmpty) continue;
      final score = overlap.length / requested.union(offered).length;
      if (score >= minimumScore) {
        results.add(HniKnowledgeSuggestion(
          candidate.id,
          score,
          'Shared terms: ${(overlap.toList()..sort()).join(', ')}',
        ));
      }
    }
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore == 0 ? a.id.compareTo(b.id) : byScore;
    });
    return List.unmodifiable(results);
  }
}
