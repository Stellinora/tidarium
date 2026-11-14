
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'ai_settings.dart';
import 'llm_client.dart';
import 'local_ocr.dart';
import 'image_prep.dart';

enum ProbeStatus { idle, running, success, failure, skipped }

class ProbeResult {
  const ProbeResult({
    required this.status,
    required this.message,
    this.latencyMs,
  });

  const ProbeResult.idle() : this(status: ProbeStatus.idle, message: '未测试');

  const ProbeResult.success(String message, {int? latencyMs})
    : this(status: ProbeStatus.success, message: message, latencyMs: latencyMs);

  const ProbeResult.failure(String message)
    : this(status: ProbeStatus.failure, message: message);

  const ProbeResult.skipped(String message)
    : this(status: ProbeStatus.skipped, message: message);

  final ProbeStatus status;
  final String message;
  final int? latencyMs;

  bool get isSuccess => status == ProbeStatus.success;
}

/// 设置页的三个能力检测。所有异常都转成可读文案，不抛给界面。
class AiProbes {
  AiProbes({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 20),
              validateStatus: (_) => true,
            ),
          );

  static const ocrSampleAsset = 'assets/diagnostics/ocr_sample.jpg';
  static const visionSampleAsset = 'assets/diagnostics/vision_sample.jpg';

  final Dio _dio;

  late final LlmClient _llm = OpenAiCompatLlmClient();

  Future<ProbeResult> connectivity(AiSettings settings, String? apiKey) async {
    if (settings.normalizedBaseUrl.isEmpty) {
      return const ProbeResult.failure('未填写 Base URL');
    }
    if (!settings.hasTextModel) {
      return const ProbeResult.failure('未填写文本模型');
    }

    final started = DateTime.now();
    try {
      final models = await _dio.get<dynamic>(
        '${settings.normalizedBaseUrl}/models',
        options: _headers(apiKey),
      );
      if (models.statusCode == 200) {
        return ProbeResult.success(
          '连接正常',
          latencyMs: DateTime.now().difference(started).inMilliseconds,
        );
      }
      if (models.statusCode == 401 || models.statusCode == 403) {
        return const ProbeResult.failure('Key 无效或无权限');
      }
      // 不支持 /models 的服务退化成一次最小对话。
      return await _ping(settings, apiKey, started);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404 ||
          error.response?.statusCode == 405) {
        return _ping(settings, apiKey, started);
      }
      return _mapError(error);
    } catch (_) {
      return const ProbeResult.failure('请求失败');
    }
  }

  Future<ProbeResult> ocr(AiSettings settings, String? apiKey) async {
    final bytes = await _loadAsset(ocrSampleAsset);
    if (bytes == null) {
      return const ProbeResult.skipped('未放置样例图 assets/diagnostics/ocr_sample.jpg');
    }
    final started = DateTime.now();
    final prepared = ImagePrep.shrink(bytes) ?? bytes;

    if (!settings.isReadyForVision) {
      if (!LocalOcrEngine.isSupported) {
        return const ProbeResult.failure('未配置视觉模型，本地 OCR 也不可用');
      }
      final local = await const LocalOcrEngine().recognize(prepared);
      if (local == null || local.trim().isEmpty) {
        return const ProbeResult.failure('本地 OCR 没有识别出文字');
      }
      return ProbeResult.success(
        '本地 OCR：${local.trim().replaceAll('\n', ' ')}',
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      );
    }

    try {
      final mime = ImagePrep.mimeOf(prepared);
      final text = await _llm.completeVision(
        settings: settings,
        apiKey: apiKey,
        image: prepared,
        mimeType: mime,
        prompt: '只输出图片中的文字，不要解释，不要加标点以外的内容。',
      );
      if (text.trim().isEmpty) {
        return const ProbeResult.failure('OCR 未返回文本');
      }
      return ProbeResult.success(
        '识别成功：${text.trim().replaceAll('\n', ' ')}',
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      );
    } on LlmException catch (error) {
      return ProbeResult.failure(error.message);
    } catch (_) {
      return const ProbeResult.failure('OCR 请求失败');
    }
  }

  Future<ProbeResult> vision(AiSettings settings, String? apiKey) async {
    final bytes = await _loadAsset(visionSampleAsset);
    if (bytes == null) {
      return const ProbeResult.skipped(
        '未放置样例图 assets/diagnostics/vision_sample.jpg',
      );
    }
    if (!settings.isReadyForVision) {
      return const ProbeResult.failure('未配置视觉模型');
    }

    final started = DateTime.now();
    try {
      final prepared = ImagePrep.shrink(bytes) ?? bytes;
      final mime = ImagePrep.mimeOf(prepared);
      final text = await _llm.completeVision(
        settings: settings,
        apiKey: apiKey,
        image: prepared,
        mimeType: mime,
        prompt: '用一句话描述这张图片里发生了什么，不超过 30 字。',
      );
      final trimmed = text.trim();
      if (trimmed.length < 4) {
        return const ProbeResult.failure('模型没有识别出图片内容');
      }
      return ProbeResult.success(
        '识别成功：$trimmed',
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      );
    } on LlmException catch (error) {
      return ProbeResult.failure(error.message);
    } catch (_) {
      return const ProbeResult.failure('多模态请求失败');
    }
  }

  Options _headers(String? apiKey) {
    return Options(
      headers: {
        if (apiKey != null && apiKey.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    );
  }

  Future<ProbeResult> _ping(
    AiSettings settings,
    String? apiKey,
    DateTime started,
  ) async {
    final response = await _dio.post<dynamic>(
      '${settings.normalizedBaseUrl}/chat/completions',
      options: _headers(apiKey),
      data: {
        'model': settings.extractionModel,
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
        'max_tokens': 1,
      },
    );
    if (response.statusCode == 200) {
      return ProbeResult.success(
        '连接正常（兼容模式）',
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const ProbeResult.failure('Key 无效或无权限');
    }
    return ProbeResult.failure('请求失败（HTTP ${response.statusCode}）');
  }

  ProbeResult _mapError(DioException error) {
    final code = error.response?.statusCode;
    if (code == 401 || code == 403) {
      return const ProbeResult.failure('Key 无效或无权限');
    }
    if (code == 429) {
      return const ProbeResult.failure('调用过于频繁（429）');
    }
    if (code == 404) {
      return const ProbeResult.failure('接口不存在（404），检查 Base URL');
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ProbeResult.failure('连接超时');
      case DioExceptionType.connectionError:
        return const ProbeResult.failure('网络不可用');
      case DioExceptionType.badResponse:
        return ProbeResult.failure('请求失败（HTTP ${code ?? '未知'}）');
      default:
        return const ProbeResult.failure('请求失败');
    }
  }

  Future<Uint8List?> _loadAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}






