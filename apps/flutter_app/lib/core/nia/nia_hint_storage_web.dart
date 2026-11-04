import 'package:web/web.dart' as web;

String? readNiaHintPreference(String key) =>
    web.window.localStorage.getItem(key);
void writeNiaHintPreference(String key, String value) =>
    web.window.localStorage.setItem(key, value);
