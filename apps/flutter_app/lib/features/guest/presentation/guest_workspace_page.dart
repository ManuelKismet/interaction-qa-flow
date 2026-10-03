import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/auth/sign_in_page.dart';
import 'package:int_qa_flow/core/platform/print_page.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';

class GuestWorkspacePage extends ConsumerStatefulWidget {
  const GuestWorkspacePage({
    required this.firebaseReady,
    this.sharedIdentityActive = false,
    super.key,
  });

  final bool firebaseReady;
  final bool sharedIdentityActive;

  @override
  ConsumerState<GuestWorkspacePage> createState() => _GuestWorkspacePageState();
}

class _GuestWorkspacePageState extends ConsumerState<GuestWorkspacePage> {
  GuestWorkspaceData? _data;
  String? _loadError;
  String _saveStatus = 'Saved on this device';
  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(guestWorkspaceStoreProvider).load();
      if (mounted) setState(() => _data = data);
    } on Object {
      if (mounted) {
        setState(() {
          _loadError = 'Unable to read local guest data. The stored copy was not changed.';
        });
      }
    }
  }

  void _save(GuestWorkspaceData data) {
    setState(() {
      _data = data;
      _saveStatus = 'Saving locally…';
      _loadError = null;
    });
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        await ref.read(guestWorkspaceStoreProvider).save(data);
        if (mounted) setState(() => _saveStatus = 'Saved on this device');
      } on Object {
        if (mounted) setState(() => _saveStatus = 'Unable to save locally');
      }
    });
  }

  Future<void> _startSharedGuestIdentity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable shared guest groups?'),
        content: const Text(
          'This uses a per-device guest identity. Only content you deliberately '
          'add to a group is stored online. Your local drafts stay on this device '
          'unless you preview and confirm an import.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay local'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue to shared groups'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(firebaseAuthProvider).signInAnonymously();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Shared groups are unavailable. Your local guest work is unchanged.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openAccountAccess() async {
    final linkGuestIdentity =
        ref.read(firebaseAuthProvider).currentUser?.isAnonymous == true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SignInPage(linkGuestIdentity: linkGuestIdentity),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final data = _data;
    if (data == null) return;
    final backup = data.encodeBackup();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guest backup'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: SelectableText(backup),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: backup));
              Navigator.pop(context);
            },
            child: const Text('Copy backup JSON'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();
    GuestWorkspaceData? imported;
    String? error;
    final text = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Preview local backup import'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Paste an IntQAFlow guest backup. Nothing changes until you '
                  'review and confirm the selected items.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Backup JSON',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    try {
                      imported = GuestWorkspaceData.decodeBackup(value);
                      error = null;
                    } on Object {
                      imported = null;
                      error = 'The backup is not valid IntQAFlow guest JSON.';
                    }
                    setDialogState(() {});
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (imported != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${imported!.knowledge.length} Knowledge items, '
                    '${imported!.sessions.length} Interact sessions and '
                    '${imported!.templates.length} templates. '
                    'All non-empty selections will be previewed next.',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: imported == null
                  ? null
                  : () => Navigator.pop(context, controller.text),
              child: const Text('Review selection'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (text == null || !mounted) return;
    try {
      imported = GuestWorkspaceData.decodeBackup(text);
    } on Object {
      return;
    }
    final selection = await showDialog<_GuestImportSelection>(
      context: context,
      builder: (context) => _GuestImportPreview(data: imported!),
    );
    if (selection == null || !mounted) return;
    final result = await ref.read(guestWorkspaceStoreProvider).importSelected(
      imported: imported!,
      knowledgeIds: selection.knowledgeIds,
      sessionIds: selection.sessionIds,
      templateIds: selection.templateIds,
    );
    _save(result);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selected work was added to this device.')),
    );
  }

  Future<void> _clearLocalCopy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this device’s guest work?'),
        content: const Text(
          'This permanently removes this browser’s local guest copy. '
          'Export a backup first if you may need it. Shared group content is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my work'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear local copy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(guestWorkspaceStoreProvider).clear();
    _save(const GuestWorkspaceData());
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IntQAFlow guest workspace'),
          actions: [
            IconButton(
              tooltip: 'Import backup',
              onPressed: _data == null ? null : _importBackup,
              icon: const Icon(Icons.file_upload_outlined),
            ),
            IconButton(
              tooltip: 'Export backup',
              onPressed: _data == null ? null : _exportBackup,
              icon: const Icon(Icons.file_download_outlined),
            ),
            if (widget.sharedIdentityActive)
              IconButton(
                tooltip: 'Shared guest groups',
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const SharedGuestGroupsPage(),
                  ),
                ),
                icon: const Icon(Icons.group_outlined),
              )
            else if (widget.firebaseReady)
              IconButton(
                tooltip: 'Enable shared guest groups',
                onPressed: _startSharedGuestIdentity,
                icon: const Icon(Icons.cloud_upload_outlined),
              ),
            IconButton(
              tooltip: 'Sign in or create account',
              onPressed: widget.firebaseReady ? _openAccountAccess : null,
              icon: const Icon(Icons.login),
            ),
            PopupMenuButton<String>(
              tooltip: 'Guest workspace options',
              onSelected: (value) {
                if (value == 'clear') _clearLocalCopy();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear local guest copy'),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Knowledge', icon: Icon(Icons.search)),
              Tab(text: 'Interact', icon: Icon(Icons.account_tree_outlined)),
            ],
          ),
        ),
        body: data == null
            ? Center(
                child: _loadError == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_loadError!),
                      ),
              )
            : Column(
                children: [
                  _GuestNotice(
                    sharedIdentityActive: widget.sharedIdentityActive,
                    saveStatus: _saveStatus,
                  ),
                  if (_loadError != null)
                    MaterialBanner(
                      content: Text(_loadError!),
                      actions: [
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _GuestKnowledgeTab(
                          items: data.knowledge,
                          onCreate: (item) => _save(
                            data.copyWith(knowledge: [item, ...data.knowledge]),
                          ),
                          onUpdate: (item) => _save(
                            data.copyWith(
                              knowledge: [
                                for (final current in data.knowledge)
                                  current['id'] == item['id'] ? item : current,
                              ],
                            ),
                          ),
                          onDelete: (id) => _deleteKnowledge(data, id),
                        ),
                        _GuestInteractTab(
                          data: data,
                          onChange: _save,
                          onSaveTemplate: (template) => _save(
                            data.copyWith(
                              templates: [template, ...data.templates],
                            ),
                          ),
                          onPrint: _printReport,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _deleteKnowledge(GuestWorkspaceData data, String id) async {
    final removed = data.knowledge.where((item) => item['id'] == id).firstOrNull;
    if (removed == null) return;
    _save(
      data.copyWith(
        knowledge: data.knowledge.where((item) => item['id'] != id).toList(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Local Knowledge item removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final current = _data ?? data;
            _save(current.copyWith(knowledge: [removed, ...current.knowledge]));
          },
        ),
      ),
    );
  }

  Future<void> _printReport(Map<String, dynamic> session) async {
    final report = const JsonEncoder.withIndent('  ').convert(session);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${session['title']} report'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(child: SelectableText(report)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              printCurrentPage();
            },
            child: const Text('Print / Save PDF'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

}

class _GuestNotice extends StatelessWidget {
  const _GuestNotice({
    required this.sharedIdentityActive,
    required this.saveStatus,
  });

  final bool sharedIdentityActive;
  final String saveStatus;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      sharedIdentityActive
          ? 'Per-device guest identity active. Local drafts stay on this device; only work explicitly shared with a group is online. $saveStatus'
          : 'Stored in this browser only. Clearing browser data or losing this device can erase it. Export a backup before you need to move it. $saveStatus',
    ),
  );
}

class _GuestKnowledgeTab extends StatefulWidget {
  const _GuestKnowledgeTab({
    required this.items,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onCreate;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final ValueChanged<String> onDelete;

  @override
  State<_GuestKnowledgeTab> createState() => _GuestKnowledgeTabState();
}

class _GuestKnowledgeTabState extends State<_GuestKnowledgeTab> {
  final _query = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _answer = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    _title.dispose();
    _body.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _create() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    widget.onCreate({
      'id': newGuestItemId(),
      'title': title,
      'body': _body.text.trim(),
      'answer': _answer.text.trim(),
      'visibility': 'local_guest',
    });
    _title.clear();
    _body.clear();
    _answer.clear();
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final title = TextEditingController(text: item['title'] as String? ?? '');
    final body = TextEditingController(text: item['body'] as String? ?? '');
    final answer = TextEditingController(text: item['answer'] as String? ?? '');
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit local Knowledge'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Question')),
              TextField(controller: body, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Details')),
              TextField(controller: answer, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Answer')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              ...item,
              'title': title.text.trim(),
              'body': body.text.trim(),
              'answer': answer.text.trim(),
            }),
            child: const Text('Save locally'),
          ),
        ],
      ),
    );
    title.dispose();
    body.dispose();
    answer.dispose();
    if (updated != null && updated['title'].toString().isNotEmpty) {
      widget.onUpdate(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text;
    final matches = widget.items
        .where((item) => matchesGuestKeywordOrPrefix(query, item))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _query,
          decoration: const InputDecoration(
            labelText: 'Search local Knowledge',
            helperText: 'Keyword and prefix search on this device; no semantic search.',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Add a local question', style: Theme.of(context).textTheme.titleMedium),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Question')),
        TextField(controller: _body, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Details')),
        TextField(controller: _answer, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Answer')),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('Save locally'),
          ),
        ),
        const Divider(height: 28),
        if (matches.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No local matches. Shared organisation Knowledge is not shown here.'),
          ),
        for (final item in matches)
          Card(
            child: ListTile(
              title: Text(item['title'] as String? ?? ''),
              subtitle: Text(
                [
                  item['body'],
                  item['answer'],
                ].whereType<String>().where((text) => text.isNotEmpty).join('\n\n'),
              ),
              isThreeLine: true,
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Edit local Knowledge',
                    onPressed: () => _edit(item),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove local Knowledge',
                    onPressed: () => widget.onDelete(item['id'] as String),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GuestInteractTab extends StatefulWidget {
  const _GuestInteractTab({
    required this.data,
    required this.onChange,
    required this.onSaveTemplate,
    required this.onPrint,
  });

  final GuestWorkspaceData data;
  final ValueChanged<GuestWorkspaceData> onChange;
  final ValueChanged<Map<String, dynamic>> onSaveTemplate;
  final ValueChanged<Map<String, dynamic>> onPrint;

  @override
  State<_GuestInteractTab> createState() => _GuestInteractTabState();
}

class _GuestInteractTabState extends State<_GuestInteractTab> {
  final _newSessionTitle = TextEditingController();
  final _newSessionParticipant = TextEditingController(text: 'Participant 1');
  String? _selectedTemplateId;

  @override
  void dispose() {
    _newSessionTitle.dispose();
    _newSessionParticipant.dispose();
    super.dispose();
  }

  void _createSession() {
    final title = _newSessionTitle.text.trim();
    final participant = _newSessionParticipant.text.trim();
    if (title.isEmpty || participant.isEmpty) return;
    final template = widget.data.templates
        .where((item) => item['id'] == _selectedTemplateId)
        .firstOrNull;
    final participantId = newGuestItemId();
    final session = <String, dynamic>{
      'id': newGuestItemId(),
      'title': title,
      'visibility': 'private_local',
      'participants': [
        {'id': participantId, 'name': participant},
      ],
      'questions': [
        for (final question in (template?['questions'] as List? ?? const []))
          _newQuestion(
            (question as Map<String, dynamic>)['text'] as String? ?? '',
            [participantId],
          ),
      ],
    };
    widget.onChange(
      widget.data.copyWith(sessions: [session, ...widget.data.sessions]),
    );
    _newSessionTitle.clear();
  }

  Map<String, dynamic> _newQuestion(String text, List<String> participantIds) => {
    'id': newGuestItemId(),
    'text': text,
    'scope': 'shared',
    'answers': [
      for (final participantId in participantIds)
        {
          'participant_id': participantId,
          'body': '',
          'branches_collapsed': false,
          'follow_ups': <Map<String, dynamic>>[],
        },
    ],
  };

  void _updateSession(Map<String, dynamic> updated) {
    widget.onChange(
      widget.data.copyWith(
        sessions: [
          for (final session in widget.data.sessions)
            session['id'] == updated['id'] ? updated : session,
        ],
      ),
    );
  }

  void _deleteSession(Map<String, dynamic> session) {
    widget.onChange(
      widget.data.copyWith(
        sessions: widget.data.sessions
            .where((item) => item['id'] != session['id'])
            .toList(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Local session removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => widget.onChange(
            widget.data.copyWith(sessions: [session, ...widget.data.sessions]),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTemplate(Map<String, dynamic> session) async {
    final name = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save local template'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text.trim()),
            child: const Text('Save template'),
          ),
        ],
      ),
    );
    name.dispose();
    if (value == null || value.isEmpty) return;
    final questions = (session['questions'] as List? ?? const [])
        .map((question) => {
          'id': newGuestItemId(),
          'text': (question as Map<String, dynamic>)['text'],
        })
        .toList();
    widget.onSaveTemplate({
      'id': newGuestItemId(),
      'name': value,
      'questions': questions,
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Interact sessions stay private on this device until you explicitly select one for a guest group.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      if (widget.data.templates.isNotEmpty)
        DropdownButtonFormField<String?>(
          initialValue: _selectedTemplateId,
          decoration: const InputDecoration(labelText: 'Optional local template'),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('Start blank')),
            for (final template in widget.data.templates)
              DropdownMenuItem(
                value: template['id'] as String,
                child: Text(template['name'] as String? ?? 'Local template'),
              ),
          ],
          onChanged: (value) => setState(() => _selectedTemplateId = value),
        ),
      TextField(
        controller: _newSessionTitle,
        decoration: const InputDecoration(labelText: 'New Interact session'),
      ),
      TextField(
        controller: _newSessionParticipant,
        decoration: const InputDecoration(labelText: 'First participant'),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _createSession,
          icon: const Icon(Icons.add),
          label: const Text('Create session locally'),
        ),
      ),
      const Divider(height: 28),
      if (widget.data.sessions.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Create a local session to start capturing answers.'),
        ),
      for (final session in widget.data.sessions)
        _GuestSessionEditor(
          key: ValueKey(session['id']),
          session: session,
          onChange: _updateSession,
          onDelete: () => _deleteSession(session),
          onSaveTemplate: () => _saveTemplate(session),
          onPrint: () => widget.onPrint(session),
          makeQuestion: _newQuestion,
        ),
      if (widget.data.templates.isNotEmpty) ...[
        const Divider(height: 28),
        Text('Local templates', style: Theme.of(context).textTheme.titleMedium),
        for (final template in widget.data.templates)
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(template['name'] as String? ?? 'Template'),
            subtitle: Text(
              '${(template['questions'] as List? ?? const []).length} prepared questions',
            ),
          ),
      ],
    ],
  );
}

class _GuestSessionEditor extends StatefulWidget {
  const _GuestSessionEditor({
    required this.session,
    required this.onChange,
    required this.onDelete,
    required this.onSaveTemplate,
    required this.onPrint,
    required this.makeQuestion,
    super.key,
  });

  final Map<String, dynamic> session;
  final ValueChanged<Map<String, dynamic>> onChange;
  final VoidCallback onDelete;
  final VoidCallback onSaveTemplate;
  final VoidCallback onPrint;
  final Map<String, dynamic> Function(String, List<String>) makeQuestion;

  @override
  State<_GuestSessionEditor> createState() => _GuestSessionEditorState();
}

class _GuestSessionEditorState extends State<_GuestSessionEditor> {
  final _participant = TextEditingController();
  final _question = TextEditingController();

  @override
  void dispose() {
    _participant.dispose();
    _question.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _participants =>
      (widget.session['participants'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  void _editSession(void Function(Map<String, dynamic>) update) {
    final session = _copyMap(widget.session);
    update(session);
    widget.onChange(session);
  }

  void _addParticipant() {
    final name = _participant.text.trim();
    if (name.isEmpty) return;
    final id = newGuestItemId();
    _editSession((session) {
      (session['participants'] as List).add({'id': id, 'name': name});
      final roots = session['questions'] as List;
      for (final root in roots) {
        _ensureAnswer(root as Map<String, dynamic>, id);
      }
    });
    _participant.clear();
  }

  void _addQuestion({required bool shared}) {
    final text = _question.text.trim();
    if (text.isEmpty) return;
    final participantIds = _participants
        .map((item) => item['id'] as String)
        .toList();
    if (participantIds.isEmpty) return;
    final question = widget.makeQuestion(
      text,
      shared ? participantIds : [participantIds.first],
    );
    question['scope'] = shared ? 'shared' : 'participant';
    if (!shared) question['target_participant_id'] = participantIds.first;
    _editSession((session) => (session['questions'] as List).add(question));
    _question.clear();
  }

  @override
  Widget build(BuildContext context) {
    final participants = _participants;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(widget.session['title'] as String? ?? 'Local session'),
        subtitle: Text('${participants.length} participants · Private on this device'),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onSaveTemplate,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save as local template'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onPrint,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Report / Print'),
              ),
              TextButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete session'),
              ),
            ],
          ),
          for (final participant in participants)
            Chip(
              avatar: const Icon(Icons.person_outline, size: 18),
              label: Text(participant['name'] as String? ?? 'Participant'),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _participant,
                  decoration: const InputDecoration(labelText: 'Add participant'),
                  onSubmitted: (_) => _addParticipant(),
                ),
              ),
              IconButton(
                tooltip: 'Add participant',
                onPressed: _addParticipant,
                icon: const Icon(Icons.person_add_alt_1),
              ),
            ],
          ),
          TextField(
            controller: _question,
            decoration: const InputDecoration(labelText: 'Prepared question'),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: participants.isEmpty ? null : () => _addQuestion(shared: true),
                child: const Text('Add shared question'),
              ),
              FilledButton.tonal(
                onPressed: participants.isEmpty ? null : () => _addQuestion(shared: false),
                child: const Text('Add question for first participant'),
              ),
            ],
          ),
          for (final question in (widget.session['questions'] as List? ?? const []))
            _GuestQuestionEditor(
              key: ValueKey((question as Map<String, dynamic>)['id']),
              question: question,
              participants: participants,
              onRemove: () => _removeRootQuestion(question),
              onUpdate: (updated) => _replaceQuestion(
                widget.session,
                updated,
                (session) => widget.onChange(session),
              ),
              makeQuestion: widget.makeQuestion,
            ),
        ],
      ),
    );
  }

  void _removeRootQuestion(Map<String, dynamic> question) {
    final removed = _copyMap(question);
    final questions = widget.session['questions'] as List? ?? const [];
    final index = questions.indexWhere(
      (item) => (item as Map<String, dynamic>)['id'] == question['id'],
    );
    _editSession(
      (session) => (session['questions'] as List).removeWhere(
        (item) => (item as Map<String, dynamic>)['id'] == question['id'],
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Local question removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _editSession((session) {
            final current = session['questions'] as List;
            current.insert(index.clamp(0, current.length).toInt(), removed);
          }),
        ),
      ),
    );
  }
}

class _GuestQuestionEditor extends StatefulWidget {
  const _GuestQuestionEditor({
    required this.question,
    required this.participants,
    required this.onUpdate,
    required this.onRemove,
    required this.makeQuestion,
    super.key,
  });

  final Map<String, dynamic> question;
  final List<Map<String, dynamic>> participants;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final VoidCallback onRemove;
  final Map<String, dynamic> Function(String, List<String>) makeQuestion;

  @override
  State<_GuestQuestionEditor> createState() => _GuestQuestionEditorState();
}

class _GuestQuestionEditorState extends State<_GuestQuestionEditor> {
  List<Map<String, dynamic>> get _answers =>
      (widget.question['answers'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  void _updateAnswer(String participantId, String body) {
    final question = _copyMap(widget.question);
    final answers = question['answers'] as List? ?? <Map<String, dynamic>>[];
    question['answers'] = answers;
    var answer = answers
        .whereType<Map>()
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (item) => item?['participant_id'] == participantId,
          orElse: () => null,
        );
    if (answer == null) {
      answer = {
        'participant_id': participantId,
        'body': '',
        'branches_collapsed': false,
        'follow_ups': <Map<String, dynamic>>[],
      };
      answers.add(answer);
    }
    answer['body'] = body;
    widget.onUpdate(question);
  }

  void _addFollowUp(String participantId, String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    final question = _copyMap(widget.question);
    final answers = question['answers'] as List? ?? <Map<String, dynamic>>[];
    question['answers'] = answers;
    var answer = answers
        .whereType<Map>()
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (item) => item?['participant_id'] == participantId,
          orElse: () => null,
        );
    if (answer == null) {
      answer = {
        'participant_id': participantId,
        'body': '',
        'branches_collapsed': false,
        'follow_ups': <Map<String, dynamic>>[],
      };
      answers.add(answer);
    }
    final followUps = answer['follow_ups'] as List? ?? <Map<String, dynamic>>[];
    answer['follow_ups'] = followUps;
    followUps.add(widget.makeQuestion(text, [participantId]));
    widget.onUpdate(question);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.question['id'] as String;
    final text = widget.question['text'] as String? ?? '';
    final scope = widget.question['scope'] as String? ?? 'shared';
    final target = widget.question['target_participant_id'] as String?;
    final applicable = widget.participants.where((participant) {
      return scope == 'shared' || participant['id'] == target;
    });
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text, style: Theme.of(context).textTheme.titleSmall),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Delete question and undo',
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
            Text(scope == 'shared' ? 'Shared question' : 'Participant-specific question'),
            for (final participant in applicable)
              _GuestAnswerEditor(
                key: ValueKey('${id}_${participant['id']}'),
                participant: participant,
                answer: _answers
                    .where((answer) => answer['participant_id'] == participant['id'])
                    .firstOrNull,
                onAnswerChanged: (body) => _updateAnswer(
                  participant['id'] as String,
                  body,
                ),
                onAddFollowUp: (text) => _addFollowUp(
                  participant['id'] as String,
                  text,
                ),
                onUpdate: _replaceAnswer,
                makeQuestion: widget.makeQuestion,
              ),
          ],
        ),
      ),
    );
  }

  void _replaceAnswer(Map<String, dynamic> updated) {
    final question = _copyMap(widget.question);
    final participantId = updated['participant_id'];
    final answers = question['answers'] as List? ?? <Map<String, dynamic>>[];
    final answerIndex = answers.indexWhere(
      (item) =>
          (item as Map<String, dynamic>)['participant_id'] == participantId,
    );
    if (answerIndex < 0) {
      answers.add(updated);
    } else {
      answers[answerIndex] = updated;
    }
    question['answers'] = answers;
    widget.onUpdate(question);
  }
}

class _GuestAnswerEditor extends StatefulWidget {
  const _GuestAnswerEditor({
    required this.participant,
    required this.answer,
    required this.onAnswerChanged,
    required this.onAddFollowUp,
    required this.onUpdate,
    required this.makeQuestion,
    super.key,
  });

  final Map<String, dynamic> participant;
  final Map<String, dynamic>? answer;
  final ValueChanged<String> onAnswerChanged;
  final ValueChanged<String> onAddFollowUp;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final Map<String, dynamic> Function(String, List<String>) makeQuestion;

  @override
  State<_GuestAnswerEditor> createState() => _GuestAnswerEditorState();
}

class _GuestAnswerEditorState extends State<_GuestAnswerEditor> {
  late final TextEditingController _answer;
  final _followUp = TextEditingController();
  final _answerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _answer = TextEditingController(
      text: widget.answer?['body'] as String? ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _GuestAnswerEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.answer?['body'] as String? ?? '';
    if (_answer.text != current && !_answerFocus.hasFocus) {
      _answer.value = TextEditingValue(text: current);
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    _followUp.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  void _addFollowUp() {
    widget.onAddFollowUp(_followUp.text);
    _followUp.clear();
  }

  @override
  Widget build(BuildContext context) {
    final participantId = widget.participant['id'] as String;
    final branches = widget.answer?['follow_ups'] as List? ?? const [];
    final collapsed = widget.answer?['branches_collapsed'] as bool? ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Answer — ${widget.participant['name']}'),
          TextField(
            controller: _answer,
            focusNode: _answerFocus,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Local answer',
              alignLabelWithHint: true,
            ),
            onChanged: widget.onAnswerChanged,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                controller: _followUp,
                  decoration: const InputDecoration(labelText: 'Follow-up question'),
                onSubmitted: (_) => _addFollowUp(),
                ),
              ),
              IconButton(
                tooltip: 'Add answer-owned follow-up',
                onPressed: _addFollowUp,
                icon: const Icon(Icons.add_comment_outlined),
              ),
              if (branches.isNotEmpty)
                IconButton(
                  tooltip: collapsed ? 'Expand follow-ups' : 'Collapse follow-ups',
                  onPressed: () {
                    final updated = _copyMap(widget.answer!);
                    updated['branches_collapsed'] = !collapsed;
                    widget.onUpdate(updated);
                  },
                  icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less),
                ),
              if (branches.isNotEmpty)
                Text('${branches.length} follow-ups'),
            ],
          ),
          if (branches.isNotEmpty && !collapsed)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: [
                  for (final branch in branches)
                    _GuestQuestionEditor(
                      key: ValueKey((branch as Map<String, dynamic>)['id']),
                      question: branch,
                      participants: [widget.participant],
                      onRemove: () => _removeNestedBranch(branch),
                      onUpdate: (updated) {
                        final answer = _copyMap(widget.answer!);
                        _replaceInQuestions(answer['follow_ups'] as List, updated);
                        widget.onUpdate(answer);
                      },
                      makeQuestion: widget.makeQuestion,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _removeNestedBranch(Map<String, dynamic> branch) {
    final removed = _copyMap(branch);
    final answer = _copyMap(widget.answer!);
    final followUps = answer['follow_ups'] as List;
    final index = followUps.indexWhere(
      (item) => (item as Map<String, dynamic>)['id'] == branch['id'],
    );
    answer['follow_ups'] = followUps
        .where((item) => (item as Map<String, dynamic>)['id'] != branch['id'])
        .toList();
    widget.onUpdate(answer);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Local follow-up removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final restored = _copyMap(widget.answer!);
            final current = restored['follow_ups'] as List;
            current.insert(index.clamp(0, current.length).toInt(), removed);
            widget.onUpdate(restored);
          },
        ),
      ),
    );
  }
}

class SharedGuestGroupsPage extends StatelessWidget {
  const SharedGuestGroupsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shared guest groups')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Shared group access is enabled for this device. Create or join a group '
          'using its invitation after the guest-group API is available.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _GuestImportSelection {
  const _GuestImportSelection({
    required this.knowledgeIds,
    required this.sessionIds,
    required this.templateIds,
  });

  final Set<String> knowledgeIds;
  final Set<String> sessionIds;
  final Set<String> templateIds;
}

class _GuestImportPreview extends StatefulWidget {
  const _GuestImportPreview({required this.data});

  final GuestWorkspaceData data;

  @override
  State<_GuestImportPreview> createState() => _GuestImportPreviewState();
}

class _GuestImportPreviewState extends State<_GuestImportPreview> {
  late final Set<String> _knowledge =
      widget.data.knowledge.map((item) => item['id'] as String).toSet();
  late final Set<String> _sessions =
      widget.data.sessions.map((item) => item['id'] as String).toSet();
  late final Set<String> _templates =
      widget.data.templates.map((item) => item['id'] as String).toSet();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm selected local import'),
    content: SizedBox(
      width: 560,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final item in widget.data.knowledge)
            CheckboxListTile(
              value: _knowledge.contains(item['id']),
              title: Text(item['title'] as String? ?? 'Knowledge'),
              onChanged: (selected) => setState(() {
                _toggle(_knowledge, item['id'] as String, selected);
              }),
            ),
          for (final item in widget.data.sessions)
            CheckboxListTile(
              value: _sessions.contains(item['id']),
              title: Text(item['title'] as String? ?? 'Interact session'),
              subtitle: const Text('Includes all participants and answer-owned branches'),
              onChanged: (selected) => setState(() {
                _toggle(_sessions, item['id'] as String, selected);
              }),
            ),
          for (final item in widget.data.templates)
            CheckboxListTile(
              value: _templates.contains(item['id']),
              title: Text(item['name'] as String? ?? 'Template'),
              onChanged: (selected) => setState(() {
                _toggle(_templates, item['id'] as String, selected);
              }),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _GuestImportSelection(
            knowledgeIds: _knowledge,
            sessionIds: _sessions,
            templateIds: _templates,
          ),
        ),
        child: const Text('Import selected locally'),
      ),
    ],
  );
}

void _toggle(Set<String> selection, String id, bool? selected) {
  if (selected == true) {
    selection.add(id);
  } else {
    selection.remove(id);
  }
}

Map<String, dynamic> _copyMap(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
    );

void _ensureAnswer(Map<String, dynamic> question, String participantId) {
  final answers = question['answers'] as List;
  if (answers.any(
    (item) => (item as Map<String, dynamic>)['participant_id'] == participantId,
  )) {
    return;
  }
  answers.add({
    'participant_id': participantId,
    'body': '',
    'branches_collapsed': false,
    'follow_ups': <Map<String, dynamic>>[],
  });
}

void _replaceQuestion(
  Map<String, dynamic> session,
  Map<String, dynamic> updated,
  ValueChanged<Map<String, dynamic>> onChange,
) {
  final copy = _copyMap(session);
  final roots = copy['questions'] as List;
  _replaceInQuestions(roots, updated);
  onChange(copy);
}

bool _replaceInQuestions(List questions, Map<String, dynamic> updated) {
  for (var index = 0; index < questions.length; index++) {
    final question = questions[index] as Map<String, dynamic>;
    if (question['id'] == updated['id']) {
      questions[index] = updated;
      return true;
    }
    for (final answer in (question['answers'] as List? ?? const [])) {
      final branches = (answer as Map<String, dynamic>)['follow_ups'] as List? ?? const [];
      if (_replaceInQuestions(branches, updated)) return true;
    }
  }
  return false;
}
