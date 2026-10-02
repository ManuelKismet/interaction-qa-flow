import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/app.dart';
import 'package:int_qa_flow/core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isFirebaseConfigured) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Firebase development configuration is incomplete.'),
          ),
        ),
      ),
    );
    return;
  }
  try {
    await Firebase.initializeApp(options: AppConfig.firebaseOptions);
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(AppConfig.recaptchaSiteKey),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Unable to initialize Firebase.')),
        ),
      ),
    );
    return;
  }
  runApp(const ProviderScope(child: IntQaFlowApp()));
}
