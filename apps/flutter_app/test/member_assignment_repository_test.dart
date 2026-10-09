import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/features/governance/data/governance_repository.dart';

void main() {
  test('member update sends cleanup only when explicitly selected', () async {
    final adapter = _Adapter();
    final client = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;
    final repository = GovernanceRepository(client);
    await repository.updateOrganisationMember('member-1', role: 'employee');
    expect(adapter.body, {'role': 'employee'});
    await repository.updateOrganisationMember(
      'member-1',
      role: 'employee',
      clearDepartmentAnswerOwners: true,
    );
    expect(adapter.body, {
      'role': 'employee',
      'clear_department_answer_owners': true,
    });
    await repository.updateOrganisationMember(
      'member-1',
      departmentId: 'department-1',
    );
    expect(adapter.body, {'department_id': 'department-1'});
    client.close();
  });
}

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic>? body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    body =
        jsonDecode(await utf8.decoder.bind(requestStream!).join())
            as Map<String, dynamic>;
    return ResponseBody.fromString(
      '{"id":"member-1","email":"member@example.test","display_name":"Member","role":"employee","status":"active"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
