import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';

final guestGroupRepositoryProvider = Provider<GuestGroupRepository>((ref) {
  return GuestGroupRepository(ref.watch(apiClientProvider));
});

final currentGuestGroupsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(guestGroupRepositoryProvider).listGroups();
    });

class GuestGroupRepository {
  const GuestGroupRepository(this._client);

  final Dio _client;

  Future<T> _request<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<Map<String, dynamic>>> listGroups() => _request(() async {
    final response = await _client.get<List<dynamic>>('/api/v1/guest/groups');
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  });

  Future<List<Map<String, dynamic>>> listArchivedGroups() =>
      _request(() async {
        final response = await _client.get<List<dynamic>>(
          '/api/v1/guest/groups/archived',
        );
        return (response.data ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String displayName,
  }) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/groups',
      data: {'name': name, 'display_name': displayName},
    );
    return response.data!;
  });

  Future<Map<String, dynamic>> getGroup(String groupId) =>
      _request(() async {
        final response = await _client.get<Map<String, dynamic>>(
          '/api/v1/guest/groups/$groupId',
        );
        return response.data!;
      });

  Future<Map<String, dynamic>> createInvitation({
    required String groupId,
    required String role,
  }) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/invitations',
      data: {'role': role, 'expires_in_hours': 24},
    );
    return response.data!;
  });

  Future<bool> previewInvitation(String token) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/invitations/preview',
      data: {'token': token},
    );
    return response.data?['valid'] == true;
  });

  Future<Map<String, dynamic>> joinInvitation({
    required String token,
    required String displayName,
  }) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/invitations/join',
      data: {'token': token, 'display_name': displayName},
    );
    return response.data!;
  });

  Future<Map<String, dynamic>> approveMember({
    required String groupId,
    required String memberId,
  }) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/members/$memberId/approve',
    );
    return response.data!;
  });

  Future<Map<String, dynamic>> changeMemberRole({
    required String groupId,
    required String memberId,
    required String role,
  }) => _request(() async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/members/$memberId/role',
      data: {'role': role},
    );
    return response.data!;
  });

  Future<void> removeMember({
    required String groupId,
    required String memberId,
  }) => _request(() async {
    await _client.delete<void>(
      '/api/v1/guest/groups/$groupId/members/$memberId',
    );
  });

  Future<Map<String, dynamic>> transferAdministration({
    required String groupId,
    required String memberId,
  }) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/transfer-administration',
      queryParameters: {'member_id': memberId},
    );
    return response.data!;
  });

  Future<Map<String, dynamic>> acceptAdminTransfer({
    required String groupId,
    required String transferId,
  }) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/admin-transfers/$transferId/accept',
    );
    return response.data!;
  });

  Future<Map<String, dynamic>> declineAdminTransfer({
    required String groupId,
    required String transferId,
  }) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/admin-transfers/$transferId/decline',
    );
    return response.data!;
  });

  Future<Map<String, dynamic>> cancelAdminTransfer({
    required String groupId,
    required String transferId,
  }) => _request(() async {
    final response = await _client.delete<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/admin-transfers/$transferId',
    );
    return response.data!;
  });

  Future<Map<String, dynamic>> archiveGroup(String groupId) =>
      _request(() async {
        final response = await _client.post<Map<String, dynamic>>(
          '/api/v1/guest/groups/$groupId/archive',
        );
        return response.data!;
      });

  Future<Map<String, dynamic>> restoreGroup(String groupId) =>
      _request(() async {
        final response = await _client.post<Map<String, dynamic>>(
          '/api/v1/guest/groups/$groupId/restore',
        );
        return response.data!;
      });

  Future<void> permanentlyDeleteGroup(String groupId) => _request(() async {
    await _client.delete<void>('/api/v1/guest/groups/$groupId/permanent');
  });

  Future<void> revokeInvitation({
    required String groupId,
    required String invitationId,
  }) => _request(() async {
    await _client.delete<void>(
      '/api/v1/guest/groups/$groupId/invitations/$invitationId',
    );
  });

  Future<List<Map<String, dynamic>>> listInvitations(String groupId) =>
      _request(() async {
        final response = await _client.get<List<dynamic>>(
          '/api/v1/guest/groups/$groupId/invitations',
        );
        return (response.data ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });

  Future<List<Map<String, dynamic>>> searchEntries({
    required String groupId,
    String query = '',
  }) => _request(() async {
    final response = await _client.get<List<dynamic>>(
      '/api/v1/guest/groups/$groupId/entries',
      queryParameters: {'query': query},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  });

  Future<Map<String, dynamic>> createKnowledge({
    required String groupId,
    required String title,
    required String body,
    required String answer,
  }) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/entries',
      data: {
        'kind': 'knowledge',
        'title': title,
        'data': {'body': body, 'answer': answer},
      },
    );
    return response.data!;
  });

  Future<Map<String, dynamic>> createInteractSession({
    required String groupId,
    required String title,
    required Map<String, dynamic> session,
  }) => _request(() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/entries',
      data: {
        'kind': 'interact_session',
        'title': title,
        'data': session,
        'share_with_group': true,
      },
    );
    return response.data!;
  });

  Future<Map<String, dynamic>> updateEntry({
    required String groupId,
    required String entryId,
    required int expectedRevision,
    required String title,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/api/v1/guest/groups/$groupId/entries/$entryId',
        data: {
          'expected_revision': expectedRevision,
          'title': title,
          'data': data,
        },
      );
      return response.data!;
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        throw const ApiException(
          'This content changed since you opened it. '
          'Refresh and review the latest version before saving.',
        );
      }
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deleteEntry({
    required String groupId,
    required String entryId,
  }) => _request(() async {
    await _client.delete<void>(
      '/api/v1/guest/groups/$groupId/entries/$entryId',
    );
  });

  Future<List<Map<String, dynamic>>> entryHistory({
    required String groupId,
    required String entryId,
  }) => _request(() async {
    final response = await _client.get<List<dynamic>>(
      '/api/v1/guest/groups/$groupId/entries/$entryId/history',
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  });

  Future<Map<String, dynamic>> exportEntry({
    required String groupId,
    required String entryId,
  }) => _request(() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/guest/groups/$groupId/entries/$entryId/export',
    );
    return response.data!;
  });

  Future<List<Map<String, dynamic>>> importSelected({
    required String groupId,
    required GuestWorkspaceData data,
    required Set<String> knowledgeIds,
    required Set<String> sessionIds,
  }) => _request(() async {
    final entries = <Map<String, dynamic>>[
      for (final item in data.knowledge)
        if (knowledgeIds.contains(item['id']))
          {
            'kind': 'knowledge',
            'title': item['title'],
            'data': item,
            'client_import_key': 'local-${item['id']}',
          },
      for (final item in data.sessions)
        if (sessionIds.contains(item['id']))
          {
            'kind': 'interact_session',
            'title': item['title'],
            'data': {...item, 'visibility': 'guest_group'},
            'client_import_key': 'local-${item['id']}',
            'share_with_group': true,
          },
    ];
    if (entries.isEmpty) return const [];
    final response = await _client.post<List<dynamic>>(
      '/api/v1/guest/groups/$groupId/import',
      data: {'entries': entries},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  });
}
