import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/organisation/data/organisation_repository.dart';
import 'package:int_qa_flow/features/organisation/domain/organisation_models.dart';

final organisationProfileProvider =
    FutureProvider.autoDispose<OrganisationProfile>((ref) async {
      final membership = await ref.watch(currentMembershipProvider.future);
      final user = ref.watch(firebaseAuthProvider).currentUser;
      if (user == null) throw StateError('Sign in to view your organisation.');
      final expectedUid = user.uid;
      final cancelToken = CancelToken();
      ref.onDispose(cancelToken.cancel);
      final profile = await ref
          .watch(organisationRepositoryProvider)
          .profile(expectedUid, cancelToken: cancelToken);
      if (ref.watch(firebaseAuthProvider).currentUser?.uid != expectedUid ||
          membership.organisationId != profile.organisationId ||
          membership.userId != profile.userId) {
        throw StateError('Organisation changed while this view was loading.');
      }
      return profile;
    });

final organisationPermissionsProvider =
    FutureProvider.autoDispose<List<OrganisationPermissionGrant>>((ref) async {
      final user = ref.watch(firebaseAuthProvider).currentUser;
      if (user == null) throw StateError('Sign in to manage permissions.');
      return ref.watch(organisationRepositoryProvider).permissions(user.uid);
    });

final organisationOwnersProvider =
    FutureProvider.autoDispose<List<OrganisationOwner>>((ref) async {
      final user = ref.watch(firebaseAuthProvider).currentUser;
      if (user == null) throw StateError('Sign in to view owners.');
      return ref.watch(organisationRepositoryProvider).owners(user.uid);
    });

final myOrganisationJoinRequestsProvider =
    FutureProvider.autoDispose<List<OrganisationJoinRequest>>((ref) async {
      final user = ref.watch(firebaseAuthProvider).currentUser;
      if (user == null) throw StateError('Sign in to view requests.');
      return ref
          .watch(organisationRepositoryProvider)
          .joinRequests(user.uid, mine: true);
    });

final pendingOrganisationJoinRequestsProvider =
    FutureProvider.autoDispose<List<OrganisationJoinRequest>>((ref) async {
      final user = ref.watch(firebaseAuthProvider).currentUser;
      if (user == null) throw StateError('Sign in to review requests.');
      return ref
          .watch(organisationRepositoryProvider)
          .joinRequests(user.uid, mine: false);
    });
