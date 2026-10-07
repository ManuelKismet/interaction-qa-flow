import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/governance/application/governance_providers.dart';
import 'package:int_qa_flow/features/governance/data/governance_repository.dart';
import 'package:int_qa_flow/features/governance/domain/governance_models.dart';
import 'package:int_qa_flow/features/guided/application/guided_providers.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/questions/application/question_providers.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';

class ReviewQueuePage extends ConsumerStatefulWidget {
  const ReviewQueuePage({super.key});

  @override
  ConsumerState<ReviewQueuePage> createState() => _ReviewQueuePageState();
}

class _ReviewQueuePageState extends ConsumerState<ReviewQueuePage> {
  String? _departmentId;
  String? _type;
  String? _status;

  ReviewQueueFilter get _filter =>
      (departmentId: _departmentId, type: _type, status: _status);

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentMembershipProvider).value?.role;
    final organisation = ref.watch(organisationProfileProvider);
    if (organisation.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (organisation.hasError ||
        !organisation.hasValue ||
        (role != 'answer_owner' &&
            !organisation.requireValue.can('review') &&
            !organisation.requireValue.can('answer_approval'))) {
      return const Center(child: Text('You do not have access to this queue.'));
    }
    final profile = organisation.requireValue;
    final canReview = profile.can('review');
    final canApproveAnswers = role == 'answer_owner' ||
        profile.can('answer_approval');
    final queue = ref.watch(reviewQueueProvider(_filter));
    final departments = ref.watch(departmentsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(reviewQueueProvider(_filter).future),
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text(
            'Review queue',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            canReview && canApproveAnswers
                ? 'Challenges, expiring guidance, and answers awaiting verification.'
                : canReview
                    ? 'Challenges, expiring guidance, and duplicate suggestions.'
                    : 'Answers awaiting verification.',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: departments.when(
                  data: (items) => DropdownButtonFormField<String?>(
                    initialValue: _departmentId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All departments'),
                      ),
                      for (final item in items)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _departmentId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Departments unavailable'),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String?>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Queue type'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All types'),
                    ),
                    if (canReview) ...[
                      const DropdownMenuItem(
                        value: 'challenge',
                        child: Text('Challenges'),
                      ),
                      const DropdownMenuItem(
                        value: 'review_due',
                        child: Text('Review due'),
                      ),
                      const DropdownMenuItem(
                        value: 'review_due_soon',
                        child: Text('Due soon'),
                      ),
                      const DropdownMenuItem(
                        value: 'duplicate_suggestion',
                        child: Text('Duplicate suggestions'),
                      ),
                    ],
                    if (canApproveAnswers)
                      const DropdownMenuItem(
                        value: 'needs_verification',
                        child: Text('Needs verification'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _type = value),
                ),
              ),
              if (canReview)
                SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Challenge status',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Open only')),
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'accepted',
                      child: Text('Accepted'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          queue.when(
            data: (items) => items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('Nothing needs attention.')),
                  )
                : Column(
                    children: [for (final item in items) _QueueRow(item: item)],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('Unable to load the review queue.')),
          ),
          if (canReview) ...[
            const SizedBox(height: 32),
            Text(
              'Interact proposals for Knowledge',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ref
                .watch(knowledgeProposalsProvider)
                .when(
                  data: (items) {
                    final pending = items
                        .where((item) => item.status == 'pending')
                        .toList();
                    if (pending.isEmpty) {
                      return const Text('No Interact proposals pending.');
                    }
                    return Column(
                      children: [
                        for (final item in pending)
                          _KnowledgeProposalRow(proposal: item),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) =>
                      const Text('Unable to load Interact proposals.'),
                ),
            const SizedBox(height: 32),
            Text(
              'Question change requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ref.watch(questionChangeRequestsProvider).when(
                  data: (items) => items.isEmpty
                      ? const Text('No question changes pending review.')
                      : Column(
                          children: [
                            for (final item in items)
                              _QuestionChangeRequestRow(request: item),
                          ],
                        ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text(
                    'Unable to load question change requests.',
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _QuestionChangeRequestRow extends ConsumerWidget {
  const _QuestionChangeRequestRow({required this.request});

  final QuestionChangeRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        title: Text(
          request.proposedTitle ??
              (request.archiveRequested
                  ? 'Question archival request'
                  : 'Question content change request'),
        ),
        subtitle: Text(request.reason),
        onTap: () => context.go('/questions/${request.questionId}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Reject change request',
              icon: const Icon(Icons.close),
              onPressed: () => _review(ref, 'reject'),
            ),
            IconButton(
              tooltip: 'Approve change request',
              icon: const Icon(Icons.check),
              onPressed: () => _review(ref, 'approve'),
            ),
          ],
        ),
      );

  Future<void> _review(WidgetRef ref, String decision) async {
    await ref.read(questionsRepositoryProvider).reviewChangeRequest(
          request.id,
          decision: decision,
        );
    ref.invalidate(questionChangeRequestsProvider);
    ref.invalidate(questionDetailProvider(request.questionId));
    ref.invalidate(questionsProvider);
  }
}

class _KnowledgeProposalRow extends ConsumerWidget {
  const _KnowledgeProposalRow({required this.proposal});
  final KnowledgeProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      leading: const Icon(Icons.lightbulb_outline),
      title: Text(proposal.questionText),
      subtitle: Text(
        proposal.answerText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Find possible existing knowledge',
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: () => _duplicates(context, ref),
          ),
          IconButton(
            tooltip: 'Reject proposal',
            icon: const Icon(Icons.close),
            onPressed: () => _decide(ref, 'reject'),
          ),
          IconButton(
            tooltip: 'Create new Q&A',
            icon: const Icon(Icons.check),
            onPressed: () => _decide(ref, 'accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _decide(
    WidgetRef ref,
    String action, {
    String? existingQuestionId,
  }) async {
    await ref
        .read(guidedRepositoryProvider)
        .decideKnowledgeProposal(
          proposal.id,
          action,
          existingQuestionId: existingQuestionId,
        );
    ref.invalidate(knowledgeProposalsProvider);
    ref.invalidate(reviewQueueProvider);
  }

  Future<void> _duplicates(BuildContext context, WidgetRef ref) async {
    final results = await ref
        .read(guidedRepositoryProvider)
        .proposalDuplicates(proposal.id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Possible existing knowledge'),
        content: SizedBox(
          width: 620,
          child: results.isEmpty
              ? const Text('No related canonical knowledge found.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final result in results)
                      ListTile(
                        title: Text(result.title),
                        subtitle: Text(
                          result.acceptedAnswerBody ?? 'Answer unavailable.',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _decide(
                              ref,
                              'link',
                              existingQuestionId: result.questionId,
                            );
                          },
                          child: const Text('Link'),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends ConsumerWidget {
  const _QueueRow({required this.item});

  final ReviewQueueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (item.type) {
      'challenge' => 'Challenge: ${item.challengeType?.replaceAll('_', ' ')}',
      'review_due' => 'Review overdue',
      'review_due_soon' => 'Review due soon',
      'duplicate_suggestion' => 'Possible duplicate',
      _ => 'Needs verification',
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Icon(switch (item.type) {
        'challenge' => Icons.report_outlined,
        'needs_verification' => Icons.fact_check_outlined,
        'duplicate_suggestion' => Icons.content_copy_outlined,
        _ => Icons.schedule_outlined,
      }),
      title: Text(item.questionTitle),
      subtitle: Text(
        [
          label,
          if (item.department != null) item.department!.name,
          if (item.suggestedCanonicalTitle != null)
            'Suggested: ${item.suggestedCanonicalTitle}',
        ].join(' · '),
      ),
      trailing: item.duplicateSuggestionId == null
          ? const Icon(Icons.chevron_right)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Reject duplicate suggestion',
                  icon: const Icon(Icons.close),
                  onPressed: () => _reject(context, ref),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
      onTap: () => context.go('/questions/${item.questionId}'),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(governanceRepositoryProvider)
          .decideDuplicateSuggestion(
            item.duplicateSuggestionId!,
            accept: false,
            reason: 'Kept separate after review',
          );
      ref.invalidate(reviewQueueProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Unable to reject duplicate suggestion.',
            ),
          ),
        );
      }
    }
  }
}
