import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/ai/ai_settings.dart';
import 'package:tidarium/core/ai/provider_preset.dart';

void main() {
  group('normalizeBaseUrl', () {
    test('裸域名补 /v1', () {
      expect(normalizeBaseUrl('https://api.example.com'), 'https://api.example.com/v1');
    });

    test('去掉尾部斜杠', () {
      expect(
        normalizeBaseUrl('https://api.example.com/v1/'),
        'https://api.example.com/v1',
      );
    });

    test('已带版本段时保持原样', () {
      expect(
        normalizeBaseUrl('https://open.bigmodel.cn/api/paas/v4'),
        'https://open.bigmodel.cn/api/paas/v4',
      );
    });

    test('空串保持为空', () {
      expect(normalizeBaseUrl('   '), '');
    });
  });

  test('预设按 id 回退到自定义', () {
    expect(ProviderPreset.byId('deepseek').label, 'DeepSeek');
    expect(ProviderPreset.byId('unknown').id, 'custom');
    expect(ProviderPreset.byId(null).id, 'custom');
  });

  test('设置序列化往返', () {
    const settings = AiSettings(
      presetId: 'zhipu',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      textModel: 'glm-4-flash',
      visionModel: 'glm-4v',
      ocrMode: OcrMode.auto,
      externalOcrUrl: 'https://ocr.example.com',
    );

    final restored = AiSettings.fromJson(settings.toJson());
    expect(restored.presetId, 'zhipu');
    expect(restored.textModel, 'glm-4-flash');
    expect(restored.visionModel, 'glm-4v');
    expect(restored.ocrMode, OcrMode.auto);
    expect(restored.externalOcrUrl, 'https://ocr.example.com');
  });

  test('OCR 模式解析未知值回落到直读', () {
    expect(OcrMode.parse('external'), OcrMode.external);
    expect(OcrMode.parse('nope'), OcrMode.visionModel);
  });

  test('Key 只显示尾号', () {
    expect(AiSettingsRepository.maskKey(null), '未设置');
    expect(AiSettingsRepository.maskKey('short'), '****');
    expect(AiSettingsRepository.maskKey('sk-1234567890abcd'), '••••••abcd');
  });
}
