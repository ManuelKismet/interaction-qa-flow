final _values = <String, String>{};
String? readNiaHintPreference(String key) => _values[key];
void writeNiaHintPreference(String key, String value) => _values[key] = value;
