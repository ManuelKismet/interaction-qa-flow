import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/features/guest/data/guest_group_repository.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';

void main() {
  test('selected Interact import explicitly shares only chosen session copies', () async {
    final adapter = _RecordingAdapter();
    final client = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;
    final sourceSession = <String, dynamic>{
      'id': 'local-session',
      'title': 'Synthetic interview',
      'visibility': 'private_local',
      'participants': [
        {'id': 'p1', 'name': 'Synthetic participant'},
      ],
      'questions': [
        {
          'id': 'q1',
          'text': 'Primary question',
          'answers': [
            {
              'participant_id': 'p1',
              'body': 'Local answer',
              'follow_ups': [
                {'id': 'q2', 'text': 'Answer-owned follow-up'},
              ],
            },
          ],
        },
      ],
    };
    final workspace = GuestWorkspaceData(
      knowledge: [
        {'id': 'not-selected', 'title': 'Keep local'},
      ],
      sessions: [sourceSession],
    );

    await GuestGroupRepository(client).importSelected(
      groupId: 'group-id',
      data: workspace,
      knowledgeIds: const {},
      sessionIds: const {'local-session'},
    );

    final entries = adapter.requestBody!['entries'] as List;
    expect(entries, hasLength(1));
    final entry = entries.single as Map<String, dynamic>;
    expect(entry['kind'], 'interact_session');
    expect(entry['share_with_group'], isTrue);
    expect(entry['client_import_key'], 'local-local-session');
    final sharedCopy = entry['data'] as Map<String, dynamic>;
    expect(sharedCopy['visibility'], 'guest_group');
    final root =
        (sharedCopy['questions'] as List).single as Map<String, dynamic>;
    final answer = (root['answers'] as List).single as Map<String, dynamic>;
    final followUp =
        (answer['follow_ups'] as List).single as Map<String, dynamic>;
    expect(answer['body'], 'Local answer');
    expect(followUp['text'], 'Answer-owned follow-up');
    expect(sourceSession['visibility'], 'private_local');
    client.close();
  });

  test('group listing uses the guest endpoint and decodes group membership', () async {
    final adapter = _RecordingAdapter();
    final client = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;

    final groups = await GuestGroupRepository(client).listGroups();

    expect(adapter.requestPath, '/api/v1/guest/groups');
    expect(groups, [
      {'id': 'shared-entry'},
    ]);
    client.close();
  });

  test('group listing errors are sanitized and distinguish unauthorized requests', () async {
    final adapter = _RecordingAdapter(
      statusCode: 401,
      responseBody: '{"detail":"private server detail"}',
    );
    final client = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;

    await expectLater(
      GuestGroupRepository(client).listGroups(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.message, 'message', contains('not authorized'))
            .having(
              (error) => error.message,
              'message',
              isNot(contains('private server detail')),
            ),
      ),
    );
    client.close();
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({
    this.statusCode = 200,
    this.responseBody = '[{"id":"shared-entry"}]',
  });

  final int statusCode;
  final String responseBody;
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
      responseBody,
      statusCode,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}
