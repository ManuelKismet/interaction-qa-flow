import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';
import 'package:int_qa_flow/features/organisation/domain/organisation_models.dart';

final organisationRepositoryProvider = Provider<OrganisationRepository>(
  (ref) => OrganisationRepository(ref.watch(apiClientProvider)),
);

class OrganisationRepository {
  const OrganisationRepository(this._client);

  final Dio _client;

  Options _options(String uid) =>
      Options(extra: {'expectedFirebaseUid': uid});

  Future<OrganisationProfile> profile(
    String uid, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/organisation/me',
        options: _options(uid),
        cancelToken: cancelToken,
      );
      return OrganisationProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<OrganisationPermissionGrant>> permissions(
    String uid, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/organisation/permissions',
        options: _options(uid),
        cancelToken: cancelToken,
      );
      return (response.data ?? const [])
          .map(
            (item) => OrganisationPermissionGrant.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<OrganisationOwner>> owners(
    String uid, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/organisation/owners',
        options: _options(uid),
        cancelToken: cancelToken,
      );
      return (response.data ?? const [])
          .map(
            (item) =>
                OrganisationOwner.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<OrganisationJoinRequest>> joinRequests(
    String uid, {
    bool mine = true,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/v1/organisation/join-requests',
        queryParameters: {'mine': mine},
        options: _options(uid),
        cancelToken: cancelToken,
      );
      return (response.data ?? const [])
          .map(
            (item) =>
                OrganisationJoinRequest.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> requestMembership(
    String uid, {
    required String requestType,
    required String targetId,
  }) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/organisation/join-requests',
        data: {'request_type': requestType, 'target_id': targetId},
        options: _options(uid),
      ),
    );
  }

  Future<void> decideJoinRequest(
    String uid,
    String requestId, {
    required bool approve,
  }) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/organisation/join-requests/$requestId/decision',
        data: {'decision': approve ? 'approve' : 'decline'},
        options: _options(uid),
      ),
    );
  }

  Future<void> grantPermission(
    String uid, {
    required String userId,
    required String permission,
    required String scopeType,
    String? scopeId,
  }) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/organisation/permissions',
        data: {
          'user_id': userId,
          'permission': permission,
          'scope_type': scopeType,
          'scope_id': scopeId,
        },
        options: _options(uid),
      ),
    );
  }

  Future<void> revokePermission(String uid, String grantId) async {
    await _request(
      () => _client.delete<void>(
        '/api/v1/organisation/permissions/$grantId',
        options: _options(uid),
      ),
    );
  }

  Future<void> appointAdmin(String uid, String userId) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/organisation/admins/$userId',
        options: _options(uid),
      ),
    );
  }

  Future<void> appointOwner(String uid, String userId) async {
    await _request(
      () => _client.post<void>(
        '/api/v1/organisation/owners',
        data: {'user_id': userId},
        options: _options(uid),
      ),
    );
  }

  Future<void> revokeOwner(String uid, String userId) async {
    await _request(
      () => _client.delete<void>(
        '/api/v1/organisation/owners/$userId',
        options: _options(uid),
      ),
    );
  }

  Future<void> _request(Future<void> Function() operation) async {
    try {
      await operation();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
