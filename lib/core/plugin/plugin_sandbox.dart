import '../model/standard_event.dart';

abstract interface class PluginHostApi {
  Future<String> fetch(String url, {Map<String, String>? headers});
}

abstract interface class RuleSandbox {
  Future<List<StandardEvent>> run(
    String rule, {
    required String source,
    required PluginHostApi host,
  });
}
