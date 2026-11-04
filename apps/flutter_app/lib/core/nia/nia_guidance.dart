import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nopak_nia/nopak_nia.dart';
import 'intqaflow_capabilities.dart';
import 'nia_teaching.dart';
export 'nia_teaching.dart' show NiaTeaching;
export 'intqaflow_capabilities.dart' show NiaTopic;

/// One owner below the real application authentication boundary. No private
/// context survives an account/authority change; drafts remain owned by the app.
class NiaHost extends StatefulWidget {
  const NiaHost({
    required this.subject,
    required this.authorityRevision,
    required this.child,
    this.teaching,
    super.key,
  });
  final NiaTeaching? teaching;
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

  static NiaTeaching? teachingOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NiaInherited>()?.teaching;

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

class _NiaHostState extends State<NiaHost> with WidgetsBindingObserver {
  late final NiaTeaching teaching = (widget.teaching ?? NiaTeaching())
    ..bind(widget.subject);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      session.invalidate();
      teaching.withdraw();
    }
  }

  late final NiaSession session = NiaSession(
    product: 'intqaflow',
    clock: () => DateTime.now().toUtc(),
  )..bind(widget.subject);
  @override
  void didUpdateWidget(NiaHost old) {
    super.didUpdateWidget(old);
    teaching.bind(widget.subject);
    if (old.subject != widget.subject)
      session.bind(widget.subject);
    else if (old.authorityRevision != widget.authorityRevision)
      session.invalidate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    teaching.dispose();
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _NiaInherited(
    session: session,
    teaching: teaching,
    revision: (widget.subject, widget.authorityRevision),
    child: widget.child,
  );
}

class _NiaInherited extends InheritedWidget {
  const _NiaInherited({
    required this.session,
    required this.teaching,
    required this.revision,
    this.workspace = 'local',
    this.available = true,
    required super.child,
  });
  final NiaSession session;
  final NiaTeaching teaching;
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
    teaching: widget.binding.teaching,
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
            teaching: value.teaching,
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
  bool lesson = false,
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
    capability: IntQaFlowGuidance(topic, requested: requested || lesson),
    requested: requested,
    visible: ModalRoute.of(context)?.isCurrent ?? true,
    busy: busy,
    complete: complete,
  );
  return decision.outcome == NiaOutcome.suggested ? decision : null;
}

class NiaInlineGuidance extends StatefulWidget {
  const NiaInlineGuidance({
    required this.topic,
    this.facts = const {},
    this.actions = const {},
    this.busy = false,
    this.complete = false,
    this.eligible = true,
    this.lessonId,
    this.inputs = const [],
    super.key,
  });
  final NiaTopic topic;
  final Map<String, Object?> facts;
  final Map<String, (String, VoidCallback)> actions;
  final bool busy, complete, eligible;
  final String? lessonId;
  final List<TextEditingController> inputs;
  @override
  State<NiaInlineGuidance> createState() => _NiaInlineGuidanceState();
}

class _NiaInlineGuidanceState extends State<NiaInlineGuidance>
    with WidgetsBindingObserver {
  NiaTeaching? teaching;
  NiaSession? owner;
  NiaDecision? decision;
  Object? binding;
  Timer? expiry;
  void Function()? stopListening;
  bool queued = false, attempted = false, recorded = false;
  bool foreground = true, active = true;
  String get lesson =>
      widget.lessonId ??
      (widget.topic.name +
          (widget.facts['overdue'] == true
              ? '.overdue'
              : widget.facts['unread'] == true
              ? '.updates'
              : '.state'));
  bool get editing {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    if (!focused.mounted) return true;
    try {
      return focused.widget is EditableText ||
          focused.findAncestorWidgetOfExactType<EditableText>() != null;
    } on FlutterError {
      // Focus can still reference a deactivated route for the current frame.
      // Unknown focus is busy, so optional guidance stays quiet until rebinding.
      return true;
    }
  }

  bool get idle =>
      active &&
      !widget.busy &&
      !widget.complete &&
      widget.eligible &&
      !widget.inputs.any((input) => input.text.isNotEmpty) &&
      !editing &&
      foreground &&
      NiaTabSurface.visibleOf(context) &&
      (ModalRoute.of(context)?.isCurrent ?? false);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    for (final input in widget.inputs) {
      input.addListener(changed);
    }
    FocusManager.instance.addListener(changed);
  }

  bool refreshQueued = false;
  void changed() {
    if (!mounted || !active || refreshQueued) return;
    refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshQueued = false;
      if (mounted && active) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    changed();
  }

  void clear() {
    expiry?.cancel();
    expiry = null;
    decision = null;
    teaching?.release(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = NiaHost.teachingOf(context);
    final current = NiaHost.bindingOf(context);
    if (teaching != next || binding != current) {
      clear();
      teaching?.removeListener(changed);
      stopListening?.call();
      attempted = false;
      teaching = next;
      binding = current;
      owner = NiaHost.sessionOf(context);
      teaching?.addListener(changed);
      stopListening = owner?.listen(changed);
    }
  }

  @override
  void didUpdateWidget(NiaInlineGuidance old) {
    super.didUpdateWidget(old);
    for (final input in old.inputs) {
      input.removeListener(changed);
    }
    for (final input in widget.inputs) {
      input.addListener(changed);
    }
    if (old.topic != widget.topic ||
        old.lessonId != widget.lessonId ||
        !mapEquals(old.facts, widget.facts)) {
      clear();
      attempted = false;
    }
  }

  void queue() {
    if (queued) return;
    queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      queued = false;
      if (!mounted || !active) return;
      if (!idle || teaching?.enabled != true) {
        if (decision != null) {
          clear();
          changed();
        }
        return;
      }
      if (decision != null && !(owner?.isCurrent(decision!) ?? false)) {
        clear();
        changed();
      }
      if (attempted ||
          decision != null ||
          teaching == null ||
          owner == null ||
          !teaching!.claim(this, lesson, remember: widget.lessonId != null))
        return;
      attempted = true;
      final d = _evaluateGuidance(
        context,
        owner!,
        widget.topic,
        widget.facts,
        lesson: widget.lessonId != null,
      );
      if (d == null) {
        teaching!.release(this);
        return;
      }
      setState(() {
        decision = d;
        recorded = false;
      });
      expiry = Timer(const Duration(seconds: 8), () {
        if (mounted) {
          clear();
          changed();
        }
      });
    });
  }

  @override
  void deactivate() {
    active = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    active = true;
  }

  @override
  void dispose() {
    for (final input in widget.inputs) {
      input.removeListener(changed);
    }
    FocusManager.instance.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    stopListening?.call();
    teaching?.removeListener(changed);
    clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    queue();
    final d = decision;
    if (!idle ||
        d == null ||
        teaching?.enabled != true ||
        teaching?.owns(this) != true ||
        !(owner?.isCurrent(d) ?? false))
      return const SizedBox.shrink();
    final proposal = d.proposals.first;
    final action = widget.actions[proposal.action];
    return _NiaHintPaint(
      onPaint: () {
        if (recorded) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !recorded &&
              idle &&
              identical(decision, d) &&
              owner!.isCurrent(d) &&
              teaching!.owns(this)) {
            if (owner!.markPresented(d)) {
              recorded = true;
              teaching!.shown(this, lesson);
            }
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8, right: 8),
                child: Icon(Icons.tips_and_updates_outlined, size: 18),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    proposal.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: () {
                    if (idle && owner!.isCurrent(d)) {
                      clear();
                      action.$2();
                    }
                  },
                  child: Text(action.$1),
                ),
              IconButton(
                tooltip: 'Got it — hide this tip',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  owner?.acceptFeedback(d, NiaFeedback.dismissed);
                  clear();
                  changed();
                },
              ),
            ],
          ),
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

/// Visibility follows the real body controller, including swipe navigation.
class NiaTabSurface extends StatefulWidget {
  const NiaTabSurface({required this.index, required this.child, super.key});
  final int index;
  final Widget child;
  static bool visibleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NiaVisible>()?.visible ??
      true;
  @override
  State<NiaTabSurface> createState() => _NiaTabSurfaceState();
}

class _NiaTabSurfaceState extends State<NiaTabSurface> {
  TabController? controller;
  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DefaultTabController.maybeOf(context);
    if (next != controller) {
      controller?.removeListener(changed);
      controller = next;
      controller?.addListener(changed);
    }
  }

  @override
  void dispose() {
    controller?.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _NiaVisible(
    visible: controller == null || controller!.index == widget.index,
    child: widget.child,
  );
}

class _NiaVisible extends InheritedWidget {
  const _NiaVisible({required this.visible, required super.child});
  final bool visible;
  @override
  bool updateShouldNotify(_NiaVisible old) => old.visible != visible;
}

class NiaWorkflowSurface extends StatelessWidget {
  const NiaWorkflowSurface({
    required this.topic,
    required this.lessonId,
    required this.child,
    this.facts = const {},
    this.busy = false,
    super.key,
  });
  final NiaTopic topic;
  final String lessonId;
  final Widget child;
  final Map<String, Object?> facts;
  final bool busy;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NiaInlineGuidance(
              topic: topic,
              lessonId: lessonId,
              facts: facts,
              busy: busy,
            ),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}

PopupMenuItem<String> niaGuidanceMenuItem(BuildContext context) {
  final teaching = NiaHost.teachingOf(context);
  return PopupMenuItem<String>(
    value: 'nia-guidance',
    enabled: teaching?.ready == true,
    onTap: () => teaching?.setEnabled(!teaching.enabled),
    child: Text(
      teaching?.enabled == false
          ? 'Turn NIA guidance on'
          : 'Turn NIA guidance off',
    ),
  );
}

class _NiaHintPaint extends SingleChildRenderObjectWidget {
  const _NiaHintPaint({required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _NiaPaintObserver(onPaint);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _NiaPaintObserver renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

class _NiaPaintObserver extends RenderProxyBox {
  _NiaPaintObserver(this.onPaint);
  VoidCallback onPaint;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}
