import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'provider_preset.dart';

/// OCR 通路：默认直接用多模态模型读图，也允许接独立 OCR 服务。
enum OcrMode {
  visionModel,
  external,
  auto;

  String get label {
    return switch (this) {
      OcrMode.visionModel => '多模态直读',
      OcrMode.external => '独立 OCR 服务',
      OcrMode.auto => '自动（先 OCR，失败回退）',
    };
  }

  static OcrMode parse(String? raw) {
    for (final value in OcrMode.values) {
      if (value.name == raw) return value;
    }
    return OcrMode.visionModel;
  }
}

class AiSettings {
  const AiSettings({
    this.presetId = 'deepseek',
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.textModel = '',
    this.visionModel = '',
    this.ocrMode = OcrMode.visionModel,
    this.externalOcrUrl = '',
  });

  factory AiSettings.fromJson(Map<String, Object?> json) {
    return AiSettings(
      presetId: json['presetId']?.toString() ?? 'deepseek',
      baseUrl: json['baseUrl']?.toString() ?? '',
      textModel: json['textModel']?.toString() ?? '',
      visionModel: json['visionModel']?.toString() ?? '',
      ocrMode: OcrMode.parse(json['ocrMode']?.toString()),
      externalOcrUrl: json['externalOcrUrl']?.toString() ?? '',
    );
  }

  final String presetId;
  final String baseUrl;
  final String textModel;
  final String visionModel;
  final OcrMode ocrMode;
  final String externalOcrUrl;

  ProviderPreset get preset => ProviderPreset.byId(presetId);

  String get normalizedBaseUrl => normalizeBaseUrl(baseUrl);

  bool get hasTextModel => textModel.trim().isNotEmpty;
  bool get hasVisionModel => visionModel.trim().isNotEmpty;

  bool get isReadyForText => normalizedBaseUrl.isNotEmpty && hasTextModel;
  bool get isReadyForVision => normalizedBaseUrl.isNotEmpty && hasVisionModel;

  AiSettings copyWith({
    String? presetId,
    String? baseUrl,
    String? textModel,
    String? visionModel,
    OcrMode? ocrMode,
    String? externalOcrUrl,
  }) {
    return AiSettings(
      presetId: presetId ?? this.presetId,
      baseUrl: baseUrl ?? this.baseUrl,
      textModel: textModel ?? this.textModel,
      visionModel: visionModel ?? this.visionModel,
      ocrMode: ocrMode ?? this.ocrMode,
      externalOcrUrl: externalOcrUrl ?? this.externalOcrUrl,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'presetId': presetId,
      'baseUrl': baseUrl,
      'textModel': textModel,
      'visionModel': visionModel,
      'ocrMode': ocrMode.name,
      'externalOcrUrl': externalOcrUrl,
    };
  }
}

/// 非敏感配置写本地 JSON，Key 单独进系统安全存储。
class AiSettingsRepository {
  AiSettingsRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'tidarium.ai.api_key';
  static const _fileName = 'ai_settings.json';

  final FlutterSecureStorage _storage;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<AiSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AiSettings();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const AiSettings();
      final json = jsonDecode(raw);
      if (json is Map<String, Object?>) return AiSettings.fromJson(json);
      if (json is Map) return AiSettings.fromJson(json.cast<String, Object?>());
      return const AiSettings();
    } catch (_) {
      return const AiSettings();
    }
  }

  Future<void> save(AiSettings settings) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(settings.toJson()), flush: false);
  }

  Future<String?> readApiKey() async {
    try {
      final value = await _storage.read(key: _keyName);
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await clearApiKey();
      return;
    }
    await _storage.write(key: _keyName, value: trimmed);
  }

  Future<void> clearApiKey() async {
    try {
      await _storage.delete(key: _keyName);
    } catch (_) {
      // 忽略：安全存储不可用时不影响使用。
    }
  }

  /// 只显示尾号，避免把完整 Key 回填到界面。
  static String maskKey(String? key) {
    if (key == null || key.isEmpty) return '未设置';
    if (key.length <= 8) return '****';
    return '••••••${key.substring(key.length - 4)}';
  }
}
