import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:int_qa_flow/app.dart';
import 'package:int_qa_flow/core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  if (AppConfig.isFirebaseConfigured) {
    try {
      await Firebase.initializeApp(options: AppConfig.firebaseOptions);
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(AppConfig.recaptchaSiteKey),
      );
      firebaseReady = true;
    } catch (_) {
      firebaseReady = false;
    }
  }
  runApp(
    ProviderScope(
      child: IntQaFlowApp(firebaseReady: firebaseReady),
    ),
  );
}
