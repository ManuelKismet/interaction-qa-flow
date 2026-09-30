import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 403) {
      return const ApiException('You do not have permission to do that.');
    }
    if (statusCode == 404) {
      return const ApiException('That item could not be found.');
    }
    if (statusCode == 409) {
      return const ApiException('That action is not available right now.');
    }
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return const ApiException('Please check the information and try again.');
    }
    return const ApiException('Unable to reach IntQAFlow. Please try again.');
  }

  @override
  String toString() => message;
}