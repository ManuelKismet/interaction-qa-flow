import 'package:flutter_test/flutter_test.dart';
import 'package:int_qa_flow/core/routing/session_deep_link.dart';
void main(){test('preserves the hosted hash session URL',(){expect(sessionDeepLinkInitialLocation(Uri.parse('https://intqaflow-dev.web.app/guided#/guided/sessions/session-123')),'/guided/sessions/session-123');});}
