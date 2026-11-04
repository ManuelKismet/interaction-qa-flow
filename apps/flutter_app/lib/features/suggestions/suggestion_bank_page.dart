import 'package:dio/dio.dart';
import 'package:int_qa_flow/core/nia/nia_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/suggestions/suggestion_bank_repository.dart';

class SuggestionBankPage extends ConsumerStatefulWidget {
  const SuggestionBankPage({
    this.realm = 'organisation',
    this.suggestionId,
    this.initialScopeId,
    this.onOpenGroupEntry,
    this.onOpenSuggestion,
    super.key,
  });
  final String realm;
  final String? suggestionId;
  final String? initialScopeId;
  final void Function(String?)? onOpenSuggestion;
  final void Function(String, String)? onOpenGroupEntry;
  @override
  ConsumerState<SuggestionBankPage> createState() => _SuggestionBankPageState();
}

class _SuggestionBankPageState extends ConsumerState<SuggestionBankPage> {
  BankJson? scope;
  String queue = 'all';
  String query = '';
  int offset = 0;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String get base =>
      widget.realm == 'group' ? '/group-suggestions' : '/suggestions';
  void refresh() {
    ref.invalidate(bankReadProvider);
  }

  void _openSuggestion(String? id) {
    if (widget.onOpenSuggestion != null) {
      widget.onOpenSuggestion!(id);
    } else {
      context.go(id == null ? base : '$base/$id');
    }
  }

  String params(BankJson values) => Uri(
    queryParameters: values.map((k, v) => MapEntry(k, v.toString())),
  ).query;
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to open the Suggestion Bank.'));
    }
    final scopes = ref.watch(bankScopesProvider((uid, widget.realm)));
    return scopes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suggestion Bank unavailable: $error'),
            TextButton(
              onPressed: () => ref.invalidate(bankScopesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (options) {
        if (options.isEmpty) {
          return const Center(
            child: Text('Join an active Group to use its Suggestion Bank.'),
          );
        }
        final selected =
            options
                .where(
                  (s) =>
                      s['scope_type'] == scope?['scope_type'] &&
                      s['scope_id'] == scope?['scope_id'],
                )
                .firstOrNull ??
            options
                .where((s) => s['scope_id'] == widget.initialScopeId)
                .firstOrNull ??
            options.first;
        final contextKey = (
          uid,
          widget.realm,
          selected['scope_type'],
          selected['scope_id'],
        );
        return KeyedSubtree(
          key: ValueKey(contextKey),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Suggestion Bank',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Propose an improvement, follow its response, and find agreed workplace practices.',
              ),
              const SizedBox(height: 16),
              if (widget.suggestionId == null)
                DropdownButtonFormField<String>(
                  initialValue:
                      '${selected['scope_type']}:${selected['scope_id']}',
                  decoration: const InputDecoration(labelText: 'Audience'),
                  items: [
                    for (final s in options)
                      DropdownMenuItem(
                        value: '${s['scope_type']}:${s['scope_id']}',
                        child: Text(
                          '${s['label']} · ${bankLabel(s['scope_type'] as String)}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    scope = options.firstWhere(
                      (s) => '${s['scope_type']}:${s['scope_id']}' == value,
                    );
                    offset = 0;
                  }),
                ),
              const SizedBox(height: 16),
              if (widget.suggestionId == null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Submit suggestion'),
                      onPressed: () async {
                        final created = await showDialog<BankJson>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => NiaHost.preserve(
                            context,
                            BankSubmissionDialog(
                              uid: uid,
                              realm: widget.realm,
                              scope: selected,
                              onOpenSuggestion: (id) => _openSuggestion(id),
                            ),
                          ),
                        );
                        if (created != null && context.mounted) {
                          refresh();
                          _openSuggestion((created['id']).toString());
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: search,
                  decoration: InputDecoration(
                    labelText: 'Search suggestions',
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.search),
                      onPressed: () => setState(() {
                        query = search.text.trim();
                        offset = 0;
                      }),
                    ),
                  ),
                  onSubmitted: (v) => setState(() {
                    query = v.trim();
                    offset = 0;
                  }),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final q in [
                      'all',
                      'following',
                      'updates',
                      'unanswered',
                      'overdue',
                      'practices',
                    ])
                      ChoiceChip(
                        label: Text(bankLabel(q)),
                        selected: queue == q,
                        onSelected: (_) => setState(() {
                          queue = q;
                          offset = 0;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _results(uid, selected),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openSuggestion(null),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to suggestions'),
                  ),
                ),
                _detail(uid),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _results(String uid, BankJson selected) {
    final key = (
      uid,
      widget.realm,
      '',
      params({
        'scope_type': selected['scope_type'],
        'scope_id': selected['scope_id'],
        'query': query,
        'queue': queue,
        'offset': offset,
      }),
    );
    final result = ref.watch(bankReadProvider(key));
    return result.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Unable to load suggestions. $e'),
      data: (data) => Column(
        children: [
          NiaInlineGuidance(
            topic: NiaTopic.suggestion,
            facts: {
              'workspace': widget.realm + ':' + selected['scope_id'].toString(),
              'overdue': (data['items'] as List).any(
                (item) => item['overdue'] == true,
              ),
              'unread': (data['items'] as List).any(
                (item) => item['unread'] == true,
              ),
            },
            actions: {
              if (queue != 'overdue')
                'overdue': (
                  'Review overdue',
                  () => setState(() {
                    queue = 'overdue';
                    offset = 0;
                  }),
                ),
              if (queue != 'updates')
                'updates': (
                  'Read updates',
                  () => setState(() {
                    queue = 'updates';
                    offset = 0;
                  }),
                ),
            },
          ),
          if ((data['items'] as List).isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No suggestions in this view.'),
            ),
          for (final raw in data['items'] as List)
            BankSummaryCard(
              item: Map<String, dynamic>.from(raw as Map),
              onTap: () => _openSuggestion((raw['id']).toString()),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (offset > 0)
                TextButton(
                  onPressed: () =>
                      setState(() => offset = (offset - 30).clamp(0, 100000)),
                  child: const Text('Previous'),
                ),
              if (data['has_more'] == true)
                TextButton(
                  onPressed: () => setState(() => offset += 30),
                  child: const Text('Next'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(String uid) {
    final key = (uid, widget.realm, '/${widget.suggestionId}', '');
    return ref
        .watch(bankReadProvider(key))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) =>
              Text('This suggestion is unavailable or your access changed. $e'),
          data: (item) => BankDetail(
            key: ValueKey((uid, widget.realm, item['id'])),
            uid: uid,
            realm: widget.realm,
            item: item,
            onChanged: refresh,
            onOpenSuggestion: (id) => _openSuggestion(id),
            onOpenGroupEntry: widget.onOpenGroupEntry,
            scopeLabel:
                (ref.read(bankScopesProvider((uid, widget.realm))).value ?? [])
                        .where(
                          (s) =>
                              s['scope_id'] == item['scope_id'] &&
                              s['scope_type'] == item['scope_type'],
                        )
                        .firstOrNull?['label']
                    as String?,
          ),
        );
  }
}

class BankSummaryCard extends StatelessWidget {
  const BankSummaryCard({required this.item, required this.onTap, super.key});
  final BankJson item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Icon(
        item['practice'] != null
            ? Icons.push_pin_outlined
            : Icons.lightbulb_outline,
      ),
      title: Text(item['title'] as String),
      subtitle: Text(
        '${bankLabel(item['status'] as String)} · ${item['owner_name'] ?? 'Awaiting reviewer'}${item['overdue'] == true ? ' · Review overdue' : ''}${item['unread'] == true ? ' · New update' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class BankSubmissionDialog extends ConsumerStatefulWidget {
  const BankSubmissionDialog({
    required this.uid,
    required this.realm,
    required this.scope,
    this.onOpenSuggestion,
    super.key,
  });
  final String uid, realm;
  final BankJson scope;
  final void Function(String)? onOpenSuggestion;
  @override
  ConsumerState<BankSubmissionDialog> createState() =>
      _BankSubmissionDialogState();
}

class _BankSubmissionDialogState extends ConsumerState<BankSubmissionDialog> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      problem = TextEditingController(),
      proposal = TextEditingController(),
      benefit = TextEditingController();
  final requestKey = bankRequestKey();
  String kind = 'suggestion';
  bool busy = false;
  bool uncertain = false;
  String? error;
  BankJson? hints;
  NiaReadGuard? relatedGuard;
  CancelToken? relatedCancellation;
  bool checkingRelated = false;
  int relatedGeneration = 0;
  @override
  void initState() {
    super.initState();
    title.addListener(_relatedQueryChanged);
  }

  Object? niaBinding;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = NiaHost.bindingOf(context);
    if (niaBinding != null && niaBinding != current) {
      relatedGeneration++;
      relatedCancellation?.cancel();
      relatedGuard?.dispose();
      relatedGuard = null;
      hints = null;
      checkingRelated = false;
    }
    niaBinding = current;
  }

  void _relatedQueryChanged() {
    relatedGeneration++;
    relatedCancellation?.cancel();
    relatedGuard?.dispose();
    relatedGuard = null;
    if (mounted)
      setState(() {
        hints = null;
        checkingRelated = false;
      });
  }

  Future<void> checkRelated() async {
    if (busy || uncertain || checkingRelated || title.text.trim().isEmpty)
      return;
    final query = title.text.trim();
    final generation = ++relatedGeneration;
    relatedGuard?.dispose();
    relatedCancellation?.cancel();
    final guard = NiaReadGuard.begin(
      context,
      subject: widget.uid,
      workspace: widget.realm + ':' + widget.scope['scope_id'].toString(),
      purpose: 'related-retrieval',
      facts: {'query': query},
    );
    if (guard == null) return;
    relatedGuard = guard;
    final cancellation = CancelToken();
    relatedCancellation = cancellation;
    setState(() {
      checkingRelated = true;
      error = null;
    });
    try {
      final result = await ref
          .read(suggestionBankRepositoryProvider)
          .request<BankJson>(
            widget.uid,
            widget.realm,
            '/nia',
            query: {
              'scope_type': widget.scope['scope_type'],
              'scope_id': widget.scope['scope_id'],
              'query': query,
            },
            cancelToken: cancellation,
          );
      if (mounted &&
          guard.current &&
          generation == relatedGeneration &&
          title.text.trim() == query) {
        setState(() => hints = result);
      }
    } catch (e) {
      if (mounted &&
          guard.current &&
          generation == relatedGeneration &&
          !cancellation.isCancelled) {
        setState(
          () => error =
              'Could not check related suggestions. Your draft is kept.',
        );
      }
    } finally {
      if (mounted && generation == relatedGeneration)
        setState(() => checkingRelated = false);
    }
  }

  Future<void> openKnowledge(BankJson knowledge) async {
    if (busy || uncertain || widget.realm != 'organisation') return;
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Open approved Knowledge?'),
        content: const Text(
          'Opening this approved answer will close this unsubmitted draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep this draft'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Open Knowledge'),
          ),
        ],
      ),
    );
    if (open == true && mounted) {
      Navigator.pop(context);
      context.go('/questions/' + knowledge['id'].toString());
    }
  }

  bool get dirty =>
      [title, problem, proposal, benefit].any((c) => c.text.isNotEmpty);
  @override
  void dispose() {
    relatedGeneration++;
    relatedCancellation?.cancel();
    relatedGuard?.dispose();
    title.removeListener(_relatedQueryChanged);
    for (final c in [title, problem, proposal, benefit]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> close() async {
    if (busy) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Discard this draft?'),
          content: const Text('Your suggestion has not been submitted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep writing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Discard draft'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      uncertain = true;
      error = null;
    });
    try {
      final result = await ref
          .read(suggestionBankRepositoryProvider)
          .request<BankJson>(
            widget.uid,
            widget.realm,
            '',
            data: {
              'scope_type': widget.scope['scope_type'],
              'scope_id': widget.scope['scope_id'],
              'client_key': requestKey,
              'kind': kind,
              'title': title.text.trim(),
              'problem': problem.text.trim(),
              'proposal': proposal.text.trim(),
              'benefit': benefit.text.trim(),
            },
          );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'Could not confirm submission. Your draft is kept; retry safely. $e',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: AlertDialog(
      title: const Text('Submit to the Suggestion Bank'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audience: ${widget.scope['label']} · ${bankLabel(widget.scope['scope_type'] as String)}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'For suggestions and everyday practices. Use your organisation’s restricted reporting process for sensitive complaints.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  items: [
                    for (final k in [
                      'suggestion',
                      'proposal',
                      'feedback',
                      'etiquette',
                    ])
                      DropdownMenuItem(value: k, child: Text(bankLabel(k))),
                  ],
                  onChanged: busy || uncertain
                      ? null
                      : (v) => setState(() => kind = v!),
                ),
                field(title, 'Title', 500),
                field(
                  problem,
                  'What problem or situation needs attention?',
                  10000,
                  lines: 3,
                ),
                field(proposal, 'What change do you propose?', 10000, lines: 3),
                field(
                  benefit,
                  'Who benefits and how?',
                  5000,
                  required: false,
                  lines: 2,
                ),
                TextButton(
                  onPressed: busy || uncertain || checkingRelated
                      ? null
                      : checkRelated,
                  child: const Text(
                    'Check related suggestions before submitting',
                  ),
                ),
                if (hints != null) ...[
                  for (final h in hints!['related'] as List)
                    ListTile(
                      title: Text(h['title'] as String),
                      subtitle: Text(bankLabel(h['status'] as String)),
                      onTap: busy
                          ? null
                          : () async {
                              final id = h['id'];
                              final open = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text(
                                    'Open the existing suggestion?',
                                  ),
                                  content: const Text(
                                    'You can support it or add an example there. Opening it will close this unsubmitted draft.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Keep this draft'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Open existing'),
                                    ),
                                  ],
                                ),
                              );
                              if (open == true && context.mounted) {
                                Navigator.pop(context);
                                if (widget.onOpenSuggestion != null) {
                                  widget.onOpenSuggestion!(id as String);
                                } else {
                                  context.go(
                                    '${widget.realm == 'group' ? '/group-suggestions' : '/suggestions'}/$id',
                                  );
                                }
                              }
                            },
                    ),
                  if (widget.realm == 'organisation')
                    for (final knowledge
                        in (hints!['knowledge'] as List? ?? const []))
                      ListTile(
                        title: Text(knowledge['title'] as String),
                        subtitle: const Text('Approved Knowledge'),
                        onTap: busy || uncertain
                            ? null
                            : () => openKnowledge(
                                Map<String, dynamic>.from(knowledge as Map),
                              ),
                      ),
                  const Text(
                    'You may still submit a separate proposal when the situation is different.',
                  ),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : close, child: const Text('Cancel')),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Submitting…' : 'Submit'),
        ),
      ],
    ),
  );
  Widget field(
    TextEditingController controller,
    String label,
    int max, {
    bool required = true,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      enabled: !busy && !uncertain,
      maxLength: max,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      validator: (v) => required && (v == null || v.trim().isEmpty)
          ? 'Please complete this field'
          : null,
    ),
  );
}

class BankDetail extends ConsumerStatefulWidget {
  const BankDetail({
    required this.uid,
    required this.realm,
    required this.item,
    required this.onChanged,
    this.onOpenGroupEntry,
    this.onOpenSuggestion,
    this.scopeLabel,
    super.key,
  });
  final String uid, realm;
  final BankJson item;
  final VoidCallback onChanged;
  final void Function(String, String)? onOpenGroupEntry;
  final String? scopeLabel;
  final void Function(String)? onOpenSuggestion;
  @override
  ConsumerState<BankDetail> createState() => _BankDetailState();
}

class _BankDetailState extends ConsumerState<BankDetail> {
  bool busy = false;
  String? error;
  final comment = TextEditingController();
  final actionKeys = <String, String>{};
  List<dynamic> older = [];
  bool more = false;
  @override
  void initState() {
    super.initState();
    more = widget.item['more_activities'] == true;
  }

  @override
  void didUpdateWidget(covariant BankDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['revision'] != widget.item['revision']) {
      older = [];
      more = widget.item['more_activities'] == true;
    }
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> act(
    String action, {
    BankJson extra = const {},
    String text = '',
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final fingerprint = '$action:$text:${extra.toString()}';
    final key = actionKeys.putIfAbsent(fingerprint, bankRequestKey);
    try {
      await ref
          .read(suggestionBankRepositoryProvider)
          .request<BankJson>(
            widget.uid,
            widget.realm,
            '/${widget.item['id']}/actions',
            data: {
              'action': action,
              'client_key': key,
              'expected_revision': widget.item['revision'],
              'text': text,
              ...extra,
            },
          );
      if (mounted) {
        comment.clear();
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'The update was not confirmed. Your input is kept. Refresh after a conflict and review the latest version. $e',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> decision(String action) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BankDecisionDialog(
        uid: widget.uid,
        realm: widget.realm,
        item: widget.item,
        action: action,
      ),
    );
    if (result == true && mounted) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audience: ${widget.scopeLabel ?? bankLabel(i['scope_type'] as String)} · ${bankLabel(i['scope_type'] as String)}',
        ),
        Text(
          i['title'] as String,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          '${bankLabel(i['kind'] as String)} · ${bankLabel(i['status'] as String)} · Submitted by ${i['author_name']}',
        ),
        const SizedBox(height: 12),
        Text('Accountable reviewer: ${i['owner_name'] ?? 'Not yet assigned'}'),
        Text('Expected review: ${i['review_due_at']}'),
        if (i['overdue'] == true)
          const Text('Review overdue — a reviewer needs to respond.'),
        if (i['unanswered'] == true)
          const Text('Awaiting an official response.'),
        const SizedBox(height: 16),
        Text('Problem', style: Theme.of(context).textTheme.titleMedium),
        SelectableText(i['problem'] as String),
        const SizedBox(height: 12),
        Text('Proposed change', style: Theme.of(context).textTheme.titleMedium),
        SelectableText(i['proposal'] as String),
        if ((i['benefit'] as String).isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Expected benefit',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SelectableText(i['benefit'] as String),
        ],
        if (i['practice'] != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agreed workplace practice',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SelectableText(i['practice'] as String),
                  const Text(
                    'This practice remains available when the proposal is closed. Revisions are recorded below.',
                  ),
                ],
              ),
            ),
          ),
        if (i['linked_to_id'] != null)
          TextButton(
            onPressed: () => widget.onOpenSuggestion != null
                ? widget.onOpenSuggestion!(i['linked_to_id'] as String)
                : context.go(
                    '${widget.realm == 'group' ? '/group-suggestions' : '/suggestions'}/${i['linked_to_id']}',
                  ),
            child: const Text('Open linked original suggestion'),
          ),
        if (i['knowledge_id'] != null)
          TextButton(
            onPressed: () => context.go('/questions/${i['knowledge_id']}'),
            child: const Text('Open linked approved Knowledge'),
          ),
        if (i['interact_id'] != null)
          TextButton(
            onPressed: () {
              if (widget.realm == 'group' && widget.onOpenGroupEntry != null) {
                widget.onOpenGroupEntry!(
                  i['scope_id'] as String,
                  i['interact_id'] as String,
                );
              } else {
                context.go(
                  widget.realm == 'group'
                      ? '/guest/groups?groupId=${i['scope_id']}&entryId=${i['interact_id']}'
                      : '/guided/sessions/${i['interact_id']}',
                );
              }
            },
            child: const Text('Open Interact review'),
          ),
        const SizedBox(height: 16),
        if (i['can_manage'] == true)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in [
                'respond',
                'assign',
                'status',
                'link_duplicate',
                if (i['linked_to_id'] != null) 'unlink_duplicate',
                'escalate',
                if (i['practice'] == null)
                  'adopt_practice'
                else ...[
                  'revise_practice',
                  'withdraw_practice',
                ],
                'start_interact',
                if (widget.realm == 'organisation') 'link_knowledge',
              ])
                OutlinedButton(
                  onPressed: busy ? null : () => decision(a),
                  child: Text(bankLabel(a)),
                ),
            ],
          ),
        if (i['can_contribute'] == true) ...[
          const SizedBox(height: 16),
          TextField(
            controller: comment,
            enabled: !busy,
            maxLength: 10000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Add a comment or concrete example',
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: busy
                    ? null
                    : () => act('comment', text: comment.text.trim()),
                child: const Text('Add contribution'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => act('support'),
                icon: const Icon(Icons.thumb_up_outlined),
                label: const Text('Support and follow'),
              ),
            ],
          ),
        ],
        if (i['following'] == true)
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    try {
                      await ref
                          .read(suggestionBankRepositoryProvider)
                          .request<BankJson>(
                            widget.uid,
                            widget.realm,
                            '/${i['id']}/seen',
                            query: {'revision': i['revision']},
                            data: {},
                          );
                      if (mounted) widget.onChanged();
                    } catch (e) {
                      if (mounted) {
                        setState(
                          () => error = 'Could not mark updates read. $e',
                        );
                      }
                    }
                  },
            child: const Text('Mark updates read'),
          ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 20),
        Text(
          'Responses and contribution history',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final e in [...i['activities'] as List, ...older])
          Card(
            child: ListTile(
              title: Text(
                '${e['actor_name']} · ${bankLabel(e['action'] as String)}',
              ),
              subtitle: Text('${e['text']}\n${e['created_at']}'),
            ),
          ),
        if (more)
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      final data = await ref
                          .read(suggestionBankRepositoryProvider)
                          .request<BankJson>(
                            widget.uid,
                            widget.realm,
                            '/${i['id']}',
                            query: {
                              'offset':
                                  (i['activities'] as List).length +
                                  older.length,
                            },
                          );
                      if (mounted) {
                        setState(() {
                          older.addAll(data['activities'] as List);
                          more = data['more_activities'] == true;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(
                          () => error = 'Could not load older history. $e',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: const Text('Load older history'),
          ),
      ],
    );
  }
}

class BankDecisionDialog extends ConsumerStatefulWidget {
  const BankDecisionDialog({
    required this.uid,
    required this.realm,
    required this.item,
    required this.action,
    super.key,
  });
  final String uid, realm, action;
  final BankJson item;
  @override
  ConsumerState<BankDecisionDialog> createState() => _BankDecisionDialogState();
}

class _BankDecisionDialogState extends ConsumerState<BankDecisionDialog> {
  final text = TextEditingController(), target = TextEditingController();
  String status = 'under_review';
  String? reviewer;
  BankJson? destination;
  DateTime? due;
  bool confirmed = false;
  String? error;
  List<BankJson>? reviewers;
  bool busy = false;
  int? latestRevision;
  final retryKeys = <String, String>{};

  @override
  void initState() {
    super.initState();
    if (widget.action == 'assign') loadReviewers();
  }

  Future<void> loadReviewers() async {
    try {
      final result = await ref
          .read(suggestionBankRepositoryProvider)
          .request<List<dynamic>>(
            widget.uid,
            widget.realm,
            '/reviewers',
            query: {
              'scope_type': widget.item['scope_type'],
              'scope_id': widget.item['scope_id'],
            },
          );
      if (mounted) {
        setState(
          () => reviewers = result
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load reviewers. $e');
    }
  }

  @override
  void dispose() {
    text.dispose();
    target.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final a = widget.action;
    if (text.text.trim().isEmpty) {
      setState(() => error = 'Explain your response or decision.');
      return;
    }
    if (a == 'assign' && (reviewer == null || due == null)) {
      setState(() => error = 'Select a reviewer and a review date.');
      return;
    }
    if (a == 'escalate' && (destination == null || !confirmed)) {
      setState(
        () => error = 'Select the destination and confirm its audience.',
      );
      return;
    }
    if (['link_duplicate', 'link_knowledge'].contains(a) &&
        target.text.trim().isEmpty) {
      setState(() => error = 'Enter the linked item ID.');
      return;
    }
    final data = <String, dynamic>{
      'text': text.text.trim(),
      if (a == 'status') 'status': status,
      if (a == 'assign') ...{
        'target_id': reviewer,
        'review_due_at': due!.toUtc().toIso8601String(),
      },
      if (['link_duplicate', 'link_knowledge'].contains(a))
        'target_id': target.text.trim(),
      if (a == 'escalate') ...{
        'target_scope': {
          'scope_type': destination!['scope_type'],
          'scope_id': destination!['scope_id'],
        },
        'confirm_visibility': confirmed,
      },
    };
    final key = retryKeys.putIfAbsent(data.toString(), bankRequestKey);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(suggestionBankRepositoryProvider)
          .request<BankJson>(
            widget.uid,
            widget.realm,
            '/${widget.item['id']}/actions',
            data: {
              'action': a,
              'client_key': key,
              'expected_revision': latestRevision ?? widget.item['revision'],
              ...data,
            },
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'Update not confirmed. Your response is kept here. Retry safely, or check the latest version after a conflict. $e',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final scopes =
        ref.watch(bankScopesProvider((widget.uid, widget.realm))).value ?? [];
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(bankLabel(a)),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a == 'status')
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'New status'),
                    items: [
                      for (final s in [
                        'under_review',
                        'needs_information',
                        'planned',
                        'in_progress',
                        'implemented',
                        'not_proceeding',
                      ])
                        DropdownMenuItem(value: s, child: Text(bankLabel(s))),
                    ],
                    onChanged: (v) => setState(() => status = v!),
                  ),
                if (a == 'assign') ...[
                  if (reviewers == null)
                    const LinearProgressIndicator()
                  else
                    DropdownButtonFormField<String>(
                      initialValue: reviewer,
                      decoration: const InputDecoration(
                        labelText: 'Accountable reviewer',
                      ),
                      items: [
                        for (final r in reviewers!)
                          DropdownMenuItem(
                            value: r['id'] as String,
                            child: Text(r['name'] as String),
                          ),
                      ],
                      onChanged: (v) => setState(() => reviewer = v),
                    ),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now().add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDate: DateTime.now().add(
                          const Duration(days: 7),
                        ),
                      );
                      if (date != null && mounted) {
                        setState(
                          () => due = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            17,
                          ),
                        );
                      }
                    },
                    child: Text(
                      due == null
                          ? 'Choose review date'
                          : 'Expected review: ${due!.toLocal()}',
                    ),
                  ),
                ],
                if (a == 'escalate') ...[
                  const Text(
                    'The original suggestion and its history stay with their current audience. The title, problem, proposed change and benefit will be copied to the selected audience. Comments, contributors and private examples are not copied.',
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Escalation destination',
                    ),
                    items: [
                      for (final s in scopes)
                        if (s['scope_id'] != widget.item['scope_id'])
                          DropdownMenuItem(
                            value: s['scope_id'] as String,
                            child: Text(
                              '${s['label']} · ${bankLabel(s['scope_type'] as String)}',
                            ),
                          ),
                    ],
                    onChanged: (v) => setState(() {
                      destination = scopes.firstWhere(
                        (s) => s['scope_id'] == v,
                      );
                      confirmed = false;
                    }),
                  ),
                  Text(
                    'Title: ${widget.item['title']}\nProblem: ${widget.item['problem']}\nProposal: ${widget.item['proposal']}\nBenefit: ${widget.item['benefit']}',
                  ),
                  CheckboxListTile(
                    value: confirmed,
                    onChanged: (v) => setState(() => confirmed = v ?? false),
                    title: const Text(
                      'I confirm this content may be shown to the selected audience.',
                    ),
                  ),
                ],
                if (['link_duplicate', 'link_knowledge'].contains(a))
                  TextField(
                    controller: target,
                    decoration: InputDecoration(
                      labelText: a == 'link_duplicate'
                          ? 'Original suggestion ID (same audience)'
                          : 'Approved Knowledge question ID (same audience)',
                    ),
                  ),
                if (a == 'start_interact')
                  const Text(
                    'Create a draft Interact review for this agreed proposal with the same audience. Capture evidence and deliberately submit its outcome through the existing Knowledge review process.',
                  ),
                if (a == 'adopt_practice' || a == 'revise_practice')
                  const Text(
                    'Write the standing workplace guidance below. It remains accessible in Practices after this suggestion closes. Each revision stays in history.',
                  ),
                if (a == 'withdraw_practice')
                  Text(
                    'Current practice: ${widget.item['practice']}\nExplain why this practice is being withdrawn. Its history will be retained.',
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: text,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 10000,
                  decoration: InputDecoration(
                    labelText:
                        a.contains('practice') && a != 'withdraw_practice'
                        ? 'Workplace practice'
                        : 'Response / reason',
                  ),
                ),
                if (error != null) ...[
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            try {
                              final latest = await ref
                                  .read(suggestionBankRepositoryProvider)
                                  .request<BankJson>(
                                    widget.uid,
                                    widget.realm,
                                    '/${widget.item['id']}',
                                  );
                              if (!context.mounted) return;
                              final accept = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Review latest update'),
                                  content: SingleChildScrollView(
                                    child: Text(
                                      'Status: ${bankLabel(latest['status'] as String)}\nReviewer: ${latest['owner_name']}\n${(latest['activities'] as List).take(5).map((e) => e['text']).join('\n')}',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Keep reviewing'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Use latest version'),
                                    ),
                                  ],
                                ),
                              );
                              if (accept == true && mounted) {
                                setState(
                                  () => latestRevision =
                                      latest['revision'] as int,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(
                                  () => error =
                                      'Latest version unavailable. Your draft is kept. $e',
                                );
                              }
                            }
                          },
                    child: const Text('Check latest version'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Saving…' : 'Confirm'),
          ),
        ],
      ),
    );
  }
}
