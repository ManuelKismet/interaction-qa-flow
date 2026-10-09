import 'package:flutter/material.dart';
import 'package:int_qa_flow/shared/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/questions/application/question_providers.dart';
import 'package:int_qa_flow/features/questions/domain/question_models.dart';
import 'package:int_qa_flow/shared/widgets/knowledge_section_tabs.dart';

class QuestionsPage extends ConsumerWidget {
  const QuestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(questionFilterProvider);
    final questions = ref.watch(questionsProvider);
    final scope = ref.watch(questionScopeFilterProvider);
    final departments = ref.watch(departmentsProvider);
    final teams = ref.watch(teamsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(questionsProvider.future),
      child: ListView(
        padding: Responsive.pagePadding(context, desktop: 16),
        children: [
          const KnowledgeSectionTabs(selected: KnowledgeSection.questions),
          const SizedBox(height: 12),
          SegmentedButton<QuestionFilter>(
            segments: [
              for (final filter in QuestionFilter.values)
                ButtonSegment(value: filter, label: Text(filter.label)),
            ],
            selected: {selectedFilter},
            onSelectionChanged: (selection) => ref
                .read(questionFilterProvider.notifier)
                .select(selection.first),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            key: const PageStorageKey('organisation-question-filters'),
            tilePadding: EdgeInsets.zero,
            maintainState: true,
            initiallyExpanded:
                scope.departmentId != null || scope.teamId != null,
            title: const Text('Filters'),
            subtitle: Text(
              [
                if (scope.departmentId != null)
                  'Department: ${departments.value?.where((item) => item.id == scope.departmentId).firstOrNull?.name ?? 'Selected'}',
                if (scope.teamId != null)
                  'Team: ${teams.value?.where((item) => item.id == scope.teamId).firstOrNull?.name ?? 'Selected'}',
                if (scope.departmentId == null && scope.teamId == null)
                  'All departments and teams',
              ].join(' · '),
            ),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: departments.when(
                      data: (items) => DropdownButtonFormField<String?>(
                        initialValue: scope.departmentId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All departments'),
                          ),
                          for (final department in items)
                            DropdownMenuItem(
                              value: department.id,
                              child: Text(department.name),
                            ),
                        ],
                        onChanged: (value) => ref
                            .read(questionScopeFilterProvider.notifier)
                            .select(departmentId: value, teamId: scope.teamId),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Departments unavailable'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: teams.when(
                      data: (items) => DropdownButtonFormField<String?>(
                        initialValue: scope.teamId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Team'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All teams'),
                          ),
                          for (final team in items)
                            DropdownMenuItem(
                              value: team.id,
                              child: Text(team.name),
                            ),
                        ],
                        onChanged: (value) => ref
                            .read(questionScopeFilterProvider.notifier)
                            .select(
                              departmentId: scope.departmentId,
                              teamId: value,
                            ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Teams unavailable'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          questions.when(
            data: (items) => items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('No questions found.')),
                  )
                : Column(
                    children: [
                      for (final question in items)
                        _QuestionRow(
                          question: question,
                          onTap: () => context.go('/questions/${question.id}'),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => const Center(
              child: Text('Unable to load questions. Pull down to try again.'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.question, required this.onTap});

  final QuestionSummary question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = question.createdAt.toLocal();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (question.department != null)
                        question.department!.name,
                      if (question.team != null) question.team!.name,
                      '${question.answerCount} answers',
                      '${date.day}/${date.month}/${date.year}',
                    ].join(' · '),
                  ),
                ],
              ),
            ),
            _StatusLabel(status: question.status),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Text(
      status.replaceAll('_', ' '),
      style: TextStyle(
        color: status == 'resolved' ? const Color(0xFF255C57) : Colors.black54,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
