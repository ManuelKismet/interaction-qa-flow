import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/auth/auth_diagnostics.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref
      .watch(firebaseAuthProvider)
      .authStateChanges()
      .map((user) {
        ref.read(authDiagnosticLoggerProvider).observeAuthState(user: user);
        return user;
      }),
);

final currentMembershipProvider = FutureProvider.autoDispose<ActiveMembership>(
  (ref) async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) throw StateError('No authenticated user');
    final diagnostics = ref.read(authDiagnosticLoggerProvider);
    diagnostics.membershipLookupStarted();
    try {
      final response = await ref
          .watch(apiClientProvider)
          .get<Map<String, dynamic>>('/api/v1/auth/me');
      final membership = ActiveMembership.fromJson(response.data!);
      diagnostics.membershipLookupCompleted(succeeded: true);
      return membership;
    } catch (_) {
      diagnostics.membershipLookupCompleted(succeeded: false);
      rethrow;
    }
  },
);

enum AccountMembershipStatus {
  active,
  noMembership,
  inactive,
  unavailable,
}

final accountMembershipStatusProvider =
    FutureProvider.autoDispose<AccountMembershipStatus>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.isAnonymous) {
        throw StateError('A registered Firebase identity is required.');
      }
      final diagnostics = ref.read(authDiagnosticLoggerProvider);
      diagnostics.accountLookupStarted();
      try {
        final response = await ref
            .watch(apiClientProvider)
            .get<Map<String, dynamic>>('/api/v1/account/state');
        final status = switch (response.data?['status']) {
          'active' => AccountMembershipStatus.active,
          'no_membership' => AccountMembershipStatus.noMembership,
          'inactive' => AccountMembershipStatus.inactive,
          _ => throw const FormatException('Unknown account membership state.'),
        };
        diagnostics.accountLookupCompleted(switch (status) {
          AccountMembershipStatus.active => 'active',
          AccountMembershipStatus.noMembership => 'no_membership',
          AccountMembershipStatus.inactive => 'inactive',
          AccountMembershipStatus.unavailable => 'unavailable',
        });
        return status;
      } catch (_) {
        diagnostics.accountLookupCompleted('unavailable');
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
  });

  final String userId;
  final String organisationId;
  final String email;
  final String displayName;
  final String role;

  factory ActiveMembership.fromJson(Map<String, dynamic> json) =>
      ActiveMembership(
        userId: json['user_id'] as String,
        organisationId: json['organisation_id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
        role: json['role'] as String,
      );
}
