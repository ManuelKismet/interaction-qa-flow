import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';

final activeGuidedSessionsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(guidedRepositoryProvider).listSessions(status: 'active');
});

final draftGuidedSessionsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(guidedRepositoryProvider).listSessions(status: 'draft');
});

final completedGuidedSessionsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(guidedRepositoryProvider).listSessions(status: 'completed');
});

final guidedTemplatesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(guidedRepositoryProvider).listTemplates();
});

final knowledgeProposalsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(guidedRepositoryProvider).listKnowledgeProposals();
});

typedef GuidedSessionQuery = ({
  String sessionId,
  String? participantId,
  GuidedViewMode viewMode,
});

final guidedSessionProvider = FutureProvider.autoDispose
    .family<GuidedSessionDetail, GuidedSessionQuery>((ref, query) {
  return ref.watch(guidedRepositoryProvider).getSession(
        query.sessionId,
        participantId: query.participantId,
        mode: query.viewMode,
      );
});

void invalidateGuidedLists(WidgetRef ref) {
  ref.invalidate(activeGuidedSessionsProvider);
  ref.invalidate(draftGuidedSessionsProvider);
  ref.invalidate(completedGuidedSessionsProvider);
}