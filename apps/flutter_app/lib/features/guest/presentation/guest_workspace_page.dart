import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/auth/sign_in_page.dart';
import 'package:int_qa_flow/core/platform/pdf_download.dart';
import 'package:int_qa_flow/core/platform/print_page.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_interact_helpers.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_report_document.dart';
import 'package:share_plus/share_plus.dart';

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
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This account is not a guest identity. Its signed-in identity was left unchanged.',
          ),
        ),
      );
      return;
    }
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

  Future<void> _clearLocalCopy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this device’s guest work?'),
        content: const Text(
          'This permanently removes this browser’s local guest copy. '
          'Shared group content is not changed.',
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
    if (!mounted) return;
    _save(const GuestWorkspaceData());
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'IntQAFlow guest workspace',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
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
            else if (_canStartSharedGuestIdentity)
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
                  if (widget.firebaseReady &&
                      _hasSignedInNonGuestUser &&
                      !widget.sharedIdentityActive)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Shared group creation and invitation redemption use a Firebase anonymous identity. This signed-in account was not switched or granted guest access.',
                      ),
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

  Future<void> _printReport(
    Map<String, dynamic> session,
    String? participantId,
  ) async {
    final participants = (session['participants'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final selectedParticipantId = participants.any(
      (participant) => participant['id'] == participantId,
    )
        ? participantId
        : participants.firstOrNull?['id'] as String?;
    final selectedParticipantName = participants
            .where((participant) => participant['id'] == selectedParticipantId)
            .firstOrNull?['name'] as String? ??
        'Not selected';
    final allParticipants = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export session PDF'),
        content: Text(
          'Stored locally on this device. Choose the participant scope to preview before exporting. Current participant: $selectedParticipantName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Selected participant'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('All participants'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (allParticipants == null || !mounted) return;
    final report = composeGuestReport(
      session: session,
      allParticipants: allParticipants,
      participantId: selectedParticipantId,
      exportedAt: DateTime.now().toUtc(),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => _GuestReportPreviewDialog(
        report: report,
        onDownload: () => _downloadPdf(report, session, allParticipants, selectedParticipantId),
        onShare: () => _sharePdf(report, session, allParticipants, selectedParticipantId),
        onPrintFallback: () => openPrintableReport(
          buildGuestReportDocument(
            session: session,
            allParticipants: allParticipants,
            participantId: selectedParticipantId,
            generatedAt: report.exportedAt,
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _makePdf(GuestReportData report) =>
      buildGuestReportPdf(report);

  Future<void> _downloadPdf(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
  ) async {
    try {
      final status = await _downloadPdfOrShareFile(
        await _makePdf(report),
        guestReportFilename(report),
      );
      if (status == ShareResultStatus.dismissed) return;
      if (status == ShareResultStatus.success) {
        if (!kIsWeb && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Choose a destination in the system sheet to save the PDF.'),
            ),
          );
        }
        return;
      }
      if (mounted) {
        await _showPdfFallback(report, session, allParticipants, participantId);
      }
    } on Object {
      if (mounted) {
        await _showPdfFallback(report, session, allParticipants, participantId);
      }
    }
  }

  Future<void> _sharePdf(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share a PDF copy?'),
        content: const Text(
          'Recipients can keep or forward this PDF. Removing their group access later cannot revoke a copy they downloaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final bytes = await _makePdf(report);
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Share Interact PDF',
          text: 'Portable PDF copy. Recipients may retain or forward it.',
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf'),
          ],
          fileNameOverrides: [guestReportFilename(report)],
          downloadFallbackEnabled: false,
          sharePositionOrigin: origin,
        ),
      );
      if (result.status == ShareResultStatus.dismissed) return;
      if (result.status == ShareResultStatus.unavailable) {
        if (mounted) {
          await _showPdfFallback(report, session, allParticipants, participantId);
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF sharing was opened.')),
        );
      }
    } on Object {
      if (mounted) {
        await _showPdfFallback(report, session, allParticipants, participantId);
      }
    }
  }

  Future<void> _showPdfFallback(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF action unavailable'),
        content: const Text(
          'This browser or device cannot complete that PDF action. Download the PDF and attach it using your preferred app, or use the print-to-PDF fallback.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'print'),
            child: const Text('Print / Save PDF fallback'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'download'),
            child: const Text('Download PDF'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'print') {
      openPrintableReport(
        buildGuestReportDocument(
          session: session,
          allParticipants: allParticipants,
          participantId: participantId,
          generatedAt: report.exportedAt,
        ),
      );
    } else if (action == 'download') {
      try {
        final status = await _downloadPdfOrShareFile(
          await _makePdf(report),
          guestReportFilename(report),
        );
        if (status == ShareResultStatus.dismissed) return;
        if (status != ShareResultStatus.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Direct download is unavailable on this device. Use the print fallback.'),
            ),
          );
        }
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF download could not be started.')),
          );
        }
      }
    }
  }

  bool get _canStartSharedGuestIdentity {
    if (!widget.firebaseReady) return false;
    final user = ref.read(firebaseAuthProvider).currentUser;
    return user == null || user.isAnonymous;
  }

  bool get _hasSignedInNonGuestUser {
    final user = ref.read(firebaseAuthProvider).currentUser;
    return user != null && !user.isAnonymous;
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
          ? 'Guest-group membership is available for this Firebase identity. Local drafts stay on this device; only work explicitly shared with a group is online. $saveStatus'
          : 'Stored in this browser only. Clearing browser data or losing this device can erase it. $saveStatus',
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
    if (updated != null &&
        updated['title'].toString().isNotEmpty &&
        mounted) {
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
  final void Function(Map<String, dynamic>, String?) onPrint;

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
    final session = template == null
        ? <String, dynamic>{
            'id': newGuestItemId(),
            'title': title,
            'visibility': 'private_local',
            'participants': [
              {'id': newGuestItemId(), 'name': participant},
            ],
            'questions': <Map<String, dynamic>>[],
          }
        : createGuestSessionFromTemplate(
            template: template,
            id: newGuestItemId(),
            title: title,
            firstParticipantName: participant,
          );
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
    if (value == null || value.isEmpty || !mounted) return;
    widget.onSaveTemplate(
      createGuestTemplateFromSession(
        session: session,
        id: newGuestItemId(),
        name: value,
      ),
    );
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
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 680
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: TextField(
                  controller: _newSessionTitle,
                  decoration: const InputDecoration(
                    labelText: 'New Interact session',
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: TextField(
                  controller: _newSessionParticipant,
                  decoration: const InputDecoration(
                    labelText: 'First participant',
                  ),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
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
          onPrint: (participantId) => widget.onPrint(session, participantId),
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
  final ValueChanged<String?> onPrint;
  final Map<String, dynamic> Function(String, List<String>) makeQuestion;

  @override
  State<_GuestSessionEditor> createState() => _GuestSessionEditorState();
}

class _GuestSessionEditorState extends State<_GuestSessionEditor> {
  final _participant = TextEditingController();
  final _question = TextEditingController();
  String? _selectedParticipantId;

  @override
  void initState() {
    super.initState();
    _selectedParticipantId = _participants.firstOrNull?['id'] as String?;
  }

  @override
  void didUpdateWidget(covariant _GuestSessionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session['id'] != widget.session['id'] ||
        !_participants.any(
          (participant) => participant['id'] == _selectedParticipantId,
        )) {
      _selectedParticipantId = _participants.firstOrNull?['id'] as String?;
    }
  }

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
        final question = root as Map<String, dynamic>;
        if (question['scope'] != 'participant') {
          _ensureAnswer(question, id);
        }
      }
    });
    setState(() => _selectedParticipantId = id);
    _participant.clear();
  }

  Future<void> _renameActiveParticipant() async {
    final participant = _participants
        .where((item) => item['id'] == _selectedParticipantId)
        .firstOrNull;
    if (participant == null) return;
    final name = TextEditingController(
      text: participant['name'] as String? ?? '',
    );
    final updatedName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename participant'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Participant name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text.trim()),
            child: const Text('Save name locally'),
          ),
        ],
      ),
    );
    name.dispose();
    if (updatedName == null ||
        updatedName.isEmpty ||
        !mounted ||
        participant['id'] is! String) {
      return;
    }
    final participantId = participant['id'] as String;
    _editSession((session) {
      for (final item in session['participants'] as List) {
        final current = item as Map<String, dynamic>;
        if (current['id'] == participantId) current['name'] = updatedName;
      }
    });
  }

  void _addQuestion({required bool shared}) {
    final text = _question.text.trim();
    if (text.isEmpty) return;
    final participantIds = _participants
        .map((item) => item['id'] as String)
        .toList();
    if (participantIds.isEmpty) return;
    final selectedParticipantId = participantIds.contains(
      _selectedParticipantId,
    )
        ? _selectedParticipantId!
        : participantIds.first;
    final question = widget.makeQuestion(
      text,
      shared ? participantIds : [selectedParticipantId],
    );
    question['scope'] = shared ? 'shared' : 'participant';
    if (!shared) {
      question['target_participant_id'] = selectedParticipantId;
    }
    _editSession((session) => (session['questions'] as List).add(question));
    _question.clear();
  }

  @override
  Widget build(BuildContext context) {
    final participants = _participants;
    final activeParticipant = participants
        .where((participant) => participant['id'] == _selectedParticipantId)
        .firstOrNull ?? participants.firstOrNull;
    final activeParticipantId = activeParticipant?['id'] as String?;
    final questions = (widget.session['questions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((question) {
          if (question['scope'] != 'participant') return true;
          final targetId = question['target_participant_id'] ??
              participants.firstOrNull?['id'];
          return targetId == activeParticipantId;
        })
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          widget.session['title'] as String? ?? 'Local session',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${participants.length} participants · Private on this device',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                onPressed: () => widget.onPrint(activeParticipantId),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Download / Share PDF'),
              ),
              PopupMenuButton<String>(
                tooltip: 'More session actions',
                onSelected: (value) {
                  if (value == 'delete') widget.onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete session'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          if (participants.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(activeParticipantId),
              initialValue: activeParticipantId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Active participant',
                helperText: 'Answers and individual questions are shown for this participant.',
              ),
              items: [
                for (final participant in participants)
                  DropdownMenuItem(
                    value: participant['id'] as String,
                    child: Text(
                      participant['name'] as String? ?? 'Participant',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _selectedParticipantId = value),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _renameActiveParticipant,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Rename active participant'),
              ),
            ),
            const SizedBox(height: 4),
          ],
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
          const SizedBox(height: 12),
          TextField(
            controller: _question,
            decoration: const InputDecoration(
              labelText: 'Prepared question',
              helperText: 'Shared questions get separate answers from each participant.',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: participants.isEmpty ? null : () => _addQuestion(shared: true),
                child: const Text('Add shared question'),
              ),
              FilledButton.tonal(
                onPressed: participants.isEmpty ? null : () => _addQuestion(shared: false),
                child: const Text('Add question for selected participant'),
              ),
            ],
          ),
          if (questions.isEmpty && participants.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No prepared questions for this participant yet.'),
            ),
          for (final question in questions)
            _GuestQuestionEditor(
              key: ValueKey(question['id']),
              question: question,
              participants: activeParticipant == null
                  ? const []
                  : [activeParticipant],
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
    this.nested = false,
    super.key,
  });

  final Map<String, dynamic> question;
  final List<Map<String, dynamic>> participants;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final VoidCallback onRemove;
  final Map<String, dynamic> Function(String, List<String>) makeQuestion;
  final bool nested;

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
    var answer = _answerForParticipant(answers, participantId);
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
    var answer = _answerForParticipant(answers, participantId);
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
    final followUp = widget.makeQuestion(text, [participantId]);
    followUp['scope'] = 'participant';
    followUp['target_participant_id'] = participantId;
    followUps.add(followUp);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 440;
        return Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: widget.nested && narrow ? 0 : 12,
            ),
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
                Text(
                  widget.nested
                      ? 'Answer-owned follow-up'
                      : scope == 'shared'
                      ? 'Shared question'
                      : 'Participant-specific question',
                ),
                for (final participant in applicable)
                  _GuestAnswerEditor(
                    key: ValueKey('${id}_${participant['id']}'),
                    participant: participant,
                    answer: _answers
                        .where(
                          (answer) =>
                              answer['participant_id'] == participant['id'],
                        )
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
      },
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

Map<String, dynamic>? _answerForParticipant(
  List answers,
  String participantId,
) {
  for (final item in answers) {
    if (item is Map && item['participant_id'] == participantId) {
      return item.cast<String, dynamic>();
    }
  }
  return null;
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
          LayoutBuilder(
            builder: (context, constraints) {
              final actions = [
                IconButton(
                  tooltip: 'Add answer-owned follow-up',
                  onPressed: _addFollowUp,
                  icon: const Icon(Icons.add_comment_outlined),
                ),
                if (branches.isNotEmpty)
                  IconButton(
                    tooltip: collapsed
                        ? 'Expand follow-ups'
                        : 'Collapse follow-ups',
                    onPressed: () {
                      final updated = _copyMap(widget.answer!);
                      updated['branches_collapsed'] = !collapsed;
                      widget.onUpdate(updated);
                    },
                    icon: Icon(
                      collapsed ? Icons.expand_more : Icons.expand_less,
                    ),
                  ),
                if (branches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('${branches.length} follow-ups'),
                  ),
              ];
              final field = TextField(
                controller: _followUp,
                decoration: const InputDecoration(
                  labelText: 'Follow-up question',
                ),
                onSubmitted: (_) => _addFollowUp(),
              );
              if (constraints.maxWidth < 440) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [field, Wrap(children: actions)],
                );
              }
              return Row(
                children: [Expanded(child: field), ...actions],
              );
            },
          ),
          if (branches.isNotEmpty && !collapsed)
            LayoutBuilder(
              builder: (context, constraints) => Padding(
                padding: EdgeInsets.only(
                  left: constraints.maxWidth < 440 ? 0 : 8,
                ),
                child: Column(
                  children: [
                    for (final branch in branches)
                      _GuestQuestionEditor(
                        key: ValueKey((branch as Map<String, dynamic>)['id']),
                        question: branch,
                        participants: [widget.participant],
                        nested: true,
                        onRemove: () => _removeNestedBranch(branch),
                        onUpdate: (updated) {
                          final answer = _copyMap(widget.answer!);
                          _replaceInQuestions(
                            answer['follow_ups'] as List,
                            updated,
                          );
                          widget.onUpdate(answer);
                        },
                        makeQuestion: widget.makeQuestion,
                      ),
                  ],
                ),
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

class SharedGuestGroupsPage extends ConsumerStatefulWidget {
  const SharedGuestGroupsPage({super.key});

  @override
  ConsumerState<SharedGuestGroupsPage> createState() =>
      _SharedGuestGroupsPageState();
}

class _SharedGuestGroupsPageState extends ConsumerState<SharedGuestGroupsPage>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>> _entries = const [];
  List<Map<String, dynamic>> _invitations = const [];
  Map<String, dynamic>? _group;
  String? _groupId;
  bool _busy = false;
  String? _error;

  GuestGroupRepository get _repository => ref.read(guestGroupRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGroups());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _loadGroups();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _busy = true;
      _error = null;
      _groups = const [];
      _group = null;
      _entries = const [];
      _invitations = const [];
    });
    try {
      final groups = await _repository.listGroups();
      final selected = groups.any((group) => group['id'] == _groupId)
          ? _groupId
          : groups.isEmpty
          ? null
          : groups.first['id'] as String;
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _groupId = selected;
      });
      if (selected != null) {
        await _loadGroup(selected);
      } else {
        setState(() {
          _group = null;
          _entries = const [];
          _invitations = const [];
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _groups = const [];
          _group = null;
          _entries = const [];
          _invitations = const [];
          _error = _safeGuestError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadGroup(String groupId) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _group = null;
      _entries = const [];
      _invitations = const [];
      _groupId = groupId;
    });
    try {
      final detail = await _repository.getGroup(groupId);
      final entries = await _repository.searchEntries(
        groupId: groupId,
        query: _search.text,
      );
      final invitations = detail['role'] == 'admin'
          ? await _repository.listInvitations(groupId)
          : const <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _groupId = groupId;
        _group = detail;
        _entries = entries;
        _invitations = invitations;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = _safeGuestError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGroup() async {
    final name = TextEditingController();
    final displayName = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a shared guest group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This explicitly stores the group and membership online. '
              'Only content you later choose to share is uploaded.',
            ),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Group name')),
            TextField(
              controller: displayName,
              decoration: const InputDecoration(labelText: 'Your display name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create group')),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      name.dispose();
      displayName.dispose();
      return;
    }
    final groupName = name.text.trim();
    final memberName = displayName.text.trim();
    name.dispose();
    displayName.dispose();
    if (groupName.isEmpty || memberName.isEmpty) return;
    await _run(() async {
      final group = await _repository.createGroup(
        name: groupName,
        displayName: memberName,
      );
      _groupId = group['id'] as String;
      await _loadGroups();
    });
  }

  Future<void> _joinByInvitation() async {
    final token = TextEditingController();
    final displayName = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a guest group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste an invitation token. Preview checks validity only and reveals no group content.'),
            TextField(controller: token, decoration: const InputDecoration(labelText: 'Invitation token')),
            TextField(controller: displayName, decoration: const InputDecoration(labelText: 'Display name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Preview invitation')),
        ],
      ),
    );
    final inviteToken = token.text.trim();
    final memberName = displayName.text.trim();
    token.dispose();
    displayName.dispose();
    if (accepted != true || inviteToken.isEmpty || memberName.isEmpty || !mounted) return;
    await _run(() async {
      if (!await _repository.previewInvitation(inviteToken)) {
        throw StateError('This invitation is unavailable, expired or revoked.');
      }
      if (!mounted) return;
      final join = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request to join?'),
          content: const Text(
            'The host must approve your membership. This request does not grant access to group content, and your display name is not identity verification.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Request access')),
          ],
        ),
      );
      if (join != true) return;
      final membership = await _repository.joinInvitation(
        token: inviteToken,
        displayName: memberName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              membership['status'] == 'pending'
                  ? 'Join request sent; the host must approve before you can access content.'
                  : 'Guest group membership confirmed.',
            ),
          ),
        );
      }
      await _loadGroups();
    });
  }

  Future<void> _createInvitation() async {
    final groupId = _groupId;
    if (groupId == null) return;
    String role = 'contributor';
    final selectedRole = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create invitation'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'New member role'),
            items: const [
              DropdownMenuItem(value: 'viewer', child: Text('Viewer — read only')),
              DropdownMenuItem(value: 'contributor', child: Text('Contributor — own content')),
              DropdownMenuItem(value: 'editor', child: Text('Editor — edit group content')),
            ],
            onChanged: (value) => setDialogState(() => role = value ?? role),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, role), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (selectedRole == null || !mounted) return;
    await _run(() async {
      final invitation = await _repository.createInvitation(
        groupId: groupId,
        role: selectedRole,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invitation created'),
          content: SelectableText(
            'Share this one-time token privately. It expires at ${invitation['expires_at']}. '
            'The token is shown only now; revoke unused invitations from the group controls.\n\n${invitation['token']}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invitation['token'] as String));
                Navigator.pop(context);
              },
              child: const Text('Copy token'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
      await _loadGroup(groupId);
    });
  }

  Future<void> _showMembers() async {
    final groupId = _groupId;
    if (groupId == null || _group == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guest group members'),
        content: SizedBox(
          width: 560,
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: ListView(
            children: [
              for (final item in (_group!['members'] as List? ?? const [])
                  .cast<Map<String, dynamic>>())
                ListTile(
                  title: Text(item['display_name'] as String? ?? 'Guest'),
                  subtitle: Text('${item['role']} · ${item['status']}'),
                  trailing: _group!['role'] == 'admin' &&
                          item['status'] == 'pending'
                      ? TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _run(() async {
                              await _repository.approveMember(
                                groupId: groupId,
                                memberId: item['id'] as String,
                              );
                              await _loadGroup(groupId);
                            });
                          },
                          child: const Text('Approve'),
                        )
                      : _group!['role'] == 'admin' &&
                              item['role'] != 'admin' &&
                              item['status'] == 'active'
                          ? PopupMenuButton<String>(
                              onSelected: (action) => _manageMemberAction(
                                groupId,
                                item,
                                action,
                              ),
                              itemBuilder: (context) => [
                                for (final role in const ['viewer', 'contributor', 'editor'])
                                  if (role != item['role'])
                                    PopupMenuItem(value: role, child: Text('Make $role')),
                                const PopupMenuItem(
                                  value: 'transfer_admin',
                                  child: Text('Transfer admin role'),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove member'),
                                ),
                              ],
                            )
                          : null,
                ),
              if (_group!['role'] == 'admin') ...[
                const Divider(),
                const Text('Active invitations'),
                for (final invite in _invitations)
                  ListTile(
                    title: Text('${invite['role']} invitation'),
                    subtitle: Text('Expires ${invite['expires_at']}'),
                    trailing: IconButton(
                      tooltip: 'Revoke invitation',
                      icon: const Icon(Icons.link_off),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _run(() async {
                          await _repository.revokeInvitation(
                            groupId: groupId,
                            invitationId: invite['id'] as String,
                          );
                          await _loadGroup(groupId);
                        });
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          if (_group!['role'] == 'admin')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _createInvitation();
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Invite member'),
            ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _manageMemberAction(
    String groupId,
    Map<String, dynamic> member,
    String action,
  ) async {
    Navigator.of(context).pop();
    if (action == 'transfer_admin' || action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'transfer_admin'
                ? 'Transfer group administration?'
                : 'Remove this guest member?',
          ),
          content: Text(action == 'transfer_admin'
              ? '${member['display_name']} will become the administrator and you will become a contributor. This does not affect organisation roles.'
              : '${member['display_name']} will lose access to this group on their next request. Already exported copies cannot be revoked.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                action == 'transfer_admin' ? 'Transfer administration' : 'Remove member',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _run(() async {
      if (action == 'remove') {
        await _repository.removeMember(
          groupId: groupId,
          memberId: member['id'] as String,
        );
      } else if (action == 'transfer_admin') {
        await _repository.transferAdministration(
          groupId: groupId,
          memberId: member['id'] as String,
        );
      } else {
        await _repository.changeMemberRole(
          groupId: groupId,
          memberId: member['id'] as String,
          role: action,
        );
      }
      await _loadGroup(groupId);
    });
  }

  Future<void> _createKnowledge() async {
    final groupId = _groupId;
    if (groupId == null) return;
    final title = TextEditingController();
    final body = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add shared Knowledge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This item will be stored online for approved group members.'),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Knowledge / answer'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Share with group')),
        ],
      ),
    );
    final itemTitle = title.text.trim();
    final itemBody = body.text.trim();
    title.dispose();
    body.dispose();
    if (accepted != true || itemTitle.isEmpty || itemBody.isEmpty || !mounted) return;
    await _run(() async {
      await _repository.createKnowledge(
        groupId: groupId,
        title: itemTitle,
        body: itemBody,
        answer: itemBody,
      );
      await _loadGroup(groupId);
    });
  }

  Future<void> _shareSelectedLocalWork() async {
    final groupId = _groupId;
    if (groupId == null) return;
    await _run(() async {
      final local = await ref.read(guestWorkspaceStoreProvider).load();
      if (!mounted) return;
      final selection = await showDialog<_GuestImportSelection>(
        context: context,
        builder: (context) => _GuestImportPreview(
          data: local,
          title: 'Preview local work to share',
          confirmLabel: 'Share selected with group',
          includeTemplates: false,
        ),
      );
      if (selection == null || !mounted) return;
      await _repository.importSelected(
        groupId: groupId,
        data: local,
        knowledgeIds: selection.knowledgeIds,
        sessionIds: selection.sessionIds,
      );
      await _loadGroup(groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected copies were shared. Your local work remains on this device.'),
          ),
        );
      }
    });
  }

  Future<void> _openEntry(Map<String, dynamic> entry) async {
    final groupId = _groupId;
    if (groupId == null) return;
    var entryDialogActive = true;
    final entryDialog = showDialog<void>(
      context: context,
      builder: (entryDialogContext) => AlertDialog(
          title: Text(entry['title'] as String? ?? 'Guest group entry'),
          content: SizedBox(
            width: 700,
            child: _GuestGroupEntryContent(entry: entry),
          ),
          actions: [
            TextButton(
              onPressed: () => _run(() async {
                final result = await _repository.exportEntry(
                  groupId: groupId,
                  entryId: entry['id'] as String,
                );
                if (entryDialogActive &&
                    entryDialogContext.mounted &&
                    (ModalRoute.of(entryDialogContext)?.isCurrent ?? false)) {
                  entryDialogActive = false;
                  Navigator.pop(entryDialogContext);
                  await _exportAuthorizedGroupEntry(result);
                }
              }),
              child: const Text('Download / Share PDF'),
            ),
            TextButton(
              onPressed: () => _run(() async {
                final history = await _repository.entryHistory(
                  groupId: groupId,
                  entryId: entry['id'] as String,
                );
                if (!entryDialogActive ||
                    !entryDialogContext.mounted ||
                    !(ModalRoute.of(entryDialogContext)?.isCurrent ?? false)) {
                  return;
                }
                await showDialog<void>(
                  context: entryDialogContext,
                  builder: (context) => AlertDialog(
                    title: const Text('Entry revisions'),
                    content: SizedBox(
                      width: 640,
                      height: MediaQuery.sizeOf(context).height * 0.55,
                      child: ListView(
                        children: [
                          for (final revision in history)
                            ListTile(
                              title: Text(
                                'Revision ${revision['revision']} · ${revision['title']}',
                              ),
                              subtitle: const Text('Updated by a group member'),
                            ),
                        ],
                      ),
                    ),
                    actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
                  ),
                );
              }),
              child: const Text('History'),
            ),
            if (_canEdit(entry))
              TextButton(
                onPressed: () {
                  entryDialogActive = false;
                  Navigator.pop(entryDialogContext);
                  _editEntry(entry);
                },
                child: const Text('Edit'),
              ),
            if (_canEdit(entry))
              TextButton(
                onPressed: () {
                  entryDialogActive = false;
                  Navigator.pop(entryDialogContext);
                  _deleteEntry(entry);
                },
                child: const Text('Delete'),
              ),
            FilledButton(
              onPressed: () {
                entryDialogActive = false;
                Navigator.pop(entryDialogContext);
              },
              child: const Text('Done'),
            ),
          ],
      ),
    );
    await entryDialog.whenComplete(() => entryDialogActive = false);
  }

  Future<void> _exportAuthorizedGroupEntry(
    Map<String, dynamic> entry,
  ) async {
    final title = entry['title'] as String? ?? 'Guest group entry';
    final data = entry['data'] is Map
        ? Map<String, dynamic>.from(entry['data'] as Map)
        : <String, dynamic>{};
    if (entry['kind'] == 'interact_session') {
      final participants = (data['participants'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final scope = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choose report scope'),
          children: [
            for (final participant in participants)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  context,
                  participant['id'] as String?,
                ),
                child: Text(
                  'Selected participant — ${participant['name'] ?? 'Participant'}',
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, '*'),
              child: const Text('All participants'),
            ),
          ],
        ),
      );
      if (scope == null || !mounted) return;
      final allParticipants = scope == '*';
      final participantId = allParticipants
          ? participants.firstOrNull?['id'] as String?
          : scope;
      final session = {...data, 'title': title};
      final report = composeGuestReport(
        session: session,
        allParticipants: allParticipants,
        participantId: participantId,
        exportedAt: DateTime.now().toUtc(),
      );
      await showDialog<void>(
        context: context,
        builder: (context) => _GuestReportPreviewDialog(
          report: report,
          onDownload: () => _downloadAuthorizedReport(
            report,
            session,
            allParticipants,
            participantId,
          ),
          onShare: () => _shareAuthorizedReport(
            report,
            session,
            allParticipants,
            participantId,
          ),
          onPrintFallback: () => openPrintableReport(
            buildGuestReportDocument(
              session: session,
              allParticipants: allParticipants,
              participantId: participantId,
              generatedAt: report.exportedAt,
            ),
          ),
        ),
      );
      return;
    }

    final document = GuestPortableDocument(
      title: title,
      scope: 'Authorized guest-group Knowledge entry',
      exportedAt: DateTime.now().toUtc(),
      sections: [
        if (data['body'] is String)
          GuestPortableSection(heading: 'Knowledge', body: data['body'] as String),
        if (data['answer'] is String)
          GuestPortableSection(heading: 'Answer', body: data['answer'] as String),
      ],
    );
    await showDialog<void>(
      context: context,
      builder: (context) => _GuestPortablePreviewDialog(
        document: document,
        onDownload: () => _downloadPortableDocument(document),
        onShare: () => _sharePortableDocument(document),
        onPrintFallback: () =>
            openPrintableReport(buildGuestPortableHtml(document)),
      ),
    );
  }

  Future<void> _downloadAuthorizedReport(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
  ) async {
    final document = buildGuestReportDocument(
      session: session,
      allParticipants: allParticipants,
      participantId: participantId,
      generatedAt: report.exportedAt,
    );
    try {
      final status = await _downloadPdfOrShareFile(
        await buildGuestReportPdf(report),
        guestReportFilename(report),
      );
      if (status == ShareResultStatus.success ||
          status == ShareResultStatus.dismissed) {
        return;
      }
    } on Object {
      // Fall through to the print-to-PDF fallback.
    }
    openPrintableReport(document);
  }

  Future<void> _shareAuthorizedReport(
    GuestReportData report,
    Map<String, dynamic> session,
    bool allParticipants,
    String? participantId,
  ) async {
    final confirmed = await _confirmPortableCopy();
    if (confirmed != true || !mounted) return;
    try {
      final bytes = await buildGuestReportPdf(report);
      final renderBox = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Share Interact PDF',
          text: 'Portable PDF copy. Recipients may retain or forward it.',
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: [guestReportFilename(report)],
          downloadFallbackEnabled: false,
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
      if (result.status == ShareResultStatus.dismissed) return;
      if (result.status == ShareResultStatus.unavailable) {
        await _downloadAuthorizedReport(
          report,
          session,
          allParticipants,
          participantId,
        );
      }
    } on Object {
      await _downloadAuthorizedReport(
        report,
        session,
        allParticipants,
        participantId,
      );
    }
  }

  Future<void> _downloadPortableDocument(
    GuestPortableDocument document,
  ) async {
    try {
      final status = await _downloadPdfOrShareFile(
        await buildGuestPortablePdf(document),
        guestPortableFilename(document),
      );
      if (status == ShareResultStatus.success ||
          status == ShareResultStatus.dismissed) {
        return;
      }
    } on Object {
      // Fall through to the print-to-PDF fallback.
    }
    openPrintableReport(buildGuestPortableHtml(document));
  }

  Future<void> _sharePortableDocument(
    GuestPortableDocument document,
  ) async {
    final confirmed = await _confirmPortableCopy();
    if (confirmed != true || !mounted) return;
    try {
      final bytes = await buildGuestPortablePdf(document);
      final renderBox = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Share PDF',
          text: 'Portable PDF copy. Recipients may retain or forward it.',
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: [guestPortableFilename(document)],
          downloadFallbackEnabled: false,
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
      if (result.status == ShareResultStatus.dismissed) return;
      if (result.status == ShareResultStatus.unavailable) {
        await _downloadPortableDocument(document);
      }
    } on Object {
      await _downloadPortableDocument(document);
    }
  }

  Future<bool?> _confirmPortableCopy() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Share a PDF copy?'),
      content: const Text(
        'Recipients can keep or forward this PDF. Removing their group access later cannot revoke a copy they downloaded.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  bool _canEdit(Map<String, dynamic> entry) {
    final role = _group?['role'];
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    return role == 'admin' ||
        role == 'editor' ||
        (role == 'contributor' && entry['created_by_uid'] == uid);
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final title = TextEditingController(text: entry['title'] as String? ?? '');
    final sourceData = entry['data'] is Map
        ? Map<String, dynamic>.from(entry['data'] as Map)
        : <String, dynamic>{};
    final body = TextEditingController(text: sourceData['body'] as String? ?? '');
    final answer = TextEditingController(
      text: sourceData['answer'] as String? ?? '',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => _GuestEntryEditDialog(
        title: title,
        body: body,
        answer: answer,
        editKnowledge: entry['kind'] != 'interact_session',
      ),
    );
    final editedTitle = title.text.trim();
    final editedBody = body.text.trim();
    final editedAnswer = answer.text.trim();
    title.dispose();
    body.dispose();
    answer.dispose();
    if (accepted != true || editedTitle.isEmpty || !mounted) return;
    final updatedData = entry['kind'] == 'interact_session'
        ? sourceData
        : {
            ...sourceData,
            'body': editedBody,
            'answer': editedAnswer,
          };
    await _run(() async {
      await _repository.updateEntry(
        groupId: groupId,
        entryId: entry['id'] as String,
        title: editedTitle,
        data: updatedData,
      );
      await _loadGroup(groupId);
    });
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete shared entry?'),
        content: const Text('This removes it from the group for all members. Existing downloads cannot be revoked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _repository.deleteEntry(
        groupId: groupId,
        entryId: entry['id'] as String,
      );
      await _loadGroup(groupId);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => _error = _safeGuestError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Shared guest groups'),
      actions: [
        IconButton(
          tooltip: 'Manage members and invitations',
          onPressed: _group == null ? null : _showMembers,
          icon: const Icon(Icons.group_outlined),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy ? null : _loadGroups,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Guest groups are separate from registered organisations. Group membership does not grant department, organisation, or private-session access. Content here is online only after you explicitly share it.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy || !_canCreateOrJoin ? null : _createGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create group'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || !_canCreateOrJoin ? null : _joinByInvitation,
              icon: const Icon(Icons.link),
              label: const Text('Join with invitation'),
            ),
          ],
        ),
        if (!_canCreateOrJoin)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'This linked account can keep using approved groups, but creating groups or redeeming invitations requires a Firebase anonymous guest identity.',
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          MaterialBanner(
            content: Text(_error!),
            actions: [TextButton(onPressed: _loadGroups, child: const Text('Retry'))],
          ),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_groups.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _groupId,
            decoration: const InputDecoration(labelText: 'Your approved guest groups'),
            items: [
              for (final group in _groups)
                DropdownMenuItem(
                  value: group['id'] as String,
                  child: Text('${group['name']} · ${group['role']}'),
                ),
            ],
            onChanged: _busy ? null : (value) => value == null ? null : _loadGroup(value),
          ),
        ],
        if (_group != null) ...[
          const SizedBox(height: 12),
          Text(
            'Approved members can access this group. Role: ${_group!['role']}. '
            'Only admins manage membership and invitations.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(labelText: 'Search group content'),
                  onSubmitted: (_) => _loadGroup(_groupId!),
                ),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: () => _loadGroup(_groupId!),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _canCreate ? _createKnowledge : null,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Add shared Knowledge'),
              ),
              OutlinedButton.icon(
                onPressed: _canCreate ? _shareSelectedLocalWork : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Preview and share local work'),
              ),
              OutlinedButton.icon(
                onPressed: _group?['role'] == 'admin' ? _createInvitation : null,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            const Text('No group content matches this search.')
          else
            for (final entry in _entries)
              Card(
                child: ListTile(
                  leading: Icon(
                    entry['kind'] == 'interact_session'
                        ? Icons.account_tree_outlined
                        : Icons.menu_book_outlined,
                  ),
                  title: Text(entry['title'] as String? ?? 'Shared content'),
                  subtitle: Text(
                    '${entry['kind']} · revision ${entry['revision']} · updated by a group member',
                  ),
                  onTap: () => _openEntry(entry),
                ),
              ),
        ] else if (!_busy && _groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No approved guest groups are linked to this device. Create a new group or request to join with an invitation. Pending requests cannot read group content.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );

  bool get _canCreate =>
      _group?['role'] == 'admin' ||
      _group?['role'] == 'editor' ||
      _group?['role'] == 'contributor';

  bool get _canCreateOrJoin =>
      ref.read(firebaseAuthProvider).currentUser?.isAnonymous == true;
}

String _safeGuestError(Object error) {
  final text = error.toString();
  if (text.contains('429')) return 'Request limit reached. Wait before trying again.';
  if (text.contains('403')) return 'This guest group action is not allowed for your role.';
  if (text.contains('404')) return 'This group, invitation or entry is unavailable.';
  if (text.contains('401')) return 'Guest identity is unavailable. Sign in again to continue.';
  return 'The guest group request failed. Check your connection and try again.';
}

Future<ShareResultStatus?> _downloadPdfOrShareFile(
  Uint8List bytes,
  String filename,
) async {
  if (await downloadPdf(bytes, filename)) return ShareResultStatus.success;
  if (kIsWeb) return null;
  final result = await SharePlus.instance.share(
    ShareParams(
      title: 'Save PDF',
      text: 'Choose a destination to save or share this PDF.',
      files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
      fileNameOverrides: [filename],
      downloadFallbackEnabled: false,
    ),
  );
  return result.status;
}

class _GuestEntryEditDialog extends StatefulWidget {
  const _GuestEntryEditDialog({
    required this.title,
    required this.body,
    required this.answer,
    required this.editKnowledge,
  });

  final TextEditingController title;
  final TextEditingController body;
  final TextEditingController answer;
  final bool editKnowledge;

  @override
  State<_GuestEntryEditDialog> createState() => _GuestEntryEditDialogState();
}

class _GuestEntryEditDialogState extends State<_GuestEntryEditDialog> {
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit shared group entry'),
    content: SizedBox(
      width: 640,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: widget.title, decoration: const InputDecoration(labelText: 'Title')),
          if (widget.editKnowledge) ...[
            TextField(
              controller: widget.body,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Knowledge'),
            ),
            TextField(
              controller: widget.answer,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Answer'),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Interact questions and answers are unchanged.'),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Save revision'),
      ),
    ],
  );
}

class _GuestReportPreviewDialog extends StatelessWidget {
  const _GuestReportPreviewDialog({
    required this.report,
    required this.onDownload,
    required this.onShare,
    required this.onPrintFallback,
  });

  final GuestReportData report;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onPrintFallback;

  Widget _question(BuildContext context, GuestReportQuestion question, int depth) {
    final indent = (depth * 12).clamp(0, 36).toDouble();
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question ${question.path}${depth > 0 ? ' · Follow-up' : ''}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (question.triggerParticipant != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Follow-up prompted by ${question.triggerParticipant}: '
                '${question.triggerAnswer?.trim().isNotEmpty == true ? question.triggerAnswer : 'Unanswered.'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SelectableText(
              question.text,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (question.answers.isEmpty)
            const ListTile(title: Text('Answer'), subtitle: Text('Unanswered.')),
          for (final answer in question.answers) ...[
            Card(
              margin: EdgeInsets.only(left: indent, top: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Answer — ${answer.participantName}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      answer.body.trim().isEmpty ? 'Unanswered.' : answer.body,
                    ),
                  ],
                ),
              ),
            ),
            for (final followUp in answer.followUps)
              _question(context, followUp, depth + 1),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Preview PDF'),
    content: SizedBox(
      width: 720,
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Portable copy · ${report.scope}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'Participants: ${report.participantNames.isEmpty ? 'Not selected' : report.participantNames.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Exported: ${report.exportedAt.toLocal()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Some uncommon characters or emoji may not render in the PDF.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: report.questions.isEmpty
                  ? const [Text('No questions are available in this report.')]
                  : [
                      for (final question in report.questions)
                        _question(context, question, 0),
                    ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: onPrintFallback,
            child: const Text('Print / Save PDF fallback'),
          ),
          OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share PDF'),
          ),
          FilledButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    ],
  );
}

class _GuestPortablePreviewDialog extends StatelessWidget {
  const _GuestPortablePreviewDialog({
    required this.document,
    required this.onDownload,
    required this.onShare,
    required this.onPrintFallback,
  });

  final GuestPortableDocument document;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onPrintFallback;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Preview PDF'),
    content: SizedBox(
      width: 720,
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: ListView(
        children: [
          Text(document.title, style: Theme.of(context).textTheme.titleLarge),
          Text('Portable copy · ${document.scope}'),
          Text('Exported: ${document.exportedAt.toLocal()}'),
          const Text(
            'Some uncommon characters or emoji may not render in the PDF.',
          ),
          const Divider(),
          for (final section in document.sections) ...[
            Text(section.heading, style: Theme.of(context).textTheme.titleMedium),
            SelectableText(
              section.body.trim().isEmpty ? 'Not provided.' : section.body,
            ),
            const SizedBox(height: 16),
          ],
          if (document.sections.isEmpty)
            const Text('No report content is available.'),
        ],
      ),
    ),
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: onPrintFallback,
            child: const Text('Print / Save PDF fallback'),
          ),
          OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share PDF'),
          ),
          FilledButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    ],
  );
}

class _GuestGroupEntryContent extends StatelessWidget {
  const _GuestGroupEntryContent({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final data = entry['data'] is Map
        ? Map<String, dynamic>.from(entry['data'] as Map)
        : <String, dynamic>{};
    if (entry['kind'] != 'interact_session') {
      return ListView(
        shrinkWrap: true,
        children: [
          for (final item in [
            ('Knowledge', data['body']),
            ('Answer', data['answer']),
          ])
            if (item.$2 is String && (item.$2 as String).isNotEmpty) ...[
              Text(item.$1, style: Theme.of(context).textTheme.titleSmall),
              SelectableText(item.$2 as String),
              const SizedBox(height: 12),
            ],
        ],
      );
    }
    final report = composeGuestReport(
      session: {
        ...data,
        'title': entry['title'] as String? ?? 'Interact session',
      },
      allParticipants: true,
      participantId: null,
      exportedAt: DateTime.now().toUtc(),
    );
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          'All participants · ${report.participantNames.join(', ')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final question in report.questions)
          _GuestEntryQuestionContent(question: question, depth: 0),
      ],
    );
  }
}

class _GuestEntryQuestionContent extends StatelessWidget {
  const _GuestEntryQuestionContent({
    required this.question,
    required this.depth,
  });

  final GuestReportQuestion question;
  final int depth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: (depth * 12).clamp(0, 36).toDouble(), top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(question.text, style: Theme.of(context).textTheme.titleSmall),
        if (question.triggerParticipant != null)
          Text(
            'Follow-up prompted by ${question.triggerParticipant}: '
            '${question.triggerAnswer?.trim().isNotEmpty == true ? question.triggerAnswer : 'Unanswered.'}',
          ),
        if (question.answers.isEmpty) const Text('Unanswered.'),
        for (final answer in question.answers) ...[
          Text('Answer — ${answer.participantName}'),
          SelectableText(answer.body.trim().isEmpty ? 'Unanswered.' : answer.body),
          for (final followUp in answer.followUps)
            _GuestEntryQuestionContent(
              question: followUp,
              depth: depth + 1,
            ),
        ],
      ],
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
  const _GuestImportPreview({
    required this.data,
    this.title = 'Confirm selected local import',
    this.confirmLabel = 'Import selected locally',
    this.includeTemplates = true,
  });

  final GuestWorkspaceData data;
  final String title;
  final String confirmLabel;
  final bool includeTemplates;

  @override
  State<_GuestImportPreview> createState() => _GuestImportPreviewState();
}

class _GuestImportPreviewState extends State<_GuestImportPreview> {
  late final Set<String> _knowledge =
      widget.data.knowledge.map((item) => item['id'] as String).toSet();
  late final Set<String> _sessions =
      widget.data.sessions.map((item) => item['id'] as String).toSet();
  late final Set<String> _templates =
      widget.includeTemplates
          ? widget.data.templates.map((item) => item['id'] as String).toSet()
          : <String>{};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 560,
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: ListView(
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
          if (!widget.includeTemplates && widget.data.templates.isNotEmpty)
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Local templates remain on this device'),
            ),
          if (widget.includeTemplates)
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
        child: Text(widget.confirmLabel),
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
