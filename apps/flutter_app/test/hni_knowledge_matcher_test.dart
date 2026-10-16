import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/hni_experimental/knowledge_matcher.dart';

void main() {
  const matcher = HniKnowledgeMatcher();
  test('ranks relevant knowledge and explains shared terms', () {
    final results = matcher.suggest('reset account password', [
      const HniKnowledgeCandidate('other', 'order office chairs'),
      const HniKnowledgeCandidate('relevant', 'reset account password'),
      const HniKnowledgeCandidate('partial', 'reset account credentials'),
    ]);
    expect(results.map((e) => e.id), ['relevant', 'partial']);
    expect(results.first.score, 1);
    expect(results.first.reason, contains('account'));
  });
  test('blank queries yield no suggestions', () {
    expect(matcher.suggest('', [const HniKnowledgeCandidate('a', 'anything')]), isEmpty);
  });
  test('does not access knowledge outside supplied authorised candidates', () {
    expect(matcher.suggest('private payroll', []), isEmpty);
  });
}
