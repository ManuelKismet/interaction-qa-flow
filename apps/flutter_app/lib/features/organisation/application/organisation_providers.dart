import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/organisation/data/organisation_repository.dart';
import 'package:int_qa_flow/features/organisation/domain/organisation_models.dart';

class OrganisationDataScope {
  const OrganisationDataScope({
    required this.firebaseUid,
    required this.userId,
    required this.organisationId,
    required this.role,
  });

  final String firebaseUid;
  final String userId;
  final String organisationId;
  final String role;
}

final organisationDataScopeProvider =
    FutureProvider.autoDispose<OrganisationDataScope>((ref) async {
      final authState = ref.watch(authStateProvider);
      final user = authState.value;
      if (user == null || user.isAnonymous) {
        throw StateError('Sign in to view organisation information.');
      }
      final membership = await ref.watch(currentMembershipProvider.future);
      if (!ref.mounted || ref.read(authStateProvider).value?.uid != user.uid) {
        throw StateError(
          'The signed-in account changed while loading membership.',
        );
      }
      return OrganisationDataScope(
        firebaseUid: user.uid,
        userId: membership.userId,
        organisationId: membership.organisationId,
        role: membership.role,
      );
    });

bool isCurrentOrganisationDataScope(Ref ref, OrganisationDataScope scope) =>
    isOrganisationDataScopeCurrent(
      mounted: ref.mounted,
      firebaseUid: ref.read(authStateProvider).value?.uid,
      membership: ref.read(currentMembershipProvider),
      scope: scope,
    );

bool isOrganisationDataScopeCurrent({
  required bool mounted,
  required String? firebaseUid,
  required AsyncValue<ActiveMembership> membership,
  required OrganisationDataScope scope,
}) =>
    mounted &&
    firebaseUid == scope.firebaseUid &&
    membership.hasValue &&
    membership.requireValue.userId == scope.userId &&
    membership.requireValue.organisationId == scope.organisationId &&
    membership.requireValue.role == scope.role;

Future<T> _loadInOrganisationScope<T>(
  Ref ref,
  Future<T> Function(OrganisationDataScope scope, CancelToken cancelToken) load,
) async {
  final scope = await ref.watch(organisationDataScopeProvider.future);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('Organisation scope changed.'));
  final value = await load(scope, cancelToken);
  if (!isCurrentOrganisationDataScope(ref, scope)) {
    throw StateError('Organisation changed while this view was loading.');
  }
  return value;
}

final organisationProfileProvider =
    FutureProvider.autoDispose<OrganisationProfile>((ref) async {
      final repository = ref.watch(organisationRepositoryProvider);
      final scope = await ref.watch(organisationDataScopeProvider.future);
      final cancelToken = CancelToken();
      ref.onDispose(() => cancelToken.cancel('Organisation scope changed.'));
      final profile = await repository.profile(
        scope.firebaseUid,
        cancelToken: cancelToken,
      );
      if (!isCurrentOrganisationDataScope(ref, scope) ||
          profile.organisationId != scope.organisationId ||
          profile.userId != scope.userId) {
        throw StateError('Organisation changed while this view was loading.');
      }
      return profile;
    });

final organisationPermissionsProvider =
    FutureProvider.autoDispose<List<OrganisationPermissionGrant>>((ref) async {
      final repository = ref.watch(organisationRepositoryProvider);
      return _loadInOrganisationScope(
        ref,
        (scope, cancelToken) =>
            repository.permissions(scope.firebaseUid, cancelToken: cancelToken),
      );
    });

final organisationOwnersProvider =
    FutureProvider.autoDispose<List<OrganisationOwner>>((ref) async {
      final repository = ref.watch(organisationRepositoryProvider);
      return _loadInOrganisationScope(
        ref,
        (scope, cancelToken) =>
            repository.owners(scope.firebaseUid, cancelToken: cancelToken),
      );
    });

final myOrganisationJoinRequestsProvider =
    FutureProvider.autoDispose<List<OrganisationJoinRequest>>((ref) async {
      final repository = ref.watch(organisationRepositoryProvider);
      return _loadInOrganisationScope(
        ref,
        (scope, cancelToken) => repository.joinRequests(
          scope.firebaseUid,
          mine: true,
          cancelToken: cancelToken,
        ),
      );
    });

final pendingOrganisationJoinRequestsProvider =
    FutureProvider.autoDispose<List<OrganisationJoinRequest>>((ref) async {
      final repository = ref.watch(organisationRepositoryProvider);
      return _loadInOrganisationScope(
        ref,
        (scope, cancelToken) => repository.joinRequests(
          scope.firebaseUid,
          mine: false,
          cancelToken: cancelToken,
        ),
      );
    });
