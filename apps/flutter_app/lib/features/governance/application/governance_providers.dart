import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/features/governance/data/governance_repository.dart';
import 'package:int_qa_flow/features/governance/domain/governance_models.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

typedef ReviewQueueFilter = ({String? departmentId, String? type, String? status});

final organisationMembersProvider =
    FutureProvider.autoDispose<List<OrganisationMember>>(
  (ref) => ref.watch(governanceRepositoryProvider).organisationMembers(),
);

final reviewQueueProvider = FutureProvider.autoDispose
    .family<List<ReviewQueueItem>, ReviewQueueFilter>(
  (ref, filter) => ref.watch(governanceRepositoryProvider).reviewQueue(
        departmentId: filter.departmentId,
        type: filter.type,
        status: filter.status,
      ),
);

final departmentOwnersProvider =
    FutureProvider.autoDispose<List<DepartmentAnswerOwner>>(
  (ref) => ref.watch(governanceRepositoryProvider).departmentOwners(),
);

final myDepartmentOwnerIdsProvider =
    FutureProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(governanceRepositoryProvider).myDepartmentOwnerIds(),
);

final duplicateCandidatesProvider = FutureProvider.autoDispose
    .family<List<SemanticSearchResult>, String>(
  (ref, questionId) => ref
      .watch(governanceRepositoryProvider)
      .duplicateCandidates(questionId),
);

final teamMembersProvider = FutureProvider.autoDispose
    .family<List<TeamMembership>, String>(
  (ref, teamId) => ref.watch(governanceRepositoryProvider).teamMembers(teamId),
);