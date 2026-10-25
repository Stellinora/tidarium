import '../plugin/plugin.dart';

class SyncReport {
  const SyncReport({required this.source, required this.fetched, this.error});

  final String source;
  final int fetched;
  final String? error;
}

class SyncScheduler {
  const SyncScheduler({this.maxConcurrency = 3});

  final int maxConcurrency;

  Future<List<SyncReport>> sync(Iterable<DataSourcePlugin> plugins) async {
    final pending = plugins.toList(growable: false);
    final reports = <SyncReport>[];

    for (var index = 0; index < pending.length; index += maxConcurrency) {
      final batch = pending.skip(index).take(maxConcurrency);
      reports.addAll(await Future.wait(batch.map(_syncPlugin)));
    }

    return reports;
  }

  Future<SyncReport> _syncPlugin(DataSourcePlugin plugin) async {
    try {
      final events = await plugin.fetchEvents();
      return SyncReport(source: plugin.manifest.id, fetched: events.length);
    } catch (error) {
      return SyncReport(
        source: plugin.manifest.id,
        fetched: 0,
        error: error.toString(),
      );
    }
  }
}
