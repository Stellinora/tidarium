import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'ai_settings.dart';

/// 文本与视觉两条能力，供导入流水线使用。实现可替换。
abstract interface class LlmClient {
  Future<Map<String, Object?>> completeText({
    required AiSettings settings,
    required String? apiKey,
    required String prompt,
    Map<String, Object?>? schema,
  });

  Future<String> completeVision({
    required AiSettings settings,
    required String? apiKey,
    required Uint8List image,
    required String mimeType,
    required String prompt,
  });
}

class LlmException implements Exception {
  LlmException(this.message, {this.retryableImageFormat = false});

  final String message;

  /// 400 且与图片负载格式有关时置为 true，调用方会换一种图片编码重试。
  final bool retryableImageFormat;

  @override
  String toString() => message;
}

class OpenAiCompatLlmClient implements LlmClient {
  OpenAiCompatLlmClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
            ),
          );

  final Dio _dio;

  @override
  Future<Map<String, Object?>> completeText({
    required AiSettings settings,
    required String? apiKey,
    required String prompt,
    Map<String, Object?>? schema,
  }) async {
    final content = await _chat(
      settings: settings,
      apiKey: apiKey,
      model: settings.textModel,
      messages: [
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      jsonMode: schema != null,
    );
    return _decodeJsonObject(content);
  }

  @override
  Future<String> completeVision({
    required AiSettings settings,
    required String? apiKey,
    required Uint8List image,
    required String mimeType,
    required String prompt,
  }) async {
    final encoded = base64Encode(image);
    // 不同厂商对 image_url 的约定不同：大多数接受 data URL，少数只收裸 base64。
    // 先用 data URL，被 400 拒绝时自动换裸 base64 重试一次。
    final variants = ['data:$mimeType;base64,$encoded', encoded];
    LlmException? lastError;

    for (final url in variants) {
      try {
        return await _chat(
          settings: settings,
          apiKey: apiKey,
          model: settings.visionModel,
          messages: [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': url},
                },
              ],
            },
          ],
          isVision: true,
        );
      } on LlmException catch (error) {
        lastError = error;
        if (error.retryableImageFormat) continue;
        rethrow;
      }
    }
    throw lastError ?? LlmException('图片识别失败');
  }


  Future<String> _chat({
    required AiSettings settings,
    required String? apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    bool jsonMode = false,
    bool isVision = false,
  }) async {
    if (settings.normalizedBaseUrl.isEmpty) {
      throw LlmException('未配置 Base URL');
    }
    if (model.trim().isEmpty) {
      throw LlmException('未配置模型');
    }

    final response = await _dio.post<dynamic>(
      '${settings.normalizedBaseUrl}/chat/completions',
      options: Options(
        headers: {
          if (apiKey != null && apiKey.isNotEmpty)
            'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': model,
        'messages': messages,
        'temperature': 0.1,
        if (jsonMode) 'response_format': {'type': 'json_object'},
      },
    );

    final code = response.statusCode;
    final detail = _providerMessage(response.data);
    if (code != 200) {
      debugPrint(
        'ai: model=$model url=${settings.normalizedBaseUrl} '
        'status=$code detail=${detail ?? ''}',
      );
    }
    final suffix = detail == null ? '' : '：$detail';
    if (code == 401 || code == 403) {
      throw LlmException('Key 无效或无权限$suffix');
    }
    if (code == 429) {
      throw LlmException('调用过于频繁，请稍后再试$suffix');
    }
    if (code == 400 && isVision) {
      throw LlmException(
        '图片格式被拒绝（HTTP 400）$suffix',
        retryableImageFormat: true,
      );
    }
    if (code == 404) {
      throw LlmException('接口或模型不存在（HTTP 404）$suffix');
    }
    if (code != 200) {
      throw LlmException('模型请求失败（HTTP $code）$suffix');
    }

    final data = response.data;
    if (data is Map && data['choices'] is List) {
      final choices = data['choices'] as List;
      if (choices.isNotEmpty) {
        final message = (choices.first as Map)['message'];
        if (message is Map) {
          final content = message['content'];
          if (content is String) return content;
          if (content is List) {
            return content
                .whereType<Map>()
                .map((part) => part['text'])
                .whereType<String>()
                .join();
          }
        }
      }
    }
    throw LlmException('模型返回格式不符合预期');
  }

  String? _providerMessage(dynamic data) {
    try {
      if (data is Map) {
        final error = data['error'];
        if (error is Map) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return _truncate(message.trim());
          }
          final code = error['code'];
          if (code is String && code.trim().isNotEmpty) {
            return _truncate(code.trim());
          }
        }
        if (error is String && error.trim().isNotEmpty) {
          return _truncate(error.trim());
        }
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return _truncate(message.trim());
        }
      } else if (data is String && data.trim().isNotEmpty) {
        return _truncate(data.trim());
      }
    } catch (_) {
      // 错误体不可解析时忽略。
    }
    return null;
  }

  String _truncate(String value) {
    const limit = 160;
    final singleLine = value.replaceAll(RegExp(r'\\s+'), ' ');
    return singleLine.length <= limit
        ? singleLine
        : '${singleLine.substring(0, limit)}…';
  }

  Map<String, Object?> _decodeJsonObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw LlmException('模型没有返回 JSON');
    }
    final candidate = text.substring(start, end + 1);
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, Object?>) return decoded;
      if (decoded is Map) return decoded.cast<String, Object?>();
      throw LlmException('模型返回的 JSON 不是对象');
    } on FormatException {
      throw LlmException('模型返回的 JSON 无法解析');
    }
  }
}




