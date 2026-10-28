import 'dart:convert';

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
import 'package:tidarium/features/timetable/timetable_time.dart';

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
  const _Host();

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
                  builder: (_) => WebImportPage(
                    school: const SchoolEntry(
                      id: 'TEST',
                      name: '测试学校',
                      initial: 'T',
                      resourceFolder: 'TEST',
                    ),
                    adapter: const SchoolAdapter(
                      adapterId: 'TEST_01',
                      adapterName: '测试适配器',
                      category: 'GENERAL_TOOL',
                      assetJsPath: 'test.js',
                      importUrl: '',
                      maintainer: 'Tidarium',
                      description: '集成测试',
                    ),
                  ),
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

  testWidgets('imports a timetable through the WebView bridge', (tester) async {
    final slotsJson = jsonEncode([
      for (final slot in defaultTimeSlots)
        {
          'number': slot.number,
          'startTime': formatMinuteOfDay(slot.startMinutes),
          'endTime': formatMinuteOfDay(slot.endMinutes),
        },
    ]);
    final configJson = jsonEncode({
      'semesterStartDate': '2026-09-02',
      'semesterTotalWeeks': 4,
      'defaultClassDuration': 45,
      'defaultBreakDuration': 10,
      'firstDayOfWeek': 1,
    });
    final coursesJson = jsonEncode([
      {
        'name': '集成测试课程',
        'teacher': '测试老师',
        'position': 'A101',
        'day': 1,
        'startSection': 1,
        'endSection': 2,
        'weeks': [1, 2],
      },
    ]);

    final script =
        '''
      (async function() {
        await window.shiguangBridgePromise.savePresetTimeSlots(${jsonEncode(slotsJson)});
        await window.shiguangBridgePromise.saveCourseConfig(${jsonEncode(configJson)});
        await window.shiguangBridgePromise.saveImportedCourses(${jsonEncode(coursesJson)});
        window.shiguangBridge.notifyTaskCompletion();
      })();
    ''';

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
        child: const MaterialApp(home: _Host()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('count:0'), findsOneWidget);

    await tester.tap(find.text('打开适配器'));
    await tester.pump();
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();

    await tester.tap(find.text('执行导入'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入'));
    await tester.pump();
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('count:1'), findsOneWidget);
  });
}
