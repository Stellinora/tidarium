import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/features/timetable/import/data/adapter_repository.dart';
import 'package:tidarium/features/timetable/import/data/wakeup_school_repository.dart';
import 'package:tidarium/features/timetable/import/import_providers.dart';
import 'package:tidarium/features/timetable/import/models/school_models.dart';
import 'package:tidarium/features/timetable/import/models/wakeup_school.dart';
import 'package:tidarium/features/timetable/import/wakeup_school_selection_page.dart';
import 'package:tidarium/ui/theme.dart';

class _FakeWakeUpSchoolRepository extends WakeUpSchoolRepository {
  @override
  Future<List<WakeUpSchool>> loadSchools() async {
    return [
      WakeUpSchool(
        name: '测试大学',
        initial: 'C',
        type: 'zf',
        url: Uri.parse('https://jw.test.edu.cn/login'),
        family: WakeUpFamily.zhengfang,
      ),
      WakeUpSchool(
        name: '专用大学',
        initial: 'Z',
        type: 'kingo_new',
        url: Uri.parse('https://kingo.example.edu.cn/'),
        family: null,
      ),
    ];
  }
}

class _FakeAdapterRepository extends AdapterRepository {
  @override
  Future<List<SchoolEntry>> loadSchools({bool forceRefresh = false}) async {
    return const [
      SchoolEntry(
        id: 'zhengfang_jiaowu',
        name: '正方教务',
        initial: 'Z',
        resourceFolder: 'zhengfang_jiaowu',
      ),
    ];
  }
}

Widget _app() {
  return ProviderScope(
    overrides: [
      wakeUpSchoolRepositoryProvider.overrideWithValue(
        _FakeWakeUpSchoolRepository(),
      ),
      adapterRepositoryProvider.overrideWithValue(_FakeAdapterRepository()),
    ],
    child: MaterialApp(
      theme: buildTidariumTheme(Brightness.light),
      home: const WakeUpSchoolSelectionPage(),
    ),
  );
}

void main() {
  testWidgets('groups supported and unsupported WakeUp schools', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('可直接导入（1）'), findsOneWidget);
    expect(find.text('其他学校（暂不支持自动解析）'), findsOneWidget);
    expect(find.text('测试大学'), findsOneWidget);
    expect(find.text('专用大学'), findsOneWidget);
    expect(find.text('可导入'), findsOneWidget);
    expect(find.text('暂不支持'), findsOneWidget);
  });

  testWidgets('searches by name and shows the unsupported explanation', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '专用');
    await tester.pumpAndSettle();
    expect(find.text('专用大学'), findsOneWidget);
    expect(find.text('测试大学'), findsNothing);

    await tester.tap(find.text('专用大学'));
    await tester.pumpAndSettle();

    expect(find.text('暂不支持该校'), findsOneWidget);
    expect(find.textContaining('kingo_new'), findsOneWidget);
  });
}
