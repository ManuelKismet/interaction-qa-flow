/// Read-only matching of current local Interact graphs, including collapsed
/// answer-owned branches. Picker/navigation IDs never replace graph IDs.
List<Map<String, dynamic>> searchLocalInteract(
  String query,
  List<Map<String, dynamic>> sessions,
) {
  final needle = query.toLowerCase().trim();
  if (needle.isEmpty) return const [];
  final terms = needle.split(RegExp(r'\s+')).where((term) => term.isNotEmpty);
  double score(Object? text) {
    if (text is! String || text.trim().isEmpty) return 0;
    final folded = text.toLowerCase();
    if (!terms.every(folded.contains)) return 0;
    if (folded.trim() == needle) return 1.9;
    if (folded.startsWith(needle)) return 1.7;
    return 1.5;
  }
  String snippet(String text) {
    final folded = text.toLowerCase();
    final positions = terms.map(folded.indexOf).where((index) => index >= 0);
    final start = folded.length != text.length || positions.isEmpty
        ? 0
        : (positions.reduce((a, b) => a < b ? a : b) - 50).clamp(0, text.length).toInt();
    final end = (start + 220).clamp(0, text.length).toInt();
    return '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}';
  }
  final hits = <Map<String, dynamic>>[];
  for (final session in sessions) {
    final id = session['id'];
    if (id is! String || id.isEmpty) continue;
    final metadata = <String, dynamic>{
      'id': id, 'session_id': id,
      'title': session['title'] as String? ?? 'Interact session',
      'source': 'Local', 'destination': 'personal',
      'kind': 'interact_session', 'match_method': 'keyword',
      'status': session['status'] as String? ?? 'Local session',
    };
    final titleScore = score(session['title']);
    if (titleScore > 0) {
      hits.add({...metadata, 'matched_in': 'session title',
        'snippet': snippet(session['title'] as String), 'relevance_score': titleScore});
    }
    final stack = <_SearchQuestion>[
      for (final question in (session['questions'] as List? ?? const []).reversed)
        if (question is Map<String, dynamic>) _SearchQuestion(question, null),
    ];
    final seen = <Map<String, dynamic>>{};
    while (stack.isNotEmpty) {
      final pending = stack.removeLast();
      final question = pending.question;
      if (!seen.add(question) || question['deleted_at'] != null) continue;
      String? participant = question['target_participant_id'] as String? ?? pending.participant;
      var relevance = score(question['text']);
      var text = question['text'] as String? ?? '';
      var matchedIn = pending.participant == null ? 'question' : 'follow-up';
      for (final answer in (question['answers'] as List? ?? const [])) {
        if (answer is! Map<String, dynamic>) continue;
        final answerScore = score(answer['body']);
        if (answerScore > relevance) {
          relevance = answerScore;
          text = answer['body'] as String;
          participant = answer['participant_id'] as String?;
          matchedIn = 'answer';
        }
        for (final child in (answer['follow_ups'] as List? ?? const []).reversed) {
          if (child is Map<String, dynamic>) {
            stack.add(_SearchQuestion(child, answer['participant_id'] as String?));
          }
        }
      }
      for (final child in (question['follow_ups'] as List? ?? const []).reversed) {
        if (child is Map<String, dynamic>) stack.add(_SearchQuestion(child, participant));
      }
      if (relevance > 0 && question['id'] is String) {
        hits.add({...metadata, 'question_id': question['id'],
          'participant_id': participant, 'matched_in': matchedIn,
          'snippet': snippet(text), 'relevance_score': relevance});
      }
    }
  }
  return hits;
}

class _SearchQuestion {
  const _SearchQuestion(this.question, this.participant);
  final Map<String, dynamic> question;
  final String? participant;
}
