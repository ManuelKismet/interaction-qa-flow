import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/auth/auth_diagnostics.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';

class _TestUser extends Fake implements User {
  _TestUser(this.uid);

  @override
  final String uid;

  @override
  bool get isAnonymous => false;
}

class _TestFirebaseApp extends Fake implements FirebaseApp {
  _TestFirebaseApp(this.projectId);

  final String projectId;

  @override
  String get name => 'test-app';

  @override
  FirebaseOptions get options => FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: projectId,
  );
}

class _TestAuth extends Fake implements FirebaseAuth {
  _TestAuth({
    this.projectId = 'intqaflow-dev',
    Stream<User?>? authStateStream,
  }) : _authStateStream = authStateStream;

  final String projectId;
  final Stream<User?>? _authStateStream;

  @override
  FirebaseApp get app => _TestFirebaseApp(projectId);

  @override
  User? get currentUser => _TestUser('test-user-uid');

  @override
  Stream<User?> authStateChanges() =>
      _authStateStream ?? Stream.value(_TestUser('test-user-uid'));
}

class _ResponseAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.path.endsWith('/account/state')
        ? '{"status":"active"}'
        : '{"user_id":"app-user","organisation_id":"org","email":"user@example.test","display_name":"User","role":"member"}';
    return ResponseBody.fromString(
      body,
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('diagnostics require explicit opt-in to a debug development build', () {
    expect(
      AuthDiagnosticLogger.isEnabledForBuild(
        debugBuild: false,
        optedIn: true,
        projectId: 'intqaflow-dev',
      ),
      isFalse,
    );
    expect(
      AuthDiagnosticLogger.isEnabledForBuild(
        debugBuild: true,
        optedIn: false,
        projectId: 'intqaflow-dev',
      ),
      isFalse,
    );
    expect(
      AuthDiagnosticLogger.isEnabledForBuild(
        debugBuild: true,
        optedIn: true,
        projectId: 'intqaflow-prod',
      ),
      isFalse,
    );
    expect(
      AuthDiagnosticLogger.isEnabledForBuild(
        debugBuild: true,
        optedIn: true,
        projectId: 'intqaflow-dev',
      ),
      isTrue,
    );
  });

  test('disabled diagnostics emit no events', () {
    final output = <String>[];
    final diagnostics = AuthDiagnosticLogger(
      enabled: false,
      sink: output.add,
    );

    expect(
      diagnostics.beginSignIn(
        auth: _TestAuth(),
        anonymousAtStart: false,
        registeredAtStart: false,
        emailPresent: true,
        passwordPresent: true,
      ),
      isNull,
    );
    diagnostics.observeAuthState(user: _TestUser('test-user-uid'));
    final lookup = diagnostics.beginAccountLookup(userId: 'test-user-uid');
    lookup?.complete('active');

    expect(output, isEmpty);
  });

  test('only one diagnostic sign-in attempt can be active at a time', () {
    final diagnostics = AuthDiagnosticLogger(
      enabled: true,
      sink: (_) {},
      attemptIdGenerator: () => 'single-attempt-id',
    );
    final first = diagnostics.beginSignIn(
      auth: _TestAuth(),
      anonymousAtStart: false,
      registeredAtStart: false,
      emailPresent: true,
      passwordPresent: true,
    )!;

    expect(diagnostics.hasActiveAttempt, isTrue);
    expect(
      diagnostics.beginSignIn(
        auth: _TestAuth(),
        anonymousAtStart: false,
        registeredAtStart: false,
        emailPresent: true,
        passwordPresent: true,
      ),
      isNull,
    );
    first.complete();
    expect(diagnostics.hasActiveAttempt, isFalse);
  });

  test('diagnostics never start for a non-development Firebase project', () {
    final diagnostics = AuthDiagnosticLogger(
      enabled: true,
      projectId: 'intqaflow-prod',
      sink: (_) {},
    );

    expect(diagnostics.enabled, isFalse);
    expect(
      diagnostics.beginSignIn(
        auth: _TestAuth(projectId: 'intqaflow-prod'),
        anonymousAtStart: false,
        registeredAtStart: false,
        emailPresent: true,
        passwordPresent: true,
      ),
      isNull,
    );
  });

  test('diagnostic lifecycle contains only allowlisted fields and values', () {
    final output = <String>[];
    final diagnostics = AuthDiagnosticLogger(
      enabled: true,
      appName: 'test-app',
      projectId: 'intqaflow-dev',
      buildId: 'test-build',
      sink: output.add,
      attemptIdGenerator: () => 'random-attempt-id',
    );
    final attempt = diagnostics.beginSignIn(
      auth: _TestAuth(),
      anonymousAtStart: true,
      registeredAtStart: false,
      emailPresent: true,
      passwordPresent: true,
    )!;
    attempt.record(AuthDiagnosticStage.firebaseCallStarted);
    diagnostics.observeAuthState(user: _TestUser('test-user-uid'));
    attempt.recordFirebaseSuccess(signedInUid: 'test-user-uid');
    final accountLookup = diagnostics.beginAccountLookup(
      userId: 'test-user-uid',
    )!;
    accountLookup.complete('active');
    final membershipLookup = diagnostics.beginMembershipLookup(
      userId: 'test-user-uid',
    )!;
    membershipLookup.complete('success');

    final events = output
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
    expect(
      events.map((event) => event['stage']),
      [
        'credentialsCaptured',
        'firebaseCallStarted',
        'firebaseCallSucceeded',
        'authStateObserved',
        'accountLookupStarted',
        'accountLookupCompleted',
        'membershipLookupStarted',
        'membershipLookupCompleted',
      ],
    );
    expect(events.first['appName'], 'test-app');
    expect(events.first['projectId'], 'intqaflow-dev');
    expect(events.first['buildId'], 'test-build');
    expect(events[4]['lookupOutcome'], isNull);
    expect(events[5]['lookupOutcome'], 'active');
    expect(events.last['lookupOutcome'], 'success');
    const allowedKeys = {
      'event',
      'attemptId',
      'operation',
      'stage',
      'stageTimestampUtc',
      'elapsedMs',
      'appName',
      'projectId',
      'buildId',
      'anonymousAtStart',
      'registeredAtStart',
      'emailPresent',
      'passwordPresent',
      'confirmationOutcome',
      'sanitizedExceptionCode',
      'anonymous',
      'registered',
      'lookupOutcome',
    };
    expect(
      events.every((event) => event.keys.every(allowedKeys.contains)),
      isTrue,
    );
    attempt.complete();
  });

  test(
    'provider lookups are attributed in either auth and SDK event order',
    () async {
      Future<List<Map<String, dynamic>>> runProviderLookups({
        required bool sdkCompletesFirst,
      }) async {
        const userId = 'test-user-uid';
        final authEvents = StreamController<User?>.broadcast();
        final auth = _TestAuth(authStateStream: authEvents.stream);
        final output = <String>[];
        final diagnostics = AuthDiagnosticLogger(
          enabled: true,
          appName: 'test-app',
          projectId: 'intqaflow-dev',
          buildId: 'test-build',
          sink: output.add,
          attemptIdGenerator: () => 'lookup-attempt-id',
        );
        final attempt = diagnostics.beginSignIn(
          auth: auth,
          anonymousAtStart: true,
          registeredAtStart: false,
          emailPresent: true,
          passwordPresent: true,
        )!;
        attempt.record(AuthDiagnosticStage.firebaseCallStarted);
        if (sdkCompletesFirst) {
          attempt.recordFirebaseSuccess(signedInUid: userId);
        }

        final client = Dio(BaseOptions(baseUrl: 'http://localhost'));
        client.httpClientAdapter = _ResponseAdapter();
        final container = ProviderContainer(
          overrides: [
            firebaseAuthProvider.overrideWithValue(auth),
            authDiagnosticLoggerProvider.overrideWithValue(diagnostics),
            apiClientProvider.overrideWithValue(client),
          ],
        );
        final authSubscription = container.listen(
          authStateProvider,
          (_, _) {},
          fireImmediately: true,
        );
        authEvents.add(_TestUser(userId));
        await container.read(authStateProvider.future);
        final accountSubscription = container.listen(
          accountMembershipStatusProvider,
          (_, _) {},
        );
        final membershipSubscription = container.listen(
          currentMembershipProvider,
          (_, _) {},
        );
        expect(
          await container.read(accountMembershipStatusProvider.future),
          AccountMembershipStatus.active,
        );
        expect(
          (await container.read(currentMembershipProvider.future)).userId,
          'app-user',
        );

        if (!sdkCompletesFirst) {
          final pendingStages = output
              .map((line) => jsonDecode(line)['stage'])
              .where(
                (stage) =>
                    stage == 'authStateObserved' ||
                    stage == 'accountLookupStarted' ||
                    stage == 'accountLookupCompleted' ||
                    stage == 'membershipLookupStarted' ||
                    stage == 'membershipLookupCompleted',
              );
          expect(pendingStages, isEmpty);
          attempt.recordFirebaseSuccess(signedInUid: userId);
        }

        final events = output
            .map((line) => jsonDecode(line) as Map<String, dynamic>)
            .toList();
        expect(
          events.map((event) => event['stage']),
          containsAllInOrder([
            'authStateObserved',
            'accountLookupStarted',
            'accountLookupCompleted',
            'membershipLookupStarted',
            'membershipLookupCompleted',
          ]),
        );
        expect(events.last['lookupOutcome'], 'success');
        final serializedEvents = jsonEncode(events);
        expect(serializedEvents, isNot(contains('app-user')));
        expect(serializedEvents, isNot(contains('user@example.test')));
        expect(serializedEvents, isNot(contains('test-user-uid')));
        authSubscription.close();
        accountSubscription.close();
        membershipSubscription.close();
        container.dispose();
        client.close();
        await authEvents.close();
        return events;
      }

      for (final sdkCompletesFirst in [false, true]) {
        final events = await runProviderLookups(
          sdkCompletesFirst: sdkCompletesFirst,
        );
        expect(
          events.map((event) => event['stage']),
          containsAllInOrder([
            'firebaseCallSucceeded',
            'authStateObserved',
            'accountLookupStarted',
            'accountLookupCompleted',
            'membershipLookupStarted',
            'membershipLookupCompleted',
          ]),
        );
        expect(events.last['lookupOutcome'], 'success');
      }
    },
  );

  test('late lookup response cannot complete or clear a newer attempt', () async {
    final output = <String>[];
    var nextAttempt = 0;
    final diagnostics = AuthDiagnosticLogger(
      enabled: true,
      projectId: 'intqaflow-dev',
      sink: output.add,
      attemptIdGenerator: () => 'attempt-${nextAttempt++}',
    );
    AuthDiagnosticAttempt startAttempt(String uid) {
      final attempt = diagnostics.beginSignIn(
        auth: _TestAuth(),
        anonymousAtStart: true,
        registeredAtStart: false,
        emailPresent: true,
        passwordPresent: true,
      )!;
      attempt.record(AuthDiagnosticStage.firebaseCallStarted);
      diagnostics.observeAuthState(user: _TestUser(uid));
      attempt.recordFirebaseSuccess(signedInUid: uid);
      return attempt;
    }

    final attemptA = startAttempt('user-a');
    final delayedResponse = Completer<String>();
    final lookupA = diagnostics.beginAccountLookup(userId: 'user-a')!;
    final lookupAFuture = delayedResponse.future.then(lookupA.complete);
    attemptA.complete();

    final attemptB = startAttempt('user-b');
    expect(
      diagnostics.beginAccountLookup(userId: 'unrelated-user'),
      isNull,
    );
    expect(diagnostics.hasActiveAttempt, isTrue);
    final lookupB = diagnostics.beginAccountLookup(userId: 'user-b')!;
    delayedResponse.complete('no_membership');
    await lookupAFuture;

    expect(diagnostics.hasActiveAttempt, isTrue);
    expect(
      output
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .where((event) => event['attemptId'] == 'attempt-1')
          .map((event) => event['lookupOutcome']),
      isNot(contains('no_membership')),
    );
    lookupB.complete('active');
    expect(diagnostics.hasActiveAttempt, isTrue);
    attemptB.complete();
  });

  test('a different UID transition clears the attempt before lookups', () {
    final output = <String>[];
    final diagnostics = AuthDiagnosticLogger(
      enabled: true,
      projectId: 'intqaflow-dev',
      sink: output.add,
    );
    final attempt = diagnostics.beginSignIn(
      auth: _TestAuth(),
      anonymousAtStart: true,
      registeredAtStart: false,
      emailPresent: true,
      passwordPresent: true,
    )!;
    attempt.record(AuthDiagnosticStage.firebaseCallStarted);
    diagnostics.observeAuthState(user: _TestUser('unexpected-uid'));
    attempt.recordFirebaseSuccess(signedInUid: 'expected-uid');
    final lookup = diagnostics.beginAccountLookup(userId: 'expected-uid');

    expect(diagnostics.hasActiveAttempt, isFalse);
    expect(lookup, isNull);
    expect(output, isNot(contains('unexpected-uid')));
    expect(output, isNot(contains('expected-uid')));
    expect(
      output.map((line) => jsonDecode(line)['stage']),
      isNot(contains('accountLookupStarted')),
    );
  });

  test('unknown Firebase exception codes collapse to other', () {
    expect(
      AuthDiagnosticLogger.sanitizeFirebaseCode(
        'auth/unrecognized-code?email=private@example.test',
      ),
      'other',
    );
  });

  test('unknown exception content is not emitted', () {
    final output = <String>[];
    final diagnostics = AuthDiagnosticLogger(
      enabled: true,
      projectId: 'intqaflow-dev',
      sink: output.add,
    );
    final attempt = diagnostics.beginSignIn(
      auth: _TestAuth(),
      anonymousAtStart: false,
      registeredAtStart: false,
      emailPresent: true,
      passwordPresent: true,
    )!;
    attempt.recordFirebaseFailure(
      'auth/unrecognized-code?email=private@example.test',
    );

    expect(output.last, contains('"sanitizedExceptionCode":"other"'));
    expect(output.last, isNot(contains('private@example.test')));
  });
}
