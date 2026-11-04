import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/auth/auth_diagnostics.dart';

bool isVerifiedRegisteredFirebaseUser(User? user) =>
    user != null && !user.isAnonymous && user.emailVerified;

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges().map((user) {
    try {
      ref.read(authDiagnosticLoggerProvider).observeAuthState(user: user);
    } on Object {
      // Auth diagnostics must not affect auth-state delivery.
    }
    return user;
  }),
);

final currentMembershipProvider = FutureProvider.autoDispose<ActiveMembership>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) throw StateError('No authenticated user');
  final expectedUid = user.uid;
  AuthDiagnosticLookup? diagnostic;
  try {
    diagnostic = ref
        .read(authDiagnosticLoggerProvider)
        .beginMembershipLookup(userId: expectedUid);
  } on Object {
    // Diagnostics must not affect account access.
  }
  ref.onDispose(() => diagnostic?.cancel());
  try {
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);
    final response = await ref
        .watch(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/api/v1/auth/me',
          options: Options(extra: {'expectedFirebaseUid': expectedUid}),
          cancelToken: cancelToken,
        );
    if (!ref.mounted || ref.read(authStateProvider).value?.uid != expectedUid) {
      throw StateError(
        'The signed-in account changed while loading membership.',
      );
    }
    final membership = ActiveMembership.fromJson(
      response.data!,
      firebaseUid: expectedUid,
    );
    _completeAuthDiagnostic(diagnostic, 'success');
    return membership;
  } catch (_) {
    _completeAuthDiagnostic(diagnostic, 'error');
    rethrow;
  }
});

enum AccountMembershipStatus { active, noMembership, inactive, unavailable }

final accountMembershipStatusProvider =
    FutureProvider.autoDispose<AccountMembershipStatus>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.isAnonymous) {
        throw StateError('A registered Firebase identity is required.');
      }
      final expectedUid = user.uid;
      AuthDiagnosticLookup? diagnostic;
      try {
        diagnostic = ref
            .read(authDiagnosticLoggerProvider)
            .beginAccountLookup(userId: expectedUid);
      } on Object {
        // Diagnostics must not affect account access.
      }
      ref.onDispose(() => diagnostic?.cancel());
      try {
        final cancelToken = CancelToken();
        ref.onDispose(cancelToken.cancel);
        final response = await ref
            .watch(apiClientProvider)
            .get<Map<String, dynamic>>(
              '/api/v1/account/state',
              options: Options(extra: {'expectedFirebaseUid': expectedUid}),
              cancelToken: cancelToken,
            );
        if (!ref.mounted ||
            ref.read(authStateProvider).value?.uid != expectedUid) {
          throw StateError(
            'The signed-in account changed while checking membership.',
          );
        }
        final status = switch (response.data?['status']) {
          'active' => AccountMembershipStatus.active,
          'no_membership' => AccountMembershipStatus.noMembership,
          'inactive' => AccountMembershipStatus.inactive,
          _ => throw const FormatException('Unknown account membership state.'),
        };
        _completeAuthDiagnostic(diagnostic, response.data!['status'] as String);
        return status;
      } catch (_) {
        _completeAuthDiagnostic(diagnostic, 'error');
        rethrow;
      }
    });

class ActiveMembership {
  const ActiveMembership({
    required this.userId,
    required this.organisationId,
    required this.email,
    required this.displayName,
    required this.role,
    this.firebaseUid,
  });

  final String userId;
  final String organisationId;
  final String email;
  final String displayName;
  final String role;

  /// Firebase identity that requested this membership; database user IDs are
  /// a separate namespace and must never be compared to Firebase UIDs.
  final String? firebaseUid;

  factory ActiveMembership.fromJson(
    Map<String, dynamic> json, {
    String? firebaseUid,
  }) => ActiveMembership(
    userId: json['user_id'] as String,
    organisationId: json['organisation_id'] as String,
    email: json['email'] as String,
    displayName: json['display_name'] as String,
    role: json['role'] as String,
    firebaseUid: firebaseUid,
  );
}

void _completeAuthDiagnostic(AuthDiagnosticLookup? lookup, String outcome) {
  try {
    lookup?.complete(outcome);
  } on Object {
    /* Diagnostic only. */
  }
}
