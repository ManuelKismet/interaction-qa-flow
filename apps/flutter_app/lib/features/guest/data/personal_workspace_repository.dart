import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';

final personalWorkspaceRepositoryProvider = Provider<PersonalWorkspaceRepository>(
  (ref) => PersonalWorkspaceRepository(ref.watch(apiClientProvider)),
);

class PersonalWorkspaceRepository {
  const PersonalWorkspaceRepository(this._client);

  final Dio _client;

  Future<List<Map<String, dynamic>>> listItems({
    required String expectedUid,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/api/v1/personal/items',
      options: Options(
        extra: {'expectedFirebaseUid': expectedUid},
      ),
    );
    return [
      for (final item in response.data ?? const [])
        if (item is Map<String, dynamic>) item,
    ];
  }

  Future<List<Map<String, dynamic>>> importItems(
    List<Map<String, dynamic>> items, {
    required String expectedUid,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/personal/items/import',
      data: {'items': items},
      options: Options(
        extra: {'expectedFirebaseUid': expectedUid},
      ),
    );
    final result = response.data?['items'];
    if (result is! List ||
        result.length != items.length ||
        result.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('The account import response was invalid.');
    }
    return [for (final item in result) item as Map<String, dynamic>];
  }

  Future<Map<String, dynamic>> updateItem({
    required String id,
    required String expectedUid,
    required int expectedRevision,
    required String title,
    required Map<String, dynamic> data,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/api/v1/personal/items/$id',
      data: {
        'expected_revision': expectedRevision,
        'title': title,
        'data': data,
      },
      options: Options(
        extra: {'expectedFirebaseUid': expectedUid},
      ),
    );
    return response.data!;
  }

  Future<void> deleteItem(
    String id, {
    required String expectedUid,
  }) async {
    await _client.delete<void>(
      '/api/v1/personal/items/$id',
      options: Options(
        extra: {'expectedFirebaseUid': expectedUid},
      ),
    );
  }
}
