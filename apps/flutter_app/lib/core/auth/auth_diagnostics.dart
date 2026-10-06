import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/config/app_config.dart';

enum AuthDiagnosticStage {
  credentialsCaptured,
  confirmationPrompted,
  confirmationCompleted,
  firebaseCallStarted,
  firebaseCallSucceeded,
  firebaseCallFailed,
  authStateObserved,
  accountLookupStarted,
  accountLookupCompleted,
  membershipLookupStarted,
  membershipLookupCompleted,
}

enum AuthDiagnosticConfirmationOutcome {
  notRequired,
  confirmed,
  cancelled,
  blocked,
  identityChanged,
}

class AuthDiagnosticLogger {
  AuthDiagnosticLogger({
    bool? enabled,
    String? appName,
    String? projectId,
    String? buildId,
    void Function(String message)? sink,
    String Function()? attemptIdGenerator,
    DateTime Function()? clock,
  }) : enabled =
           isEnabledForBuild(
             debugBuild: kDebugMode,
             optedIn:
                 enabled ?? const bool.fromEnvironment('AUTH_DIAGNOSTICS'),
             projectId: projectId ?? AppConfig.firebaseProjectId,
           ),
       _appName = _safeIdentity(appName ?? '[DEFAULT]', '[DEFAULT]'),
       _buildId = _safeIdentity(buildId ?? AppConfig.buildId, 'unspecified'),
       _sink = sink ?? debugPrint,
       _attemptIdGenerator = attemptIdGenerator ?? _newAttemptId,
       _clock = clock ?? DateTime.now;

  static final instance = AuthDiagnosticLogger();

  final bool enabled;
  bool get hasActiveAttempt => enabled && _activeAttempt != null;
  final String _appName;
  final String _buildId;
  final void Function(String message) _sink;
  final String Function() _attemptIdGenerator;
  final DateTime Function() _clock;
  AuthDiagnosticAttempt? _activeAttempt;

  static bool isEnabledForBuild({
    required bool debugBuild,
    required bool optedIn,
    required String projectId,
  }) =>
      debugBuild && optedIn && projectId == 'intqaflow-dev';

  static String _safeIdentity(String value, String fallback) {
    if (value.length > 80 || !RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(value)) {
      return fallback;
    }
    return value;
  }

  AuthDiagnosticAttempt? beginSignIn({
    required FirebaseAuth auth,
    required bool anonymousAtStart,
    required bool registeredAtStart,
    required bool emailPresent,
    required bool passwordPresent,
  }) {
    if (!enabled || _activeAttempt != null) return null;
    final projectId = _projectIdFor(auth);
    if (projectId == null || projectId != 'intqaflow-dev') return null;
    late final String attemptId;
    try {
      attemptId = _attemptIdGenerator();
    } on Object {
      return null;
    }
    final attempt = AuthDiagnosticAttempt._(
      logger: this,
      attemptId: attemptId,
      appName: _appNameFor(auth),
      projectId: projectId,
      anonymousAtStart: anonymousAtStart,
      registeredAtStart: registeredAtStart,
      emailPresent: emailPresent,
      passwordPresent: passwordPresent,
    );
    _activeAttempt = attempt;
    attempt.record(AuthDiagnosticStage.credentialsCaptured);
    return attempt;
  }

  void observeAuthState({required User? user}) {
    final attempt = _activeAttempt;
    if (attempt == null || !attempt.firebaseCallStarted) return;
    try {
      final anonymous = user?.isAnonymous == true;
      final registered = user != null && !anonymous;
      attempt._record(
        AuthDiagnosticStage.authStateObserved,
        anonymous: anonymous,
        registered: registered,
      );
      attempt._observeIdentity(user: user, registered: registered);
    } on Object {
      attempt._finish();
    }
  }

  void accountLookupStarted() {
    final attempt = _eligibleAttempt;
    attempt?.record(AuthDiagnosticStage.accountLookupStarted);
  }

  void accountLookupCompleted(String outcome) {
    final attempt = _eligibleAttempt;
    if (attempt == null) return;
    attempt._record(
      AuthDiagnosticStage.accountLookupCompleted,
      lookupOutcome: _lookupOutcome(outcome),
    );
    if (outcome != 'active') attempt._finish();
  }

  void membershipLookupStarted() {
    final attempt = _eligibleAttempt;
    attempt?.record(AuthDiagnosticStage.membershipLookupStarted);
  }

  void membershipLookupCompleted({required bool succeeded}) {
    final attempt = _eligibleAttempt;
    if (attempt == null) return;
    attempt._record(
      AuthDiagnosticStage.membershipLookupCompleted,
      lookupOutcome: succeeded ? 'success' : 'failure',
    );
    attempt._finish();
  }

  AuthDiagnosticAttempt? get _eligibleAttempt {
    final attempt = _activeAttempt;
    if (attempt == null ||
        !attempt.firebaseCallSucceeded ||
        !attempt._identityVerified) {
      return null;
    }
    return attempt;
  }

  void _emit(
    AuthDiagnosticAttempt attempt,
    AuthDiagnosticStage stage, {
    AuthDiagnosticConfirmationOutcome? confirmationOutcome,
    String? sanitizedExceptionCode,
    bool? anonymous,
    bool? registered,
    String? lookupOutcome,
  }) {
    if (!enabled || !identical(_activeAttempt, attempt)) return;
    try {
      final now = _clock();
      final event = <String, Object?>{
        'event': 'auth_diagnostic',
        'attemptId': attempt.attemptId,
        'operation': 'existing_account_sign_in',
        'stage': stage.name,
        'stageTimestampUtc': now.toUtc().toIso8601String(),
        'elapsedMs': attempt.elapsedMilliseconds,
        'appName': attempt.appName,
        'projectId': attempt.projectId,
        'buildId': _buildId,
        'anonymousAtStart': attempt.anonymousAtStart,
        'registeredAtStart': attempt.registeredAtStart,
        'emailPresent': attempt.emailPresent,
        'passwordPresent': attempt.passwordPresent,
        if (confirmationOutcome != null)
          'confirmationOutcome': confirmationOutcome.name,
        if (sanitizedExceptionCode != null)
          'sanitizedExceptionCode': sanitizedExceptionCode,
        if (anonymous != null) 'anonymous': anonymous,
        if (registered != null) 'registered': registered,
        if (lookupOutcome != null) 'lookupOutcome': lookupOutcome,
      };
      _sink(jsonEncode(event));
    } on Object {
      // Diagnostics must never alter authentication behavior.
    }
  }

  void _clear(AuthDiagnosticAttempt attempt) {
    if (identical(_activeAttempt, attempt)) _activeAttempt = null;
  }

  String _appNameFor(FirebaseAuth auth) {
    try {
      return _safeIdentity(auth.app.name, _appName);
    } on Object {
      return _appName;
    }
  }

  String? _projectIdFor(FirebaseAuth auth) {
    try {
      final configuredProjectId = auth.app.options.projectId;
      if (configuredProjectId == null) return null;
      final projectId = _safeIdentity(configuredProjectId, '');
      return projectId.isEmpty ? null : projectId;
    } on Object {
      return null;
    }
  }

  static String _lookupOutcome(String outcome) => switch (outcome) {
    'active' || 'no_membership' || 'inactive' || 'unavailable' => outcome,
    'success' || 'failure' => outcome,
    _ => 'other',
  };

  static String sanitizeFirebaseCode(String code) {
    final normalized = code.toLowerCase().split('/').last;
    const safeCodes = {
      'invalid-credential',
      'wrong-password',
      'user-not-found',
      'invalid-email',
      'too-many-requests',
      'network-request-failed',
      'user-disabled',
      'operation-not-allowed',
      'app-not-authorized',
      'invalid-api-key',
      'captcha-check-failed',
      'invalid-app-credential',
      'web-storage-unsupported',
    };
    return safeCodes.contains(normalized) ? normalized : 'other';
  }

  static String _newAttemptId() {
    final random = Random.secure();
    const alphabet = '0123456789abcdef';
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

class AuthDiagnosticAttempt {
  AuthDiagnosticAttempt._({
    required AuthDiagnosticLogger logger,
    required this.attemptId,
    required this.appName,
    required this.projectId,
    required this.anonymousAtStart,
    required this.registeredAtStart,
    required this.emailPresent,
    required this.passwordPresent,
  }) : _logger = logger {
    _stopwatch = Stopwatch()..start();
    _timeout = Timer(const Duration(minutes: 2), _finish);
  }

  final AuthDiagnosticLogger _logger;
  final String attemptId;
  final String appName;
  final String projectId;
  final bool anonymousAtStart;
  final bool registeredAtStart;
  final bool emailPresent;
  final bool passwordPresent;
  late final Stopwatch _stopwatch;
  late final Timer _timeout;
  bool firebaseCallSucceeded = false;
  bool firebaseCallStarted = false;
  bool _registeredStateObserved = false;
  bool _identityVerified = false;
  String? _observedRegisteredUid;
  String? _expectedUid;
  bool _finished = false;
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;

  void record(
    AuthDiagnosticStage stage, {
    AuthDiagnosticConfirmationOutcome? confirmationOutcome,
  }) {
    _record(stage, confirmationOutcome: confirmationOutcome);
  }

  void recordFirebaseFailure(String code) {
    _record(
      AuthDiagnosticStage.firebaseCallFailed,
      sanitizedExceptionCode: AuthDiagnosticLogger.sanitizeFirebaseCode(code),
    );
    _finish();
  }

  void recordFirebaseSuccess({required String? signedInUid}) {
    firebaseCallSucceeded = true;
    record(AuthDiagnosticStage.firebaseCallSucceeded);
    if (signedInUid == null) {
      _finish();
      return;
    }
    _expectedUid = signedInUid;
    final observedUid = _observedRegisteredUid;
    if (observedUid != null) {
      if (observedUid == signedInUid) {
        _identityVerified = true;
      } else {
        _finish();
      }
    }
  }

  void _observeIdentity({required User? user, required bool registered}) {
    if (!registered) {
      if (_registeredStateObserved) _finish();
      return;
    }
    _registeredStateObserved = true;
    final uid = user!.uid;
    _observedRegisteredUid = uid;
    final expectedUid = _expectedUid;
    if (expectedUid != null) {
      if (uid == expectedUid) {
        _identityVerified = true;
      } else {
        _finish();
      }
    }
  }

  void complete() => _finish();

  void _record(
    AuthDiagnosticStage stage, {
    AuthDiagnosticConfirmationOutcome? confirmationOutcome,
    String? sanitizedExceptionCode,
    bool? anonymous,
    bool? registered,
    String? lookupOutcome,
  }) {
    if (_finished) return;
    if (stage == AuthDiagnosticStage.firebaseCallStarted) {
      firebaseCallStarted = true;
    }
    _logger._emit(
      this,
      stage,
      confirmationOutcome: confirmationOutcome,
      sanitizedExceptionCode: sanitizedExceptionCode,
      anonymous: anonymous,
      registered: registered,
      lookupOutcome: lookupOutcome,
    );
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timeout.cancel();
    _stopwatch.stop();
    _logger._clear(this);
  }
}

final authDiagnosticLoggerProvider = Provider<AuthDiagnosticLogger>(
  (ref) => AuthDiagnosticLogger.instance,
);
