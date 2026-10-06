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
      attempt._observeIdentity(user: user, registered: registered);
    } on Object {
      attempt._finish();
    }
  }

  AuthDiagnosticLookup? beginAccountLookup({required String userId}) =>
      _beginLookup(
        userId: userId,
        startedStage: AuthDiagnosticStage.accountLookupStarted,
        completedStage: AuthDiagnosticStage.accountLookupCompleted,
      );

  AuthDiagnosticLookup? beginMembershipLookup({required String userId}) =>
      _beginLookup(
        userId: userId,
        startedStage: AuthDiagnosticStage.membershipLookupStarted,
        completedStage: AuthDiagnosticStage.membershipLookupCompleted,
      );

  AuthDiagnosticLookup? _beginLookup({
    required String userId,
    required AuthDiagnosticStage startedStage,
    required AuthDiagnosticStage completedStage,
  }) {
    final attempt = _activeAttempt;
    if (attempt == null ||
        !attempt.firebaseCallStarted ||
        !attempt._canObserveIdentity(userId)) {
      return null;
    }
    final lookup = AuthDiagnosticLookup._(
      attempt: attempt,
      userId: userId,
      startedStage: startedStage,
      completedStage: completedStage,
    );
    return attempt._registerLookup(lookup) ? lookup : null;
  }

  DateTime _diagnosticTime() {
    try {
      return _clock();
    } on Object {
      return DateTime.now();
    }
  }

  void _emit(
    AuthDiagnosticAttempt attempt,
    AuthDiagnosticStage stage, {
    AuthDiagnosticConfirmationOutcome? confirmationOutcome,
    String? sanitizedExceptionCode,
    bool? anonymous,
    bool? registered,
    String? lookupOutcome,
    DateTime? stageTime,
    int? elapsedMs,
  }) {
    if (!enabled || !identical(_activeAttempt, attempt)) return;
    try {
      final now = stageTime ?? _diagnosticTime();
      final event = <String, Object?>{
        'event': 'auth_diagnostic',
        'attemptId': attempt.attemptId,
        'operation': 'existing_account_sign_in',
        'stage': stage.name,
        'stageTimestampUtc': now.toUtc().toIso8601String(),
        'elapsedMs': elapsedMs ?? attempt.elapsedMilliseconds,
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
  bool _authStateObservedEmitted = false;
  final Set<AuthDiagnosticLookup> _lookups = {};
  DateTime? _authStateObservedAt;
  int? _authStateObservedElapsedMs;
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
    if (_finished) return;
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
        _flushPendingEvents();
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
    if (!_authStateObservedEmitted) {
      _authStateObservedAt = _logger._diagnosticTime();
      _authStateObservedElapsedMs = elapsedMilliseconds;
    }
    final uid = user!.uid;
    _observedRegisteredUid = uid;
    final expectedUid = _expectedUid;
    if (expectedUid != null) {
      if (uid == expectedUid) {
        _identityVerified = true;
        _flushPendingEvents();
      } else {
        _finish();
      }
    }
  }

  bool _canObserveIdentity(String userId) {
    if (_finished) return false;
    final expectedUid = _expectedUid;
    final observedUid = _observedRegisteredUid;
    return (expectedUid == null || expectedUid == userId) &&
        (observedUid == null || observedUid == userId);
  }

  bool _registerLookup(AuthDiagnosticLookup lookup) {
    if (!_canObserveIdentity(lookup.userId)) return false;
    _lookups.add(lookup);
    if (_identityVerified) lookup._flushPendingEvents();
    return true;
  }

  void _flushPendingEvents() {
    if (!_identityVerified || _finished) return;
    if (_registeredStateObserved && !_authStateObservedEmitted) {
      _authStateObservedEmitted = true;
      _record(
        AuthDiagnosticStage.authStateObserved,
        anonymous: false,
        registered: true,
        stageTime: _authStateObservedAt,
        elapsedMs: _authStateObservedElapsedMs,
      );
    }
    for (final lookup in _lookups.toList()) {
      if (lookup.userId != _expectedUid) {
        lookup.cancel();
      } else {
        lookup._flushPendingEvents();
      }
      if (_finished) break;
    }
  }

  void _removeLookup(AuthDiagnosticLookup lookup) {
    _lookups.remove(lookup);
  }

  void _completeLookup(AuthDiagnosticLookup lookup, String outcome) {
    if (_finished || !_lookups.contains(lookup)) return;
    if (!_identityVerified || lookup.userId != _expectedUid) {
      lookup._setPendingOutcome(outcome);
      return;
    }
    lookup._emitStarted();
    lookup._emitCompleted(outcome);
    _lookups.remove(lookup);
    lookup._invalidate();
    if (lookup.completedStage == AuthDiagnosticStage.accountLookupCompleted &&
        outcome != 'active') {
      _finish();
    } else if (lookup.completedStage ==
        AuthDiagnosticStage.membershipLookupCompleted) {
      _finish();
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
    DateTime? stageTime,
    int? elapsedMs,
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
      stageTime: stageTime,
      elapsedMs: elapsedMs,
    );
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timeout.cancel();
    _stopwatch.stop();
    for (final lookup in _lookups.toList()) {
      lookup._invalidate();
    }
    _lookups.clear();
    _observedRegisteredUid = null;
    _expectedUid = null;
    _logger._clear(this);
  }
}

class AuthDiagnosticLookup {
  AuthDiagnosticLookup._({
    required AuthDiagnosticAttempt attempt,
    required String userId,
    required this.startedStage,
    required this.completedStage,
  }) : _attempt = attempt,
       _userId = userId,
       _startedAt = attempt._logger._diagnosticTime(),
       _startedElapsedMs = attempt.elapsedMilliseconds;

  final AuthDiagnosticAttempt _attempt;
  String? _userId;
  String get userId => _userId ?? '';
  final AuthDiagnosticStage startedStage;
  final AuthDiagnosticStage completedStage;
  final DateTime _startedAt;
  final int _startedElapsedMs;
  bool _startedEmitted = false;
  bool _completed = false;
  String? _pendingOutcome;
  DateTime? _completedAt;
  int? _completedElapsedMs;
  bool _cancelled = false;

  void complete(String outcome) {
    if (_cancelled || _completed) return;
    _completed = true;
    _completedAt = _attempt._logger._diagnosticTime();
    _completedElapsedMs = _attempt.elapsedMilliseconds;
    _attempt._completeLookup(this, outcome);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _attempt._removeLookup(this);
    _userId = null;
  }

  void _flushPendingEvents() {
    if (_cancelled || _attempt._finished) return;
    _emitStarted();
    final outcome = _pendingOutcome;
    if (_completed && outcome != null) {
      _pendingOutcome = null;
      _attempt._completeLookup(this, outcome);
    }
  }

  void _emitStarted() {
    if (_cancelled || _startedEmitted) return;
    _startedEmitted = true;
    _attempt._record(
      startedStage,
      stageTime: _startedAt,
      elapsedMs: _startedElapsedMs,
    );
  }

  void _emitCompleted(String outcome) {
    if (_cancelled) return;
    _attempt._record(
      completedStage,
      lookupOutcome: AuthDiagnosticLogger._lookupOutcome(outcome),
      stageTime: _completedAt,
      elapsedMs: _completedElapsedMs,
    );
  }

  void _setPendingOutcome(String outcome) {
    _pendingOutcome = outcome;
  }

  void _invalidate() {
    _cancelled = true;
    _userId = null;
    _pendingOutcome = null;
  }
}

final authDiagnosticLoggerProvider = Provider<AuthDiagnosticLogger>(
  (ref) => AuthDiagnosticLogger.instance,
);
