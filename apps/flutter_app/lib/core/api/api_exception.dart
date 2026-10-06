import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return const ApiException(
        'The request was not authorized. Check your sign-in and application verification, then retry.',
      );
    }
    if (statusCode == 403) {
      return const ApiException('You do not have permission to do that.');
    }
    if (statusCode == 404) {
      return const ApiException('That item could not be found.');
    }
    if (statusCode == 409) {
      return const ApiException(
        'This content changed or is unavailable. Refresh and review it before trying again.',
      );
    }
    if (statusCode == 408) {
      return const ApiException(
        'The request timed out. Refresh status before trying again.',
      );
    }
    if (statusCode == 429) {
      return const ApiException(
        'Request limit reached. Wait before trying again.',
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return const ApiException(
        'IntQAFlow is temporarily unavailable. Refresh status before trying again.',
      );
    }
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return const ApiException('Please check the information and try again.');
    }
    if ({
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    }.contains(error.type)) {
      return const ApiException(
        'The request timed out. Refresh status before trying again.',
      );
    }
    return const ApiException(
      'Unable to reach IntQAFlow. Check your connection and refresh status before trying again.',
    );
  }

  @override
  String toString() => message;
}