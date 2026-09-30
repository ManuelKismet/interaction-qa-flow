import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/platform/print_page.dart';
import 'package:int_qa_flow/features/guided/application/guided_providers.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';

class GuidedSessionPage extends ConsumerStatefulWidget {
  const GuidedSessionPage({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<GuidedSessionPage> createState() => _GuidedSessionPageState();
}

class _GuidedSessionPageState extends ConsumerState<GuidedSessionPage> {
  String? _participantId;
  GuidedViewMode _viewMode = GuidedViewMode.allRelevant;
  GuidedSaveState _saveState = GuidedSaveState.idle;
  bool _reportMode = false;
  bool _allParticipantsReport = false;

  GuidedSessionQuery get _query => (
    sessionId: widget.sessionId,
    participantId: _allParticipantsReport ? null : _participantId,
    viewMode: _viewMode,
  );

  void _refresh() => ref.invalidate(guidedSessionProvider);

  void _editing() {
    if (mounted) setState(() => _saveState = GuidedSaveState.editing);
  }

  Future<void> _save(Future<void> Function() operation) async {
    if (mounted) setState(() => _saveState = GuidedSaveState.saving);
    try {
      await operation();
      if (mounted) setState(() => _saveState = GuidedSaveState.saved);
      _refresh();
    } catch (_) {
      if (mounted) setState(() => _saveState = GuidedSaveState.failed);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(guidedSessionProvider(_query));
    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to load this Interact session.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
          ],
        ),
      ),
      data: (session) {
        if (_participantId == null &&
            session.participants.isNotEmpty &&
            !_allParticipantsReport) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _participantId == null) {
              setState(() => _participantId = session.participants.first.id);
            }
          });
        }
        final activeParticipant = session.participants
            .where((item) => item.id == _participantId)
            .firstOrNull;
        final answered = _countAnswered(session.questions, _participantId);
        return Column(
          children: [
            _SessionHeader(
              session: session,
              saveState: _saveState,
              reportMode: _reportMode,
              allParticipantsReport: _allParticipantsReport,
              onBack: () => context.go('/guided'),
              onToggleReport: (all) => setState(() {
                _reportMode = !_reportMode || _allParticipantsReport != all;
                _allParticipantsReport = _reportMode && all;
              }),
              onExport: (format) => _export(session, format),
              onHistory: _history,
              onPrint: _reportMode ? printCurrentPage : null,
              onTransition: session.status == 'draft'
                  ? () => _transition('start')
                  : session.status == 'active'
                  ? () => _transition('complete')
                  : null,
            ),
            if (!_reportMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 230,
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey(_participantId),
                        initialValue: _participantId,
                        decoration: const InputDecoration(
                          labelText: 'Active participant',
                        ),
                        items: [
                          for (final participant in session.participants)
                            DropdownMenuItem(
                              value: participant.id,
                              child: Text(participant.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _participantId = value),
                      ),
                    ),
                    SegmentedButton<GuidedViewMode>(
                      segments: [
                        for (final mode in GuidedViewMode.values)
                          ButtonSegment(value: mode, label: Text(mode.label)),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (selection) =>
                          setState(() => _viewMode = selection.first),
                    ),
                    Text(
                      '$answered of ${session.preparedQuestionCount} prepared answered',
                    ),
                    Text('${session.followUpCount} follow-ups'),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Add participant'),
                      onPressed: () => _addParticipant(),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Shared question'),
                      onPressed: () => _addQuestion('shared'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Participant question'),
                      onPressed: activeParticipant == null
                          ? null
                          : () => _addQuestion('participant'),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: _reportMode
                  ? GuidedReportView(
                      session: session,
                      allParticipants: _allParticipantsReport,
                    )
                  : GuidedFlowView(
                      questions: session.questions,
                      participantId: _participantId,
                      participantName: activeParticipant?.name,
                      onEditing: _editing,
                      onSaveQuestion: (question, value) => _save(
                        () => ref
                            .read(guidedRepositoryProvider)
                            .updateQuestion(question.id, value),
                      ),
                      onSaveAnswer: (question, answer, value) => _save(() {
                        if (_participantId == null) return Future.value();
                        if (answer == null) {
                          return ref
                              .read(guidedRepositoryProvider)
                              .saveAnswer(
                                questionId: question.id,
                                participantId: _participantId!,
                                body: value,
                              );
                        }
                        return ref
                            .read(guidedRepositoryProvider)
                            .updateAnswer(answer.id, body: value);
                      }),
                      onAddFollowUp: _addFollowUp,
                      onToggleBranch: (answer) => _save(
                        () => ref
                            .read(guidedRepositoryProvider)
                            .updateAnswer(
                              answer.id,
                              branchesCollapsed: !answer.branchesCollapsed,
                            ),
                      ),
                      onDelete: _deleteQuestion,
                      onKnowledgeSearch: _knowledgeSearch,
                      onPropose: _propose,
                    ),
            ),
          ],
        );
      },
    );
  }

  int _countAnswered(List<GuidedQuestion> questions, String? participantId) {
    return questions.where((question) => question.source != 'follow_up').where((
      question,
    ) {
      final answer = question.answerFor(participantId);
      return answer != null && answer.body.trim().isNotEmpty;
    }).length;
  }

  Future<String?> _textDialog(String title, String label) async {
    final controller = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final value = controller.text.trim();
    return submit == true && value.isNotEmpty ? value : null;
  }

  Future<void> _addParticipant() async {
    final name = await _textDialog('Add participant', 'Name');
    if (name == null) return;
    final participant = await ref
        .read(guidedRepositoryProvider)
        .addParticipant(widget.sessionId, name);
    _refresh();
    setState(() => _participantId = participant.id);
  }

  Future<void> _addQuestion(String scope) async {
    final text = await _textDialog(
      scope == 'shared' ? 'Add shared question' : 'Add participant question',
      'Question',
    );
    if (text == null) return;
    await _save(
      () => ref
          .read(guidedRepositoryProvider)
          .addQuestion(
            widget.sessionId,
            text,
            scope: scope,
            participantId: scope == 'participant' ? _participantId : null,
          ),
    );
  }

  Future<void> _addFollowUp(GuidedAnswer answer) async {
    final text = await _textDialog('Add follow-up', 'Question');
    if (text == null) return;
    await _save(
      () => ref.read(guidedRepositoryProvider).addFollowUp(answer.id, text),
    );
  }

  Future<void> _deleteQuestion(GuidedQuestion question) async {
    await ref
        .read(guidedRepositoryProvider)
        .setQuestionDeleted(question.id, true);
    _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          question.source == 'follow_up'
              ? 'Follow-up deleted'
              : 'Question deleted',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ref
                .read(guidedRepositoryProvider)
                .setQuestionDeleted(question.id, false);
            _refresh();
          },
        ),
      ),
    );
  }

  Future<void> _knowledgeSearch(GuidedQuestion question) async {
    final results = await ref
        .read(guidedRepositoryProvider)
        .searchKnowledge(question.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IntQAFlow Knowledge'),
        content: SizedBox(
          width: 600,
          child: results.isEmpty
              ? const Text('No related Knowledge found.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final result in results)
                      ListTile(
                        title: Text(result.title),
                        subtitle: Text(
                          result.acceptedAnswerBody ?? 'Answer unavailable.',
                        ),
                        trailing: Text('${(result.similarity * 100).round()}%'),
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

  Future<void> _propose(GuidedQuestion question, GuidedAnswer answer) async {
    await ref.read(guidedRepositoryProvider).proposeKnowledge(question, answer);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent to Knowledge review.')),
      );
    }
  }

  Future<void> _transition(String action) async {
    await ref
        .read(guidedRepositoryProvider)
        .transition(widget.sessionId, action);
    invalidateGuidedLists(ref);
    _refresh();
  }

  Future<void> _export(GuidedSessionDetail session, String format) async {
    final contents = await ref
        .read(guidedRepositoryProvider)
        .exportSession(session.id, format);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${format.toUpperCase()} export'),
        content: SizedBox(
          width: 700,
          height: 420,
          child: SingleChildScrollView(child: SelectableText(contents)),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
            onPressed: () => Clipboard.setData(ClipboardData(text: contents)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _history() async {
    final revisions = await ref
        .read(guidedRepositoryProvider)
        .revisions(widget.sessionId);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save history'),
        content: SizedBox(
          width: 480,
          child: revisions.isEmpty
              ? const Text('No revisions yet.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final revision in revisions)
                      ListTile(
                        title: Text(revision.change),
                        subtitle: Text(
                          'Revision ${revision.revisionNumber} · ${revision.createdAt.toLocal()}',
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

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.session,
    required this.saveState,
    required this.reportMode,
    required this.allParticipantsReport,
    required this.onBack,
    required this.onToggleReport,
    required this.onExport,
    required this.onHistory,
    required this.onPrint,
    required this.onTransition,
  });

  final GuidedSessionDetail session;
  final GuidedSaveState saveState;
  final bool reportMode;
  final bool allParticipantsReport;
  final VoidCallback onBack;
  final ValueChanged<bool> onToggleReport;
  final ValueChanged<String> onExport;
  final VoidCallback onHistory;
  final VoidCallback? onPrint;
  final VoidCallback? onTransition;

  @override
  Widget build(BuildContext context) {
    final saveLabel = switch (saveState) {
      GuidedSaveState.editing => 'Editing...',
      GuidedSaveState.saving => 'Saving...',
      GuidedSaveState.saved => 'Saved',
      GuidedSaveState.failed => 'Save failed',
      GuidedSaveState.idle => '',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to Interact',
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  [
                    session.status,
                    session.visibility,
                    if (session.ownerText?.isNotEmpty == true)
                      session.ownerText!,
                    if (session.contextReference?.isNotEmpty == true)
                      session.contextReference!,
                  ].join(' · '),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              saveLabel,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          IconButton(
            tooltip: 'Active participant report',
            icon: Icon(
              reportMode && !allParticipantsReport
                  ? Icons.edit_outlined
                  : Icons.description_outlined,
            ),
            onPressed: () => onToggleReport(false),
          ),
          IconButton(
            tooltip: 'All participants report',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => onToggleReport(true),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.download_outlined),
            onSelected: onExport,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'json', child: Text('JSON')),
              PopupMenuItem(value: 'csv', child: Text('CSV')),
            ],
          ),
          IconButton(
            tooltip: 'Save history',
            icon: const Icon(Icons.history),
            onPressed: onHistory,
          ),
          if (onPrint != null)
            IconButton(
              tooltip: 'Print / Save PDF',
              icon: const Icon(Icons.print_outlined),
              onPressed: onPrint,
            ),
          if (onTransition != null)
            FilledButton(
              onPressed: onTransition,
              child: Text(session.status == 'draft' ? 'Start' : 'Complete'),
            ),
        ],
      ),
    );
  }
}

class GuidedFlowView extends StatelessWidget {
  const GuidedFlowView({
    required this.questions,
    required this.participantId,
    required this.participantName,
    required this.onEditing,
    required this.onSaveQuestion,
    required this.onSaveAnswer,
    required this.onAddFollowUp,
    required this.onToggleBranch,
    required this.onDelete,
    required this.onKnowledgeSearch,
    required this.onPropose,
    super.key,
  });

  final List<GuidedQuestion> questions;
  final String? participantId;
  final String? participantName;
  final VoidCallback onEditing;
  final Future<void> Function(GuidedQuestion, String) onSaveQuestion;
  final Future<void> Function(GuidedQuestion, GuidedAnswer?, String)
  onSaveAnswer;
  final ValueChanged<GuidedAnswer> onAddFollowUp;
  final ValueChanged<GuidedAnswer> onToggleBranch;
  final ValueChanged<GuidedQuestion> onDelete;
  final ValueChanged<GuidedQuestion> onKnowledgeSearch;
  final void Function(GuidedQuestion, GuidedAnswer) onPropose;

  @override
  Widget build(BuildContext context) {
    if (participantId == null) {
      return const Center(child: Text('Add or select a participant to begin.'));
    }
    if (questions.isEmpty) {
      return const Center(child: Text('No questions in this view.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
      itemCount: questions.length,
      itemBuilder: (context, index) => GuidedQuestionNode(
        question: questions[index],
        participantId: participantId!,
        participantName: participantName ?? 'Participant',
        depth: 0,
        returnLabel: index + 1 < questions.length
            ? 'Return to main path · ${questions[index + 1].text}'
            : 'End of prepared path',
        onEditing: onEditing,
        onSaveQuestion: onSaveQuestion,
        onSaveAnswer: onSaveAnswer,
        onAddFollowUp: onAddFollowUp,
        onToggleBranch: onToggleBranch,
        onDelete: onDelete,
        onKnowledgeSearch: onKnowledgeSearch,
        onPropose: onPropose,
      ),
    );
  }
}

class GuidedQuestionNode extends StatelessWidget {
  const GuidedQuestionNode({
    required this.question,
    required this.participantId,
    required this.participantName,
    required this.depth,
    required this.returnLabel,
    required this.onEditing,
    required this.onSaveQuestion,
    required this.onSaveAnswer,
    required this.onAddFollowUp,
    required this.onToggleBranch,
    required this.onDelete,
    required this.onKnowledgeSearch,
    required this.onPropose,
    super.key,
  });

  final GuidedQuestion question;
  final String participantId;
  final String participantName;
  final int depth;
  final String returnLabel;
  final VoidCallback onEditing;
  final Future<void> Function(GuidedQuestion, String) onSaveQuestion;
  final Future<void> Function(GuidedQuestion, GuidedAnswer?, String)
  onSaveAnswer;
  final ValueChanged<GuidedAnswer> onAddFollowUp;
  final ValueChanged<GuidedAnswer> onToggleBranch;
  final ValueChanged<GuidedQuestion> onDelete;
  final ValueChanged<GuidedQuestion> onKnowledgeSearch;
  final void Function(GuidedQuestion, GuidedAnswer) onPropose;

  @override
  Widget build(BuildContext context) {
    final answer = question.answerFor(participantId);
    final accent = question.source == 'follow_up'
        ? const Color(0xFF365F9F)
        : question.scope == 'participant'
        ? const Color(0xFF9B4F32)
        : const Color(0xFF255C57);
    final label = question.source == 'follow_up'
        ? 'Follow-up'
        : question.scope == 'participant'
        ? 'Participant-specific'
        : 'Prepared · Shared';
    return Padding(
      padding: EdgeInsets.only(left: depth * 24.0, bottom: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Check Knowledge',
                    icon: const Icon(Icons.manage_search_outlined),
                    onPressed: () => onKnowledgeSearch(question),
                  ),
                  IconButton(
                    tooltip: 'Delete question',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(question),
                  ),
                ],
              ),
              _DebouncedField(
                key: ValueKey('question-${question.id}-${question.text}'),
                initialValue: question.text,
                minLines: 1,
                style: Theme.of(context).textTheme.titleMedium,
                onEditing: onEditing,
                onSave: (value) => onSaveQuestion(question, value),
              ),
              const SizedBox(height: 10),
              Text(
                'Answer · $participantName',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              _DebouncedField(
                key: ValueKey(
                  'answer-${answer?.id ?? question.id}-${answer?.body ?? ''}',
                ),
                initialValue: answer?.body ?? '',
                minLines: 2,
                hintText: 'Record $participantName’s answer...',
                onEditing: onEditing,
                onSave: (value) => onSaveAnswer(question, answer, value),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Add follow-up'),
                    onPressed: answer == null
                        ? null
                        : () => onAddFollowUp(answer),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Propose for Knowledge'),
                    onPressed: answer == null || answer.body.trim().isEmpty
                        ? null
                        : () => onPropose(question, answer),
                  ),
                  if (question.followUps.isNotEmpty && answer != null)
                    TextButton.icon(
                      icon: Icon(
                        answer.branchesCollapsed
                            ? Icons.expand_more
                            : Icons.expand_less,
                      ),
                      label: Text(
                        answer.branchesCollapsed
                            ? 'Expand branch'
                            : 'Collapse branch',
                      ),
                      onPressed: () => onToggleBranch(answer),
                    ),
                ],
              ),
              if (question.followUps.isNotEmpty &&
                  !(answer?.branchesCollapsed ?? false)) ...[
                const SizedBox(height: 8),
                for (final followUp in question.followUps)
                  GuidedQuestionNode(
                    question: followUp,
                    participantId: participantId,
                    participantName: participantName,
                    depth: depth + 1,
                    returnLabel: 'Return to previous path',
                    onEditing: onEditing,
                    onSaveQuestion: onSaveQuestion,
                    onSaveAnswer: onSaveAnswer,
                    onAddFollowUp: onAddFollowUp,
                    onToggleBranch: onToggleBranch,
                    onDelete: onDelete,
                    onKnowledgeSearch: onKnowledgeSearch,
                    onPropose: onPropose,
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_left, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          returnLabel,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DebouncedField extends StatefulWidget {
  const _DebouncedField({
    required this.initialValue,
    required this.onEditing,
    required this.onSave,
    required this.minLines,
    this.hintText,
    this.style,
    super.key,
  });

  final String initialValue;
  final VoidCallback onEditing;
  final Future<void> Function(String) onSave;
  final int minLines;
  final String? hintText;
  final TextStyle? style;

  @override
  State<_DebouncedField> createState() => _DebouncedFieldState();
}

class _DebouncedFieldState extends State<_DebouncedField> {
  Timer? _timer;
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    widget.onEditing();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 650), () {
      if (value != widget.initialValue && value.trim().isNotEmpty) {
        widget.onSave(value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: widget.minLines,
      maxLines: null,
      style: widget.style,
      decoration: InputDecoration(hintText: widget.hintText, isDense: true),
      onChanged: _changed,
    );
  }
}

class GuidedReportView extends StatelessWidget {
  const GuidedReportView({
    required this.session,
    required this.allParticipants,
    super.key,
  });
  final GuidedSessionDetail session;
  final bool allParticipants;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text(session.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Owner: ${session.ownerText ?? 'Not specified'}'),
        Text(
          'Context / reference: ${session.contextReference ?? 'Not specified'}',
        ),
        Text(
          allParticipants
              ? 'All participants report'
              : 'Active participant report',
        ),
        const SizedBox(height: 24),
        for (final question in session.questions)
          _ReportQuestion(
            question: question,
            participants: session.participants,
            depth: 0,
          ),
      ],
    );
  }
}

class _ReportQuestion extends StatelessWidget {
  const _ReportQuestion({
    required this.question,
    required this.participants,
    required this.depth,
  });
  final GuidedQuestion question;
  final List<GuidedParticipant> participants;
  final int depth;

  @override
  Widget build(BuildContext context) {
    String participantName(String id) =>
        participants.where((item) => item.id == id).firstOrNull?.name ??
        'Participant';
    return Padding(
      padding: EdgeInsets.only(left: depth * 24.0, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            depth == 0 ? question.text : 'Follow-up · ${question.text}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          if (question.answers.isEmpty)
            const Text(
              'No answer recorded.',
              style: TextStyle(color: Colors.black54),
            ),
          for (final answer in question.answers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${participantName(answer.participantId)}: ${answer.body.isEmpty ? 'No answer recorded.' : answer.body}',
              ),
            ),
          for (final followUp in question.followUps)
            _ReportQuestion(
              question: followUp,
              participants: participants,
              depth: depth + 1,
            ),
        ],
      ),
    );
  }
}
