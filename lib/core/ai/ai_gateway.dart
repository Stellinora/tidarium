enum AiRoute { local, cloud, auto }

enum AiProvider { anthropic, deepseek, openAiCompatible }

class AiRequest {
  const AiRequest({
    required this.prompt,
    this.schema = const {},
    this.route = AiRoute.auto,
    this.provider,
  });

  final String prompt;
  final Map<String, Object?> schema;
  final AiRoute route;
  final AiProvider? provider;
}

abstract interface class AiGateway {
  Future<Map<String, Object?>> complete(AiRequest request);
}

class AiQuota {
  AiQuota({this.maxCallsPerRun = 20, this.maxCallsPerMinute = 5});

  final int maxCallsPerRun;
  final int maxCallsPerMinute;

  int _callsThisRun = 0;
  final List<DateTime> _recentCalls = [];

  bool tryAcquire({DateTime? now}) {
    final moment = now ?? DateTime.now();
    _recentCalls.removeWhere(
      (call) => moment.difference(call) >= const Duration(minutes: 1),
    );

    if (_callsThisRun >= maxCallsPerRun ||
        _recentCalls.length >= maxCallsPerMinute) {
      return false;
    }

    _callsThisRun += 1;
    _recentCalls.add(moment);
    return true;
  }

  void reset() {
    _callsThisRun = 0;
    _recentCalls.clear();
  }
}
