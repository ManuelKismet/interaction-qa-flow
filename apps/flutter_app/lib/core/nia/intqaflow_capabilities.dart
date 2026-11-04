import 'package:nopak_nia/nopak_nia.dart';

enum NiaTopic {
  storage,
  knowledge,
  interact,
  groups,
  identity,
  participant,
  questions,
  session,
  groupCopy,
  sharedItem,
  lifecycle,
  suggestion,
  organisation,
}

/// IntQAFlow adapter: permitted current workflow facts, not a user profile or
/// another product's opportunities. All resulting actions stay human initiated.
final class IntQaFlowGuidance implements NiaCapability {
  IntQaFlowGuidance(this.topic, {this.requested = false});
  final NiaTopic topic;
  final bool requested;
  @override
  String get id => 'intqaflow.' + topic.name;
  @override
  int get version => 1;
  @override
  String get purpose => 'guidance';
  @override
  Set<String> get supportedEvents => {'requested', 'changed'};
  @override
  List<NiaProposal> evaluate(NiaContext context, NiaBudget budget) {
    final f = context.facts;
    bool yes(String key) => f[key] == true;
    String text(String key, String fallback) =>
        f[key] is String && (f[key] as String).trim().isNotEmpty
        ? f[key] as String
        : fallback;
    NiaProposal guide(
      String id,
      String message, {
      int priority = 0,
      String? action,
    }) => NiaProposal(
      id: id,
      message: message,
      reason: topic.name,
      priority: priority,
      effect: action == null ? NiaEffect.guidance : NiaEffect.navigation,
      action: action,
    );
    if (yes('unsaved'))
      return [
        guide(
          'unsaved',
          'Your changes have not been saved. Keep this page open and retry saving before leaving.',
          priority: 10,
        ),
      ];
    if (!requested) {
      if (topic == NiaTopic.suggestion && yes('overdue') && !yes('closed')) {
        return [
          guide(
            'overdue',
            'A review date has passed. Check the responsible reviewer and the recorded response before following up.',
            action: 'overdue',
          ),
        ];
      }
      if (topic == NiaTopic.suggestion && yes('unread')) {
        return [
          guide(
            'unread',
            'There are updates to suggestions you follow. Open Updates to read the response.',
            action: 'updates',
          ),
        ];
      }
      if (topic == NiaTopic.interact && yes('participantMissing')) {
        return [
          guide(
            'choose-participant',
            'Choose the active participant before entering individual answers.',
          ),
        ];
      }
      if (topic == NiaTopic.lifecycle && yes('readOnly')) {
        return [
          guide(
            'read-only',
            'This session is ' +
                text('status', 'read-only') +
                '. You can read it and export reports; editing is unavailable.',
          ),
        ];
      }
      return const [];
    }
    return switch (topic) {
      NiaTopic.storage => [guide('storage', _storage(f))],
      NiaTopic.knowledge => [
        guide(
          'search',
          yes('private')
              ? 'Search includes accessible Local, Private, Group and Organisation Knowledge and Interact. Only the query is sent; browser-local content remains on this device. Open a source to inspect it before using it.'
              : 'This search covers Knowledge and Interact stored on this device. It stays local. Related results can help you reuse an existing answer before adding another question.',
        ),
      ],
      NiaTopic.interact => [
        guide(
          'interact',
          yes('private')
              ? 'New sessions are private to your account. Select a participant to enter their answers. Importing and Group sharing remain separate deliberate actions.'
              : 'New sessions stay on this device. Select the participant whose answers you are recording; save or export the flow when you need a copy elsewhere.',
        ),
      ],
      NiaTopic.groups => [
        guide(
          'groups',
          yes('verified')
              ? 'Group access follows this verified identity and is separate from organisation membership. Your Group role is ' +
                    text('role', 'shown in the selected Group') +
                    '. Use Suggestions & practices in Group options to review that Group’s proposals.'
              : 'Groups require a registered account with a verified email. Organisation membership is not required, and local work remains available while you sign in or verify.',
        ),
      ],
      NiaTopic.identity => [
        guide(
          'identity',
          'Group access belongs to the current verified identity. Changing accounts does not transfer its Groups, personal work or organisation permissions.',
        ),
      ],
      NiaTopic.participant => [
        guide(
          'participant',
          'Answers and individual questions belong to the selected participant. Changing the active participant changes the answers shown; it does not copy another participant’s responses.',
        ),
      ],
      NiaTopic.questions => [
        guide(
          'questions',
          'Shared questions have separate answers for each participant. Participant questions apply only to their selected participant. Add a follow-up from the relevant answer to preserve its branch.',
        ),
      ],
      NiaTopic.session => [
        guide(
          'session',
          'Local and personal-account sessions stay editable without organisation lifecycle states. Delete offers Undo immediately; saved JSON copies can be reopened deliberately. Group copies remain separate.',
        ),
      ],
      NiaTopic.groupCopy => [
        guide(
          'group-copy',
          yes('readOnly')
              ? 'This Group copy is read-only for your current role. Personal and local originals remain separate.'
              : 'You are editing a shared Group copy. Use Save Group copy to publish these changes to that Group; personal and local originals remain separate.',
        ),
      ],
      NiaTopic.sharedItem => [
        guide(
          'shared-item',
          'This is the currently accessible shared Group revision' +
              (f['revision'] is num ? ' ' + f['revision'].toString() : '') +
              '. Inspect its history before changing it. Exporting or importing creates a deliberate copy and does not overwrite the original.',
        ),
      ],
      NiaTopic.lifecycle => [guide('lifecycle', _lifecycle(f))],
      NiaTopic.suggestion => [
        guide(
          'suggestion',
          yes('closed')
              ? 'This suggestion is closed. Its original proposal, official response and agreed practices remain readable. An authorised reviewer can reopen it with a reason.'
              : yes('canReview')
              ? 'Review the proposal and evidence, name an accountable reviewer and review date, and record the reason for each official action. Linking duplicates preserves the originals.'
              : 'Check related accessible suggestions before submitting. You can follow updates and contribute when your current role permits; official decisions belong to the authorised reviewers.',
        ),
      ],
      NiaTopic.organisation => [
        guide(
          'organisation',
          'Organisation access follows active membership and assigned scope. Department answer authority and Team membership are separate; recommendations never grant review or verification permission.',
        ),
      ],
    };
  }

  String _storage(Map<String, Object?> f) {
    final status = f['saveStatus'] as String? ?? 'Storage status unavailable';
    final private = f['private'] == true;
    final registered = f['registered'] == true;
    final heading = private
        ? 'Personal workspace · Local browser copy: ' + status
        : registered
        ? 'Registered personal account · Local copy · ' + status
        : 'Guest workspace · ' + status;
    final detail = private
        ? 'New Knowledge and Interact sessions are saved privately to your account. Local browser work remains separate until you explicitly import it. Group sharing is separate.'
        : registered
        ? 'Local drafts stay in this browser profile and may be visible to people using it. Importing selected local work into your account is optional. Group and organisation access are separate.'
        : 'People using this browser profile can see its local work. Clearing browser data can erase it; keep a JSON backup when you need a reusable copy.';
    return heading +
        '. ' +
        detail +
        (f['noOrganisation'] == true
            ? ' This signed-in account has no organisation membership.'
            : '');
  }

  String _lifecycle(Map<String, Object?> f) {
    final status = f['status'] as String? ?? 'draft';
    final next = switch (status) {
      'draft' => 'Draft sessions can be prepared before they are activated.',
      'active' =>
        'Active sessions collect answers. Complete the session deliberately when the interaction is finished.',
      'completed' =>
        'Completed sessions are read-only. Reports remain available; use the existing proposal workflow to submit suitable Knowledge for review.',
      _ =>
        'Archived sessions are read-only. Archive is final; there is no reopen or restore action.',
    };
    return next +
        (f['canManage'] == false
            ? ' Your current role cannot change this session.'
            : '');
  }
}
