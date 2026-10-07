import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';

Future<T> _loadGuided<T>(
  Ref ref,
  Future<T> Function(GuidedRepository repository) load,
) async {
  ref.watch(authStateProvider);
  ref.watch(currentMembershipProvider);
  await ref.watch(organisationProfileProvider.future);
  if (!ref.mounted) throw StateError('Interact scope changed while loading.');
  final repository = ref.watch(guidedRepositoryProvider);
  final result = await load(repository);
  if (!ref.mounted) throw StateError('Interact scope changed while loading.');
  repository.ensureCurrent();
  return result;
}

final activeGuidedSessionsProvider = FutureProvider.autoDispose((ref) {
  return _loadGuided(ref, (repository) => repository.listSessions(status: 'active'));
});

final draftGuidedSessionsProvider = FutureProvider.autoDispose((ref) {
  return _loadGuided(ref, (repository) => repository.listSessions(status: 'draft'));
});

final completedGuidedSessionsProvider = FutureProvider.autoDispose((ref) {
  return _loadGuided(ref, (repository) => repository.listSessions(status: 'completed'));
});

final guidedTemplatesProvider = FutureProvider.autoDispose((ref) {
  return _loadGuided(ref, (repository) => repository.listTemplates());
});

final knowledgeProposalsProvider = FutureProvider.autoDispose((ref) {
  return _loadGuided(ref, (repository) => repository.listKnowledgeProposals());
});

typedef GuidedSessionQuery = ({
  String sessionId,
  String? participantId,
  GuidedViewMode viewMode,
});

final guidedSessionProvider = FutureProvider.autoDispose
    .family<GuidedSessionDetail, GuidedSessionQuery>((ref, query) {
  return _loadGuided(ref, (repository) => repository.getSession(
        query.sessionId,
        participantId: query.participantId,
        mode: query.viewMode,
      ));
});

void invalidateGuidedLists(WidgetRef ref) {
  ref.invalidate(activeGuidedSessionsProvider);
  ref.invalidate(draftGuidedSessionsProvider);
  ref.invalidate(completedGuidedSessionsProvider);
}