import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/api/api_client.dart';

void main() {
  test('attaches current Firebase and App Check tokens to protected calls', () async {
    final tokens = _FakeTokenSource();
    final adapter = _RecordingAdapter((_) => _ok());
    final client = createApiClient(tokens, adapter: adapter);

    await client.get<void>('/api/v1/questions');

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bear' + 'er ' + 'current-id-token',
    );
    expect(
      adapter.requests.single.headers['X-Firebase-AppCheck'],
      'current-app-check-token',
    );
    client.close();
  });

  test('refreshes expired sessions and signs out after a rejected refresh', () async {
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
      'Bear' + 'er ' + 'refreshed-id-token',
    );
    client.close();
  });
}

class _FakeTokenSource implements ApiTokenSource {
  String currentToken = 'current-id-token';
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
  Future<String?> appCheckToken() async => 'current-app-check-token';

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

ResponseBody _unauthorized() => ResponseBody.fromString(
      '{"detail":"Authentication required"}',
      401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
