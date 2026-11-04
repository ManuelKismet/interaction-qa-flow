import 'package:int_qa_flow/features/guest/domain/guest_workspace_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/api/api_client.dart';
import 'package:int_qa_flow/core/api/api_exception.dart';

typedef BankJson = Map<String, dynamic>;
final suggestionBankRepositoryProvider = Provider<SuggestionBankRepository>(
  (ref) => SuggestionBankRepository(ref.watch(apiClientProvider)),
);

class SuggestionBankRepository {
  const SuggestionBankRepository(this.client);
  final Dio client;
  Future<T> request<T>(
    String uid,
    String realm,
    String path, {
    BankJson query = const {},
    BankJson? data,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await client.request<T>(
        '/api/v1/suggestion-bank$path',
        queryParameters: {'realm': realm, ...query},
        data: data,
        options: Options(
          method: data == null ? 'GET' : 'POST',
          extra: {'expectedFirebaseUid': uid},
        ),
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

// Every asynchronous result belongs to an account, workspace and exact context.
// Providers dispose/cancel on navigation; the API independently rechecks access.
final bankScopesProvider = FutureProvider.autoDispose
    .family<List<BankJson>, (String, String)>((ref, key) async {
      final token = CancelToken();
      ref.onDispose(token.cancel);
      final result = await ref
          .watch(suggestionBankRepositoryProvider)
          .request<List<dynamic>>(
            key.$1,
            key.$2,
            '/scopes',
            cancelToken: token,
          );
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
final bankReadProvider = FutureProvider.autoDispose
    .family<BankJson, (String, String, String, String)>((ref, key) async {
      final token = CancelToken();
      ref.onDispose(token.cancel);
      return ref
          .watch(suggestionBankRepositoryProvider)
          .request<BankJson>(
            key.$1,
            key.$2,
            key.$3,
            query: Map<String, dynamic>.from(Uri.splitQueryString(key.$4)),
            cancelToken: token,
          );
    });

String bankLabel(String value) => value
    .split('_')
    .map((s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1))
    .join(' ');
String bankRequestKey() => _bankIds.next();

final _bankIds = GuestItemIdGenerator();
