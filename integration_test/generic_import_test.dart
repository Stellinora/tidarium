import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tidarium/features/timetable/data/timetable_store.dart';
import 'package:tidarium/features/timetable/import/data/adapter_repository.dart';
import 'package:tidarium/features/timetable/import/import_providers.dart';
import 'package:tidarium/features/timetable/import/models/school_models.dart';
import 'package:tidarium/features/timetable/import/web_import_page.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/timetable_providers.dart';

class _FakeAdapterRepository extends AdapterRepository {
  _FakeAdapterRepository(this.script);

  final String script;

  @override
  Future<String> loadAdapterScript(
    SchoolEntry school,
    SchoolAdapter adapter, {
    bool forceRefresh = false,
  }) async {
    return script;
  }
}

class _Host extends ConsumerWidget {
  const _Host({required this.school, required this.adapter});

  final SchoolEntry school;
  final SchoolAdapter adapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(timetableProvider).courses.length;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('count:$count'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      WebImportPage(school: school, adapter: adapter),
                ),
              ),
              child: const Text('打开适配器'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write('''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>课表查询</title>
</head>
<body>
  <p>课表查询</p>
  <table id="kbgrid_table_0"><tbody><tr>
    <td id="1-1" class="td_wrap">
      <div class="timetable_con"><div class="title">高等数学</div></div>
    </td>
    <td id="2-1" class="td_wrap">
      <div class="timetable_con"><div class="title">大学英语</div></div>
    </td>
  </tr></tbody></table>
</body>
</html>
''');
      await request.response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  testWidgets('imports through a manual generic academic URL', (tester) async {
    const script = r'''
      (async function() {
        var courses = [];
        document.querySelectorAll('#kbgrid_table_0 td.td_wrap').forEach(function(cell) {
          var day = parseInt(cell.id.split('-')[0], 10);
          var title = cell.querySelector('.timetable_con .title');
          if (!title) return;
          courses.push({
            name: title.textContent.trim(),
            teacher: '测试老师',
            position: 'A101',
            day: day,
            startSection: 1,
            endSection: 2,
            weeks: [1, 2]
          });
        });
        await window.shiguangBridgePromise.saveImportedCourses(JSON.stringify(courses));
        window.shiguangBridge.notifyTaskCompletion();
      })();
    ''';

    const school = SchoolEntry(
      id: 'GENERIC',
      name: '通用教务测试',
      initial: 'T',
      resourceFolder: 'GENERIC',
    );
    const adapter = SchoolAdapter(
      adapterId: 'GENERIC_01',
      adapterName: '通用教务测试适配器',
      category: 'GENERAL_TOOL',
      assetJsPath: 'generic.js',
      importUrl: '',
      maintainer: 'Tidarium',
      description: '集成测试',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialTimetableProvider.overrideWithValue(
            TimetableData.initial(now: DateTime(2026, 9, 2)),
          ),
          timetableStoreProvider.overrideWithValue(InMemoryTimetableStore()),
          adapterRepositoryProvider.overrideWithValue(
            _FakeAdapterRepository(script),
          ),
        ],
        child: const MaterialApp(
          home: _Host(school: school, adapter: adapter),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('count:0'), findsOneWidget);

    await tester.tap(find.text('打开适配器'));
    for (var index = 0; index < 40; index++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('输入网址'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'http://127.0.0.1:${server.port}/',
    );
    await tester.tap(find.text('打开'));
    for (var index = 0; index < 40; index++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('执行导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入'));

    for (var index = 0; index < 50; index++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.text('count:2').evaluate().isNotEmpty) break;
    }

    expect(find.text('count:2'), findsOneWidget);
  });
}
