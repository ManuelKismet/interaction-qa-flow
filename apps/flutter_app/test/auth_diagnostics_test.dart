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
  _TestAuth({this.projectId = 'intqaflow-dev'});

  final String projectId;

  @override
  FirebaseApp get app => _TestFirebaseApp(projectId);

  @override
  User? get currentUser => _TestUser('test-user-uid');

  @override
  Stream<User?> authStateChanges() => Stream.value(_TestUser('test-user-uid'));
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
    diagnostics.accountLookupStarted();
    diagnostics.accountLookupCompleted('active');

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
    attempt.recordFirebaseSuccess(signedInUid: 'test-user-uid');
    diagnostics.observeAuthState(user: _TestUser('test-user-uid'));
    diagnostics.accountLookupStarted();
    diagnostics.accountLookupCompleted('active');
    diagnostics.membershipLookupStarted();
    diagnostics.membershipLookupCompleted(succeeded: true);

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

  test('auth and membership providers emit the staged lookup lifecycle', () async {
    final auth = _TestAuth();
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
    attempt.recordFirebaseSuccess(signedInUid: 'test-user-uid');

    final client = Dio(BaseOptions(baseUrl: 'http://localhost'));
    client.httpClientAdapter = _ResponseAdapter();
    final container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        authDiagnosticLoggerProvider.overrideWithValue(diagnostics),
        apiClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    expect(
      await container.read(accountMembershipStatusProvider.future),
      AccountMembershipStatus.active,
    );
    expect(
      (await container.read(currentMembershipProvider.future)).userId,
      'app-user',
    );

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
    diagnostics.accountLookupStarted();

    expect(diagnostics.hasActiveAttempt, isFalse);
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
