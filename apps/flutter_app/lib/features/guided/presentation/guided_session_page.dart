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
  String? _activeName;

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
      if (mounted && _isCurrent(repository, sessionId)) {
        setState(() => _saveState = GuidedSaveState.failed);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Not saved: $error')));
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
      if (mounted && _isCurrent(repository, sessionId)) {
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
        ? null
        : membershipState.value;
    final authorityState = ref.watch(organisationProfileProvider);
    final authority = authorityState.isLoading || authorityState.hasError
        ? null
        : authorityState.value;
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
        final canEditSession =
            session.status != 'archived' &&
            authority != null &&
            membership != null &&
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
        drafts?.reconcile(
          session,
          complete:
              _query.participantId == null &&
              _query.viewMode == GuidedViewMode.allRelevant,
        );
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
                !session.participants.any(
                  (item) => item.id == _participantId,
                )) &&
            session.participants.isNotEmpty &&
            !_allParticipantsReport) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                widget.sessionId == session.id &&
                (_participantId == null ||
                    !session.participants.any(
                      (item) => item.id == _participantId,
                    ))) {
              setState(() => _participantId = session.participants.first.id);
            }
          });
        }
        final activeParticipant = session.participants
            .where((item) => item.id == _participantId)
            .firstOrNull;
        _activeName = activeParticipant?.name;
        final answered = _countAnswered(session.questions, _participantId);
        final topArea = <Widget>[
          _SessionHeader(
            session: session,
            saveState:
                _saveState == GuidedSaveState.saving ||
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
            onLifecycleInfo: () => _lifecycleInfo(session, canEditSession),
            onSessionAction: canEditSession
                ? (action) => _sessionAction(session, action)
                : null,
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
                      onPressed: drafts.isBusy
                          ? null
                          : () {
                              drafts.useServerVersion();
                              _refresh();
                            },
                      child: const Text('Use server version'),
                    ),
                ],
              ),
            ),
          if (session.status == 'archived')
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Archived session: read-only for everyone. Reports and exports remain available; archived sessions cannot be reopened.',
                  key: ValueKey('guided-session-archived-notice'),
                ),
              ),
            )
          else if (readOnly)
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
                  if (canEditSession && activeParticipant != null)
                    PopupMenuButton<String>(
                      tooltip: 'Active participant actions',
                      icon: const Icon(Icons.manage_accounts_outlined),
                      onSelected: (action) => action == 'rename'
                          ? _renameParticipant(activeParticipant)
                          : _removeParticipant(activeParticipant),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename participant'),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove participant'),
                        ),
                      ],
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
                    '$answered of ${session.preparedQuestionCount} questions answered',
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
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            // Keep the session controls bounded so the question list (and
            // its focused field) stays reachable on phones and with the
            // on-screen keyboard open.
            final maxTop = constraints.maxHeight.isFinite
                ? constraints.maxHeight *
                      (constraints.maxHeight < 560 ? 0.4 : 0.6)
                : double.infinity;
            return Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxTop),
                  child: SingleChildScrollView(
                    key: const ValueKey('guided-session-controls'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: topArea,
                    ),
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
                              drafts?.question(question, value) ??
                              Future.value(),
                          onSaveAnswer: (question, answer, value) =>
                              drafts != null && participantId != null
                              ? drafts.answer(
                                  question,
                                  answer,
                                  participantId,
                                  value,
                                )
                              : Future.value(),
                          onAddFollowUp: _addFollowUp,
                          onToggleBranch: (answer) => _save(
                            () => repository!.updateAnswer(
                              answer.id,
                              branchesCollapsed: !answer.branchesCollapsed,
                              expectedRevision:
                                  drafts?.revision ?? session.revision,
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

  Future<String?> _textDialog(
    String title,
    String label, {
    String? hint,
    String initialValue = '',
    String action = 'Add',
    String? message,
  }) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final controller = TextEditingController(text: initialValue);
    final submit = await showGuidedScopedDialog<bool>(
      context: context,
      repository: repository,
      isCurrent: () => _isCurrent(repository, sessionId),
      builder: (context) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[Text(message), const SizedBox(height: 12)],
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label, hintText: hint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
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
    final name = await _textDialog(
      'Add participant',
      'Name',
      hint: 'e.g. Alex (team lead)',
    );
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
      hint: scope == 'shared'
          ? 'e.g. What went well this week?'
          : 'e.g. What support do you need next?',
      message: scope == 'shared'
          ? 'Shared questions are answered separately by every participant.'
          : 'Only ${_activeName ?? 'the active participant'} answers this question.',
    );
    if (text == null || !_isCurrent(repository, sessionId)) return;
    await _save(
      () => repository.addQuestion(
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
    final text = await _textDialog(
      'Add follow-up',
      'Question',
      hint: 'e.g. Can you give an example?',
      message: 'The follow-up belongs to this answer and its participant.',
    );
    if (text == null || !_isCurrent(repository, sessionId)) return;
    await _save(() => repository.addFollowUp(answer.id, text));
  }

  Future<void> _deleteQuestion(GuidedQuestion question) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    await _drafts?.flush();
    if (!_isCurrent(repository, sessionId) || _drafts?.error != null) return;
    await _save(() => repository.setQuestionDeleted(question.id, true));
    if (!mounted ||
        !_isCurrent(repository, sessionId) ||
        _saveState != GuidedSaveState.saved) {
      return;
    }
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
            await _save(
              () => repository.setQuestionDeleted(question.id, false),
            );
            if (_isCurrent(repository, sessionId)) _refresh();
          },
        ),
      ),
    );
  }

  Future<void> _knowledgeSearch(GuidedQuestion question) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final results = await _readCurrent(
      repository,
      sessionId,
      () => repository.searchKnowledge(question.id),
    );
    if (!mounted || results == null || !_isCurrent(repository, sessionId)) {
      return;
    }
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
    if (mounted &&
        _isCurrent(repository, sessionId) &&
        _saveState == GuidedSaveState.saved) {
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
    final contents = await _readCurrent(
      repository,
      session.id,
      () => repository.exportSession(session.id, format),
    );
    if (!mounted || contents == null || !_isCurrent(repository, session.id)) {
      return;
    }
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

  void _notify(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final result = await showGuidedScopedDialog<bool>(
      context: context,
      repository: repository,
      isCurrent: () => _isCurrent(repository, sessionId),
      builder: (context) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true && _isCurrent(repository, sessionId);
  }

  Future<void> _lifecycleInfo(GuidedSessionDetail session, bool canEdit) {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final next = switch (session.status) {
      'draft' => 'Start makes it active. Archive is also available.',
      'active' => 'Complete marks it completed. Archive is also available.',
      'completed' =>
        'Completed sessions stay editable by authorised editors. Archive is the only further step.',
      _ =>
        'Archived sessions are read-only and cannot be reopened or restored.',
    };
    return showGuidedScopedDialog<void>(
      context: context,
      repository: repository,
      isCurrent: () => _isCurrent(repository, sessionId),
      builder: (context) => AlertDialog(
        title: const Text('Lifecycle and recovery'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${guidedStatusLabel(session.status)}',
              key: const ValueKey('guided-lifecycle-status'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(next),
            const SizedBox(height: 8),
            const Text(
              'Archive is final: there is no reopen or restore action. Reports and JSON/CSV exports stay available.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Save history lists audit entries only; it cannot restore earlier versions. A deleted question can be restored with Undo straight after deleting it.',
            ),
            if (!canEdit) ...[
              const SizedBox(height: 8),
              const Text('You can view this session but cannot change it.'),
            ],
          ],
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

  Future<void> _sessionAction(GuidedSessionDetail session, String action) {
    return switch (action) {
      'details' => _editDetails(session),
      'template' => _saveAsTemplate(session),
      'archive' => _archive(),
      _ => Future.value(),
    };
  }

  Future<void> _archive() async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final confirmed = await _confirm(
      'Archive session?',
      'Archiving makes this organisation session read-only for everyone. There is no reopen or restore action. Reports and JSON/CSV exports stay available.',
      'Archive',
    );
    if (!confirmed) return;
    await _transition('archive');
    if (_isCurrent(repository, sessionId) &&
        _saveState == GuidedSaveState.saved) {
      _notify('Session archived in the organisation workspace.');
    }
  }

  Future<void> _editDetails(GuidedSessionDetail session) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final title = TextEditingController(text: session.title);
    final owner = TextEditingController(text: session.ownerText ?? '');
    final contextReference = TextEditingController(
      text: session.contextReference ?? '',
    );
    final submit = await showGuidedScopedDialog<bool>(
      context: context,
      repository: repository,
      isCurrent: () => _isCurrent(repository, sessionId),
      builder: (context) => AlertDialog(
        title: const Text('Session details'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Session title',
                hintText: 'e.g. Q3 onboarding review',
              ),
            ),
            TextField(
              controller: owner,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Owner',
                hintText: 'e.g. People team',
              ),
            ),
            TextField(
              controller: contextReference,
              decoration: const InputDecoration(
                labelText: 'Context / reference',
                hintText: 'e.g. Ticket HR-142',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save details'),
          ),
        ],
      ),
    );
    final newTitle = title.text.trim();
    String? optional(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    final newOwner = optional(owner);
    final newContext = optional(contextReference);
    if (submit != true || !_isCurrent(repository, sessionId)) return;
    if (newTitle.isEmpty) {
      _notify('Session title cannot be blank. Nothing was changed.');
      return;
    }
    await _save(
      () => repository.updateSessionDetails(
        sessionId,
        title: newTitle,
        ownerText: newOwner,
        contextReference: newContext,
        expectedRevision: _drafts?.revision ?? session.revision,
      ),
    );
    if (_isCurrent(repository, sessionId) &&
        _saveState == GuidedSaveState.saved) {
      invalidateGuidedLists(ref);
      _notify('Session details saved to the organisation workspace.');
    }
  }

  Future<void> _saveAsTemplate(GuidedSessionDetail session) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final name = await _textDialog(
      'Save as organisation template',
      'Template name',
      hint: 'e.g. Weekly check-in',
      initialValue: session.title,
      action: 'Save template',
      message:
          'Creates a new organisation template (version 1) in this organisation\'s Templates. Question wording, shared/participant targets and follow-up branches are copied as numbered participant slots. Answers and participant names are not included, and this session is not changed.',
    );
    if (name == null || !_isCurrent(repository, sessionId)) return;
    await _drafts?.flush();
    if (!_isCurrent(repository, sessionId)) return;
    if (_drafts?.error != null || _drafts?.isBusy == true) {
      _notify('Save or resolve pending edits before creating a template.');
      return;
    }
    try {
      final full = await repository.getSession(sessionId);
      if (!_isCurrent(repository, sessionId)) return;
      final questions = guidedTemplateQuestionsFromSession(full);
      if (questions.isEmpty) {
        _notify('Add at least one question before saving a template.');
        return;
      }
      await repository.createTemplateFromQuestions(name, questions);
      if (!_isCurrent(repository, sessionId)) return;
      ref.invalidate(guidedTemplatesProvider);
      _notify(
        'Saved organisation template "$name" (version 1). Answers were not included.',
      );
    } on GuidedConflict {
      if (_isCurrent(repository, sessionId)) {
        _notify(
          'A template named "$name" already exists. Nothing was created; choose another name.',
        );
      }
    } catch (error) {
      if (_isCurrent(repository, sessionId)) {
        _notify(
          'Template creation was not confirmed ($error). Check Templates before retrying to avoid a duplicate.',
        );
      }
    }
  }

  Future<void> _renameParticipant(GuidedParticipant participant) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final name = await _textDialog(
      'Rename participant',
      'Name',
      hint: 'e.g. Alex (team lead)',
      initialValue: participant.name,
      action: 'Rename',
    );
    if (name == null ||
        name == participant.name ||
        !_isCurrent(repository, sessionId)) {
      return;
    }
    await _save(() => repository.renameParticipant(participant.id, name));
    if (_isCurrent(repository, sessionId) &&
        _saveState == GuidedSaveState.saved) {
      _notify('Participant renamed in the organisation workspace.');
    }
  }

  Future<void> _removeParticipant(GuidedParticipant participant) async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final confirmed = await _confirm(
      'Remove ${participant.name}?',
      'Only participants without answers or participant questions can be removed, so other participants\' answers and branches are never changed. If ${participant.name} has content, nothing is removed.',
      'Remove',
    );
    if (!confirmed) return;
    await _drafts?.flush();
    if (!_isCurrent(repository, sessionId) || _drafts?.error != null) return;
    if (mounted) setState(() => _saveState = GuidedSaveState.saving);
    try {
      await repository.removeParticipant(participant.id);
      if (!_isCurrent(repository, sessionId)) return;
      setState(() {
        _saveState = GuidedSaveState.saved;
        if (_participantId == participant.id) _participantId = null;
      });
      _refresh();
      _notify(
        'Removed ${participant.name} from the organisation session.',
        action: SnackBarAction(
          label: 'Add back',
          onPressed: () {
            if (!_isCurrent(repository, sessionId)) return;
            unawaited(
              _save(() async {
                final restored = await repository.addParticipant(
                  sessionId,
                  participant.name,
                );
                if (_isCurrent(repository, sessionId)) {
                  setState(() => _participantId = restored.id);
                }
              }),
            );
          },
        ),
      );
    } on GuidedConflict {
      if (!_isCurrent(repository, sessionId)) return;
      setState(() => _saveState = GuidedSaveState.idle);
      _refresh();
      _notify(
        '${participant.name} has answers or participant questions, so nothing was removed.',
      );
    } catch (error) {
      if (!_isCurrent(repository, sessionId)) return;
      setState(() => _saveState = GuidedSaveState.failed);
      _refresh();
      _notify(
        'Removal of ${participant.name} was not confirmed ($error). Reloaded the session.',
      );
    }
  }

  Future<void> _history() async {
    final repository = ref.read(guidedRepositoryProvider);
    final sessionId = widget.sessionId;
    final revisions = await _readCurrent(
      repository,
      sessionId,
      () => repository.revisions(sessionId),
    );
    if (!mounted || revisions == null || !_isCurrent(repository, sessionId)) {
      return;
    }
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
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Audit entries only. Earlier versions cannot be restored from this list.',
                      ),
                    ),
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
    required this.onLifecycleInfo,
    required this.onSessionAction,
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
  final VoidCallback onLifecycleInfo;
  final ValueChanged<String>? onSessionAction;

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
            'Organisation',
            guidedVisibilityLabel(session.visibility),
            'Status: ${guidedStatusLabel(session.status)}',
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
      IconButton(
        tooltip: 'Lifecycle and recovery',
        icon: const Icon(Icons.info_outline),
        onPressed: onLifecycleInfo,
      ),
      if (onSessionAction != null)
        PopupMenuButton<String>(
          tooltip: 'Session actions',
          icon: const Icon(Icons.more_vert),
          onSelected: onSessionAction,
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'details',
              child: Text('Edit session details'),
            ),
            const PopupMenuItem(
              value: 'template',
              child: Text('Save as organisation template'),
            ),
            if (session.status != 'archived')
              const PopupMenuItem(
                value: 'archive',
                child: Text('Archive session'),
              ),
          ],
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
      if (question.followUps.isEmpty || (answer?.branchesCollapsed ?? false)) {
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
        : 'Shared';
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
                      initialValue:
                          pendingValues[GuidedPendingEdits.questionKey(
                            question.id,
                          )] ??
                          question.text,
                      managedDebounce: managedDebounce,
                      minLines: 1,
                      labelText: question.source == 'follow_up'
                          ? 'Follow-up question text'
                          : 'Question text',
                      hintText: question.source == 'follow_up'
                          ? 'e.g. What made that difficult?'
                          : 'e.g. What would you like to cover first?',
                      style: Theme.of(context).textTheme.titleMedium,
                      onEditing: onEditing,
                      onSave: (value) => onSaveQuestion(question, value),
                    ),
                  const SizedBox(height: 10),
                  if (readOnly) ...[
                    Text(
                      'Answer · $participantName',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      answer?.body.isNotEmpty == true
                          ? answer!.body
                          : 'No answer recorded.',
                    ),
                  ] else
                    _DebouncedField(
                      key: ValueKey('answer-${question.id}-$participantId'),
                      initialValue:
                          pendingValues[GuidedPendingEdits.answerKey(
                            question.id,
                            participantId,
                          )] ??
                          answer?.body ??
                          '',
                      managedDebounce: managedDebounce,
                      allowBlank: true,
                      minLines: 2,
                      labelText: 'Answer · $participantName',
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
    this.labelText,
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
  final String? labelText;
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
      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        isDense: true,
        errorText: _error,
      ),
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

String guidedStatusLabel(String status) => switch (status) {
  'draft' => 'Draft',
  'active' => 'Active',
  'completed' => 'Completed',
  'archived' => 'Archived',
  _ => status,
};

String guidedVisibilityLabel(String visibility) => switch (visibility) {
  'private' => 'Private to creator',
  'organisation' => 'Organisation members',
  'department' => 'Department',
  'team' => 'Team',
  _ => visibility,
};
