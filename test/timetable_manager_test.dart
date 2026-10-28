import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/data/timetable_store.dart';
import 'package:tidarium/features/timetable/model/timetable_config.dart';
import 'package:tidarium/features/timetable/model/timetable_data.dart';
import 'package:tidarium/features/timetable/model/timetable_library.dart';
import 'package:tidarium/features/timetable/timetable_manager_page.dart';
import 'package:tidarium/features/timetable/timetable_providers.dart';
import 'package:tidarium/ui/theme.dart';

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(timetableProvider).config.name;
    return Scaffold(
      body: Column(
        children: [
          Text('当前：$name'),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TimetableManagerPage(),
              ),
            ),
            child: const Text('打开课表管理'),
          ),
        ],
      ),
    );
  }
}

TimetableData _table(String id, String name) {
  return TimetableData(
    id: id,
    config: TimetableConfig(name: name),
    timeSlots: defaultTimeSlots,
    courses: const [],
  );
}

Widget _app() {
  return ProviderScope(
    overrides: [
      initialTimetableLibraryProvider.overrideWithValue(
        TimetableLibrary(
          activeId: 'first',
          timetables: [_table('first', '第一课表'), _table('second', '第二课表')],
        ),
      ),
      timetableStoreProvider.overrideWithValue(InMemoryTimetableStore()),
    ],
    child: MaterialApp(
      theme: buildTidariumTheme(Brightness.light),
      home: const _Host(),
    ),
  );
}

void main() {
  testWidgets('lists and switches timetables', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('当前：第一课表'), findsOneWidget);

    await tester.tap(find.text('打开课表管理'));
    await tester.pumpAndSettle();

    expect(find.text('课表管理'), findsOneWidget);
    expect(find.text('第一课表'), findsOneWidget);
    expect(find.text('第二课表'), findsOneWidget);

    await tester.tap(find.text('第二课表'));
    await tester.pumpAndSettle();

    expect(find.text('当前：第二课表'), findsOneWidget);
  });
}
