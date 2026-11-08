import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/import/data/adapter_repository.dart';
import 'package:tidarium/features/timetable/import/data/wakeup_school_repository.dart';
import 'package:tidarium/features/timetable/import/import_providers.dart';
import 'package:tidarium/features/timetable/import/models/school_models.dart';
import 'package:tidarium/features/timetable/import/models/wakeup_school.dart';
import 'package:tidarium/features/timetable/import/unified_school_selection_page.dart';
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
        id: 'TESTU',
        name: '测试大学',
        initial: 'C',
        resourceFolder: 'TESTU',
      ),
    ];
  }
}

class _FakeWakeUpRepository extends WakeUpSchoolRepository {
  @override
  Future<List<WakeUpSchool>> loadSchools() async {
    return [
      WakeUpSchool(
        name: '测试大学',
        initial: 'C',
        type: 'zf',
        url: Uri.parse('https://jw.example.edu.cn/'),
        family: WakeUpFamily.zhengfang,
      ),
      WakeUpSchool(
        name: '另一大学',
        initial: 'L',
        type: 'kingo_new',
        url: Uri.parse('https://other.example.edu.cn/'),
        family: null,
      ),
    ];
  }
}

Widget _app() {
  return ProviderScope(
    overrides: [
      adapterRepositoryProvider.overrideWithValue(_FakeAdapterRepository()),
      wakeUpSchoolRepositoryProvider.overrideWithValue(
        _FakeWakeUpRepository(),
      ),
    ],
    child: MaterialApp(
      theme: buildTidariumTheme(Brightness.light),
      home: const UnifiedSchoolSelectionPage(),
    ),
  );
}

void main() {
  testWidgets('merges school sources without source labels', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('搜索学校'), findsOneWidget);
    expect(find.text('测试大学'), findsOneWidget);
    expect(find.text('另一大学'), findsOneWidget);
    expect(find.textContaining('拾光'), findsNothing);
    expect(find.textContaining('WakeUp'), findsNothing);
    expect(find.text('正方教务-通用教务'), findsNothing);
    expect(find.text('可导入'), findsOneWidget);
    expect(find.text('暂不支持'), findsOneWidget);
  });

  testWidgets('filters the unified list', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '另一');
    await tester.pumpAndSettle();

    expect(find.text('另一大学'), findsOneWidget);
    expect(find.text('测试大学'), findsNothing);
  });
}
