import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/ask/application/ask_suggestions_controller.dart';
import 'package:int_qa_flow/shared/widgets/knowledge_section_tabs.dart';

class AskPage extends ConsumerStatefulWidget {
  const AskPage({super.key});

  @override
  ConsumerState<AskPage> createState() => _AskPageState();
}

class _AskPageState extends ConsumerState<AskPage> {
  final _titleController = TextEditingController();
  final _detailController = TextEditingController();
  String? _departmentId;
  String? _teamId;

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
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
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'IntQAFlow Knowledge',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const KnowledgeSectionTabs(selected: KnowledgeSection.ask),
                const SizedBox(height: 28),
                Text(
                  'What do you need to know?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Ask a question'),
                  onChanged: (_) => _questionChanged(),
                ),
                _SuggestionList(
                  suggestions: suggestions,
                  onRetry: ref.read(askSuggestionsProvider.notifier).retry,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _detailController,
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
                    onChanged: (value) => setState(() => _departmentId = value),
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

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.suggestions, required this.onRetry});

  final AsyncValue<AskSuggestions> suggestions;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return suggestions.when(
      data: (items) {
        if (items.hits.isEmpty &&
            items.failedSources.isEmpty &&
            items.partialSources.isEmpty &&
            !items.hasSearched &&
            items.notice == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Related questions and Knowledge',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (items.notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    items.notice!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              if (items.hits.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD5DAD8)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < items.hits.length;
                        index++
                      ) ...[
                        _SuggestionRow(result: items.hits[index]),
                        if (index < items.hits.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              if (items.failedSources.isNotEmpty ||
                  items.partialSources.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (items.failedSources.isNotEmpty)
                        Text(
                          'Some accessible Knowledge sources could not be '
                          'searched: ${items.failedSources.join(', ')}.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (items.partialSources.isNotEmpty)
                        Text(
                          'Some sources reached their result limit: '
                          '${items.partialSources.join(', ')}.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      TextButton(
                        onPressed: items.isRefreshing ? null : onRetry,
                        child: const Text('Retry search'),
                      ),
                    ],
                  ),
                ),
              if (items.isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              if (items.hits.isEmpty &&
                  items.failedSources.isEmpty &&
                  items.partialSources.isEmpty &&
                  items.hasSearched &&
                  items.notice == null)
                const Text('No matching Knowledge found.'),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('Existing answers are temporarily unavailable.'),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.result});

  final AskKnowledgeHit result;

  @override
  Widget build(BuildContext context) {
    final highRelevance = result.relevance >= 1.2;
    return InkWell(
      onTap: () {
        switch (result.destination) {
          case 'organisation':
            context.go('/questions/${result.id}');
            break;
          case 'group':
            context.go(
              '/guest/groups?groupId=${Uri.encodeQueryComponent(result.groupId ?? '')}'
              '&entryId=${Uri.encodeQueryComponent(result.id)}',
            );
            break;
          default:
            context.go(
              '/personal/questions?knowledgeItemId=${Uri.encodeQueryComponent(result.id)}',
            );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          result.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(result.source),
                      ),
                      for (final label in result.attribution)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(label),
                        ),
                      Text(
                        result.matchMethod,
                        style: TextStyle(
                          color: highRelevance
                              ? const Color(0xFF255C57)
                              : const Color(0xFF8A5A00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (result.snippet != null && result.snippet!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        result.snippet!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    result.status,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
