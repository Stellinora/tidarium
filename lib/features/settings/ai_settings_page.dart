import 'package:flutter/material.dart';

import '../../core/ai/ai_settings.dart';
import '../../core/ai/probes.dart';
import '../../core/ai/provider_preset.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key, this.repository});

  final AiSettingsRepository? repository;

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final AiSettingsRepository _repo =
      widget.repository ?? AiSettingsRepository();
  late final AiProbes _probes = AiProbes();

  final _baseUrlController = TextEditingController();
  final _keyController = TextEditingController();
  final _textModelController = TextEditingController();
  final _visionModelController = TextEditingController();

  AiSettings _settings = const AiSettings();
  String? _existingKeyMasked;
  bool _keyEdited = false;
  bool _loading = true;
  bool _saving = false;
  String? _baseUrlError;
  String? _savedHint;

  ProbeResult _connectivity = const ProbeResult.idle();
  ProbeResult _ocr = const ProbeResult.idle();
  ProbeResult _vision = const ProbeResult.idle();
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repo.load();
    final key = await _repo.readApiKey();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _baseUrlController.text = settings.baseUrl;
      _textModelController.text = settings.textModel;
      _visionModelController.text = settings.visionModel;
      _existingKeyMasked = key == null
          ? null
          : AiSettingsRepository.maskKey(key);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _keyController.dispose();
    _textModelController.dispose();
    _visionModelController.dispose();
    super.dispose();
  }

  void _selectPreset(String? id) {
    if (id == null) return;
    final preset = ProviderPreset.byId(id);
    setState(() {
      _settings = _settings.copyWith(presetId: preset.id);
      if (preset.baseUrl.isNotEmpty) {
        _baseUrlController.text = preset.baseUrl;
      }
      _baseUrlError = null;
      _savedHint = null;
    });
  }

  Future<AiSettings?> _collect() async {
    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      setState(() => _baseUrlError = '请填写 Base URL');
      return null;
    }
    setState(() => _baseUrlError = null);
    return _settings.copyWith(
      baseUrl: baseUrl,
      textModel: _textModelController.text.trim(),
      visionModel: _visionModelController.text.trim(),
    );
  }

  Future<void> _save() async {
    final settings = await _collect();
    if (settings == null) return;

    setState(() {
      _saving = true;
      _savedHint = null;
    });
    await _repo.save(settings);
    if (_keyEdited) {
      await _repo.saveApiKey(_keyController.text);
    }
    final key = await _repo.readApiKey();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _saving = false;
      _keyEdited = false;
      _keyController.clear();
      _existingKeyMasked = key == null
          ? null
          : AiSettingsRepository.maskKey(key);
      _savedHint = '已保存';
    });
  }

  Future<void> _runConnectivity() async {
    final settings = await _collect();
    if (settings == null) return;
    final key = await _repo.readApiKey();
    setState(() {
      _testing = true;
      _connectivity = const ProbeResult(
        status: ProbeStatus.running,
        message: '测试中…',
      );
    });
    final result = await _probes.connectivity(settings, key);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _connectivity = result;
    });
  }

  Future<void> _runOcr() async {
    final settings = await _collect();
    if (settings == null) return;
    final key = await _repo.readApiKey();
    setState(() {
      _testing = true;
      _ocr = const ProbeResult(status: ProbeStatus.running, message: '测试中…');
    });
    final result = await _probes.ocr(settings, key);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ocr = result;
    });
  }

  Future<void> _runVision() async {
    final settings = await _collect();
    if (settings == null) return;
    final key = await _repo.readApiKey();
    setState(() {
      _testing = true;
      _vision = const ProbeResult(
        status: ProbeStatus.running,
        message: '测试中…',
      );
    });
    final result = await _probes.vision(settings, key);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _vision = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI 服务')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI 服务')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('服务商', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _settings.presetId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final preset in ProviderPreset.values)
                DropdownMenuItem(value: preset.id, child: Text(preset.label)),
            ],
            onChanged: _selectPreset,
          ),
          if (_settings.preset.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _settings.preset.note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            decoration: InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.deepseek.com/v1',
              errorText: _baseUrlError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_baseUrlError != null) {
                setState(() => _baseUrlError = null);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            '实际请求地址：${normalizeBaseUrl(_baseUrlController.text)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: _existingKeyMasked == null
                  ? '未设置'
                  : '当前：$_existingKeyMasked（留空则不修改）',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _keyEdited = true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textModelController,
            decoration: const InputDecoration(
              labelText: '文本模型',
              hintText: '例如 deepseek-chat',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _visionModelController,
            decoration: const InputDecoration(
              labelText: '视觉模型',
              hintText: '例如 glm-4v',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('OCR 通路', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          DropdownButtonFormField<OcrMode>(
            initialValue: _settings.ocrMode,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final mode in OcrMode.values)
                DropdownMenuItem(value: mode, child: Text(mode.label)),
            ],
            onChanged: (mode) {
              if (mode == null) return;
              setState(() => _settings = _settings.copyWith(ocrMode: mode));
            },
          ),
          const SizedBox(height: 24),
          Text('能力检测', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          _ProbeTile(
            label: '可到达性测试',
            result: _connectivity,
            onRun: _testing ? null : _runConnectivity,
          ),
          _ProbeTile(
            label: 'OCR 测试',
            result: _ocr,
            onRun: _testing ? null : _runOcr,
          ),
          _ProbeTile(
            label: '多模态测试',
            result: _vision,
            onRun: _testing ? null : _runVision,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
          if (_savedHint != null) ...[
            const SizedBox(height: 8),
            Text(
              _savedHint!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProbeTile extends StatelessWidget {
  const _ProbeTile({
    required this.label,
    required this.result,
    required this.onRun,
  });

  final String label;
  final ProbeResult result;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (result.status) {
      ProbeStatus.success => theme.colorScheme.primary,
      ProbeStatus.failure => theme.colorScheme.error,
      ProbeStatus.skipped => theme.colorScheme.onSurfaceVariant,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final suffix = result.latencyMs == null ? '' : ' · ${result.latencyMs}ms';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onRun,
              child: Text(label),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                switch (result.status) {
                  ProbeStatus.idle => '未测试',
                  ProbeStatus.running => '测试中…',
                  ProbeStatus.success => '通过$suffix',
                  ProbeStatus.failure => result.message,
                  ProbeStatus.skipped => result.message,
                },
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
