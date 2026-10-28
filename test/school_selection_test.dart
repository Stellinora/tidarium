import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/import/data/adapter_repository.dart';
import 'package:tidarium/features/timetable/import/import_providers.dart';
import 'package:tidarium/features/timetable/import/models/school_models.dart';
import 'package:tidarium/features/timetable/import/school_selection_page.dart';
import 'package:tidarium/ui/theme.dart';

class _FakeAdapterRepository extends AdapterRepository {
  @override
  Future<List<SchoolEntry>> loadSchools({bool forceRefresh = false}) async {
    return const [
      SchoolEntry(
        id: 'zhengfang_jiaowu',
        name: '正方教务-通用教务',
        initial: 'Z',
        resourceFolder: 'zhengfang_jiaowu',
      ),
      SchoolEntry(
        id: 'chaoxing_jiaowu',
        name: '超星教务系统-通用教务',
        initial: 'C',
        resourceFolder: 'chaoxing_jiaowu',
      ),
      SchoolEntry(
        id: 'qingguo_jiaowu',
        name: '青果教务-通用教务',
        initial: 'Q',
        resourceFolder: 'qingguo_jiaowu',
      ),
      SchoolEntry(
        id: 'urp_jiaowu',
        name: 'URP教务-通用教务',
        initial: 'U',
        resourceFolder: 'urp_jiaowu',
      ),
      SchoolEntry(
        id: 'GLOBAL_TOOLS',
        name: '通用工具与服务',
        initial: 'T',
        resourceFolder: 'GLOBAL_TOOLS',
      ),
      SchoolEntry(
        id: 'TESTU',
        name: '测试大学',
        initial: 'C',
        resourceFolder: 'TESTU',
      ),
    ];
  }
}

Widget _app() {
  return ProviderScope(
    overrides: [
      adapterRepositoryProvider.overrideWithValue(_FakeAdapterRepository()),
    ],
    child: MaterialApp(
      theme: buildTidariumTheme(Brightness.light),
      home: const SchoolSelectionPage(),
    ),
  );
}

void main() {
  testWidgets('pins generic academic systems and tools', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('通用教务系统'), findsOneWidget);
    expect(find.text('正方教务-通用教务'), findsOneWidget);
    expect(find.text('超星教务系统-通用教务'), findsOneWidget);
    expect(find.text('通用工具'), findsOneWidget);
    expect(find.text('通用工具与服务'), findsOneWidget);
    expect(find.text('全部学校'), findsOneWidget);
  });

  testWidgets('search returns a flat list without section headers', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '测试');
    await tester.pumpAndSettle();

    expect(find.text('测试大学'), findsOneWidget);
    expect(find.text('通用教务系统'), findsNothing);
  });
}
