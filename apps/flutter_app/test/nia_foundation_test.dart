import 'package:flutter_test/flutter_test.dart';
import 'package:nopak_nia/nopak_nia.dart';

class Capability implements NiaCapability {
  Capability({
    this.output = const [
      NiaProposal(id: 'help', message: 'Review the current scope.'),
    ],
    this.run,
  });
  final List<NiaProposal> output;
  final void Function()? run;
  @override
  String get id => 'workflow-guidance';
  @override
  String get purpose => 'guidance';
  @override
  int get version => 1;
  @override
  Set<String> get supportedEvents => {'requested', 'changed'};
  @override
  List<NiaProposal> evaluate(NiaContext context, NiaBudget budget) {
    run?.call();
    return output;
  }
}

class Fixture {
  Fixture({NiaBudget budget = const NiaBudget()}) {
    engine = NiaSession(product: 'test', clock: () => now, budget: budget)
      ..bind('alice');
  }
  DateTime now = DateTime.utc(2026, 11, 4, 12);
  late final NiaSession engine;
  int sequence = 0;
  NiaScope scope({
    String user = 'alice',
    String workspace = 'local',
    String revision = 'v1',
    String product = 'test',
  }) => NiaScope(
    product: product,
    subject: user,
    workspace: workspace,
    authorityRevision: revision,
  );
  NiaContext context({
    NiaScope? value,
    String purpose = 'guidance',
    Map<String, Object?> facts = const {},
  }) => engine.capture(
    scope: value ?? scope(),
    purpose: purpose,
    facts: facts,
    permitted: true,
  )!;
  NiaDecision evaluate({
    NiaContext? context,
    NiaCapability? capability,
    bool requested = true,
    bool visible = true,
    bool busy = false,
    bool complete = false,
    String? id,
    String kind = 'requested',
  }) {
    final snapshot = context ?? this.context();
    return engine.evaluate(
      context: snapshot,
      event: NiaEvent(
        id: id ?? 'event-' + (sequence++).toString(),
        kind: kind,
        occurredAt: now,
      ),
      capability: capability ?? Capability(),
      requested: requested,
      visible: visible,
      busy: busy,
      complete: complete,
    );
  }
}

void main() {
  test('explicit account binding and permitted purpose are required', () {
    final f = Fixture();
    expect(
      f.engine.capture(
        scope: f.scope(),
        purpose: 'guidance',
        facts: {},
        permitted: false,
      ),
      isNull,
    );
    expect(
      f.engine.capture(
        scope: f.scope(user: 'bob'),
        purpose: 'guidance',
        facts: {},
        permitted: true,
      ),
      isNull,
    );
    expect(
      f.engine.capture(
        scope: f.scope(product: 'other'),
        purpose: 'guidance',
        facts: {},
        permitted: true,
      ),
      isNull,
    );
  });
  test('malformed or oversized context cannot enter memory', () {
    final f = Fixture(
      budget: const NiaBudget(maximumFields: 1, maximumFieldLength: 16),
    );
    expect(
      f.engine.capture(
        scope: f.scope(),
        purpose: 'guidance',
        facts: {'a': 1, 'b': 2},
        permitted: true,
      ),
      isNull,
    );
    expect(
      f.engine.capture(
        scope: f.scope(),
        purpose: 'guidance',
        facts: {'a': 'x' * 17},
        permitted: true,
      ),
      isNull,
    );
    expect(
      f.engine.capture(
        scope: f.scope(),
        purpose: 'guidance',
        facts: {'a': Object()},
        permitted: true,
      ),
      isNull,
    );
    expect(
      f.engine.capture(
        scope: f.scope(),
        purpose: 'guidance',
        facts: {'a': double.nan},
        permitted: true,
      ),
      isNull,
    );
  });
  test('captured facts are immutable defensive copies', () {
    final f = Fixture();
    final input = <String, Object?>{'count': 1};
    final c = f.context(facts: input);
    input['count'] = 2;
    expect(c.facts['count'], 1);
    expect(() => c.facts['count'] = 3, throwsUnsupportedError);
  });
  test('new account invalidates decisions and clears feedback', () {
    final f = Fixture();
    final decision = f.evaluate();
    expect(f.engine.markPresented(decision), isTrue);
    expect(f.engine.acceptFeedback(decision, NiaFeedback.helpful), isTrue);
    f.engine.bind('bob');
    expect(f.engine.isCurrent(decision), isFalse);
    expect(f.engine.feedback, isEmpty);
  });
  test('switch away and back never revives old context', () {
    final f = Fixture();
    final c = f.context();
    f.engine.bind('bob');
    f.engine.bind('alice');
    expect(f.engine.isContextCurrent(c), isFalse);
  });
  test('authority revision invalidates all purposes within that workspace', () {
    final f = Fixture();
    final a = f.context();
    final other = f.context(purpose: 'other');
    f.context(value: f.scope(revision: 'v2'));
    expect(f.engine.isContextCurrent(a), isFalse);
    expect(f.engine.isContextCurrent(other), isFalse);
  });
  test('different workspace facts do not replace one another', () {
    final f = Fixture();
    final a = f.context();
    f.context(value: f.scope(workspace: 'group:one'));
    expect(f.engine.isContextCurrent(a), isTrue);
  });
  test('new snapshot invalidates late work on previous snapshot', () {
    final f = Fixture();
    final old = f.context();
    f.context();
    expect(f.evaluate(context: old).outcome, NiaOutcome.stale);
  });
  test('exact expiry and clock rollback fail closed', () {
    final f = Fixture();
    final c = f.context();
    f.now = f.now.add(const Duration(minutes: 2));
    expect(f.engine.isContextCurrent(c), isFalse);
    f.now = f.now.subtract(const Duration(minutes: 3));
    expect(f.engine.isContextCurrent(c), isFalse);
  });
  test('reads cannot extend context lifetime', () {
    final f = Fixture();
    final c = f.context();
    final expires = c.expiresAt;
    f.now = f.now.add(const Duration(minutes: 1));
    expect(f.engine.isContextCurrent(c), isTrue);
    expect(c.expiresAt, expires);
  });
  test('events are deduplicated and cannot extend validity', () {
    final f = Fixture();
    final c = f.context();
    expect(f.evaluate(context: c, id: 'same').outcome, NiaOutcome.suggested);
    expect(f.evaluate(context: c, id: 'same').outcome, NiaOutcome.duplicate);
  });
  test('unsupported event does not enter evaluator', () {
    var called = false;
    final f = Fixture();
    expect(
      f
          .evaluate(
            kind: 'unknown',
            capability: Capability(run: () => called = true),
          )
          .outcome,
      NiaOutcome.invalid,
    );
    expect(called, isFalse);
  });
  test('busy and invisible surfaces are intentionally silent', () {
    final f = Fixture();
    expect(f.evaluate(busy: true).outcome, NiaOutcome.silent);
    expect(f.evaluate(visible: false).outcome, NiaOutcome.silent);
    expect(
      f.evaluate(requested: false, complete: true).outcome,
      NiaOutcome.silent,
    );
  });
  test('saturation is bounded and never silently replays old events', () {
    final f = Fixture(budget: const NiaBudget(maximumEvents: 1));
    final c = f.context();
    expect(f.evaluate(context: c).outcome, NiaOutcome.suggested);
    expect(f.evaluate(context: c).outcome, NiaOutcome.capacity);
  });
  test('capability cannot publish shared or persistent actions', () {
    final f = Fixture();
    for (final effect in [NiaEffect.sharedAction, NiaEffect.privateDraft]) {
      expect(
        f
            .evaluate(
              capability: Capability(
                output: [
                  NiaProposal(id: 'write', message: 'Write', effect: effect),
                ],
              ),
            )
            .outcome,
        NiaOutcome.invalid,
      );
    }
  });
  test('faulty and oversized outputs fail closed', () {
    final f = Fixture();
    expect(
      f
          .evaluate(
            capability: Capability(
              output: [NiaProposal(id: 'bad', message: 'x' * 513)],
            ),
          )
          .outcome,
      NiaOutcome.invalid,
    );
    expect(
      f
          .evaluate(
            capability: Capability(
              output: const [
                NiaProposal(id: 'same', message: 'One'),
                NiaProposal(id: 'same', message: 'Two'),
              ],
            ),
          )
          .outcome,
      NiaOutcome.invalid,
    );
    expect(
      f
          .evaluate(
            capability: Capability(
              output: const [
                NiaProposal(id: 'nan', message: 'One', relevance: double.nan),
              ],
            ),
          )
          .outcome,
      NiaOutcome.invalid,
    );
  });
  test('exception does not become fabricated guidance or app failure', () {
    final f = Fixture();
    expect(
      f
          .evaluate(
            capability: Capability(
              run: () => throw StateError('private detail'),
            ),
          )
          .outcome,
      NiaOutcome.failed,
    );
  });
  test('revocation during evaluation suppresses output', () {
    final f = Fixture();
    expect(
      f.evaluate(capability: Capability(run: f.engine.invalidate)).outcome,
      NiaOutcome.stale,
    );
  });
  test('evaluation work exceeding deadline cannot be presented', () {
    final f = Fixture();
    expect(
      f
          .evaluate(
            capability: Capability(
              run: () {
                f.now = f.now.add(const Duration(seconds: 1));
              },
            ),
          )
          .outcome,
      NiaOutcome.stale,
    );
  });
  test('feedback requires actual presentation and is single use', () {
    final f = Fixture();
    final d = f.evaluate();
    expect(f.engine.acceptFeedback(d, NiaFeedback.helpful), isFalse);
    expect(f.engine.markPresented(d), isTrue);
    expect(f.engine.markPresented(d), isFalse);
    expect(f.engine.acceptFeedback(d, NiaFeedback.helpful), isTrue);
    expect(f.engine.acceptFeedback(d, NiaFeedback.unhelpful), isFalse);
    expect(f.engine.feedback[NiaFeedback.helpful], 1);
  });
  test(
    'dismissal quiets automatic repeat; explicit request remains possible',
    () {
      final f = Fixture();
      final d = f.evaluate();
      f.engine.markPresented(d);
      f.engine.acceptFeedback(d, NiaFeedback.dismissed);
      expect(f.evaluate(requested: false).outcome, NiaOutcome.silent);
      expect(f.evaluate().outcome, NiaOutcome.suggested);
      f.engine.resetFeedback();
      expect(f.evaluate(requested: false).outcome, NiaOutcome.suggested);
    },
  );
  test(
    'automatic presentation budget and cooldown do not block explicit help',
    () {
      final f = Fixture(
        budget: const NiaBudget(maximumAutomaticPresentations: 1),
      );
      final d = f.evaluate(requested: false);
      expect(f.engine.markPresented(d), isTrue);
      expect(f.evaluate(requested: false).outcome, NiaOutcome.silent);
      expect(f.evaluate().outcome, NiaOutcome.suggested);
    },
  );
  test('disable and dispose invalidate every old decision', () {
    final f = Fixture();
    final d = f.evaluate();
    f.engine.setEnabled(false);
    expect(f.engine.isCurrent(d), isFalse);
    f.engine.setEnabled(true);
    expect(f.engine.isCurrent(d), isFalse);
    final next = f.evaluate();
    f.engine.dispose();
    expect(f.engine.isCurrent(next), isFalse);
  });
  test('shared matching preserves established local Knowledge ranking', () {
    expect(NiaMatching.textRelevance('printer', title: 'Printer'), 1.9);
    expect(NiaMatching.textRelevance('printer', title: 'Printer paper'), 1.7);
    expect(NiaMatching.textRelevance('printer', title: 'Refill printer'), 1.5);
    expect(
      NiaMatching.textRelevance(
        'paper',
        title: 'Office',
        evidence: ['Use paper here'],
      ),
      2.5,
    );
    expect(
      NiaMatching.textRelevance(
        'new paper',
        title: 'Office',
        evidence: ['paper is new'],
      ),
      1.6,
    );
    expect(
      NiaMatching.textRelevance('paper', title: 'Office', evidence: ['Other']),
      0.9,
    );
  });
  test(
    'authority withdrawal notifies dependants and unsubscribe stops receipts',
    () {
      final f = Fixture();
      final d = f.evaluate();
      var changes = 0;
      final cancel = f.engine.listen(() => changes++);
      f.engine.reviseAuthority('local', 'v2');
      expect(f.engine.isCurrent(d), isFalse);
      expect(changes, 1);
      cancel();
      f.engine.invalidate();
      expect(changes, 1);
    },
  );
}
