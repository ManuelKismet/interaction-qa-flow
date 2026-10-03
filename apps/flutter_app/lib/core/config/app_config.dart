import 'package:firebase_core/firebase_core.dart';

abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'intqaflow-dev.firebaseapp.com',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'intqaflow-dev',
  );
  static const firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:398672910103:web:e968506023d8eab9290952',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '398672910103',
  );
  static const recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_ENTERPRISE_SITE_KEY',
  );

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: firebaseApiKey,
        authDomain: firebaseAuthDomain,
        projectId: firebaseProjectId,
        appId: firebaseAppId,
        messagingSenderId: firebaseMessagingSenderId,
      );

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty && recaptchaSiteKey.isNotEmpty;
}