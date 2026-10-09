import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/app.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/routing/app_router.dart';
import 'package:int_qa_flow/core/routing/session_deep_link.dart';

void main() {
  for (final route in [
    '/questions/question-123',
    '/guided/sessions/session-123?questionId=q1&participantId=p1',
    '/personal/interact/sessions/abc-1?questionId=q2',
    '/personal/questions?knowledgeItemId=k1',
    '/guest/groups?groupId=g1&entryId=e1',
  ]) {
    testWidgets('retains $route through authentication loading', (
      tester,
    ) async {
      var browserUri = Uri.parse('https://example.test/#$route');
      final container = ProviderContainer(
        overrides: [
          launchUriProvider.overrideWith((ref) => browserUri),
          authStateProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IntQaFlowApp(),
        ),
      );
      expect(find.text('Checking account'), findsOneWidget);
      // Model the URL reset caused by a temporary MaterialApp before auth ends.
      browserUri = Uri.parse('https://example.test/');
      final router = container.read(appRouterProvider('signed-in-user'));
      expect(router.routeInformationProvider.value.uri.toString(), route);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('preserves supported workspace routes and rejects unknown routes', () {
    for (final route in [
      '/',
      '/organisation',
      '/questions',
      '/guided',
      '/review-queue',
      '/admin',
      '/guest/groups',
      '/personal',
      '/personal/ask',
      '/personal/questions',
      '/personal/interact',
    ]) {
      expect(
        sessionDeepLinkInitialLocation(
          Uri.parse('https://example.test/#$route'),
        ),
        route,
      );
      expect(
        sessionDeepLinkInitialLocation(Uri.parse('https://example.test$route')),
        route,
      );
    }
    for (final fragment in [
      '/unknown',
      '//evil.test/questions/q',
      '/questions/q/extra',
    ]) {
      expect(
        sessionDeepLinkInitialLocation(
          Uri.parse('https://example.test/#$fragment'),
        ),
        '/',
      );
    }
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.test/guided/sessions/old#/questions/new'),
      ),
      '/questions/new',
    );
  });
  test('retains personal Interact session links in path and hash form', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.test/personal/interact/sessions/abc-1'),
      ),
      '/personal/interact/sessions/abc-1',
    );
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse(
          'https://intqaflow-dev.web.app/#/personal/interact/sessions/abc-1',
        ),
      ),
      '/personal/interact/sessions/abc-1',
    );
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse('https://example.test/personal/interact/sessions/a/b'),
      ),
      '/',
    );
  });

  test('retains a valid session deep link and query across initialization', () {
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse(
          'https://example.test/guided/sessions/session-123?tab=report',
        ),
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

  test(
    'retains unknown session identifiers for normal authorization handling',
    () {
      expect(
        sessionDeepLinkInitialLocation(
          Uri.parse('https://example.test/guided/sessions/unknown-id'),
        ),
        '/guided/sessions/unknown-id',
      );
    },
  );

  test(
    'retains unknown hash session identifiers for authorization handling',
    () {
      expect(
        sessionDeepLinkInitialLocation(
          Uri.parse(
            'https://intqaflow-dev.web.app/guided#/guided/sessions/unknown-id',
          ),
        ),
        '/guided/sessions/unknown-id',
      );
    },
  );

  test('rejects malformed sessions and preserves question detail routes', () {
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
      '/questions/question-123',
    );
    expect(
      sessionDeepLinkInitialLocation(
        Uri.parse(
          'https://intqaflow-dev.web.app/guided#/questions/question-123',
        ),
      ),
      '/questions/question-123',
    );
  });
}
