import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nopak_nia/nopak_nia.dart';
import 'intqaflow_capabilities.dart';
export 'intqaflow_capabilities.dart' show NiaTopic;

/// One owner below the real application authentication boundary. No private
/// context survives an account/authority change; drafts remain owned by the app.
class NiaHost extends StatefulWidget {
  const NiaHost({
    required this.subject,
    required this.authorityRevision,
    required this.child,
    super.key,
  });
  final String subject, authorityRevision;
  final Widget child;

  /// Retain the existing owner across a Navigator dialog boundary. A changed
  /// authority makes the dialog's assistance unavailable until it is reopened.
  static Widget preserve(BuildContext context, Widget child) {
    final binding = context.dependOnInheritedWidgetOfExactType<_NiaInherited>();
    return binding == null
        ? child
        : _NiaRouteScope(binding: binding, child: child);
  }

  static Object? bindingOf(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<_NiaInherited>();
    return host == null
        ? null
        : (host.session, host.revision, host.workspace, host.available);
  }

  static NiaSession? sessionOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NiaInherited>()?.session;
  @override
  State<NiaHost> createState() => _NiaHostState();
}

class _NiaHostState extends State<NiaHost> {
  late final NiaSession session = NiaSession(
    product: 'intqaflow',
    clock: () => DateTime.now().toUtc(),
  )..bind(widget.subject);
  @override
  void didUpdateWidget(NiaHost old) {
    super.didUpdateWidget(old);
    if (old.subject != widget.subject)
      session.bind(widget.subject);
    else if (old.authorityRevision != widget.authorityRevision)
      session.invalidate();
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _NiaInherited(
    session: session,
    revision: (widget.subject, widget.authorityRevision),
    child: widget.child,
  );
}

class _NiaInherited extends InheritedWidget {
  const _NiaInherited({
    required this.session,
    required this.revision,
    this.workspace = 'local',
    this.available = true,
    required super.child,
  });
  final NiaSession session;
  final (String, String) revision;
  final String workspace;
  final bool available;
  @override
  bool updateShouldNotify(_NiaInherited old) =>
      old.session != session ||
      old.revision != revision ||
      old.workspace != workspace ||
      old.available != available;
}

class _NiaRouteScope extends StatefulWidget {
  const _NiaRouteScope({required this.binding, required this.child});
  final _NiaInherited binding;
  final Widget child;
  @override
  State<_NiaRouteScope> createState() => _NiaRouteScopeState();
}

class _NiaRouteScopeState extends State<_NiaRouteScope> {
  late final int revision;
  void Function()? unsubscribe;
  bool invalid = false;
  @override
  void initState() {
    super.initState();
    revision = widget.binding.session.bindingRevision;
    unsubscribe = widget.binding.session.listen(() {
      if (widget.binding.session.bindingRevision != revision && !invalid) {
        invalid = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _NiaInherited(
    session: widget.binding.session,
    revision: widget.binding.revision,
    workspace: widget.binding.workspace,
    available: widget.binding.available && !invalid,
    child: widget.child,
  );
}

/// A narrower workspace shares the account owner and invalidates its own leases.
class NiaWorkspaceScope extends StatefulWidget {
  const NiaWorkspaceScope({
    required this.workspace,
    required this.authorityRevision,
    required this.child,
    this.available = true,
    super.key,
  });
  final String workspace, authorityRevision;
  final Widget child;
  final bool available;
  @override
  State<NiaWorkspaceScope> createState() => _NiaWorkspaceScopeState();
}

class _NiaWorkspaceScopeState extends State<NiaWorkspaceScope> {
  Object? previous;
  _NiaInherited? get parent =>
      context.dependOnInheritedWidgetOfExactType<_NiaInherited>();
  String revision(_NiaInherited value) =>
      value.revision.$2 + ':' + widget.authorityRevision;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(NiaWorkspaceScope old) {
    super.didUpdateWidget(old);
    sync();
  }

  void sync() {
    final value = parent;
    if (value == null) return;
    final binding = (
      value.session,
      widget.workspace,
      revision(value),
      value.available && widget.available,
    );
    // Audience-specific reads may use different keys within this workspace.
    // Cancel assistance on authority changes without touching application drafts.
    if (previous != null && previous != binding) value.session.invalidate();
    previous = binding;
    value.session.reviseAuthority(widget.workspace, revision(value));
  }

  @override
  Widget build(BuildContext context) {
    final value = parent;
    return value == null
        ? widget.child
        : _NiaInherited(
            session: value.session,
            revision: (value.revision.$1, revision(value)),
            workspace: widget.workspace,
            available: value.available && widget.available,
            child: widget.child,
          );
  }
}

int _guidanceEvent = 0;
NiaDecision? _evaluateGuidance(
  BuildContext context,
  NiaSession owner,
  NiaTopic topic,
  Map<String, Object?> facts, {
  bool requested = false,
  bool busy = false,
  bool complete = false,
}) {
  final host = context.dependOnInheritedWidgetOfExactType<_NiaInherited>();
  if (host?.available == false) return null;
  final snapshot = owner.capture(
    scope: NiaScope(
      product: 'intqaflow',
      subject: host?.revision.$1 ?? 'local',
      workspace: facts['workspace'] as String? ?? host?.workspace ?? 'local',
      authorityRevision: host?.revision.$2 ?? 'local',
    ),
    purpose: 'guidance',
    facts: facts,
    permitted: true,
  );
  if (snapshot == null) return null;
  final decision = owner.evaluate(
    context: snapshot,
    event: NiaEvent(
      id: 'ui-' + (_guidanceEvent++).toString(),
      kind: requested ? 'requested' : 'changed',
      occurredAt: snapshot.observedAt,
    ),
    capability: IntQaFlowGuidance(topic, requested: requested),
    requested: requested,
    visible: ModalRoute.of(context)?.isCurrent ?? true,
    busy: busy,
    complete: complete,
  );
  return decision.outcome == NiaOutcome.suggested ? decision : null;
}

Future<void> showNiaGuidance(
  BuildContext context, {
  required NiaTopic topic,
  required String title,
  Map<String, Object?> facts = const {},
}) async {
  final inherited = NiaHost.sessionOf(context);
  final owner =
      inherited ??
      (NiaSession(product: 'intqaflow', clock: () => DateTime.now().toUtc())
        ..bind('local'));
  try {
    final decision = _evaluateGuidance(
      context,
      owner,
      topic,
      facts,
      requested: true,
    );
    if (decision == null || !owner.isCurrent(decision) || !context.mounted)
      return;
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _GuidanceDialog(title: title, owner: owner, decision: decision),
    );
  } finally {
    if (inherited == null) owner.dispose();
  }
}

mixin _NiaEvaluation<T extends StatefulWidget> on State<T> {
  NiaSession? _local;
  NiaSession get session =>
      NiaHost.sessionOf(context) ??
      (_local ??= NiaSession(
        product: 'intqaflow',
        clock: () => DateTime.now().toUtc(),
      )..bind('local'));
  NiaDecision? decide(
    NiaTopic topic,
    Map<String, Object?> facts, {
    bool requested = false,
    bool busy = false,
    bool complete = false,
  }) => _evaluateGuidance(
    context,
    session,
    topic,
    facts,
    requested: requested,
    busy: busy,
    complete: complete,
  );
  @override
  void dispose() {
    _local?.dispose();
    super.dispose();
  }
}

/// On-demand contextual explanation in the existing control's position. The
/// previous static information blobs do not enter this interface.
class NiaHelpButton extends StatelessWidget {
  const NiaHelpButton({
    required this.topic,
    required this.tooltip,
    required this.title,
    this.facts = const {},
    super.key,
  });
  final NiaTopic topic;
  final String tooltip, title;
  final Map<String, Object?> facts;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: const Icon(Icons.lightbulb_outline, size: 16),
    onPressed: () =>
        showNiaGuidance(context, topic: topic, title: title, facts: facts),
  );
}

class _GuidanceDialog extends StatefulWidget {
  const _GuidanceDialog({
    required this.title,
    required this.owner,
    required this.decision,
  });
  final String title;
  final NiaSession owner;
  final NiaDecision decision;
  @override
  State<_GuidanceDialog> createState() => _GuidanceDialogState();
}

class _GuidanceDialogState extends State<_GuidanceDialog> {
  Timer? expiry;
  void Function()? unsubscribe;
  @override
  void initState() {
    super.initState();
    unsubscribe = widget.owner.listen(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    });
    expiry = Timer(
      widget.decision.context.expiresAt.difference(DateTime.now().toUtc()),
      () {
        if (mounted) setState(() {});
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.owner.markPresented(widget.decision);
    });
  }

  @override
  void dispose() {
    expiry?.cancel();
    unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.owner.isCurrent(widget.decision);
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: current
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in widget.decision.proposals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(p.message),
                  ),
              ],
            )
          : const Text(
              'The workspace context changed. Close this explanation and reopen it for the current state.',
            ),
      actions: [
        if (current)
          TextButton(
            onPressed: () {
              widget.owner.acceptFeedback(widget.decision, NiaFeedback.helpful);
              Navigator.pop(context);
            },
            child: const Text('Helpful'),
          ),
        TextButton(
          onPressed: () {
            widget.owner.acceptFeedback(widget.decision, NiaFeedback.dismissed);
            Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Only meaningful current-state guidance is eligible. No generic review card,
/// feed, repeated polling or automatic server call exists here.
class NiaInlineGuidance extends StatefulWidget {
  const NiaInlineGuidance({
    required this.topic,
    this.facts = const {},
    this.busy = false,
    this.complete = false,
    this.actions = const {},
    super.key,
  });
  final NiaTopic topic;
  final Map<String, Object?> facts;
  final bool busy, complete;
  final Map<String, (String, VoidCallback)> actions;
  @override
  State<NiaInlineGuidance> createState() => _NiaInlineGuidanceState();
}

class _NiaInlineGuidanceState extends State<NiaInlineGuidance>
    with _NiaEvaluation<NiaInlineGuidance> {
  NiaDecision? decision;
  Timer? expiry;
  NiaSession? owner;
  Object? binding;
  bool dismissed = false;
  void evaluate() {
    expiry?.cancel();
    owner = session;
    decision = decide(
      widget.topic,
      widget.facts,
      busy: widget.busy,
      complete: widget.complete,
    );
    final current = decision;
    if (current != null) {
      expiry = Timer(
        current.context.expiresAt.difference(DateTime.now().toUtc()),
        () {
          if (mounted) setState(() => decision = null);
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(decision, current))
          owner?.markPresented(current);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBinding = NiaHost.bindingOf(context);
    if (owner != session || binding != currentBinding) {
      binding = currentBinding;
      dismissed = false;
      evaluate();
    }
  }

  @override
  void didUpdateWidget(NiaInlineGuidance old) {
    super.didUpdateWidget(old);
    if (old.topic != widget.topic ||
        old.busy != widget.busy ||
        old.complete != widget.complete ||
        !mapEquals(old.facts, widget.facts)) {
      dismissed = false;
      evaluate();
    }
  }

  @override
  void dispose() {
    expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = decision;
    if (dismissed ||
        d == null ||
        !(owner?.isCurrent(d) ?? false) ||
        widget.busy)
      return const SizedBox.shrink();
    final p = d.proposals.first;
    final action = widget.actions[p.action];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                p.message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: () {
                  if (owner?.isCurrent(d) ?? false) action.$2();
                },
                child: Text(action.$1),
              ),
            IconButton(
              tooltip: 'Dismiss guidance',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16),
              onPressed: () {
                owner?.acceptFeedback(d, NiaFeedback.dismissed);
                setState(() => dismissed = true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The product's existing authenticated client owns IO and server permission
/// checks. This lease only fences the resulting assistance against replacement
/// accounts, workspace/authority changes, changed input and disposal.
class NiaReadGuard {
  NiaReadGuard._(this.owner, this.snapshot, this.ownsSession);
  final NiaSession owner;
  final NiaContext snapshot;
  final bool ownsSession;
  bool _disposed = false;
  static NiaReadGuard? begin(
    BuildContext context, {
    required String subject,
    required String workspace,
    required String purpose,
    required Map<String, Object?> facts,
  }) {
    final binding = context.dependOnInheritedWidgetOfExactType<_NiaInherited>();
    if (binding != null &&
        (!binding.available || binding.revision.$1 != subject))
      return null;
    final owner =
        binding?.session ??
        (NiaSession(product: 'intqaflow', clock: () => DateTime.now().toUtc())
          ..bind(subject));
    final snapshot = owner.capture(
      scope: NiaScope(
        product: 'intqaflow',
        subject: subject,
        workspace: workspace,
        authorityRevision: binding?.revision.$2 ?? 'isolated',
      ),
      purpose: purpose,
      facts: facts,
      permitted: true,
    );
    if (snapshot == null) {
      if (binding == null) owner.dispose();
      return null;
    }
    return NiaReadGuard._(owner, snapshot, binding == null);
  }

  bool get current => !_disposed && owner.isContextCurrent(snapshot);
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (ownsSession)
      owner.dispose();
    else
      owner.revokeContext(snapshot);
  }
}
