import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/core/config/app_config.dart';

const _authorizationScheme = 'Bearer';

final apiClientProvider = Provider<Dio>((ref) {
  final source = _FirebaseTokenSource(
    auth: FirebaseAuth.instance,
    appCheck: FirebaseAppCheck.instance,
  );
  final client = createApiClient(source);
  ref.onDispose(client.close);
  return client;
});

abstract interface class ApiTokenSource {
  String? get currentUid;

  Future<String?> idToken({bool forceRefresh = false});

  Future<String?> appCheckToken();

  Future<void> signOut();
}

class _FirebaseTokenSource implements ApiTokenSource {
  const _FirebaseTokenSource({required this.auth, required this.appCheck});

  final FirebaseAuth auth;
  final FirebaseAppCheck appCheck;

  @override
  String? get currentUid => auth.currentUser?.uid;

  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      auth.currentUser?.getIdToken(forceRefresh);

  @override
  Future<String?> appCheckToken() => appCheck.getToken();

  @override
  Future<void> signOut() => auth.signOut();
}

Dio createApiClient(ApiTokenSource tokenSource, {HttpClientAdapter? adapter}) {
  final client = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {'Content-Type': 'application/json'},
    ),
  );
  if (adapter != null) client.httpClientAdapter = adapter;

  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          await _attachTokens(options, tokenSource);
          handler.next(options);
        } catch (error) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: error,
              type: DioExceptionType.unknown,
            ),
          );
        }
      },
      onResponse: (response, handler) {
        final expectedUid =
            response.requestOptions.extra['expectedFirebaseUid'];
        if (expectedUid is String && tokenSource.currentUid != expectedUid) {
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.cancel,
              error: StateError(
                'The signed-in account changed during the request.',
              ),
            ),
          );
          return;
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        final detail = jsonEncode(error.response?.data ?? '').toLowerCase();
        final expectedUid = options.extra['expectedFirebaseUid'];
        if (error.response?.statusCode != 401 ||
            options.extra['authRetried'] == true ||
            detail.contains('app check') ||
            (expectedUid is String && tokenSource.currentUid != expectedUid)) {
          handler.next(error);
          return;
        }
        try {
          final idToken = await tokenSource.idToken(forceRefresh: true);
          if (expectedUid is String && tokenSource.currentUid != expectedUid) {
            handler.next(error);
            return;
          }
          if (idToken == null) {
            if (expectedUid is! String &&
                options.uri.path != '/api/v1/account/state') {
              await tokenSource.signOut();
            }
            handler.next(error);
            return;
          }
          await _attachTokens(options, tokenSource, idToken: idToken);
          options.extra['authRetried'] = true;
          final response = await client.fetch<dynamic>(options);
          handler.resolve(response);
        } on DioException catch (retryError) {
          if (retryError.response?.statusCode == 401 &&
              !{
                '/api/v1/auth/me',
                '/api/v1/account/state',
              }.contains(options.uri.path) &&
              expectedUid is! String) {
            await tokenSource.signOut();
          }
          handler.next(retryError);
        } catch (_) {
          handler.next(error);
        }
      },
    ),
  );
  return client;
}

Future<void> _attachTokens(
  RequestOptions options,
  ApiTokenSource tokenSource, {
  String? idToken,
}) async {
  final expectedUid = options.extra['expectedFirebaseUid'];
  if (expectedUid is String && tokenSource.currentUid != expectedUid) {
    throw StateError('The signed-in account changed before the request.');
  }
  final currentIdToken = idToken ?? await tokenSource.idToken();
  if (expectedUid is String && tokenSource.currentUid != expectedUid) {
    throw StateError('The signed-in account changed before the request.');
  }
  final appCheckToken = await tokenSource.appCheckToken();
  if (expectedUid is String && tokenSource.currentUid != expectedUid) {
    throw StateError('The signed-in account changed before the request.');
  }
  if (currentIdToken == null ||
      currentIdToken.isEmpty ||
      appCheckToken == null ||
      appCheckToken.isEmpty) {
    throw StateError('Firebase authentication or App Check is unavailable.');
  }
  options
    ..headers['Authorization'] = '$_authorizationScheme $currentIdToken'
    ..headers['X-Firebase-AppCheck'] = appCheckToken;
}
