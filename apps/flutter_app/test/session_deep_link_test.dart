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

  test('retains hosted hash session routes and their query parameters', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse(
          'https://intqaflow-dev.web.app/guided#/guided/sessions/session-123?tab=report',
        ),
      ),
      '/guided/sessions/session-123?tab=report',
    );
  });

  test('supports session path URLs with query parameters', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse(
          'https://example.test/guided/sessions/session-123?tab=report',
        ),
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

  test('retains unknown hash session identifiers for authorization handling', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse(
          'https://intqaflow-dev.web.app/guided#/guided/sessions/unknown-id',
        ),
      ),
      '/guided/sessions/unknown-id',
    );
  });

  test('does not preserve unrelated or malformed path or hash routes', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.test/guided/sessions/one/two'),
      ),
      '/',
    );
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse(
          'https://intqaflow-dev.web.app/guided#/guided/sessions/one/two',
        ),
      ),
      '/',
    );
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.test/questions/question-123'),
      ),
      '/',
    );
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse(
          'https://intqaflow-dev.web.app/guided#/questions/question-123',
        ),
      ),
      '/',
    );
  });
}
