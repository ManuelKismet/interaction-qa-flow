import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/platform/print_page.dart';
import 'package:int_qa_flow/features/guided/application/guided_providers.dart';
import 'package:int_qa_flow/features/guided/application/guided_pending_edits.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_report_document.dart';
import 'package:int_qa_flow/features/guided/presentation/guided_scope_dialog.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';

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
  GuidedPendingEdits? _drafts;

  @override
  void didUpdateWidget(covariant GuidedSessionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      final drafts = _drafts;
      if (drafts != null) unawaited(Future<void>.microtask(drafts.flush));
      _drafts = null;
      _participantId = null;
      _saveState = GuidedSaveState.idle;
      _reportMode = false;
      _allParticipantsReport = false;
    }
  }

  @override
  void dispose() {
    final drafts = _drafts;
    if (drafts != null) unawaited(Future<void>.microtask(drafts.flush));
    super.dispose();
  }

  GuidedSessionQuery get _query => (
    sessionId: widget.sessionId,
    participantId: _allParticipantsReport ? null : _participantId,
    viewMode: _reportMode ? GuidedViewMode.allRelevant : _viewMode,
  );

  void _refresh() => ref.invalidate(guidedSessionProvider);

  void _editing() {
    if (mounted) setState(() => _saveState = GuidedSaveState.editing);
  }

  Future<void> _save(Future<void> Function() operation) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    if (mounted) setState(() => _saveState = GuidedSaveState.saving);
    try {
      await _drafts?.flush();
      if (!_isCurrent(repository, sessionId)) return;
      if (_drafts?.error != null || _drafts?.isBusy == true) {
        setState(() => _saveState = GuidedSaveState.failed);
        return;
      }
      await operation();
      if (_isCurrent(repository, sessionId)) {
        setState(() => _saveState = GuidedSaveState.saved);
        _refresh();
      }
    } catch (error) {
      if (_isCurrent(repository, sessionId)) {
        setState(() => _saveState = GuidedSaveState.failed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not saved: $error')),
        );
        if (error is GuidedConflict) _refresh();
      }
    }
  }

  bool _isCurrent(GuidedRepository repository, String sessionId) {
    if (!mounted || widget.sessionId != sessionId) return false;
    try {
      repository.ensureCurrent();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<T?> _readCurrent<T>(
    GuidedRepository repository,
    String sessionId,
    Future<T> Function() read,
  ) async {
    try {
      final result = await read();
      return _isCurrent(repository, sessionId) ? result : null;
    } catch (error) {
      if (_isCurrent(repository, sessionId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load this session action: $error')),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(guidedSessionProvider(_query));
    final membershipState = ref.watch(currentMembershipProvider);
    final membership = membershipState.isLoading || membershipState.hasError
        ? null : membershipState.value;
    final authorityState = ref.watch(organisationProfileProvider);
    final authority = authorityState.isLoading || authorityState.hasError
        ? null : authorityState.value;
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
        final canEditSession = session.status != 'archived' &&
            authority != null && membership != null &&
            authority.userId == membership.userId &&
            authority.organisationId == membership.organisationId &&
            (membership.userId == session.createdById ||
                ((authority.isOwner ||
                        authority.permissions.contains('legacy_admin')) &&
                    session.visibility != 'private'));
        final drafts = canEditSession
            ? ref.watch(guidedPendingEditsProvider(session.id))
            : null;
        if (!canEditSession && authority != null && membership != null) {
          _drafts?.suspend();
        }
        if (_drafts != null && !identical(_drafts, drafts)) {
          _saveState = GuidedSaveState.idle;
        }
        _drafts = drafts;
        drafts?.reconcile(session,
          complete: _query.participantId == null &&
              _query.viewMode == GuidedViewMode.allRelevant);
        if (drafts != null) {
          ref.listen(guidedPendingEditsProvider(session.id), (_, next) {
            if (next.state == GuidedSaveState.saved && mounted) _refresh();
          });
        }
        final participantId = _participantId;
        final repository = drafts?.repository;
        final readOnly = !canEditSession;
        VoidCallback? transition;
        if (canEditSession && session.status == 'draft') {
          transition = () => _transition('start');
        } else if (canEditSession && session.status == 'active') {
          transition = () => _transition('complete');
        }
        if ((_participantId == null ||
                !session.participants.any((item) => item.id == _participantId)) &&
            session.participants.isNotEmpty &&
            !_allParticipantsReport) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.sessionId == session.id &&
                (_participantId == null ||
                    !session.participants.any((item) => item.id == _participantId))) {
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
              saveState: _saveState == GuidedSaveState.saving ||
                      _saveState == GuidedSaveState.failed ||
                      drafts?.state == GuidedSaveState.idle
                  ? _saveState
                  : drafts?.state ?? _saveState,
              reportMode: _reportMode,
              allParticipantsReport: _allParticipantsReport,
              onBack: () => context.go('/guided'),
              onToggleReport: (all) => setState(() {
                _reportMode = !_reportMode || _allParticipantsReport != all;
                _allParticipantsReport = _reportMode && all;
              }),
              onExport: (format) => _export(session, format),
              onHistory: _history,
              onPrint: _reportMode
                  ? () => openPrintableReport(
                      buildGuidedReportDocument(
                        session: session,
                        allParticipants: _allParticipantsReport,
                        participantId: _participantId,
                        generatedAt: DateTime.now(),
                      ),
                    )
                  : null,
              onTransition: transition,
            ),
            if (drafts != null && drafts.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Not saved: ${drafts.error}'),
                    TextButton(
                      onPressed: drafts.isBusy ? null : drafts.retry,
                      child: const Text('Review and retry'),
                    ),
                    if (drafts.conflict)
                      TextButton(
                        onPressed: drafts.isBusy ? null : () {
                          drafts.useServerVersion();
                          _refresh();
                        },
                        child: const Text('Use server version'),
                      ),
                  ],
                ),
              ),
            if (readOnly)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'View-only session. Private sessions can only be edited by their creator. Other sessions allow their creator, an organisation owner or a legacy administrator.',
                    key: ValueKey('guided-session-read-only-notice'),
                  ),
                ),
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
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Active participant',
                        ),
                        selectedItemBuilder: (context) => [
                          for (final participant in session.participants)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                participant.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        items: [
                          for (final participant in session.participants)
                            DropdownMenuItem(
                              value: participant.id,
                              child: Text(
                                participant.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                    if (canEditSession) ...[
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
                      key: ValueKey((session.id, repository)),
                      questions: session.questions,
                      participantId: _participantId,
                      participantName: activeParticipant?.name,
                      readOnly: readOnly,
                      managedDebounce: drafts != null,
                      pendingValues: drafts?.values ?? const {},
                      onEditing: _editing,
                      onSaveQuestion: (question, value) =>
                          drafts?.question(question, value) ?? Future.value(),
                      onSaveAnswer: (question, answer, value) =>
                          drafts != null && participantId != null
                          ? drafts.answer(question, answer, participantId, value)
                          : Future.value(),
                      onAddFollowUp: _addFollowUp,
                      onToggleBranch: (answer) => _save(
                        () => repository!
                            .updateAnswer(
                              answer.id,
                              branchesCollapsed: !answer.branchesCollapsed,
                              expectedRevision: drafts?.revision ?? session.revision,
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
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final controller = TextEditingController();
    final submit = await showGuidedScopedDialog<bool>(
      context: context,
      repository: repository,
      isCurrent: () => _isCurrent(repository, sessionId),
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
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final name = await _textDialog('Add participant', 'Name');
    if (name == null || !_isCurrent(repository, sessionId)) return;
    await _save(() async {
      final participant = await repository.addParticipant(sessionId, name);
      if (_isCurrent(repository, sessionId)) {
        setState(() => _participantId = participant.id);
      }
    });
  }

  Future<void> _addQuestion(String scope) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final participantId = _participantId;
    final text = await _textDialog(
      scope == 'shared' ? 'Add shared question' : 'Add participant question',
      'Question',
    );
    if (text == null || !_isCurrent(repository, sessionId)) return;
    await _save(
      () => repository
          .addQuestion(
            sessionId,
            text,
            scope: scope,
            participantId: scope == 'participant' ? participantId : null,
          ),
    );
  }

  Future<void> _addFollowUp(GuidedAnswer answer) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final text = await _textDialog('Add follow-up', 'Question');
    if (text == null || !_isCurrent(repository, sessionId)) return;
    await _save(
      () => repository.addFollowUp(answer.id, text),
    );
  }

  Future<void> _deleteQuestion(GuidedQuestion question) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    await _drafts?.flush();
    if (!_isCurrent(repository, sessionId) || _drafts?.error != null) return;
    await _save(() => repository.setQuestionDeleted(question.id, true));
    if (!_isCurrent(repository, sessionId) || _saveState != GuidedSaveState.saved) return;
    _refresh();
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
            if (!_isCurrent(repository, sessionId)) return;
            await _save(() => repository.setQuestionDeleted(question.id, false));
            if (_isCurrent(repository, sessionId)) _refresh();
          },
        ),
      ),
    );
  }

  Future<void> _knowledgeSearch(GuidedQuestion question) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final results = await _readCurrent(repository, sessionId,
      () => repository.searchKnowledge(question.id));
    if (results == null || !_isCurrent(repository, sessionId)) return;
    await showGuidedScopedDialog<void>(
      context: context,
      repository: repository,
      isCurrent: () => _isCurrent(repository, sessionId),
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
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    await _save(() => repository.proposeKnowledge(question, answer));
    if (_isCurrent(repository, sessionId) && _saveState == GuidedSaveState.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent to Knowledge review.')),
      );
    }
  }

  Future<void> _transition(String action) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    await _save(() => repository.transition(sessionId, action));
    if (_isCurrent(repository, sessionId)) invalidateGuidedLists(ref);
  }

  Future<void> _export(GuidedSessionDetail session, String format) async {
    final repository = ref.read(guidedRepositoryProvider);
    final contents = await _readCurrent(repository, session.id,
      () => repository.exportSession(session.id, format));
    if (contents == null || !_isCurrent(repository, session.id)) return;
    await showGuidedScopedDialog<void>(
      context: context,
      repository: repository,
      isCurrent: () => _isCurrent(repository, session.id),
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
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final revisions = await _readCurrent(repository, sessionId,
      () => repository.revisions(sessionId));
    if (revisions == null || !_isCurrent(repository, sessionId)) return;
    await showGuidedScopedDialog<void>(
      context: context,
      repository: repository,
      isCurrent: () => _isCurrent(repository, sessionId),
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
    final backButton = IconButton(
      tooltip: 'Back to Interact',
      icon: const Icon(Icons.arrow_back),
      onPressed: onBack,
    );
    final sessionTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          [
            session.status,
            session.visibility,
            if (session.ownerText?.isNotEmpty == true) session.ownerText!,
            if (session.contextReference?.isNotEmpty == true)
              session.contextReference!,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final actions = <Widget>[
      if (saveLabel.isNotEmpty)
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
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    backButton,
                    const SizedBox(width: 8),
                    Expanded(child: sessionTitle),
                  ],
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ],
            );
          }
          return Row(
            children: [
              backButton,
              const SizedBox(width: 8),
              Expanded(child: sessionTitle),
              ...actions,
            ],
          );
        },
      ),
    );
  }
}

class GuidedFlowView extends StatelessWidget {
  const GuidedFlowView({
    required this.questions,
    required this.participantId,
    required this.participantName,
    this.readOnly = false,
    this.managedDebounce = false,
    this.pendingValues = const {},
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
  final bool readOnly;
  final bool managedDebounce;
  final Map<String, String> pendingValues;
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
    final visibleQuestions = <_VisibleGuidedQuestion>[];
    void append(
      GuidedQuestion question, {
      required int depth,
      required List<int> path,
      String? parentText,
    }) {
      visibleQuestions.add(
        _VisibleGuidedQuestion(
          question: question,
          depth: depth,
          path: path,
          parentText: parentText,
        ),
      );
      final answer = question.answerFor(participantId);
      if (question.followUps.isEmpty ||
          (answer?.branchesCollapsed ?? false)) {
        return;
      }
      for (final (index, followUp) in question.followUps.indexed) {
        append(
          followUp,
          depth: depth + 1,
          path: [...path, index + 1],
          parentText: question.text,
        );
      }
    }

    for (final (index, question) in questions.indexed) {
      append(question, depth: 0, path: [index + 1]);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          key: const ValueKey('guided-flow-list'),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
          children: [
            for (final visible in visibleQuestions)
              GuidedQuestionNode(
                question: visible.question,
                participantId: participantId!,
                participantName: participantName ?? 'Participant',
                readOnly: readOnly,
                managedDebounce: managedDebounce,
                pendingValues: pendingValues,
                depth: visible.depth,
                path: visible.path,
                parentText: visible.parentText,
                onEditing: onEditing,
                onSaveQuestion: onSaveQuestion,
                onSaveAnswer: onSaveAnswer,
                onAddFollowUp: onAddFollowUp,
                onToggleBranch: onToggleBranch,
                onDelete: onDelete,
                onKnowledgeSearch: onKnowledgeSearch,
                onPropose: onPropose,
              ),
          ],
        ),
      ),
    );
  }
}

class _VisibleGuidedQuestion {
  const _VisibleGuidedQuestion({
    required this.question,
    required this.depth,
    required this.path,
    required this.parentText,
  });

  final GuidedQuestion question;
  final int depth;
  final List<int> path;
  final String? parentText;
}

class GuidedQuestionNode extends StatelessWidget {
  const GuidedQuestionNode({
    required this.question,
    required this.participantId,
    required this.participantName,
    this.readOnly = false,
    this.managedDebounce = false,
    this.pendingValues = const {},
    required this.depth,
    required this.path,
    required this.parentText,
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
  final bool readOnly;
  final bool managedDebounce;
  final Map<String, String> pendingValues;
  final int depth;
  final List<int> path;
  final String? parentText;
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
    return _CappedBranchIndent(
      depth: depth,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if (!readOnly) ...[
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
                    ],
                  ),
                  Text(
                    'Path ${path.join('.')} · $label',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  if (parentText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Parent: $parentText',
                        softWrap: true,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (readOnly)
                    Text(
                      question.text,
                      style: Theme.of(context).textTheme.titleMedium,
                    )
                  else
                    _DebouncedField(
                      key: ValueKey('question-${question.id}'),
                      initialValue: pendingValues[GuidedPendingEdits.questionKey(question.id)] ?? question.text,
                      managedDebounce: managedDebounce,
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
                  if (readOnly)
                    Text(
                      answer?.body.isNotEmpty == true
                          ? answer!.body
                          : 'No answer recorded.',
                    )
                  else
                    _DebouncedField(
                      key: ValueKey(
                        'answer-${question.id}-$participantId',
                      ),
                      initialValue: pendingValues[GuidedPendingEdits.answerKey(question.id, participantId)] ?? answer?.body ?? '',
                      managedDebounce: managedDebounce,
                      allowBlank: true,
                      minLines: 2,
                      hintText: 'Record $participantName’s answer...',
                      onEditing: onEditing,
                      onSave: (value) => onSaveAnswer(question, answer, value),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (!readOnly) ...[
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
                          onPressed:
                              answer == null || answer.body.trim().isEmpty
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
                      if (question.followUps.isNotEmpty && answer != null)
                        Text('${question.followUps.length} follow-ups'),
                    ],
                  ),
                  if (question.followUps.isNotEmpty &&
                      !(answer?.branchesCollapsed ?? false)) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_left, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              parentText == null
                                  ? 'Return to main path'
                                  : 'Return to parent · $parentText',
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
        ),
      ),
    );
  }
}

class _CappedBranchIndent extends StatelessWidget {
  const _CappedBranchIndent({required this.depth, required this.child});

  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final cap = constraints.maxWidth.isFinite
              ? (constraints.maxWidth * 0.02).clamp(0.0, 8.0)
              : 8.0;
          final indent = (depth * 4.0).clamp(0.0, cap).toDouble();
          return Padding(
            padding: EdgeInsets.only(left: indent),
            child: child,
          );
        },
      );
}

class _DebouncedField extends StatefulWidget {
  const _DebouncedField({
    required this.initialValue,
    required this.onEditing,
    required this.onSave,
    required this.minLines,
    this.hintText,
    this.style,
    this.allowBlank = false,
    this.managedDebounce = false,
    super.key,
  });

  final String initialValue;
  final VoidCallback onEditing;
  final Future<void> Function(String) onSave;
  final int minLines;
  final String? hintText;
  final TextStyle? style;
  final bool allowBlank;
  final bool managedDebounce;

  @override
  State<_DebouncedField> createState() => _DebouncedFieldState();
}

class _DebouncedFieldState extends State<_DebouncedField> {
  Timer? _timer;
  String? _pending;
  String? _error;
  bool _saving = false;
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _timer?.cancel();
    if (!widget.managedDebounce && _pending != null) {
      unawaited(_savePending());
    }
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    widget.onEditing();
    _pending = value;
    setState(() => _error = null);
    _timer?.cancel();
    if (widget.managedDebounce) {
      unawaited(widget.onSave(value));
    } else {
      _timer = Timer(const Duration(milliseconds: 650), _savePending);
    }
  }

  @override
  void didUpdateWidget(covariant _DebouncedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue == _controller.text) {
      _pending = null;
    } else if (_pending == null && !_saving) {
      _controller.text = widget.initialValue;
    } else if (oldWidget.initialValue != widget.initialValue) {
      _error = 'Changed on the server. Your edit is retained.';
      _timer?.cancel();
    }
  }

  Future<void> _savePending() async {
    final value = _pending;
    if (value == null || _saving) return;
    if (!widget.allowBlank && value.trim().isEmpty) {
      if (mounted) setState(() => _error = 'Question title cannot be blank.');
      return;
    }
    final save = widget.onSave;
    _saving = true;
    try {
      await save(value);
      if (_pending == value) _pending = null;
    } catch (_) {
      if (mounted) setState(() => _error = 'Not saved. Please retry.');
    } finally {
      _saving = false;
      if (mounted && _pending != null && _error == null) {
        _timer = Timer(const Duration(milliseconds: 650), _savePending);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: widget.minLines,
      maxLines: null,
      style: widget.style,
      decoration: InputDecoration(hintText: widget.hintText, isDense: true, errorText: _error),
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
    final visibleQuestions = <_VisibleReportQuestion>[];
    void append(
      GuidedQuestion question, {
      required int depth,
      required List<int> path,
      String? parentText,
    }) {
      visibleQuestions.add(
        _VisibleReportQuestion(
          question: question,
          depth: depth,
          path: path,
          parentText: parentText,
        ),
      );
      for (final (index, followUp) in question.followUps.indexed) {
        append(
          followUp,
          depth: depth + 1,
          path: [...path, index + 1],
          parentText: question.text,
        );
      }
    }

    for (final (index, question) in session.questions.indexed) {
      append(question, depth: 0, path: [index + 1]);
    }
    return ListView(
      key: const ValueKey('guided-report-list'),
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
        for (final visible in visibleQuestions)
          _ReportQuestion(
            question: visible.question,
            participants: session.participants,
            depth: visible.depth,
            path: visible.path,
            parentText: visible.parentText,
          ),
      ],
    );
  }
}

class _VisibleReportQuestion {
  const _VisibleReportQuestion({
    required this.question,
    required this.depth,
    required this.path,
    required this.parentText,
  });

  final GuidedQuestion question;
  final int depth;
  final List<int> path;
  final String? parentText;
}

class _ReportQuestion extends StatelessWidget {
  const _ReportQuestion({
    required this.question,
    required this.participants,
    required this.depth,
    required this.path,
    required this.parentText,
  });
  final GuidedQuestion question;
  final List<GuidedParticipant> participants;
  final int depth;
  final List<int> path;
  final String? parentText;

  @override
  Widget build(BuildContext context) {
    String participantName(String id) =>
        participants.where((item) => item.id == id).firstOrNull?.name ??
        'Participant';
    return _CappedBranchIndent(
      depth: depth,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Path ${path.join('.')} · ${depth == 0 ? 'Question' : 'Follow-up'}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              if (parentText != null)
                Text(
                  'Parent: $parentText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              Text(
                question.text,
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
            ],
          ),
        ),
      ),
    );
  }
}
