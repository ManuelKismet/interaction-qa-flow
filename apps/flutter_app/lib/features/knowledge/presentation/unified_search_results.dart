import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/features/ask/application/ask_suggestions_controller.dart';

enum SearchResultFilter { all, knowledge, interact }

class UnifiedSearchResults extends StatefulWidget {
  const UnifiedSearchResults({
    required this.suggestions,
    required this.onRetry,
    required this.onOpenLocalInteract,
    this.onOpenPersonalKnowledge,
    this.onOpenGroupResult,
    super.key,
  });
  final AsyncValue<AskSuggestions> suggestions;
  final VoidCallback onRetry;
  final ValueChanged<AskKnowledgeHit> onOpenLocalInteract;
  final ValueChanged<String>? onOpenPersonalKnowledge;
  final ValueChanged<AskKnowledgeHit>? onOpenGroupResult;

  @override
  State<UnifiedSearchResults> createState() => _UnifiedSearchResultsState();
}

class _UnifiedSearchResultsState extends State<UnifiedSearchResults> {
  SearchResultFilter _filter = SearchResultFilter.all;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.suggestions.value?.hasSearched == true)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final filter in SearchResultFilter.values)
                ChoiceChip(
                  label: Text(switch (filter) {
                    SearchResultFilter.all => 'All',
                    SearchResultFilter.knowledge => 'Knowledge',
                    SearchResultFilter.interact => 'Interact',
                  }),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
        ),
      _SearchResultList(
        suggestions: widget.suggestions,
        onRetry: widget.onRetry,
        filter: _filter,
        onOpenLocalInteract: widget.onOpenLocalInteract,
        onOpenPersonalKnowledge: widget.onOpenPersonalKnowledge,
        onOpenGroupResult: widget.onOpenGroupResult,
      ),
    ],
  );
}

class _SearchResultList extends StatelessWidget {
  const _SearchResultList({
    required this.suggestions,
    required this.onRetry,
    required this.filter,
    required this.onOpenLocalInteract,
    this.onOpenPersonalKnowledge,
    this.onOpenGroupResult,
  });

  final AsyncValue<AskSuggestions> suggestions;
  final VoidCallback onRetry;
  final SearchResultFilter filter;
  final ValueChanged<AskKnowledgeHit> onOpenLocalInteract;
  final ValueChanged<String>? onOpenPersonalKnowledge;
  final ValueChanged<AskKnowledgeHit>? onOpenGroupResult;

  @override
  Widget build(BuildContext context) {
    return suggestions.when(
      data: (items) {
        final hits = items.hits
            .where(
              (hit) => switch (filter) {
                SearchResultFilter.all => true,
                SearchResultFilter.knowledge => !hit.isInteract,
                SearchResultFilter.interact => hit.isInteract,
              },
            )
            .toList();
        if (hits.isEmpty &&
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
                'Search results',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (hits.any((hit) => hit.isInteract))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Interact content is session work, not approved Knowledge.',
                  ),
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
              if (hits.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD5DAD8)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < hits.length; index++) ...[
                        _SuggestionRow(
                          result: hits[index],
                          onOpenLocalInteract: onOpenLocalInteract,
                          onOpenPersonalKnowledge: onOpenPersonalKnowledge,
                          onOpenGroupResult: onOpenGroupResult,
                        ),
                        if (index < hits.length - 1) const Divider(height: 1),
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
                          'Some accessible sources could not be '
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
              if (hits.isEmpty &&
                  items.failedSources.isEmpty &&
                  items.partialSources.isEmpty &&
                  items.hasSearched &&
                  items.notice == null)
                const Text('No matching results.'),
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
  const _SuggestionRow({
    required this.result,
    required this.onOpenLocalInteract,
    this.onOpenPersonalKnowledge,
    this.onOpenGroupResult,
  });

  final AskKnowledgeHit result;
  final ValueChanged<AskKnowledgeHit> onOpenLocalInteract;
  final ValueChanged<String>? onOpenPersonalKnowledge;
  final ValueChanged<AskKnowledgeHit>? onOpenGroupResult;

  @override
  Widget build(BuildContext context) {
    final highRelevance = result.relevance >= 1.2;
    return InkWell(
      onTap: () {
        if (result.isInteract) {
          if (result.source == 'Local') {
            onOpenLocalInteract(result);
            return;
          }
          final params = <String, String>{
            if (result.questionId != null) 'questionId': result.questionId!,
            if (result.participantId != null)
              'participantId': result.participantId!,
          };
          if (result.destination == 'group') {
            if (onOpenGroupResult != null) {
              onOpenGroupResult!(result);
              return;
            }
            params.addAll({'groupId': result.groupId!, 'entryId': result.id});
            context.go(
              Uri(path: '/guest/groups', queryParameters: params).toString(),
            );
          } else {
            final path = result.destination == 'organisation_interact'
                ? '/guided/sessions/${Uri.encodeComponent(result.sessionId!)}'
                : '/personal/interact/sessions/${Uri.encodeComponent(result.sessionId!)}';
            context.go(
              Uri.parse(path)
                  .replace(queryParameters: params.isEmpty ? null : params)
                  .toString(),
            );
          }
          return;
        }
        switch (result.destination) {
          case 'organisation':
            context.go('/questions/${result.id}');
          case 'group':
            if (onOpenGroupResult != null) {
              onOpenGroupResult!(result);
              return;
            }
            context.go(
              Uri(
                path: '/guest/groups',
                queryParameters: {
                  'groupId': result.groupId ?? '',
                  'entryId': result.id,
                },
              ).toString(),
            );
          default:
            if (onOpenPersonalKnowledge != null) {
              onOpenPersonalKnowledge!(result.id);
            } else {
              context.go(
                Uri(
                  path: '/personal/questions',
                  queryParameters: {'knowledgeItemId': result.id},
                ).toString(),
              );
            }
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
                      if (result.isInteract)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Interact'),
                        ),
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
