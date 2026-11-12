import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/ai/ai_settings.dart';
import 'package:tidarium/features/import/import_confirm_page.dart';
import 'package:tidarium/features/intake/image_intake.dart';
import 'package:tidarium/ui/theme.dart';

class _EmptySettingsRepository extends AiSettingsRepository {
  @override
  Future<AiSettings> load() async => const AiSettings();

  @override
  Future<String?> readApiKey() async => null;
}

ImageIntake _image() {
  return ImageIntake(
    origin: ImageOrigin.systemShare,
    bytes: Uint8List.fromList(const [1, 2, 3]),
    mimeType: 'image/png',
    receivedAt: DateTime(2026, 11, 11),
  );
}

void main() {
  testWidgets('未配置视觉模型时给出设置入口', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTidariumTheme(Brightness.light),
          home: ImportConfirmPage(
            images: [_image()],
            settingsRepository: _EmptySettingsRepository(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('还没有配置视觉模型'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);
  });

  testWidgets('320dp 窄屏不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTidariumTheme(Brightness.light),
          home: ImportConfirmPage(
            images: [_image()],
            settingsRepository: _EmptySettingsRepository(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('去设置'), findsOneWidget);
  });
}
