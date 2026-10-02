import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/routing/session_deep_link.dart';

void main() {
  test('retains a valid session deep link and query across initialization', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.test/guided/sessions/session-123?tab=report'),
      ),
      '/guided/sessions/session-123?tab=report',
    );
  });

  test('retains unknown session identifiers for normal authorization handling', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.test/guided/sessions/unknown-id'),
      ),
      '/guided/sessions/unknown-id',
    );
  });

  test('does not preserve unrelated or malformed deep links', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.test/guided/sessions/one/two'),
      ),
      '/',
    );
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.test/questions/question-123'),
      ),
      '/',
    );
  });
}
