import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/guided/application/guided_providers.dart';
import 'package:int_qa_flow/features/guided/data/guided_repository.dart';
import 'package:int_qa_flow/features/guided/domain/guided_models.dart';

class GuidedPage extends ConsumerWidget {
  const GuidedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftGuidedSessionsProvider);
    final active = ref.watch(activeGuidedSessionsProvider);
    final completed = ref.watch(completedGuidedSessionsProvider);
    final templates = ref.watch(guidedTemplatesProvider);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'IntQAFlow Interact',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Tooltip(
                  message: 'Import legacy Interact JSON',
                  child: IconButton(
                    icon: const Icon(Icons.upload_file_outlined),
                    onPressed: () => _importLegacy(context, ref),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New session'),
                  onPressed: () => _createSession(context, ref),
                ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Active sessions'),
              Tab(text: 'Templates'),
              Tab(text: 'Completed sessions'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SessionsList(groups: [drafts, active]),
                _TemplatesList(templates: templates),
                _SessionsList(groups: [completed]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSession(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final owner = TextEditingController();
    final reference = TextEditingController();
    String visibility = 'private';
    String? templateId;
    String? departmentId;
    String? teamId;
    final templates = await ref.read(guidedTemplatesProvider.future);
    final departments = await ref.read(departmentsProvider.future);
    final teams = await ref.read(teamsProvider.future);
    if (!context.mounted) return;
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Interact session'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Session title')),
                  TextField(controller: owner, decoration: const InputDecoration(labelText: 'Owner (optional)')),
                  TextField(controller: reference, decoration: const InputDecoration(labelText: 'Context / reference')),
                  DropdownButtonFormField<String?>(
                    initialValue: templateId,
                    decoration: const InputDecoration(labelText: 'Start'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Blank session')),
                      for (final template in templates)
                        DropdownMenuItem(value: template.id, child: Text('${template.name} · v${template.currentVersion}')),
                    ],
                    onChanged: (value) => setState(() => templateId = value),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: departmentId,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No department')),
                      for (final item in departments) DropdownMenuItem(value: item.id, child: Text(item.name)),
                    ],
                    onChanged: (value) => setState(() => departmentId = value),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: teamId,
                    decoration: const InputDecoration(labelText: 'Team'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No team')),
                      for (final item in teams) DropdownMenuItem(value: item.id, child: Text(item.name)),
                    ],
                    onChanged: (value) => setState(() => teamId = value),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: visibility,
                    decoration: const InputDecoration(labelText: 'Visibility'),
                    items: const [
                      DropdownMenuItem(value: 'private', child: Text('Private')),
                      DropdownMenuItem(value: 'department', child: Text('Department')),
                      DropdownMenuItem(value: 'team', child: Text('Team')),
                      DropdownMenuItem(value: 'organisation', child: Text('Organisation')),
                    ],
                    onChanged: (value) => setState(() => visibility = value ?? 'private'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (create != true || title.text.trim().isEmpty) return;
    final session = await ref.read(guidedRepositoryProvider).createSession(
          title: title.text.trim(),
          owner: owner.text.trim().isEmpty ? null : owner.text.trim(),
          contextReference: reference.text.trim().isEmpty ? null : reference.text.trim(),
          departmentId: departmentId,
          teamId: teamId,
          visibility: visibility,
          templateId: templateId,
        );
    invalidateGuidedLists(ref);
    if (context.mounted) context.go('/guided/sessions/${session.id}');
  }

  Future<void> _importLegacy(BuildContext context, WidgetRef ref) async {
    final payload = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import legacy Interact JSON'),
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: payload,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(labelText: 'Legacy JSON'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );
    if (submit != true || payload.text.trim().isEmpty) return;
    final session = await ref.read(guidedRepositoryProvider).importLegacy(payload.text);
    invalidateGuidedLists(ref);
    if (context.mounted) context.go('/guided/sessions/${session.id}');
  }
}

class _SessionsList extends StatelessWidget {
  const _SessionsList({required this.groups});
  final List<AsyncValue<List<GuidedSessionSummary>>> groups;

  @override
  Widget build(BuildContext context) {
    final loading = groups.any((group) => group.isLoading);
    final sessions = groups.expand((group) => group.value ?? const <GuidedSessionSummary>[]).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    if (loading && sessions.isEmpty) return const Center(child: CircularProgressIndicator());
    if (sessions.isEmpty) return const Center(child: Text('No sessions here yet.'));
    return ListView.separated(
      padding: const EdgeInsets.all(32),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          title: Text(session.title),
          subtitle: Text([
            session.status,
            session.visibility,
            if (session.contextReference?.isNotEmpty == true) session.contextReference!,
          ].join(' · ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/guided/sessions/${session.id}'),
        );
      },
    );
  }
}

class _TemplatesList extends ConsumerWidget {
  const _TemplatesList({required this.templates});
  final AsyncValue<List<GuidedTemplate>> templates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return templates.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Unable to load templates.')),
      data: (items) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Create template'),
                  onPressed: () => _create(context, ref),
                ),
                IconButton(
                  tooltip: 'Import templates',
                  icon: const Icon(Icons.upload_file_outlined),
                  onPressed: () => _import(context, ref),
                ),
                IconButton(
                  tooltip: 'Export templates',
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => _export(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (items.isEmpty) const Center(child: Text('No templates yet.')),
          for (final item in items)
            ListTile(
              title: Text(item.name),
              subtitle: Text('v${item.currentVersion} · ${item.questions.length} questions · ${item.status}'),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  final repository = ref.read(guidedRepositoryProvider);
                  if (action == 'version') {
                    await _saveVersion(context, ref, item);
                    return;
                  }
                  if (action == 'duplicate') await repository.duplicateTemplate(item.id);
                  if (action == 'archive') await repository.archiveTemplate(item.id);
                  ref.invalidate(guidedTemplatesProvider);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'version', child: Text('Save as new version')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
              onTap: item.status == 'active' ? () => _start(context, ref, item) : null,
            ),
        ],
      ),
    );
  }

  Future<void> _saveVersion(
    BuildContext context,
    WidgetRef ref,
    GuidedTemplate template,
  ) async {
    final drafts = [
      for (final question in template.questions)
        _TemplateVersionDraftQuestion.existing(question),
    ];
    final questionsWithChildren = template.questions
        .map((question) => question.parentTemplateQuestionId)
        .whereType<String>()
        .toSet();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final canSave =
              drafts.isNotEmpty &&
              drafts.every((draft) => draft.controller.text.trim().isNotEmpty);
          return AlertDialog(
            title: Text('Edit questions for v${template.currentVersion + 1}'),
            content: SizedBox(
              width: 600,
              height: 520,
              child: ListView(
                children: [
                  for (final draft in drafts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: ValueKey('template-question-${draft.id}'),
                              controller: draft.controller,
                              decoration: InputDecoration(
                                labelText: draft.source?.scope == 'participant'
                                    ? 'Participant question'
                                    : 'Shared question',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(
                            tooltip: questionsWithChildren.contains(draft.id)
                                ? 'Remove child questions first'
                                : 'Remove draft question',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: questionsWithChildren.contains(draft.id)
                                ? null
                                : () => setState(() {
                                    drafts.remove(draft);
                                    draft.controller.dispose();
                                  }),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add shared question'),
                      onPressed: () => setState(() {
                        drafts.add(_TemplateVersionDraftQuestion.newShared());
                      }),
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
                onPressed: canSave
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text('Save new version'),
              ),
            ],
          );
        },
      ),
    );
    try {
      if (save == true) {
        final questions = [
          for (var index = 0; index < drafts.length; index++)
            GuidedTemplateQuestion(
              id: drafts[index].id,
              text: drafts[index].controller.text.trim(),
              scope: drafts[index].source?.scope ?? 'shared',
              orderIndex: index,
              participantReference: drafts[index].source?.participantReference,
              parentTemplateQuestionId:
                  drafts[index].source?.parentTemplateQuestionId,
            ),
        ];
        await ref
            .read(guidedRepositoryProvider)
            .versionTemplate(template.id, questions);
        ref.invalidate(guidedTemplatesProvider);
      }
    } finally {
      for (final draft in drafts) {
        draft.controller.dispose();
      }
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final questions = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create template'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Template name')),
            TextField(
              controller: questions,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(labelText: 'Shared questions · one per line'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    final lines = questions.text.split('\n').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    if (submit != true || name.text.trim().isEmpty || lines.isEmpty) return;
    await ref.read(guidedRepositoryProvider).createTemplate(name.text.trim(), lines);
    ref.invalidate(guidedTemplatesProvider);
  }

  Future<void> _start(BuildContext context, WidgetRef ref, GuidedTemplate template) async {
    final session = await ref.read(guidedRepositoryProvider).createSession(
          title: template.name,
          templateId: template.id,
        );
    invalidateGuidedLists(ref);
    if (context.mounted) context.go('/guided/sessions/${session.id}');
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final payload = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import templates'),
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: payload,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(labelText: 'Template JSON'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );
    if (submit != true || payload.text.trim().isEmpty) return;
    await ref.read(guidedRepositoryProvider).importTemplates(payload.text);
    ref.invalidate(guidedTemplatesProvider);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final contents = await ref.read(guidedRepositoryProvider).exportTemplates();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Template JSON export'),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _TemplateVersionDraftQuestion {
  _TemplateVersionDraftQuestion.existing(GuidedTemplateQuestion question)
    : id = question.id,
      source = question,
      controller = TextEditingController(text: question.text);

  _TemplateVersionDraftQuestion.newShared()
    : id = 'draft-${DateTime.now().microsecondsSinceEpoch}',
      source = null,
      controller = TextEditingController();

  final String id;
  final GuidedTemplateQuestion? source;
  final TextEditingController controller;
}
