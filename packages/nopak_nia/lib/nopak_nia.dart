/// Native Intelligence Core. No IO, location, identity authority, persistent
/// profiling, model provider or write executor. Product adapters supply only
/// currently permitted context; existing services remain authoritative.
library;

enum NiaEffect { guidance, navigation, privateDraft, sharedAction }

enum NiaOutcome {
  suggested,
  silent,
  disabled,
  stale,
  invalid,
  duplicate,
  capacity,
  failed,
}

enum NiaFeedback { helpful, unhelpful, dismissed }

final class NiaScope {
  const NiaScope({
    required this.product,
    required this.subject,
    required this.workspace,
    required this.authorityRevision,
  });
  final String product, subject, workspace, authorityRevision;
  (String, String, String, String) get key =>
      (product, subject, workspace, authorityRevision);
  bool get valid => [
    product,
    subject,
    workspace,
    authorityRevision,
  ].every((v) => v.trim() == v && v.isNotEmpty && v.length <= 256);
}

final class NiaBudget {
  const NiaBudget({
    this.maximumContexts = 32,
    this.maximumEvents = 256,
    this.maximumFields = 32,
    this.maximumFieldLength = 512,
    this.maximumProposals = 3,
    this.maximumFeedback = 64,
    this.maximumAutomaticPresentations = 3,
    this.contextLifetime = const Duration(minutes: 2),
    this.evaluationDeadline = const Duration(milliseconds: 50),
    this.automaticCooldown = const Duration(minutes: 2),
  });
  final int maximumContexts,
      maximumEvents,
      maximumFields,
      maximumFieldLength,
      maximumProposals,
      maximumFeedback,
      maximumAutomaticPresentations;
  final Duration contextLifetime, evaluationDeadline, automaticCooldown;
  bool get valid =>
      [
        maximumContexts,
        maximumEvents,
        maximumFields,
        maximumFieldLength,
        maximumProposals,
        maximumFeedback,
        maximumAutomaticPresentations,
      ].every((v) => v > 0) &&
      contextLifetime > Duration.zero &&
      evaluationDeadline > Duration.zero &&
      !automaticCooldown.isNegative;
}

final class NiaContext {
  NiaContext._(
    this.owner,
    this.scope,
    this.purpose,
    this.generation,
    this.revision,
    this.observedAt,
    this.expiresAt,
    Map<String, Object?> facts,
  ) : facts = Map.unmodifiable(facts);
  final Object owner;
  final NiaScope scope;
  final String purpose;
  final int generation, revision;
  final DateTime observedAt, expiresAt;
  final Map<String, Object?> facts;
}

final class NiaEvent {
  const NiaEvent({
    required this.id,
    required this.kind,
    required this.occurredAt,
    this.schemaVersion = 1,
  });
  final String id, kind;
  final DateTime occurredAt;
  final int schemaVersion;
}

final class NiaProposal {
  const NiaProposal({
    required this.id,
    required this.message,
    this.reason = 'workflow',
    this.relevance = 1,
    this.priority = 0,
    this.effect = NiaEffect.guidance,
    this.action,
  });
  final String id, message, reason;
  final double relevance;
  final int priority;
  final NiaEffect effect;

  /// An allow-listed product action ID, never an arbitrary URL/tool/executor.
  final String? action;
}

abstract interface class NiaCapability {
  String get id;
  int get version;
  String get purpose;
  Set<String> get supportedEvents;
  List<NiaProposal> evaluate(NiaContext context, NiaBudget budget);
}

final class NiaDecision {
  NiaDecision._(
    this.owner,
    this.context,
    this.capability,
    this.outcome,
    this.proposals,
    this.requested,
    this.createdAt,
  );
  final Object owner;
  final NiaContext context;
  final String capability;
  final NiaOutcome outcome;
  final List<NiaProposal> proposals;
  final bool requested;
  final DateTime createdAt;
}

/// One account/session owner. Its scope is bound by the application's auth
/// adapter, not by a permission boolean supplied by a recommendation.
final class NiaSession {
  NiaSession({
    required this.product,
    required this.clock,
    this.budget = const NiaBudget(),
  }) {
    if (product.trim().isEmpty || !budget.valid)
      throw ArgumentError('Invalid NIA policy');
  }
  final String product;
  final DateTime Function() clock;
  final NiaBudget budget;
  String? _subject;
  bool _enabled = true, _disposed = false;
  int _generation = 0, _revision = 0, _shown = 0;
  DateTime? _lastClock, _lastShown;
  final _contexts = <(String, String), NiaContext>{};
  final _events = <String>{};
  final _authorities = <String, String>{};
  final _presented = <NiaDecision>{}, _feedbackReceipts = <NiaDecision>{};
  final _dismissed = <(String, String)>{};
  final _feedback = <NiaFeedback, int>{};
  bool get enabled => _enabled && !_disposed;
  int get generation => _generation;
  Map<NiaFeedback, int> get feedback => Map.unmodifiable(_feedback);

  final _listeners = <void Function()>{};
  void Function() listen(void Function() listener) {
    if (_disposed || _listeners.length >= budget.maximumFeedback) return () {};
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _notify() {
    for (final listener in _listeners.toList(growable: false)) {
      try {
        listener();
      } on Object {
        /* Adapter failure cannot affect workflow. */
      }
    }
  }

  bool reviseAuthority(String workspace, String revision) {
    if (_disposed || !_field(workspace) || !_field(revision)) return false;
    if (_authorities[workspace] == revision) return true;
    if (!_authorities.containsKey(workspace) &&
        _authorities.length >= budget.maximumContexts)
      return false;
    _contexts.removeWhere((key, value) => key.$1 == workspace);
    _authorities[workspace] = revision;
    _notify();
    return true;
  }

  DateTime? _now() {
    final value = clock();
    if (!value.isUtc || (_lastClock?.isAfter(value) ?? false)) return null;
    _lastClock = value;
    return value;
  }

  void bind(String subject) {
    if (_disposed) return;
    if (subject.trim().isEmpty || subject.length > 256)
      throw ArgumentError('Invalid subject');
    if (_subject == subject) return;
    _subject = subject;
    _enabled = true;
    _clear();
  }

  void _clear() {
    _generation++;
    _contexts.clear();
    _authorities.clear();
    _events.clear();
    _presented.clear();
    _feedbackReceipts.clear();
    _dismissed.clear();
    _feedback.clear();
    _shown = 0;
    _lastShown = null;
    _notify();
  }

  void invalidate() => _clear();
  void setEnabled(bool value) {
    if (_disposed || _enabled == value) return;
    _enabled = value;
    _clear();
  }

  void resetFeedback() => _clear();
  void dispose() {
    _clear();
    _subject = null;
    _disposed = true;
    _listeners.clear();
  }

  bool _field(String value) =>
      value.isNotEmpty &&
      value.trim() == value &&
      value.length <= budget.maximumFieldLength;
  bool _facts(Map<String, Object?> facts) =>
      facts.length <= budget.maximumFields &&
      facts.entries.every(
        (entry) =>
            _field(entry.key) &&
            switch (entry.value) {
              null || bool() => true,
              String value => value.length <= budget.maximumFieldLength,
              num value => value.isFinite,
              _ => false,
            },
      );

  /// Changes whenever the bound account or its authority is invalidated.
  int get bindingRevision => _generation;

  NiaContext? capture({
    required NiaScope scope,
    required String purpose,
    required Map<String, Object?> facts,
    required bool permitted,
  }) {
    if (!enabled ||
        !permitted ||
        !scope.valid ||
        scope.product != product ||
        scope.subject != _subject ||
        !_field(purpose) ||
        !_facts(facts))
      return null;
    final now = _now();
    if (now == null) return null;
    final key = (scope.workspace, purpose);
    if (!_contexts.containsKey(key) &&
        _contexts.length >= budget.maximumContexts)
      return null;
    if (!reviseAuthority(scope.workspace, scope.authorityRevision)) return null;
    final context = NiaContext._(
      this,
      scope,
      purpose,
      _generation,
      ++_revision,
      now,
      now.add(budget.contextLifetime),
      facts,
    );
    _contexts[key] = context;
    return context;
  }

  void revokeContext(NiaContext context) {
    final key = (context.scope.workspace, context.purpose);
    if (identical(context.owner, this) && identical(_contexts[key], context)) {
      _contexts.remove(key);
      _notify();
    }
  }

  bool isContextCurrent(NiaContext context) {
    if (!enabled ||
        !identical(context.owner, this) ||
        context.generation != _generation ||
        context.scope.subject != _subject ||
        !identical(
          _contexts[(context.scope.workspace, context.purpose)],
          context,
        ))
      return false;
    final now = _now();
    return now != null &&
        !now.isBefore(context.observedAt) &&
        now.isBefore(context.expiresAt);
  }

  NiaDecision evaluate({
    required NiaContext context,
    required NiaEvent event,
    required NiaCapability capability,
    bool requested = false,
    bool visible = true,
    bool busy = false,
    bool complete = false,
  }) {
    NiaDecision stop(NiaOutcome outcome, DateTime time) => NiaDecision._(
      this,
      context,
      capability.id,
      outcome,
      const [],
      requested,
      time,
    );
    final now = _now();
    if (now == null) return stop(NiaOutcome.stale, context.observedAt);
    if (!enabled) return stop(NiaOutcome.disabled, now);
    if (!isContextCurrent(context)) return stop(NiaOutcome.stale, now);
    if (!_field(event.id) ||
        !_field(event.kind) ||
        event.schemaVersion != 1 ||
        !event.occurredAt.isUtc ||
        event.occurredAt.isAfter(now) ||
        event.occurredAt.isBefore(context.observedAt) ||
        capability.version != 1 ||
        !_field(capability.id) ||
        capability.purpose != context.purpose ||
        !capability.supportedEvents.contains(event.kind))
      return stop(NiaOutcome.invalid, now);
    if (_events.contains(event.id)) return stop(NiaOutcome.duplicate, now);
    if (_events.length >= budget.maximumEvents)
      return stop(NiaOutcome.capacity, now);
    _events.add(event.id);
    if (!visible || busy || (complete && !requested))
      return stop(NiaOutcome.silent, now);
    if (!requested &&
        (_shown >= budget.maximumAutomaticPresentations ||
            (_lastShown != null &&
                now.difference(_lastShown!) < budget.automaticCooldown))) {
      return stop(NiaOutcome.silent, now);
    }
    try {
      final output = capability.evaluate(context, budget);
      final after = _now();
      if (after == null ||
          after.difference(now) > budget.evaluationDeadline ||
          !isContextCurrent(context))
        return stop(NiaOutcome.stale, now);
      if (output.length > budget.maximumProposals ||
          output.map((p) => p.id).toSet().length != output.length ||
          output.any(
            (p) =>
                !_field(p.id) ||
                !_field(p.message) ||
                !_field(p.reason) ||
                !p.relevance.isFinite ||
                p.relevance < 0 ||
                p.relevance > 1 ||
                p.priority < 0 ||
                (p.effect != NiaEffect.guidance &&
                    p.effect != NiaEffect.navigation) ||
                (p.action != null && !_field(p.action!)),
          ))
        return stop(NiaOutcome.invalid, now);
      final useful =
          output
              .where(
                (p) =>
                    p.relevance >= .5 &&
                    (requested || !_dismissed.contains((capability.id, p.id))),
              )
              .toList()
            ..sort((a, b) {
              final priority = b.priority.compareTo(a.priority);
              if (priority != 0) return priority;
              final score = b.relevance.compareTo(a.relevance);
              return score != 0 ? score : a.id.compareTo(b.id);
            });
      return NiaDecision._(
        this,
        context,
        capability.id,
        useful.isEmpty ? NiaOutcome.silent : NiaOutcome.suggested,
        List.unmodifiable(useful),
        requested,
        now,
      );
    } on Object {
      return stop(NiaOutcome.failed, now);
    }
  }

  bool isCurrent(NiaDecision decision) =>
      identical(decision.owner, this) &&
      decision.outcome == NiaOutcome.suggested &&
      isContextCurrent(decision.context);
  bool markPresented(NiaDecision decision) {
    if (!isCurrent(decision) ||
        _presented.contains(decision) ||
        _presented.length >= budget.maximumFeedback)
      return false;
    final now = _now();
    if (now == null) return false;
    _presented.add(decision);
    if (!decision.requested) {
      _shown++;
      _lastShown = now;
    }
    return true;
  }

  bool acceptFeedback(NiaDecision decision, NiaFeedback kind) {
    if (!isCurrent(decision) ||
        !_presented.contains(decision) ||
        !_feedbackReceipts.add(decision))
      return false;
    _feedback[kind] = (_feedback[kind] ?? 0) + 1;
    if (kind == NiaFeedback.dismissed || kind == NiaFeedback.unhelpful) {
      for (final p in decision.proposals) {
        _dismissed.add((decision.capability, p.id));
      }
    }
    return true;
  }
}

/// Bounded matching primitive. Call only after the product has enforced access.
/// It neither retrieves records nor establishes their visibility.
abstract final class NiaMatching {
  /// Preserve the established deterministic ordering. The product adapter
  /// supplies its bounded, already permitted records; no retrieval happens here.
  static double textRelevance(
    String query, {
    required String title,
    Iterable<String> evidence = const [],
  }) {
    final foldedQuery = query.toLowerCase().trim();
    final foldedTitle = title.toLowerCase();
    if (foldedTitle == foldedQuery) return 1.9;
    if (foldedTitle.startsWith(foldedQuery)) return 1.7;
    if (foldedTitle.contains(foldedQuery)) return 1.5;
    final body = evidence.join(' ').toLowerCase();
    if (body.contains(foldedQuery)) return 2.5;
    final terms = foldedQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    if (terms.isNotEmpty && terms.every(body.contains)) return 1.6;
    return 0.9;
  }
}
