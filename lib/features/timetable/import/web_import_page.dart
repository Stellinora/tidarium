import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../timetable_providers.dart';
import 'import_payload.dart';
import 'import_providers.dart';
import 'models/school_models.dart';
import 'web_bridge_js.dart';

class WebImportPage extends ConsumerStatefulWidget {
  const WebImportPage({super.key, required this.school, required this.adapter});

  final SchoolEntry school;
  final SchoolAdapter adapter;

  @override
  ConsumerState<WebImportPage> createState() => _WebImportPageState();
}

class _WebImportPageState extends ConsumerState<WebImportPage> {
  late final WebViewController _controller;

  var _loading = true;
  var _importing = false;
  var _progress = 0.0;
  String? _pageTitle;
  String? _currentUrl;
  String? _defaultUserAgent;
  var _desktopMode = false;

  String? _coursesRaw;
  String? _slotsRaw;
  String? _configRaw;
  final _warnings = <String>[];
  Timer? _importTimeout;

  @override
  void dispose() {
    _importTimeout?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'ShiguangBridge',
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress / 100);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _pageTitle = null;
            });
          },
          onPageFinished: (_) async {
            await _injectBridge();
            final title = await _controller.getTitle();
            final currentUrl = await _controller.currentUrl();
            _defaultUserAgent ??= await _controller.getUserAgent();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _progress = 1;
              _pageTitle = title;
              _currentUrl = currentUrl;
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              if (mounted) setState(() => _loading = false);
              _toast('网页加载失败：${error.description}');
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'http' ||
                uri.scheme == 'https' ||
                uri.scheme == 'about') {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    _loadPage();
  }

  Future<void> _loadPage() async {
    final rawUrl = widget.adapter.importUrl.trim();
    if (rawUrl.isEmpty) {
      await _controller.loadHtmlString(_emptyAdapterPage);
      return;
    }

    final url = rawUrl.contains('://') ? rawUrl : 'https://$rawUrl';
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _toast('适配器 URL 无效，只支持 http/https');
      return;
    }
    await _controller.loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageTitle?.trim().isNotEmpty == true
              ? _pageTitle!
              : widget.adapter.adapterName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '输入网址',
            onPressed: _importing ? null : _promptForUrl,
            icon: const Icon(Icons.link),
          ),
          IconButton(
            tooltip: _desktopMode ? '手机模式' : '桌面模式',
            onPressed: _importing ? null : _toggleDesktopMode,
            icon: Icon(
              _desktopMode ? Icons.phone_android : Icons.desktop_windows,
            ),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _importing ? null : _controller.reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showUrlHint)
            Material(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.language,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '需要登录教务系统时先输入网址；分享码类适配器可直接执行导入。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _promptForUrl,
                      child: const Text('输入网址'),
                    ),
                  ],
                ),
              ),
            ),
          if (_progress < 1)
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '先在上方网页完成登录，再点击下方按钮执行导入。'
                    '导入会覆盖当前课程表。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading || _importing ? null : _runImport,
                      icon: _importing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(_importing ? '正在导入…' : '执行导入'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showUrlHint {
    if (widget.adapter.importUrl.trim().isNotEmpty) return false;
    final url = _currentUrl ?? '';
    return url.isEmpty || url.startsWith('about:');
  }

  Future<void> _promptForUrl() async {
    final controller = TextEditingController(
      text: widget.adapter.importUrl.trim().isNotEmpty
          ? widget.adapter.importUrl.trim()
          : (_currentUrl?.startsWith('http') == true ? _currentUrl : ''),
    );
    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('输入教务系统网址'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://jw.example.edu.cn',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('打开'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || input.isEmpty || !mounted) return;

    final address = input.contains('://') ? input : 'https://$input';
    final uri = Uri.tryParse(address);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _toast('网址格式不正确，只支持 http/https');
      return;
    }

    setState(() {
      _loading = true;
      _progress = 0;
      _currentUrl = address;
    });
    await _controller.loadRequest(uri);
  }

  Future<void> _toggleDesktopMode() async {
    setState(() => _desktopMode = !_desktopMode);
    await _controller.setUserAgent(
      _desktopMode ? _desktopUserAgent : _defaultUserAgent,
    );
    await _controller.reload();
  }

  Future<void> _injectBridge() async {
    await _controller.runJavaScript('''
      window._shiguangNativeBridge = {
        postMessage: function(message) {
          if (window.ShiguangBridge && window.ShiguangBridge.postMessage) {
            window.ShiguangBridge.postMessage(message);
          }
        }
      };
    ''');
    await _controller.runJavaScript(shiguangBridgeInitJs);
  }

  Future<void> _runImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('执行导入'),
        content: Text(
          '将使用「${widget.adapter.adapterName}」导入课程，'
          '并覆盖当前课程表。确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _importing = true;
      _coursesRaw = null;
      _slotsRaw = null;
      _configRaw = null;
      _warnings.clear();
    });

    try {
      final script = await ref
          .read(adapterRepositoryProvider)
          .loadAdapterScript(widget.school, widget.adapter, forceRefresh: true);
      await _injectBridge();
      await _controller.runJavaScript(
        "window.currentTableId = 'main';\n$script",
      );
      _toast('适配器已启动，请按网页提示操作');
    } catch (error) {
      if (!mounted) return;
      setState(() => _importing = false);
      _toast('加载适配器脚本失败：$error');
    }
  }

  Future<void> _onBridgeMessage(JavaScriptMessage message) async {
    Map<String, Object?> data;
    try {
      data = (jsonDecode(message.message) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }

    final action = data['action']?.toString();
    final callbackId = data['callbackId']?.toString();
    final payloadRaw = data['payload']?.toString();
    Map<String, Object?> payload = const {};

    if (payloadRaw != null && payloadRaw.isNotEmpty) {
      try {
        payload = (jsonDecode(payloadRaw) as Map).cast<String, Object?>();
      } catch (_) {
        await _reply(callbackId, false, 'payload 不是有效 JSON');
        return;
      }
    }

    switch (action) {
      case 'showToast':
        _toast(payload['message']?.toString() ?? '');
      case 'showAlert':
        await _showAlert(payload, callbackId);
      case 'showPrompt':
        await _showPrompt(payload, callbackId);
      case 'showSingleSelection':
        await _showSingleSelection(payload, callbackId);
      case 'saveImportedCourses':
        _coursesRaw = payload['coursesJsonString']?.toString();
        await _reply(callbackId, true, true);
      case 'saveCourseConfig':
        _configRaw = payload['configJsonString']?.toString();
        await _reply(callbackId, true, true);
      case 'savePresetTimeSlots':
        _slotsRaw = payload['timeSlotsJsonString']?.toString();
        await _reply(callbackId, true, true);
      case 'saveComboSchedule':
        _warnings.add('组合作息暂不支持，已忽略组合作息设置。');
        await _reply(callbackId, true, true);
      case 'notifyTaskCompletion':
        await _completeImport();
    }
  }

  Future<void> _showAlert(
    Map<String, Object?> payload,
    String? callbackId,
  ) async {
    final title = payload['titleText']?.toString() ?? '';
    final content = payload['contentText']?.toString() ?? '';
    final confirmText = payload['confirmText']?.toString() ?? '确定';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title.isEmpty ? '提示' : title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    await _reply(callbackId, true, confirmed ?? false);
  }

  Future<void> _showPrompt(
    Map<String, Object?> payload,
    String? callbackId,
  ) async {
    final validator = payload['validatorJsFunction']?.toString();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ImportPromptDialog(
        title: payload['titleText']?.toString() ?? '请输入',
        tip: payload['tipText']?.toString() ?? '',
        defaultText: payload['defaultText']?.toString() ?? '',
        validate: (input) => _validatePrompt(validator, input),
      ),
    );

    await _reply(callbackId, true, result);
  }

  Future<String?> _validatePrompt(String? functionName, String input) async {
    if (functionName == null || functionName.trim().isEmpty) return null;

    try {
      final result = await _controller.runJavaScriptReturningResult(
        '${functionName.trim()}(${jsonEncode(input)})',
      );
      final text = _unwrapJsResult(result);
      if (text.isEmpty ||
          text.toLowerCase() == 'false' ||
          text.toLowerCase() == 'null') {
        return null;
      }
      return text;
    } catch (error) {
      return '校验脚本执行失败：$error';
    }
  }

  Future<void> _showSingleSelection(
    Map<String, Object?> payload,
    String? callbackId,
  ) async {
    List<String> items;
    try {
      final raw = payload['itemsJsonString']?.toString() ?? '[]';
      items = (jsonDecode(raw) as List).map((item) => item.toString()).toList();
    } catch (_) {
      await _reply(callbackId, true, null);
      return;
    }

    final defaultIndex =
        (payload['defaultSelectedIndex'] as num?)?.toInt() ?? -1;
    if (!mounted) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(payload['titleText']?.toString() ?? '请选择'),
        children: [
          for (var index = 0; index < items.length; index++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(index),
              child: Row(
                children: [
                  if (index == defaultIndex)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.check, size: 18),
                    ),
                  Expanded(child: Text(items[index])),
                ],
              ),
            ),
        ],
      ),
    );

    await _reply(callbackId, true, selected);
  }

  Future<void> _completeImport() async {
    _importTimeout?.cancel();
    if (_coursesRaw == null) {
      setState(() => _importing = false);
      _toast('适配器没有提交课程数据');
      return;
    }

    try {
      final data = ref.read(timetableProvider);
      var slots = _slotsRaw == null
          ? data.timeSlots
          : parseImportedTimeSlots(_slotsRaw!);
      var config = _configRaw == null
          ? data.config
          : parseImportedConfig(_configRaw!, data.config);

      if (_slotsRaw == null) {
        final requiredSections = maxSectionInImportedCourses(_coursesRaw!);
        if (requiredSections > slots.length) {
          final extended = extendTimeSlotsForSections(
            slots: slots,
            requiredSections: requiredSections,
            config: config,
          );
          if (extended.length > slots.length) {
            _warnings.add(
              '已自动补充 ${extended.length - slots.length} 个节次，'
              '请在课程表设置中确认时间',
            );
            slots = extended;
          }
        }
      }

      final imported = parseImportedCourses(
        _coursesRaw!,
        config: config,
        slots: slots,
      );
      _warnings.addAll(imported.warnings);

      if (imported.courses.isEmpty) {
        setState(() => _importing = false);
        _toast('没有可导入的课程');
        return;
      }

      if (imported.courses.any((course) => course.day > 5)) {
        config = config.copyWith(showWeekends: true);
      }

      await ref
          .read(timetableProvider.notifier)
          .replaceSchedule(
            config: config,
            timeSlots: slots,
            courses: imported.courses,
          );
      if (!mounted) return;

      setState(() => _importing = false);
      _toast('已导入 ${imported.courses.length} 门课程');

      if (_warnings.isNotEmpty) {
        await _showWarnings();
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _importing = false);
      _toast('导入失败：$error');
    }
  }

  Future<void> _showWarnings() async {
    final visible = _warnings.take(10).toList();
    final remaining = _warnings.length - visible.length;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('部分内容未导入'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final warning in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $warning'),
                ),
              if (remaining > 0)
                Text(
                  '还有 $remaining 项未显示',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _reply(String? callbackId, bool success, Object? result) async {
    if (callbackId == null) return;
    try {
      await _controller.runJavaScript(
        'window._shiguangNativeCallback('
        '${jsonEncode(callbackId)}, $success, ${jsonEncode(result)});',
      );
    } catch (_) {
      // The page may have navigated away.
    }
  }

  String _unwrapJsResult(Object? value) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.length >= 2 &&
          trimmed.startsWith('"') &&
          trimmed.endsWith('"')) {
        try {
          return (jsonDecode(trimmed) as String).trim();
        } catch (_) {
          return trimmed;
        }
      }
      return trimmed;
    }
    return value.toString().trim();
  }

  void _toast(String message) {
    if (!mounted || message.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ImportPromptDialog extends StatefulWidget {
  const _ImportPromptDialog({
    required this.title,
    required this.tip,
    required this.defaultText,
    required this.validate,
  });

  final String title;
  final String tip;
  final String defaultText;
  final Future<String?> Function(String input) validate;

  @override
  State<_ImportPromptDialog> createState() => _ImportPromptDialogState();
}

class _ImportPromptDialogState extends State<_ImportPromptDialog> {
  late final TextEditingController _controller;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.tip.isNotEmpty) ...[
              Text(widget.tip),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_busy,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确定'),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await widget.validate(_controller.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pop(_controller.text);
  }
}

const String _desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const String _emptyAdapterPage = '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: sans-serif; padding: 24px; color: #333; line-height: 1.6; }
    h2 { font-size: 20px; }
  </style>
</head>
<body>
  <h2>Tidarium 适配器</h2>
  <p>这个适配器没有预设登录页。</p>
  <p>如果需要教务系统网页，点击右上角链接图标输入网址并登录。</p>
  <p>分享码类适配器可以直接点击下方“执行导入”。</p>
</body>
</html>
''';
