import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/auth/auth_providers.dart';
import 'package:int_qa_flow/features/ask/application/ask_controller.dart';
import 'package:int_qa_flow/features/governance/application/governance_providers.dart';
import 'package:int_qa_flow/features/organisation/application/organisation_providers.dart';
import 'package:int_qa_flow/features/organisation/presentation/organisation_page.dart';

void main() {
  test(
    'organisation list providers discard late responses after UID switch',
    () async {
      final auth = _TestAuth(_TestUser('user-a'));
      final events = StreamController<User?>.broadcast();
      final adapter = _OrganisationAdapter()..holdListsForUid = 'user-a';
      final client = createApiClient(_TestTokens(auth), adapter: adapter);
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          authStateProvider.overrideWith((ref) => _authEvents(auth, events)),
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(events.close);

      final deliveredResponses = <String>[];
      final subscriptions = [
        container.listen(organisationPermissionsProvider, (_, next) {
          if (next.hasValue) {
            deliveredResponses.add(next.requireValue.toString());
          }
        }),
        container.listen(organisationOwnersProvider, (_, next) {
          if (next.hasValue) {
            deliveredResponses.add(next.requireValue.toString());
          }
        }),
        container.listen(myOrganisationJoinRequestsProvider, (_, next) {
          if (next.hasValue) {
            deliveredResponses.add(next.requireValue.toString());
          }
        }),
        container.listen(pendingOrganisationJoinRequestsProvider, (_, next) {
          if (next.hasValue) {
            deliveredResponses.add(next.requireValue.toString());
          }
        }),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });
      final providers = [
        organisationPermissionsProvider,
        organisationOwnersProvider,
        myOrganisationJoinRequestsProvider,
        pendingOrganisationJoinRequestsProvider,
      ];
      final oldResults = [
        for (final provider in providers)
          container
              .read(provider.future)
              .then<Object?>((value) => value, onError: (Object _) => null),
      ];
      await _waitFor(() => adapter.heldResponses.length == 4);

      final userB = _TestUser('user-b');
      auth.user = userB;
      events.add(userB);
      await _waitFor(
        () =>
            adapter.requests
                .where(
                  (request) =>
                      request.uid == 'user-b' &&
                      _OrganisationAdapter.listPaths.contains(request.path),
                )
                .length ==
            4,
      );
      await Future.wait([
        for (final provider in providers) container.read(provider.future),
      ]);

      for (final response in adapter.heldResponses.values) {
        response.completer.complete(
          adapter.responseFor(response.uid, response.path),
        );
      }
      await Future.wait(oldResults);
      expect(
        await Future.wait([
          for (final provider in providers) container.read(provider.future),
        ]),
        everyElement(isEmpty),
      );
      expect(deliveredResponses.join(), isNot(contains('grant-a')));
      expect(
        deliveredResponses.join(),
        isNot(contains('Owner marker for user A')),
      );
      expect(deliveredResponses.join(), isNot(contains('pending-target-a')));
      expect(
        container.read(organisationDataScopeProvider).requireValue.firebaseUid,
        'user-b',
      );
      expect(
        adapter.requests.where((request) => request.uid == 'user-b'),
        isNotEmpty,
      );
      expect(
        adapter.requests.where((request) => request.uid == 'user-a'),
        isNotEmpty,
      );
    },
  );

  testWidgets(
    'routed page refreshes revoked review capability and retries list errors',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final adapter = _OrganisationAdapter()
        ..reviewerUids.add('user-a')
        ..failMyRequestsOnce = true;
      final mounted = await _mountRoutedPage(tester, adapter: adapter);

      await tester.pumpAndSettle();
      expect(find.text('Requests could not be loaded.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No pending or recent requests.'), findsOneWidget);
      expect(find.textContaining('Requests you can review'), findsOneWidget);

      adapter.reviewerUids.remove('user-a');
      adapter.rejectJoinDecisions = true;
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Requests you can review'), findsNothing);
      expect(find.text('Review requests and proposals'), findsOneWidget);
      expect(find.text('Not granted'), findsWidgets);
      mounted.close();
    },
  );

  testWidgets(
    'routed organisation page clears owner data on role, UID and signout',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final adapter = _OrganisationAdapter()..ownerUids.add('user-a');
      final mounted = await _mountRoutedPage(tester, adapter: adapter);
      await tester.pumpAndSettle();
      expect(find.text('Owner administration'), findsOneWidget);
      expect(find.text('Owner marker for user A'), findsOneWidget);

      adapter.ownerUids.remove('user-a');
      adapter.roleByUid['user-a'] = 'employee';
      mounted.auth.user = _TestUser('user-a');
      mounted.events.add(mounted.auth.user);
      await tester.pumpAndSettle();
      expect(find.text('Owner administration'), findsNothing);
      expect(find.text('Owner marker for user A'), findsNothing);

      mounted.auth.user = _TestUser('user-b');
      mounted.events.add(mounted.auth.user);
      await tester.pumpAndSettle();
      expect(find.text('Organisation user-b'), findsOneWidget);
      expect(find.text('Owner marker for user A'), findsNothing);
      expect(find.text('grant-a'), findsNothing);

      mounted.auth.user = null;
      mounted.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Organisation user-b'), findsNothing);
      expect(
        find.text('Organisation membership is unavailable.'),
        findsOneWidget,
      );
      mounted.close();
    },
  );
}

Future<_MountedPage> _mountRoutedPage(
  WidgetTester tester, {
  required _OrganisationAdapter adapter,
}) async {
  final auth = _TestAuth(_TestUser('user-a'));
  final events = StreamController<User?>.broadcast();
  final client = createApiClient(_TestTokens(auth), adapter: adapter);
  final router = GoRouter(
    initialLocation: '/organisation',
    routes: [
      GoRoute(
        path: '/organisation',
        builder: (context, state) => const Scaffold(body: OrganisationPage()),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        authStateProvider.overrideWith((ref) => _authEvents(auth, events)),
        apiClientProvider.overrideWithValue(client),
        departmentsProvider.overrideWith((ref) async => const []),
        teamsProvider.overrideWith((ref) async => const []),
        organisationMembersProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return _MountedPage(auth, events, client, router);
}

class _MountedPage {
  const _MountedPage(this.auth, this.events, this.client, this.router);

  final _TestAuth auth;
  final StreamController<User?> events;
  final Dio client;
  final GoRouter router;

  void close() {
    events.close();
    client.close();
    router.dispose();
  }
}

Stream<User?> _authEvents(_TestAuth auth, StreamController<User?> events) =>
    Stream<User?>.multi((controller) {
      controller.add(auth.currentUser);
      final subscription = events.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for requests.');
}

class _TestAuth implements FirebaseAuth {
  _TestAuth(this.user);

  User? user;

  @override
  User? get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestUser implements User {
  _TestUser(this.uid);

  @override
  final String uid;

  @override
  bool get isAnonymous => false;

  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestTokens implements ApiTokenSource {
  _TestTokens(this.auth);

  final _TestAuth auth;

  @override
  String? get currentUid => auth.currentUser?.uid;

  @override
  Future<String?> idToken({bool forceRefresh = false}) async => currentUid;

  @override
  Future<String?> appCheckToken() async => 'test-app-check';

  @override
  Future<void> signOut() async => auth.user = null;
}

class _HeldResponse {
  _HeldResponse(this.uid, this.path, this.completer);

  final String uid;
  final String path;
  final Completer<ResponseBody> completer;
}

class _RequestRecord {
  const _RequestRecord(this.uid, this.path);

  final String uid;
  final String path;
}

class _OrganisationAdapter implements HttpClientAdapter {
  static const listPaths = {
    '/api/v1/organisation/permissions',
    '/api/v1/organisation/owners',
    '/api/v1/organisation/join-requests',
  };

  String? holdListsForUid;
  bool failMyRequestsOnce = false;
  bool rejectJoinDecisions = false;
  final reviewerUids = <String>{};
  final ownerUids = <String>{};
  final roleByUid = <String, String>{
    'user-a': 'employee',
    'user-b': 'employee',
  };
  final requests = <_RequestRecord>[];
  final heldResponses = <String, _HeldResponse>{};
  final _attempts = <String, int>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final authorization = options.headers['Authorization'] as String;
    final uid = authorization.replaceFirst('Bearer ', '');
    final path = options.uri.path;
    final mine = options.queryParameters['mine']?.toString() == 'true';
    requests.add(_RequestRecord(uid, path));
    final key = '$uid:$path:$mine';
    _attempts[key] = (_attempts[key] ?? 0) + 1;

    if (path == '/api/v1/organisation/join-requests/request-a/decision' &&
        rejectJoinDecisions) {
      return _response({'detail': 'Permission was revoked'}, statusCode: 403);
    }
    if (path == '/api/v1/organisation/join-requests' &&
        mine &&
        failMyRequestsOnce &&
        (_attempts[key] ?? 0) == 1) {
      return _response({'detail': 'Temporary failure'}, statusCode: 503);
    }
    if (uid == holdListsForUid && listPaths.contains(path)) {
      final completer = Completer<ResponseBody>();
      heldResponses[key] = _HeldResponse(uid, path, completer);
      return completer.future;
    }
    return responseFor(uid, path, mine);
  }

  ResponseBody responseFor(String uid, String path, [Object? mine]) {
    final userId = uid == 'user-a' ? 'db-user-a' : 'db-user-b';
    final organisationId = uid == 'user-a' ? 'org-a' : 'org-b';
    final isOwner = ownerUids.contains(uid);
    final isReviewer = reviewerUids.contains(uid);
    final value = switch (path) {
      '/api/v1/account/state' => {'status': 'active'},
      '/api/v1/auth/me' => {
        'user_id': userId,
        'organisation_id': organisationId,
        'email': '$uid@example.test',
        'display_name': uid,
        'role': roleByUid[uid] ?? 'employee',
      },
      '/api/v1/organisation/me' => {
        'organisation_id': organisationId,
        'organisation_name': 'Organisation $uid',
        'user_id': userId,
        'role': roleByUid[uid] ?? 'employee',
        'primary_department': null,
        'teams': <String>[],
        'is_owner': isOwner,
        'permissions': isReviewer ? ['review'] : <String>[],
        'permission_scopes': isReviewer
            ? [
                {
                  'permission': 'review',
                  'scope_type': 'department',
                  'scope_id': 'department-$uid',
                },
              ]
            : <Map<String, Object?>>[],
        'assignment_managers': <String>[],
      },
      '/api/v1/organisation/permissions' =>
        uid == 'user-a'
            ? [
                {
                  'id': 'grant-a',
                  'user_id': userId,
                  'permission': 'review',
                  'scope_type': 'department',
                  'scope_id': 'department-a',
                },
              ]
            : <Map<String, Object?>>[],
      '/api/v1/organisation/owners' =>
        uid == 'user-a'
            ? [
                {
                  'user_id': userId,
                  'display_name': 'Owner marker for user A',
                  'email': 'owner-a@example.test',
                  'active': true,
                },
              ]
            : <Map<String, Object?>>[],
      '/api/v1/organisation/join-requests' =>
        mine == true
            ? <Map<String, Object?>>[]
            : isReviewer
            ? [
                {
                  'id': 'request-a',
                  'requester_id': 'db-requester',
                  'request_type': 'department',
                  'target_id': 'pending-target-a',
                  'status': 'pending',
                  'reason': null,
                  'reviewed_by': null,
                  'reviewer_note': null,
                  'created_at': '2026-10-07T00:00:00Z',
                  'reviewed_at': null,
                },
              ]
            : <Map<String, Object?>>[],
      _ => <String, Object?>{},
    };
    return _response(value);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(Object? value, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode(value),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
