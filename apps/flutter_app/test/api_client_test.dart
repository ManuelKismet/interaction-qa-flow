import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';

const _authorizationScheme = 'Bearer';

void main() {
  test('maps shared API failures to safe actionable messages', () {
    const expected = {
      403: 'You do not have permission to do that.',
      404: 'That item could not be found.',
      408: 'The request timed out. Refresh status before trying again.',
      409:
          'This content changed or is unavailable. Refresh and review it before trying again.',
      429: 'Request limit reached. Wait before trying again.',
      503:
          'IntQAFlow is temporarily unavailable. Refresh status before trying again.',
    };
    for (final entry in expected.entries) {
      final request = RequestOptions(path: '/api/v1/guest/groups');
      final error = DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: entry.key,
          data: {'detail': 'secret-password raw server details'},
        ),
      );
      final message = ApiException.fromDio(error).message;
      expect(message, entry.value);
      expect(message, isNot(contains('secret-password')));
    }
  });

  test(
    'attaches current Firebase and App Check tokens to protected calls',
    () async {
      final tokens = _FakeTokenSource();
      final adapter = _RecordingAdapter((_) => _ok());
      final client = createApiClient(tokens, adapter: adapter);

      await client.get<void>('/api/v1/questions');

      expect(
        adapter.requests.single.headers['Authorization'],
        '$_authorizationScheme current-id-token',
      );
      expect(
        adapter.requests.single.headers['X-Firebase-AppCheck'],
        'current-app-check-token',
      );
      client.close();
    },
  );

  test(
    'shared guest-group listing uses Firebase and App Check tokens',
    () async {
      final tokens = _FakeTokenSource();
      final adapter = _RecordingAdapter((_) => _okList());
      final client = createApiClient(tokens, adapter: adapter);

      await client.get<List<dynamic>>('/api/v1/guest/groups');

      expect(adapter.requests.single.path, '/api/v1/guest/groups');
      expect(
        adapter.requests.single.headers['Authorization'],
        '$_authorizationScheme current-id-token',
      );
      expect(
        adapter.requests.single.headers['X-Firebase-AppCheck'],
        'current-app-check-token',
      );
      client.close();
    },
  );

  test(
    'refreshes expired sessions and signs out after a rejected refresh',
    () async {
      final tokens = _FakeTokenSource();
      final adapter = _RecordingAdapter((_) => _unauthorized());
      final client = createApiClient(tokens, adapter: adapter);

      await expectLater(
        client.get<void>('/api/v1/questions'),
        throwsA(isA<DioException>()),
      );

      expect(tokens.forceRefreshCount, 1);
      expect(tokens.signedOut, isTrue);
      expect(adapter.requests.length, 2);
      expect(
        adapter.requests.last.headers['Authorization'],
        '$_authorizationScheme refreshed-id-token',
      );
      client.close();
    },
  );

  test(
    'does not retry a personal request with a different Firebase UID',
    () async {
      final tokens = _FakeTokenSource()..currentUid = 'owner-a';
      final adapter = _RecordingAdapter((_) {
        tokens.currentUid = 'owner-b';
        return _unauthorized();
      });
      final client = createApiClient(tokens, adapter: adapter);

      await expectLater(
        client.get<void>(
          '/api/v1/personal/items',
          options: Options(extra: {'expectedFirebaseUid': 'owner-a'}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(tokens.forceRefreshCount, 0);
      expect(tokens.signedOut, isFalse);
      expect(adapter.requests, hasLength(1));
      client.close();
    },
  );

  test(
    'rejects a successful response after the Firebase UID changes',
    () async {
      final tokens = _FakeTokenSource()..currentUid = 'owner-a';
      final adapter = _RecordingAdapter((_) {
        tokens.currentUid = 'owner-b';
        return _okList();
      });
      final client = createApiClient(tokens, adapter: adapter);

      await expectLater(
        client.get<List<dynamic>>(
          '/api/v1/organisation/permissions',
          options: Options(extra: {'expectedFirebaseUid': 'owner-a'}),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );

      expect(adapter.requests, hasLength(1));
      client.close();
    },
  );

  test(
    'does not dispatch after identity changes while loading App Check',
    () async {
      final tokens = _FakeTokenSource()
        ..currentUid = 'owner-a'
        ..uidAfterAppCheck = 'owner-b';
      final adapter = _RecordingAdapter((_) => _ok());
      final client = createApiClient(tokens, adapter: adapter);

      await expectLater(
        client.get<void>(
          '/api/v1/organisation/permissions',
          options: Options(extra: {'expectedFirebaseUid': 'owner-a'}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests, isEmpty);
      client.close();
    },
  );

  test(
    'keeps a linked guest identity after organisation membership lookup returns 401',
    () async {
      final tokens = _FakeTokenSource();
      final adapter = _RecordingAdapter((_) => _unauthorized());
      final client = createApiClient(tokens, adapter: adapter);

      await expectLater(
        client.get<void>('/api/v1/auth/me'),
        throwsA(isA<DioException>()),
      );

      expect(tokens.forceRefreshCount, 1);
      expect(tokens.signedOut, isFalse);
      expect(adapter.requests.length, 2);
      client.close();
    },
  );

  test(
    'keeps signed-in identity when account-state lookup cannot be verified',
    () async {
      final tokens = _FakeTokenSource();
      final adapter = _RecordingAdapter((_) => _unauthorized());
      final client = createApiClient(tokens, adapter: adapter);

      await expectLater(
        client.get<void>('/api/v1/account/state'),
        throwsA(isA<DioException>()),
      );

      expect(tokens.forceRefreshCount, 1);
      expect(tokens.signedOut, isFalse);
      expect(adapter.requests.length, 2);
      client.close();
    },
  );
}

class _FakeTokenSource implements ApiTokenSource {
  @override
  String? currentUid = 'test-uid';

  String currentToken = 'current-id-token';
  String? uidAfterAppCheck;
  int forceRefreshCount = 0;
  bool signedOut = false;

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      forceRefreshCount++;
      currentToken = 'refreshed-id-token';
    }
    return currentToken;
  }

  @override
  Future<String?> appCheckToken() async {
    if (uidAfterAppCheck != null) currentUid = uidAfterAppCheck;
    return 'current-app-check-token';
  }

  @override
  Future<void> signOut() async => signedOut = true;
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final ResponseBody Function(int requestIndex) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(requests.length);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok() => ResponseBody.fromString(
  '{}',
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

ResponseBody _okList() => ResponseBody.fromString(
  '[]',
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

ResponseBody _unauthorized() => ResponseBody.fromString(
  '{"detail":"Authentication required"}',
  401,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);
