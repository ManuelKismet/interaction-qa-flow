import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/governance/application/governance_providers.dart';
import 'package:int_qa_flow/features/governance/data/governance_repository.dart';
import 'package:int_qa_flow/features/governance/domain/governance_models.dart';
import 'package:int_qa_flow/features/questions/application/question_providers.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';

class QuestionDetailPage extends ConsumerStatefulWidget {
  const QuestionDetailPage({required this.questionId, super.key});

  final String questionId;

  @override
  ConsumerState<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends ConsumerState<QuestionDetailPage> {
  final _answerController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isMutating = false;
  bool _discussionOpen = false;

  @override
  void dispose() {
    _answerController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(questionDetailProvider(widget.questionId));
    return detail.when(
      data: (question) => _buildDetail(
        question,
        ref.watch(currentMembershipProvider).value,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to load this question.'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.invalidate(questionDetailProvider(widget.questionId)),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(QuestionDetail question, ActiveMembership? membership) {
    final canResolve =
        question.author.id == membership?.userId ||
        membership?.role == 'admin';
    final canCorrect = canResolve && question.status != 'archived';
    final canGovern = {
      'admin',
      'answer_owner',
    }.contains(membership?.role);
    final otherAnswers = question.answers
        .where((answer) => !answer.isAccepted)
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          question.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      if (canCorrect) ...[
                        IconButton(
                          tooltip: 'Edit question',
                          onPressed: _isMutating
                              ? null
                              : () => _editQuestion(question),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Archive question',
                          onPressed: _isMutating
                              ? null
                              : () => _archiveQuestion(question),
                          icon: const Icon(Icons.archive_outlined),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    [
                      question.author.displayName,
                      if (question.department != null)
                        question.department!.name,
                      if (question.team != null) question.team!.name,
                      question.status.replaceAll('_', ' '),
                    ].join(' · '),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (question.canonicalQuestion case final canonical?) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF4D8),
                        border: Border(
                          left: BorderSide(color: Color(0xFFB47A14), width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'This question has been linked to an existing answer.',
                                ),
                                Text(
                                  canonical.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.go('/questions/${canonical.id}'),
                            child: const Text('View current answer'),
                          ),
                          if (canGovern)
                            IconButton(
                              tooltip: 'Unmerge question',
                              onPressed: _isMutating
                                  ? null
                                  : () => _unmerge(question),
                              icon: const Icon(Icons.link_off),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (question.body case final body? when body.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(body, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                  if (question.aliases.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Also asked as',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    for (final alias in question.aliases.take(3))
                      Text(
                        '• ${alias.title}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                  ],
                  if (question.canonicalQuestion == null && canGovern) ...[
                    const SizedBox(height: 28),
                    _buildDuplicateCandidates(question),
                  ] else if (question.canonicalQuestion == null) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _isMutating
                            ? null
                            : () => _reportDuplicate(question),
                        icon: const Icon(Icons.content_copy_outlined, size: 18),
                        label: const Text('Already answered elsewhere?'),
                      ),
                    ),
                  ],
                  if (question.status == 'resolved' && canResolve) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _isMutating
                            ? null
                            : () => _runAction(
                                () => ref
                                    .read(questionsRepositoryProvider)
                                    .reopen(question.id),
                                'Question reopened.',
                              ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reopen question'),
                      ),
                    ),
                  ],
                  if (question.acceptedAnswer case final accepted?) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Accepted answer',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _AnswerView(
                      answer: accepted,
                      accepted: true,
                      onHelpful: () => _react(accepted.id, 'helpful'),
                      onNotHelpful: () => _react(accepted.id, 'not_helpful'),
                      onChallenge: () => _showChallengeDialog(accepted),
                      onVerify: canGovern && accepted.status != 'verified'
                          ? () => _govern(accepted.id, 'verify')
                          : null,
                      onReview: canGovern && accepted.status == 'verified'
                          ? () => _govern(accepted.id, 'review')
                          : null,
                      onChallenges: canGovern && accepted.challengeCount > 0
                          ? () => _showChallenges(accepted)
                          : null,
                      onHistory: () => _showHistory(accepted),
                    ),
                  ],
                  if (otherAnswers.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      question.acceptedAnswer == null
                          ? 'Answers'
                          : 'Other answers',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    for (final answer in otherAnswers)
                      _AnswerView(
                        answer: answer,
                        accepted: false,
                        onHelpful: () => _react(answer.id, 'helpful'),
                        onNotHelpful: () => _react(answer.id, 'not_helpful'),
                        onChallenge: () => _showChallengeDialog(answer),
                        onVerify: canGovern && answer.status != 'verified'
                            ? () => _govern(answer.id, 'verify')
                            : null,
                        onReview: canGovern && answer.status == 'verified'
                            ? () => _govern(answer.id, 'review')
                            : null,
                        onChallenges: canGovern && answer.challengeCount > 0
                            ? () => _showChallenges(answer)
                            : null,
                        onHistory: () => _showHistory(answer),
                        onAccept: canResolve && question.status != 'archived'
                            ? () => _runAction(
                                () => ref
                                    .read(questionsRepositoryProvider)
                                    .resolve(question.id, answer.id),
                                'Answer accepted.',
                              )
                            : null,
                      ),
                  ],
                  if (question.status != 'archived') ...[
                    const SizedBox(height: 36),
                    Text(
                      'Answer this question',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _answerController,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'Write an answer',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _isMutating ? null : _submitAnswer,
                        child: const Text('Submit answer'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('Discussion (${question.commentCount})'),
                    onExpansionChanged: (value) =>
                        setState(() => _discussionOpen = value),
                    children: _discussionOpen ? [_buildDiscussion()] : const [],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussion() {
    final comments = ref.watch(commentsProvider(widget.questionId));
    return comments.when(
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No discussion yet.'),
            ),
          for (final comment in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('${comment.author.displayName}: ${comment.body}'),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Add to the discussion',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isMutating ? null : _submitComment,
              child: const Text('Add comment'),
            ),
          ),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Unable to load the discussion.'),
      ),
    );
  }

  Widget _buildDuplicateCandidates(QuestionDetail question) {
    final candidates = ref.watch(duplicateCandidatesProvider(question.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Possible duplicates',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        candidates.when(
          data: (items) => items.isEmpty
              ? const Text('No strong duplicate candidates found.')
              : Column(
                  children: [
                    for (final candidate in items.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.content_copy_outlined),
                        title: Text(candidate.canonicalTitle),
                        subtitle: Text(
                          [
                            if (candidate.department != null)
                              candidate.department!.name,
                            candidate.answerStatus == 'verified'
                                ? 'Verified answer'
                                : 'Community answer',
                            if (candidate.matchSource != 'canonical')
                              'Matched “${candidate.matchedText}”',
                          ].join(' · '),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () =>
                              _compareQuestions(question, candidate),
                          child: const Text('Compare'),
                        ),
                      ),
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) =>
              const Text('Unable to check for possible duplicates.'),
        ),
      ],
    );
  }

  Future<void> _compareQuestions(
    QuestionDetail current,
    SemanticSearchResult candidate,
  ) async {
    final direction = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compare questions'),
        content: SizedBox(
          width: 720,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ComparisonColumn(
                  label: 'Current question',
                  title: current.title,
                  body: current.body,
                  answer: current.acceptedAnswer?.body,
                  status: current.acceptedAnswer?.status,
                  department: current.department?.name,
                  resolvedAt: current.resolvedAt,
                ),
              ),
              const VerticalDivider(width: 32),
              Expanded(
                child: _ComparisonColumn(
                  label: 'Potential canonical question',
                  title: candidate.canonicalTitle,
                  body: candidate.canonicalBody,
                  answer: candidate.acceptedAnswerBody ?? 'Answer unavailable.',
                  status: candidate.answerStatus,
                  department: candidate.department?.name,
                  resolvedAt: candidate.resolvedAt,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep separate'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'current'),
            child: const Text('Make current canonical'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'existing'),
            child: const Text('Merge into existing'),
          ),
        ],
      ),
    );
    if (direction == null) return;
    final mergeIntoExisting = direction == 'existing';
    await _confirmMerge(
      canonicalQuestionId: mergeIntoExisting
          ? candidate.canonicalQuestionId
          : current.id,
      duplicateQuestionId: mergeIntoExisting
          ? current.id
          : candidate.canonicalQuestionId,
      canonicalAnswerId: mergeIntoExisting
          ? candidate.answerId
          : current.acceptedAnswer?.id,
    );
  }

  Future<void> _confirmMerge({
    required String canonicalQuestionId,
    required String duplicateQuestionId,
    String? canonicalAnswerId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge questions?'),
        content: const Text(
          'These questions will share one canonical answer.\n\nOriginal questions and history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => ref
          .read(governanceRepositoryProvider)
          .merge(
            canonicalQuestionId: canonicalQuestionId,
            duplicateQuestionIds: [duplicateQuestionId],
            canonicalAnswerId: canonicalAnswerId,
            reason: 'Merged after duplicate comparison',
          ),
      'Questions merged. Original history was preserved.',
    );
    ref.invalidate(duplicateCandidatesProvider);
  }

  Future<void> _unmerge(QuestionDetail question) async {
    await _runAction(
      () => ref
          .read(governanceRepositoryProvider)
          .unmerge(question.id, 'Corrected canonical association'),
      'Question restored as independent.',
    );
  }

  Future<void> _reportDuplicate(QuestionDetail question) async {
    try {
      final candidates = await ref
          .read(governanceRepositoryProvider)
          .duplicateCandidates(question.id);
      if (!mounted) return;
      if (candidates.isEmpty) {
        _showError(Object(), 'No likely existing questions were found.');
        return;
      }
      final selected = await showDialog<SemanticSearchResult>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Already answered elsewhere?'),
          children: [
            for (final candidate in candidates)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, candidate),
                child: Text(candidate.canonicalTitle),
              ),
          ],
        ),
      );
      if (selected == null) return;
      await _runAction(
        () => ref
            .read(governanceRepositoryProvider)
            .suggestDuplicate(
              questionId: question.id,
              canonicalQuestionId: selected.canonicalQuestionId,
              reason: 'Reported from question detail',
            ),
        'Duplicate report added to the review queue.',
      );
    } catch (error) {
      _showError(error, 'Unable to report this duplicate.');
    }
  }

  Future<void> _submitAnswer() async {
    final body = _answerController.text.trim();
    if (body.isEmpty) return;
    await _runAction(
      () => ref
          .read(questionsRepositoryProvider)
          .createAnswer(widget.questionId, body),
      'Answer submitted.',
      onSuccess: _answerController.clear,
    );
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    await _runAction(
      () => ref
          .read(questionsRepositoryProvider)
          .createComment(widget.questionId, body),
      'Comment added.',
      onSuccess: _commentController.clear,
    );
  }

  Future<void> _react(String answerId, String reaction) async {
    await _runAction(
      () => ref.read(questionsRepositoryProvider).react(answerId, reaction),
      'Feedback recorded.',
    );
  }

  Future<void> _govern(String answerId, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'verify' ? 'Verify answer?' : 'Review as current?',
        ),
        content: Text(
          action == 'verify'
              ? 'This becomes the department’s current verified answer.'
              : 'This renews the review period without creating a content version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action == 'verify' ? 'Verify' : 'Confirm review'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = ref.read(governanceRepositoryProvider);
    await _runAction(
      () => action == 'verify'
          ? repository.verify(answerId)
          : repository.review(answerId),
      action == 'verify' ? 'Answer verified.' : 'Review date renewed.',
    );
  }

  Future<void> _showChallengeDialog(AnswerDetail answer) async {
    var type = 'suggest_update';
    final reason = TextEditingController();
    final replacement = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Suggest an update'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Issue type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'outdated',
                      child: Text('Outdated'),
                    ),
                    DropdownMenuItem(
                      value: 'incorrect',
                      child: Text('Incorrect'),
                    ),
                    DropdownMenuItem(value: 'unclear', child: Text('Unclear')),
                    DropdownMenuItem(
                      value: 'incomplete',
                      child: Text('Incomplete'),
                    ),
                    DropdownMenuItem(
                      value: 'suggest_update',
                      child: Text('Suggest update'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => type = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'What needs attention?',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: replacement,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Suggested replacement (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, reason.text.trim().isNotEmpty),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      await _runAction(
        () => ref
            .read(governanceRepositoryProvider)
            .challenge(
              answerId: answer.id,
              type: type,
              reason: reason.text.trim(),
              suggestedAnswer: replacement.text.trim(),
            ),
        'Update submitted for review.',
      );
    }
    reason.dispose();
    replacement.dispose();
  }

  Future<void> _showHistory(AnswerDetail answer) async {
    try {
      final versions = await ref
          .read(governanceRepositoryProvider)
          .versions(answer.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Answer history'),
          content: SizedBox(
            width: 560,
            child: versions.isEmpty
                ? const Text('No verified versions yet.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: versions.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final version = versions[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'v${version.versionNumber} · ${version.status}',
                        ),
                        subtitle: Text(
                          [
                            version.body,
                            '${version.changedBy.displayName} · ${_formatDate(version.createdAt)}',
                            ?version.reason,
                          ].join('\n'),
                        ),
                      );
                    },
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
    } catch (error) {
      _showError(error, 'Unable to load answer history.');
    }
  }

  Future<void> _showChallenges(AnswerDetail answer) async {
    try {
      final items = await ref
          .read(governanceRepositoryProvider)
          .challenges(answer.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Answer challenges'),
          content: SizedBox(
            width: 560,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) => _ChallengeRow(
                challenge: items[index],
                onDecision: items[index].status == 'open'
                    ? (accept) {
                        Navigator.pop(dialogContext);
                        _decideChallenge(items[index], accept);
                      }
                    : null,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error, 'Unable to load challenges.');
    }
  }

  Future<void> _decideChallenge(AnswerChallenge challenge, bool accept) async {
    final replacement = TextEditingController(text: challenge.suggestedAnswer);
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Accept challenge' : 'Reject challenge'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (accept)
                TextField(
                  controller: replacement,
                  minLines: 3,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Replacement answer (optional)',
                  ),
                ),
              if (accept) const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Reviewer note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept ? 'Accept' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(
        () => ref
            .read(governanceRepositoryProvider)
            .decideChallenge(
              challenge.id,
              accept: accept,
              reviewerNote: note.text.trim(),
              replacementBody: replacement.text.trim(),
            ),
        accept ? 'Challenge accepted.' : 'Challenge rejected.',
      );
      ref.invalidate(reviewQueueProvider);
    }
    replacement.dispose();
    note.dispose();
  }

  void _showError(Object error, String fallback) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error is ApiException ? error.message : fallback)),
    );
  }

  Future<void> _editQuestion(QuestionDetail question) async {
    try {
      final departments = await ref.read(departmentsProvider.future);
      final teams = await ref.read(teamsProvider.future);
      if (!mounted) return;
      final result = await showDialog<_QuestionEditResult>(
        context: context,
        builder: (context) => _QuestionEditDialog(
          question: question,
          departments: departments,
          teams: teams,
        ),
      );
      if (result == null) return;
      await _runAction(
        () => ref
            .read(questionsRepositoryProvider)
            .updateQuestion(
              question.id,
              title: result.title,
              body: result.body,
              departmentId: result.departmentId,
              teamId: result.teamId,
            ),
        'Question updated.',
      );
    } catch (error) {
      _showError(error, 'Unable to load question options.');
    }
  }

  Future<void> _archiveQuestion(QuestionDetail question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive question?'),
        content: const Text(
          'The question will leave active lists but remain available for history and governance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isMutating = true);
    try {
      await ref.read(questionsRepositoryProvider).archiveQuestion(question.id);
      ref.invalidate(questionsProvider);
      if (!mounted) return;
      context.go('/questions');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Question archived.')));
    } catch (error) {
      _showError(error, 'Unable to archive this question.');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage, {
    VoidCallback? onSuccess,
  }) async {
    setState(() => _isMutating = true);
    try {
      await action();
      onSuccess?.call();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'Unable to complete that action. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(questionsProvider);
    ref.invalidate(commentsProvider(widget.questionId));
    ref.invalidate(questionDetailProvider(widget.questionId));
    await ref.read(questionDetailProvider(widget.questionId).future);
  }
}

class _QuestionEditResult {
  const _QuestionEditResult({
    required this.title,
    required this.body,
    required this.departmentId,
    required this.teamId,
  });

  final String title;
  final String? body;
  final String? departmentId;
  final String? teamId;
}

class _QuestionEditDialog extends StatefulWidget {
  const _QuestionEditDialog({
    required this.question,
    required this.departments,
    required this.teams,
  });

  final QuestionDetail question;
  final List<DepartmentSummary> departments;
  final List<TeamSummary> teams;

  @override
  State<_QuestionEditDialog> createState() => _QuestionEditDialogState();
}

class _QuestionEditDialogState extends State<_QuestionEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late String? _departmentId;
  late String? _teamId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.question.title);
    _bodyController = TextEditingController(text: widget.question.body ?? '');
    _departmentId = widget.question.department?.id;
    _teamId = widget.question.team?.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit question'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Question'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'Detail'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _departmentId,
                decoration: const InputDecoration(labelText: 'Department'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No department'),
                  ),
                  for (final department in widget.departments)
                    DropdownMenuItem(
                      value: department.id,
                      child: Text(department.name),
                    ),
                ],
                onChanged: (value) => setState(() => _departmentId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _teamId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Team'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No team')),
                  for (final team in widget.teams.where(
                    (team) => team.status != 'inactive',
                  ))
                    DropdownMenuItem(
                      value: team.id,
                      child: Text(
                        team.department == null
                            ? team.name
                            : '${team.department!.name} · ${team.name}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _teamId = value;
                  _departmentId = suggestedDepartmentForTeam(
                    widget.teams,
                    value,
                    _departmentId,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _titleController.text.trim().isEmpty
              ? null
              : () {
                  final body = _bodyController.text.trim();
                  Navigator.pop(
                    context,
                    _QuestionEditResult(
                      title: _titleController.text.trim(),
                      body: body.isEmpty ? null : body,
                      departmentId: _departmentId,
                      teamId: _teamId,
                    ),
                  );
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AnswerView extends StatelessWidget {
  const _AnswerView({
    required this.answer,
    required this.accepted,
    required this.onHelpful,
    required this.onNotHelpful,
    required this.onChallenge,
    required this.onHistory,
    this.onAccept,
    this.onVerify,
    this.onReview,
    this.onChallenges,
  });

  final AnswerDetail answer;
  final bool accepted;
  final VoidCallback onHelpful;
  final VoidCallback onNotHelpful;
  final VoidCallback onChallenge;
  final VoidCallback onHistory;
  final VoidCallback? onAccept;
  final VoidCallback? onVerify;
  final VoidCallback? onReview;
  final VoidCallback? onChallenges;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: accepted ? const Color(0xFFE9F2EE) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: accepted ? const Color(0xFF255C57) : const Color(0xFFC8BDA7),
            width: accepted ? 4 : 1,
          ),
          bottom: const BorderSide(color: Color(0xFFD8D0C2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(answer.body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          _AnswerMetadata(answer: answer),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: onHelpful,
                icon: const Icon(Icons.thumb_up_outlined, size: 18),
                label: Text('Helpful ${answer.helpfulCount}'),
              ),
              TextButton.icon(
                onPressed: onNotHelpful,
                icon: const Icon(Icons.thumb_down_outlined, size: 18),
                label: Text('Not helpful ${answer.notHelpfulCount}'),
              ),
              if (onAccept != null)
                TextButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Accept answer'),
                ),
              TextButton.icon(
                onPressed: onChallenge,
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: const Text('Suggest update'),
              ),
              TextButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('History'),
              ),
              if (onVerify != null)
                TextButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Verify'),
                ),
              if (onReview != null)
                TextButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: const Text('Review as current'),
                ),
              if (onChallenges != null)
                TextButton.icon(
                  onPressed: onChallenges,
                  icon: const Icon(Icons.report_outlined, size: 18),
                  label: Text('Challenges ${answer.challengeCount}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnswerMetadata extends StatelessWidget {
  const _AnswerMetadata({required this.answer});

  final AnswerDetail answer;

  @override
  Widget build(BuildContext context) {
    final governanceLabel = switch (answer.freshnessStatus) {
      'review_due_soon' || 'overdue' => 'Review due',
      'challenged' => 'Update under review',
      _ when answer.status == 'verified' => 'Verified',
      _ => 'Community answer',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          answer.author.displayName,
          style: const TextStyle(color: Colors.black54),
        ),
        Text(
          governanceLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (answer.verifiedByUser case final verifier?)
          Text(
            'by ${verifier.displayName}',
            style: const TextStyle(color: Colors.black54),
          ),
        if (answer.reviewDueAt case final due?)
          Text(
            'Review ${_formatDate(due)}',
            style: const TextStyle(color: Colors.black54),
          ),
      ],
    );
  }
}

class _ComparisonColumn extends StatelessWidget {
  const _ComparisonColumn({
    required this.label,
    required this.title,
    this.body,
    this.answer,
    this.status,
    this.department,
    this.resolvedAt,
  });

  final String label;
  final String title;
  final String? body;
  final String? answer;
  final String? status;
  final String? department;
  final DateTime? resolvedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (body case final text? when text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(text),
        ],
        const SizedBox(height: 16),
        Text(
          answer ?? 'No accepted answer',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          [
            ?status,
            ?department,
            if (resolvedAt != null) 'Resolved ${_formatDate(resolvedAt!)}',
          ].join(' · '),
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.challenge, this.onDecision});

  final AnswerChallenge challenge;
  final void Function(bool accept)? onDecision;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${challenge.type.replaceAll('_', ' ')} · ${challenge.status}'),
        const SizedBox(height: 6),
        Text(challenge.reason),
        if (challenge.suggestedAnswer case final suggestion?) ...[
          const SizedBox(height: 6),
          Text('Suggested: $suggestion'),
        ],
        if (onDecision != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => onDecision!(false),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => onDecision!(true),
                child: const Text('Accept'),
              ),
            ],
          ),
      ],
    );
  }
}

String _formatDate(DateTime value) =>
    value.toLocal().toString().split(' ').first;
