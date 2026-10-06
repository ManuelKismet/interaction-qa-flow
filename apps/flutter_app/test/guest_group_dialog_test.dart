import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/app.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/core/auth/sign_in_page.dart';
import 'package:int_qa_flow/core/routing/app_router.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/data/guest_storage_interface.dart';
import 'package:int_qa_flow/features/guest/data/guest_workspace_store.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:int_qa_flow/features/guest/presentation/guest_workspace_page.dart';

class _TestFirebaseAuth implements FirebaseAuth {
  _TestFirebaseAuth([this.user]);

  final User? user;

  @override
  User? get currentUser => user ?? _TestUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestUser implements User {
  _TestUser({
    this.anonymous = true,
    this.verified = false,
    this.testUid = 'test-anonymous-uid',
  });

  @override
  String get uid => testUid;

  @override
  bool get isAnonymous => anonymous;

  @override
  bool get emailVerified => verified;

  @override
  String? get email => 'test@example.test';

  final bool anonymous;
  final bool verified;
  final String testUid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SwitchingFirebaseAuth implements FirebaseAuth {
  _SwitchingFirebaseAuth(this.user);

  User? user;

  @override
  User? get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingEntryRepository extends GuestGroupRepository {
  _PendingEntryRepository() : super(Dio());

  final exportResult = Completer<Map<String, dynamic>>();
  final historyResult = Completer<List<Map<String, dynamic>>>();
  var exportRequested = false;
  var historyRequested = false;

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => [
    {'id': 'group-1', 'name': 'Group', 'role': 'viewer'},
  ];

  @override
  Future<List<Map<String, dynamic>>> listArchivedGroups() async => const [];

  @override
  Future<Map<String, dynamic>> getGroup(String groupId) async => {
    'id': groupId,
    'role': 'viewer',
    'members': [],
  };

  @override
  Future<List<Map<String, dynamic>>> searchEntries({
    required String groupId,
    String query = '',
  }) async => [
    {
      'id': 'entry-1',
      'kind': 'knowledge',
      'title': 'Shared entry',
      'revision': 1,
      'data': {'answer': 'Shared answer'},
    },
  ];

  @override
  Future<Map<String, dynamic>> exportEntry({
    required String groupId,
    required String entryId,
  }) {
    exportRequested = true;
    return exportResult.future;
  }

  @override
  Future<List<Map<String, dynamic>>> entryHistory({
    required String groupId,
    required String entryId,
  }) {
    historyRequested = true;
    return historyResult.future;
  }
}

class _FailingGroupsRepository extends GuestGroupRepository {
  _FailingGroupsRepository() : super(Dio());

  var attempts = 0;

  @override
  Future<List<Map<String, dynamic>>> listGroups() async {
    attempts++;
    throw StateError('private test detail');
  }
}

class _FailingDraftRepository extends GuestGroupRepository {
  _FailingDraftRepository() : super(Dio());

  var createGroupAttempts = 0;
  var joinAttempts = 0;
  var createKnowledgeAttempts = 0;
  var updateEntryAttempts = 0;

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => [
    {'id': 'group-1', 'name': 'Test group', 'role': 'editor'},
  ];

  @override
  Future<List<Map<String, dynamic>>> listArchivedGroups() async => const [];

  @override
  Future<Map<String, dynamic>> getGroup(String groupId) async => {
    'id': groupId,
    'name': 'Test group',
    'role': 'editor',
    'members': [],
  };

  @override
  Future<List<Map<String, dynamic>>> searchEntries({
    required String groupId,
    String query = '',
  }) async => [
    {
      'id': 'entry-1',
      'kind': 'knowledge',
      'title': 'Original title',
      'revision': 1,
      'created_by_uid': 'test-anonymous-uid',
      'data': {'body': 'Original body', 'answer': 'Original answer'},
    },
  ];

  @override
  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String displayName,
  }) async {
    createGroupAttempts++;
    throw StateError('private invitation-token detail');
  }

  @override
  Future<bool> previewInvitation(String token) async => true;

  @override
  Future<Map<String, dynamic>> joinInvitation({
    required String token,
    required String displayName,
  }) async {
    joinAttempts++;
    throw StateError('private invitation-token detail');
  }

  @override
  Future<Map<String, dynamic>> createKnowledge({
    required String groupId,
    required String title,
    required String body,
    required String answer,
  }) async {
    createKnowledgeAttempts++;
    throw StateError('private answer detail');
  }

  @override
  Future<Map<String, dynamic>> updateEntry({
    required String groupId,
    required String entryId,
    required int expectedRevision,
    required String title,
    required Map<String, dynamic> data,
  }) async {
    updateEntryAttempts++;
    throw StateError('private answer detail');
  }
}

class _FailingLocalStorage implements GuestStorage {
  @override
  String? read() => null;

  @override
  void write(String value) => throw StateError('private storage detail');

  @override
  void remove() {}
}

class _EmptyGroupsRepository extends GuestGroupRepository {
  _EmptyGroupsRepository() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => [];

  @override
  Future<List<Map<String, dynamic>>> listArchivedGroups() async => const [];
}

class _ShareRepository extends GuestGroupRepository {
  _ShareRepository() : super(Dio());

  Set<String>? sharedKnowledgeIds;
  Set<String>? sharedSessionIds;

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => [
    {'id': 'group-1', 'name': 'Local Safety Team', 'role': 'editor'},
  ];

  @override
  Future<List<Map<String, dynamic>>> listArchivedGroups() async => const [];

  @override
  Future<Map<String, dynamic>> getGroup(String groupId) async => {
    'id': groupId,
    'name': 'Local Safety Team',
    'role': 'editor',
    'members': [],
  };

  @override
  Future<List<Map<String, dynamic>>> searchEntries({
    required String groupId,
    String query = '',
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> importSelected({
    required String groupId,
    required GuestWorkspaceData data,
    required Set<String> knowledgeIds,
    required Set<String> sessionIds,
  }) async {
    sharedKnowledgeIds = knowledgeIds;
    sharedSessionIds = sessionIds;
    return const [];
  }
}

class _MemberManagementRepository extends GuestGroupRepository {
  _MemberManagementRepository({
    this.isTransferTarget = false,
    this.transferRequested = false,
  }) : super(Dio());

  var removeRequests = 0;
  var memberStatus = 'active';
  final bool isTransferTarget;
  bool transferRequested;
  bool transferAccepted = false;
  bool archived = false;
  var transferRequests = 0;
  var acceptTransferRequests = 0;
  var archiveRequests = 0;
  var restoreRequests = 0;

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => archived
      ? []
      : [
          {
            'id': 'group-1',
            'name': 'Research group',
            'role': isTransferTarget && !transferAccepted ? 'viewer' : 'admin',
          },
        ];

  @override
  Future<List<Map<String, dynamic>>> listArchivedGroups() async => archived
      ? [
          {
            'id': 'group-1',
            'name': 'Research group',
            'can_restore': true,
            'restore_until': '2030-01-31T00:00:00+00:00',
          },
        ]
      : const [];

  @override
  Future<Map<String, dynamic>> getGroup(String groupId) async => {
    'id': groupId,
    'name': 'Research group',
    'role': isTransferTarget && !transferAccepted ? 'viewer' : 'admin',
    'pending_admin_transfer': transferRequested && !transferAccepted
        ? {
            'id': 'transfer-1',
            'target_display_name': 'Invited viewer',
            'expires_at': '2030-01-08T00:00:00+00:00',
            'is_target': isTransferTarget,
            'is_requester': !isTransferTarget,
          }
        : null,
    'members': [
      if (memberStatus != 'removed')
        {
          'id': 'member-1',
          'display_name': 'Invited viewer',
          'role': 'viewer',
          'status': memberStatus,
        },
    ],
  };

  @override
  Future<List<Map<String, dynamic>>> searchEntries({
    required String groupId,
    String query = '',
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> listInvitations(String groupId) async =>
      [];

  @override
  Future<void> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    removeRequests++;
    memberStatus = 'removed';
  }

  @override
  Future<Map<String, dynamic>> transferAdministration({
    required String groupId,
    required String memberId,
  }) async {
    transferRequests++;
    transferRequested = true;
    return {'id': 'transfer-1', 'status': 'pending'};
  }

  @override
  Future<Map<String, dynamic>> acceptAdminTransfer({
    required String groupId,
    required String transferId,
  }) async {
    acceptTransferRequests++;
    transferAccepted = true;
    return {'id': transferId, 'status': 'accepted'};
  }

  @override
  Future<Map<String, dynamic>> archiveGroup(String groupId) async {
    archiveRequests++;
    archived = true;
    return {'id': groupId};
  }

  @override
  Future<Map<String, dynamic>> restoreGroup(String groupId) async {
    restoreRequests++;
    archived = false;
    return {'id': groupId};
  }
}

class _AccountTransitionRepository extends GuestGroupRepository {
  _AccountTransitionRepository(this.auth) : super(Dio());

  final _SwitchingFirebaseAuth auth;
  var transferAccepted = false;
  var acceptedByUid = '';

  @override
  Future<List<Map<String, dynamic>>> listGroups() async => [
    {
      'id': 'transition-group',
      'name': 'Transition group',
      'role': auth.currentUser?.uid == 'recipient-uid' && !transferAccepted
          ? 'viewer'
          : 'admin',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> listArchivedGroups() async => const [];

  @override
  Future<Map<String, dynamic>> getGroup(String groupId) async {
    final isRecipient = auth.currentUser?.uid == 'recipient-uid';
    return {
      'id': groupId,
      'name': 'Transition group',
      'role': isRecipient && !transferAccepted ? 'viewer' : 'admin',
      'pending_admin_transfer': transferAccepted
          ? null
          : {
              'id': 'transfer-1',
              'target_display_name': 'Recipient',
              'expires_at': '2030-01-08T00:00:00+00:00',
              'is_target': isRecipient,
              'is_requester': !isRecipient,
            },
      'members': [],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> searchEntries({
    required String groupId,
    String query = '',
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> listInvitations(String groupId) async =>
      [];

  @override
  Future<Map<String, dynamic>> acceptAdminTransfer({
    required String groupId,
    required String transferId,
  }) async {
    acceptedByUid = auth.currentUser!.uid;
    transferAccepted = true;
    return {'id': transferId, 'status': 'accepted'};
  }
}

class _MemoryGuestStorage implements GuestStorage {
  String? value;

  @override
  void remove() => value = null;

  @override
  String? read() => value;

  @override
  void write(String value) => this.value = value;
}

void main() {
  testWidgets(
    'verified registered identity can create and join while unverified is denied',
    (tester) async {
      for (final user in [
        _TestUser(),
        _TestUser(anonymous: false, verified: true),
        _TestUser(anonymous: false, verified: false),
      ]) {
        final eligible = user.isAnonymous || user.emailVerified;
        final auth = _TestFirebaseAuth(user);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firebaseAuthProvider.overrideWithValue(auth),
              guestGroupRepositoryProvider.overrideWithValue(
                _EmptyGroupsRepository(),
              ),
            ],
            child: const MaterialApp(home: SharedGuestGroupsPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Shared groups'), findsOneWidget);
        final createButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Create group'),
        );
        final joinButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Join with invitation'),
        );
        expect(createButton.onPressed != null, eligible);
        expect(joinButton.onPressed != null, eligible);
        expect(
          find.textContaining('Verify this account’s email'),
          user.isAnonymous || user.emailVerified
              ? findsNothing
              : findsOneWidget,
        );
        expect(identical(user, auth.currentUser), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('shared group creation validates required fields in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(
            _EmptyGroupsRepository(),
          ),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    final createDialogButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Create group'),
    );
    await tester.tap(createDialogButton);
    await tester.pumpAndSettle();
    expect(find.text('Enter a group name.'), findsOneWidget);
    expect(find.text('Enter a display name.'), findsOneWidget);

    await tester.enterText(field('Group name'), 'Safety');
    await tester.tap(createDialogButton);
    await tester.pumpAndSettle();
    expect(find.text('Enter a group name.'), findsNothing);
    expect(find.text('Enter a display name.'), findsOneWidget);
    expect(tester.widget<TextField>(field('Group name')).controller!.text, 'Safety');
  });

  testWidgets('failed remote forms retain drafts without replaying writes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FailingDraftRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    Future<void> tapDialogAction(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    await tester.tap(find.widgetWithText(FilledButton, 'Create group').first);
    await tester.pumpAndSettle();
    await tester.enterText(field('Group name'), 'Safety team');
    await tester.enterText(field('Your display name'), 'Alice');
    await tapDialogAction('Create group');
    expect(repository.createGroupAttempts, 1);
    expect(
      find.textContaining('private invitation-token detail'),
      findsNothing,
    );
    expect(
      find.textContaining('Status was refreshed. Review it before retrying.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create group').first);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Group name')).controller!.text, 'Safety team');
    expect(tester.widget<TextField>(field('Your display name')).controller!.text, 'Alice');
    await tapDialogAction('Cancel');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Join with invitation'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Invitation token'), 'temporary-token');
    await tester.enterText(field('Display name'), 'Alice');
    await tapDialogAction('Preview invitation');
    await tapDialogAction('Request access');
    expect(repository.joinAttempts, 1);
    expect(find.textContaining('temporary-token'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Join with invitation'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Invitation token')).controller!.text, 'temporary-token');
    expect(tester.widget<TextField>(field('Display name')).controller!.text, 'Alice');
    await tapDialogAction('Cancel');

    final addKnowledge = find.widgetWithText(
      OutlinedButton,
      'Add shared Knowledge',
    );
    await tester.ensureVisible(addKnowledge);
    await tester.tap(addKnowledge);
    await tester.pumpAndSettle();
    await tester.enterText(field('Title'), 'Draft title');
    await tester.enterText(field('Knowledge / answer'), 'Draft content');
    await tapDialogAction('Share with group');
    expect(repository.createKnowledgeAttempts, 1);
    await tester.tap(addKnowledge);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Title')).controller!.text, 'Draft title');
    expect(
      tester.widget<TextField>(field('Knowledge / answer')).controller!.text,
      'Draft content',
    );
    await tapDialogAction('Cancel');

    await tester.tap(find.text('Original title'));
    await tester.pumpAndSettle();
    await tapDialogAction('Edit');
    await tester.enterText(field('Title'), 'Edited draft title');
    await tester.enterText(field('Knowledge'), 'Edited draft body');
    await tester.enterText(field('Answer'), 'Edited draft answer');
    await tapDialogAction('Save revision');
    expect(repository.updateEntryAttempts, 1);
    await tester.tap(find.text('Original title'));
    await tester.pumpAndSettle();
    await tapDialogAction('Edit');
    expect(tester.widget<TextField>(field('Title')).controller!.text, 'Edited draft title');
    expect(tester.widget<TextField>(field('Knowledge')).controller!.text, 'Edited draft body');
    expect(tester.widget<TextField>(field('Answer')).controller!.text, 'Edited draft answer');
    expect(
      find.textContaining('private answer detail'),
      findsNothing,
    );
    await tapDialogAction('Cancel');
    expect(repository.createGroupAttempts, 1);
    expect(repository.joinAttempts, 1);
    expect(repository.createKnowledgeAttempts, 1);
    expect(repository.updateEntryAttempts, 1);
  });

  testWidgets('failed autosave blocks sign-in navigation with warning', (
    tester,
  ) async {
    final storage = _FailingLocalStorage();
    final store = GuestWorkspaceStore(storage);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestWorkspaceStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: GuestWorkspacePage(firebaseReady: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final question = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Question',
    );
    await tester.enterText(question, 'Keep this draft');
    final save = find.widgetWithText(FilledButton, 'Save locally');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsNothing);
    expect(
      find.text(
        'Unable to save local changes. Retry saving before leaving this workspace.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Your changes are not saved. Keep this page open and retry.'),
      findsOneWidget,
    );
    expect(find.textContaining('private storage detail'), findsNothing);
  });

  testWidgets('group lookup failure does not claim there are no groups', (
    tester,
  ) async {
    final repository = _FailingGroupsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The shared-group request could not be verified'),
      findsOneWidget,
    );
    expect(find.textContaining('No approved shared groups are linked'), findsNothing);
    expect(find.text('private test detail'), findsNothing);
    await tester.tap(find.text('Refresh status'));
    await tester.pumpAndSettle();
    expect(repository.attempts, 2);
  });

  testWidgets('group sharing is opt-in and describes online destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ShareRepository();
    final store = GuestWorkspaceStore(_MemoryGuestStorage());
    await store.save(
      const GuestWorkspaceData(
        knowledge: [
          {'id': 'knowledge-1', 'title': 'Local knowledge'},
        ],
        sessions: [
          {
            'id': 'session-1',
            'title': 'Private interview',
            'participants': [
              {'id': 'participant-1', 'name': 'Alice'},
            ],
            'questions': [
              {
                'id': 'question-1',
                'text': 'Prompt',
                'answers': [
                  {'participant_id': 'participant-1', 'body': 'Private answer'},
                ],
              },
            ],
          },
        ],
        templates: [
          {'id': 'template-1', 'name': 'Local template'},
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(repository),
          guestWorkspaceStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await _pumpUntilEnabled(
      tester,
      find.widgetWithText(OutlinedButton, 'Preview and share local work'),
    );

    await tester.tap(find.text('Preview and share local work'));
    await _pumpUntilFound(
      tester,
      find.text('Preview sharing to Local Safety Team'),
    );
    expect(find.text('Preview sharing to Local Safety Team'), findsOneWidget);
    expect(
      find.textContaining('uploads selected copies online to Local Safety Team'),
      findsOneWidget,
    );
    expect(find.textContaining('Approved group members'), findsOneWidget);
    expect(
      find.textContaining('local originals stay on this device'),
      findsOneWidget,
    );
    expect(
      find.text('Sharing uploads all participants and answer-owned branches'),
      findsOneWidget,
    );
    expect(find.text('Local templates remain on this device'), findsOneWidget);
    expect(
      find.textContaining(
        'existing group copy is reused without being overwritten',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('added locally'), findsNothing);
    expect(
      tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Local knowledge'),
          matching: find.byType(CheckboxListTile),
        ),
      ).value,
      isFalse,
    );
    expect(
      tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Private interview'),
          matching: find.byType(CheckboxListTile),
        ),
      ).value,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Share selected with group'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Cancel'));
    await _pumpUntilGone(
      tester,
      find.text('Preview sharing to Local Safety Team'),
    );
    expect(repository.sharedKnowledgeIds, isNull);
    expect((await store.load()).sessions.single['title'], 'Private interview');

    await tester.tap(find.text('Preview and share local work'));
    await _pumpUntilFound(
      tester,
      find.text('Preview sharing to Local Safety Team'),
    );
    await tester.tap(find.text('Local knowledge'));
    await tester.pump();
    await tester.tap(find.text('Share selected with group'));
    await tester.pumpAndSettle();

    expect(repository.sharedKnowledgeIds, {'knowledge-1'});
    expect(repository.sharedSessionIds, isEmpty);
    expect((await store.load()).knowledge.single['title'], 'Local knowledge');
    expect((await store.load()).sessions.single['title'], 'Private interview');
  });

  testWidgets(
    'verified registered identity can create and join while unverified is denied',
    (tester) async {
      for (final verified in [true, false]) {
        final user = _TestUser(anonymous: false, verified: verified);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth(user)),
              guestGroupRepositoryProvider.overrideWithValue(
                _EmptyGroupsRepository(),
              ),
            ],
            child: const MaterialApp(home: SharedGuestGroupsPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Shared groups'), findsOneWidget);
        final createButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Create group'),
        );
        final joinButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Join with invitation'),
        );
        expect(createButton.onPressed != null, verified);
        expect(joinButton.onPressed != null, verified);
        expect(
          find.textContaining('Verify this account’s email'),
          verified ? findsNothing : findsOneWidget,
        );
        expect(identical(user, _TestFirebaseAuth(user).currentUser), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('removing a member keeps the shared groups page mounted', (
    tester,
  ) async {
    final repository = _MemberManagementRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Manage members and invitations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();

    expect(find.text('Remove this guest member?'), findsOneWidget);
    expect(find.text('Shared groups'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Remove member').last,
    );
    await tester.pumpAndSettle();

    expect(repository.removeRequests, 1);
    expect(repository.memberStatus, 'removed');
    expect(find.text('Shared groups'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Invited viewer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('group administration transfer requires recipient acceptance', (
    tester,
  ) async {
    final ownerRepository = _MemberManagementRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(ownerRepository),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Manage members and invitations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request admin transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Request group administration?'), findsOneWidget);
    expect(find.textContaining('You remain an administrator unless they accept'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Send request'));
    await tester.pumpAndSettle();

    expect(ownerRepository.transferRequests, 1);
    expect(find.textContaining('Waiting for Invited viewer to accept'), findsOneWidget);
    expect(
      find.textContaining('Role: admin'),
      findsOneWidget,
      reason: 'The requester keeps the current role until the recipient accepts.',
    );
  });

  testWidgets('recipient sees and can accept pending administration transfer', (
    tester,
  ) async {
    final recipientRepository = _MemberManagementRepository(
      isTransferTarget: true,
      transferRequested: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(recipientRepository),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('asked to accept group administration'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Accept administration'));
    await tester.pumpAndSettle();
    expect(recipientRepository.acceptTransferRequests, 1);
    expect(
      find.textContaining('asked to accept group administration'),
      findsNothing,
    );
    expect(find.textContaining('Role: admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account transition remounts shared-group state for recipient', (
    tester,
  ) async {
    final owner = _TestUser(anonymous: false, testUid: 'owner-uid');
    final recipient = _TestUser(anonymous: false, testUid: 'recipient-uid');
    final auth = _SwitchingFirebaseAuth(owner);
    final authEvents = StreamController<User?>();
    final repository = _AccountTransitionRepository(auth);
    final routers = <String, GoRouter>{};
    authEvents.add(owner);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => authEvents.stream),
          firebaseAuthProvider.overrideWithValue(auth),
          accountMembershipStatusProvider.overrideWith(
            (ref) async => AccountMembershipStatus.active,
          ),
          currentMembershipProvider.overrideWith(
            (ref) async => const ActiveMembership(
              userId: 'app-user',
              organisationId: 'org',
              email: 'member@example.test',
              displayName: 'Member',
              role: 'member',
            ),
          ),
          appRouterProvider.overrideWith((ref, firebaseUid) {
            final router = GoRouter(
              initialLocation: '/guest/groups',
              routes: [
                GoRoute(
                  path: '/guest/groups',
                  builder: (context, state) => const SharedGuestGroupsPage(),
                ),
              ],
            );
            routers[firebaseUid] = router;
            ref.onDispose(router.dispose);
            return router;
          }),
          guestGroupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const IntQaFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Waiting for Recipient to accept'),
      findsOneWidget,
    );
    expect(find.text('Accept administration'), findsNothing);
    expect(routers.keys, contains('owner-uid'));

    auth.user = recipient;
    authEvents.add(recipient);
    await tester.pumpAndSettle();
    expect(routers.keys, containsAll(['owner-uid', 'recipient-uid']));
    expect(routers['owner-uid'], isNot(same(routers['recipient-uid'])));
    expect(
      find.textContaining('asked to accept group administration'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Accept administration'));
    await tester.pumpAndSettle();

    expect(repository.acceptedByUid, 'recipient-uid');
    expect(
      find.textContaining('asked to accept group administration'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await authEvents.close();
  });

  testWidgets('group archive explains same-UID recovery and can be restored', (
    tester,
  ) async {
    final repository = _MemberManagementRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
          guestGroupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SharedGuestGroupsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Archive group'));
    await tester.pumpAndSettle();
    expect(find.text('Archive this shared group?'), findsOneWidget);
    expect(find.textContaining('only the same Firebase account'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Archive group').last);
    await tester.pumpAndSettle();

    expect(repository.archiveRequests, 1);
    expect(find.text('Archived groups'), findsOneWidget);
    expect(
      find.textContaining('Only this same Firebase account can restore'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Restore'));
    await tester.pumpAndSettle();
    expect(repository.restoreRequests, 1);
    expect(find.text('Research group · admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['Download / Share PDF', 'History']) {
    testWidgets(
      'does not open $action result after the entry dialog is dismissed',
      (tester) async {
        final repository = _PendingEntryRepository();
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firebaseAuthProvider.overrideWithValue(_TestFirebaseAuth()),
              guestGroupRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              navigatorKey: navigatorKey,
              home: const SharedGuestGroupsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final entry = find.text('Shared entry');
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        await tester.tap(find.text(action).last);
        await tester.pump();
        expect(
          action == 'Download / Share PDF'
              ? repository.exportRequested
              : repository.historyRequested,
          isTrue,
        );

        navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);

        if (action == 'Download / Share PDF') {
          repository.exportResult.complete({'answer': 'Authorized export'});
        } else {
          repository.historyResult.complete([
            {'revision': 1},
          ]);
        }
        await tester.pumpAndSettle();
        expect(find.text('Authorized group export'), findsNothing);
        expect(find.text('Entry revisions'), findsNothing);
      },
    );
  }
}

Future<void> _pumpUntilEnabled(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty &&
        tester.widget<OutlinedButton>(finder).onPressed != null) {
      return;
    }
  }
  fail('Widget did not become enabled: $finder');
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Widget did not appear: $finder');
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Widget did not disappear: $finder');
}
