import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/questions/data/questions_repository.dart';

void main() {
  test('reopen sends an empty JSON action body', () async {
    final adapter = _RecordingAdapter();
    final client = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;

    await QuestionsRepository(client).reopen('question-id');

    expect(adapter.requestPath, '/api/v1/questions/question-id/reopen');
    expect(adapter.requestBody, isEmpty);
    client.close();
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  Map<String, dynamic>? requestBody;
  String? requestPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestPath = options.uri.path;
    if (requestStream != null) {
      final encodedBody = await utf8.decoder.bind(requestStream).join();
      if (encodedBody.isNotEmpty) {
        requestBody = jsonDecode(encodedBody) as Map<String, dynamic>;
      }
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}
