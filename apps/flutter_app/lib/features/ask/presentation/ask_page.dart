import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/ask/application/ask_suggestions_controller.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';
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
                _SuggestionList(suggestions: suggestions),
                const SizedBox(height: 12),
                TextField(
                  controller: _detailController,
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
                      suggestions.value?.isNotEmpty == true
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
  const _SuggestionList({required this.suggestions});

  final AsyncValue<List<SemanticSearchResult>> suggestions;

  @override
  Widget build(BuildContext context) {
    return suggestions.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Related questions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD5DAD8)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _SuggestionRow(result: items[index]),
                      if (index < items.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
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

  final SemanticSearchResult result;

  @override
  Widget build(BuildContext context) {
    final highConfidence = result.confidence == 'high_confidence';
    return InkWell(
      onTap: () => context.go('/questions/${result.questionId}'),
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
                      const SizedBox(width: 8),
                      Text(
                        highConfidence ? 'Likely match' : 'Related',
                        style: TextStyle(
                          color: highConfidence
                              ? const Color(0xFF255C57)
                              : const Color(0xFF8A5A00),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.acceptedAnswerBody ?? 'No answer yet.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (result.department != null) result.department!.name,
                      if (result.team != null) result.team!.name,
                      if (result.answerStatus == 'verified')
                        'Verified answer'
                      else if (result.acceptedAnswerBody != null)
                        'Existing answer'
                      else
                        'Open question',
                    ].join(' · '),
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
