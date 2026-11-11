/// 预设的 OpenAI 兼容服务商。模型名不写死，由用户在设置页填写或从 /models 拉取。
class ProviderPreset {
  const ProviderPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    this.supportsModelList = true,
    this.note = '',
  });

  final String id;
  final String label;
  final String baseUrl;
  final bool supportsModelList;
  final String note;

  static const openAi = ProviderPreset(
    id: 'openai',
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
  );

  static const deepSeek = ProviderPreset(
    id: 'deepseek',
    label: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
  );

  static const zhipu = ProviderPreset(
    id: 'zhipu',
    label: '智谱 GLM',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    supportsModelList: false,
    note: '智谱的 /models 支持不完整，模型名建议手动填写',
  );

  static const custom = ProviderPreset(
    id: 'custom',
    label: '自定义（OpenAI 兼容）',
    baseUrl: '',
    note: '支持 vLLM、Ollama、OneAPI 等兼容端点',
  );

  static const values = [openAi, deepSeek, zhipu, custom];

  static ProviderPreset byId(String? id) {
    for (final preset in values) {
      if (preset.id == id) return preset;
    }
    return custom;
  }
}

/// 补全并清理 Base URL：
/// - 去掉尾部斜杠
/// - 已带版本段（/v1、/v4 等）原样保留
/// - 否则补 /v1
String normalizeBaseUrl(String input) {
  var url = input.trim();
  if (url.isEmpty) return url;
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  final hasVersion = RegExp(r'/v\d+($|/)').hasMatch(url);
  if (!hasVersion) url = '$url/v1';
  return url;
}
