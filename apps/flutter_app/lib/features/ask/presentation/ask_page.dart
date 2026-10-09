import 'package:flutter/material.dart';
import 'package:int_qa_flow/shared/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/ask/application/ask_suggestions_controller.dart';
import 'package:int_qa_flow/shared/widgets/knowledge_section_tabs.dart';
import 'package:int_qa_flow/features/knowledge/presentation/unified_search_results.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';

class AskPage extends ConsumerStatefulWidget {
  const AskPage({super.key});

  @override
  ConsumerState<AskPage> createState() => _AskPageState();
}

class _AskPageState extends ConsumerState<AskPage> {
  final _titleController = TextEditingController();
  final _detailController = TextEditingController();
  final _detailFocus = FocusNode();
  final _optionsController = ExpansibleController();
  String? _departmentId;
  String? _teamId;

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _detailFocus.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(askControllerProvider);
    final suggestions = ref.watch(askSuggestionsProvider);
    final departments = ref.watch(departmentsProvider);
    final teams = ref.watch(teamsProvider);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: Responsive.pagePadding(context, desktop: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const KnowledgeSectionTabs(selected: KnowledgeSection.ask),
                const SizedBox(height: 12),
                Text(
                  'What do you need to know?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Ask a question'),
                  onChanged: (_) => _questionChanged(),
                  onSubmitted: (_) {
                    _optionsController.expand();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _detailFocus.requestFocus();
                    });
                  },
                ),
                UnifiedSearchResults(
                  suggestions: suggestions,
                  onOpenLocalInteract: (hit) =>
                      openLocalInteractSearchResult(context, hit),
                  onRetry: ref.read(askSuggestionsProvider.notifier).retry,
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  key: const PageStorageKey('organisation-question-options'),
                  controller: _optionsController,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  maintainState: true,
                  title: const Text('Details and assignment (optional)'),
                  subtitle: _departmentId != null || _teamId != null
                      ? const Text('Assignment selected')
                      : null,
                  children: [
                    TextField(
                      controller: _detailController,
                      focusNode: _detailFocus,
                      textInputAction: TextInputAction.newline,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Add detail (optional)',
                      ),
                      onChanged: (_) => _questionChanged(),
                    ),
                    const SizedBox(height: 12),
                    departments.when(
                      data: (items) => DropdownButtonFormField<String?>(
                        initialValue: _departmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department (optional)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No department'),
                          ),
                          for (final department in items)
                            DropdownMenuItem(
                              value: department.id,
                              child: Text(department.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _departmentId = value),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) =>
                          const Text('Departments are unavailable.'),
                    ),
                    const SizedBox(height: 12),
                    teams.when(
                      data: (items) => DropdownButtonFormField<String?>(
                        initialValue: _teamId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Team (optional)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No team'),
                          ),
                          for (final team in items.where(
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
                            items,
                            value,
                            _departmentId,
                          );
                        }),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Teams are unavailable.'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed:
                        _titleController.text.trim().isEmpty ||
                            submission.isLoading
                        ? null
                        : _submit,
                    icon: submission.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      suggestions.value?.hits.isNotEmpty == true
                          ? 'Ask as new question'
                          : 'Ask',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _questionChanged() {
    setState(() {});
    final query = _titleController.text.trim();
    ref.read(askSuggestionsProvider.notifier).queryChanged(query);
  }

  Future<void> _submit() async {
    final questionId = await ref
        .read(askControllerProvider.notifier)
        .submit(
          title: _titleController.text.trim(),
          body: _detailController.text.trim(),
          departmentId: _departmentId,
          teamId: _teamId,
        );
    if (!mounted) return;

    if (questionId != null) {
      context.go('/questions/$questionId');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to submit the question.')),
    );
  }
}
