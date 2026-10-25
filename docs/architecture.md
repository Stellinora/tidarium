# Tidarium 技术框架

> 版本：0.2（2026-10-25）
> 代码状态：P0 + P1 已完成，构建、安装与模拟器运行验证通过
> 讨论来源：[`basic.md`](../basic.md)

## 1. 项目标识

| 项 | 值 |
| --- | --- |
| 产品名 | Tidarium / 时匣 |
| 定位 | 一体化日程助手（课程、作业、线上课聚合） |
| 仓库 | `Stellinora/tidarium` |
| Dart 包名 | `tidarium` |
| Android applicationId | `io.github.stellinora.tidarium` |
| Debug applicationId | `io.github.stellinora.tidarium.debug` |
| 显示名 | 时匣 |
| 平台 | Android（Flutter，单平台起步） |

命名：日耳曼语 `*tīdiz`（时间，英语 tide 同源）+ 拉丁语 `-ārium`（容器/场所），字面「盛放时间的匣子」。

`com.uni.class` 仅作为工作目录名保留。`class` 是 Java/Kotlin/Dart 保留字，不能出现在包名中，因此不使用。

## 2. 产品边界

做：

- 聚合多平台课程表、作业截止时间、线上课/直播
- 前台缓存优先、后台静默同步
- 插件化数据源、规则可热更新
- 宿主层 AI 网关：本地模型优先、云端 BYOK 兜底

不做：

- 不代提交作业/考试，不做自动答题
- 不动态下发原生代码（`.so` / `.dex`）
- 不在沙箱内持有云端 API Key
- 不绕过平台风控或验证码

## 3. 技术栈与版本

| 项 | 版本 | 说明 |
| --- | --- | --- |
| Flutter | 3.47.7 stable | FVM 缓存于 `C:\ProgramData\runtime\runtimes\flutter\versions\3.47.7` |
| Dart | 3.13.5 | 随 Flutter 附带 |
| Gradle | 9.3.1 | 首次构建时下载 |
| AGP | 9.1.0 | `android/settings.gradle.kts` |
| Kotlin | 2.4.0 | 同上 |
| compileSdk / targetSdk | 36 | 来自 Flutter Gradle 插件 |
| minSdk | 24 | Android 7.0 |
| JDK | 21.0.2（target 17） | mise 管理 |
| Riverpod | 3.4.3 | 状态管理 |
| Dio | 5.11.1 | HTTP |
| html | 0.15.7 | DOM 解析 |
| intl | 0.20.3 | 日期格式化 |
| flutter_secure_storage | 11.2.0 | Cookie/凭证存储 |
| Android SDK | `C:\ProgramData\runtime\android-sdk` | platform-tools 37.0.1、platform 36、build-tools 36.0.0 |
| NDK / CMake | 28.2.13676358 / 3.22.1 | Flutter 3.47.7 默认 NDK；首次构建自动补 CMake |
| Emulator | 37.2.12.0，`C:\Program Files\Android\emulator` | SDK 内 `emulator` 目录为 junction |
| AVD | `C:\vhds\avd\tidarium_36` | pixel_10、Android 16 / API 36、4 GB RAM |
| Drift + SQLite | 规划 P2 | 结构化持久化 |
| flutter_inappwebview | 规划 P3 | 登录 Cookie 截获 |
| JSONata / QuickJS | 规划 P4 | 规则层与沙箱 |

## 4. 分层

```
features/            Presentation: 页面、Provider、ViewModel
        |
core/sync, core/auth Application: 调度、会话、配额
        |
core/model, core/plugin  Domain: StandardEvent、插件契约、沙箱接口
        |
core/db, secure storage  Data: 事件存储、凭证存储
        |
WebView, Dio, AI runtime Platform
```

依赖方向只能由外向内。`core/model` 与 `core/plugin` 不依赖 Flutter，便于单测和未来的桌面端复用。

## 5. 目录与实现状态

```
lib/
  main.dart                       [x] ProviderScope 入口
  app.dart                        [x] MaterialApp、明暗主题
  ui/theme.dart                   [x] Material 3 主题
  core/
    model/standard_event.dart     [x] 统一事件模型与 JSON 契约
    plugin/plugin.dart            [x] Manifest、权限、AuthState、DataSourcePlugin
    plugin/plugin_registry.dart   [x] 内置插件静态注册
    plugin/plugin_sandbox.dart    [x] HostApi 与 RuleSandbox 接口
    auth/auth_manager.dart        [x] 认证接口
    sync/sync_scheduler.dart      [x] 并发 3 的同步调度与异常隔离
    ai/ai_gateway.dart            [x] 路由、Provider、AiQuota
    db/event_store.dart           [x] EventStore 接口 + 内存实现
  plugins/
    chaoxing/chaoxing_plugin.dart [x] 契约占位，待 P3 实现
    mooc/mooc_plugin.dart         [x] 契约占位，待 P3 实现
  features/
    home/                         [x] 首页、Provider、空状态
    settings/                     [x] 插件与权限展示
```

## 6. 领域模型

`StandardEvent` 是所有插件输出的唯一交换格式：

```dart
class StandardEvent {
  final String id;        // 去重键，建议 "<source>:<platform-id>"
  final EventType type;   // assignment / course / online_session
  final String title;
  final DateTime? dueTime;
  final String source;    // "chaoxing" / "mooc"
}
```

- 线上课在 JSON 中使用 `online_session`，与讨论稿一致；Dart 侧枚举名为 `onlineSession`。
- 入库按 `id` upsert，来源平台内的稳定 ID 是去重关键。
- 时间统一存 UTC，展示层再转本地时区。

## 7. 插件系统

### 7.1 契约

- `PluginManifest`：`id`、名称、版本、权限集合。
- `PluginPermission`：`network`、`aiCloud`、`aiLocal`、`submitActions`。
- `AuthState`：`unknown`、`valid`、`expired`、`kicked`，按插件隔离。
- `DataSourcePlugin`：`authenticate()` + `fetchEvents()`，只负责“认证 → 拉取 → 归一化”。

### 7.2 注册与隔离

- App 启动时静态注册内置插件（`PluginRegistry`），不下载原生代码。
- 单个插件失败只影响自身：`SyncScheduler` 捕获异常并生成带 `error` 的 `SyncReport`。
- 插件不直接访问数据库与安全存储，只通过宿主 API。

### 7.3 规则分层

| 层 | 形式 | 适用 | 状态 |
| --- | --- | --- | --- |
| L0 | Dart 内置插件 | 复杂登录、私有协议 | 当前 |
| L1 | 声明式 JSON/JSONata | 返回干净 JSON 的站点 | P4 |
| L2 | QuickJS 沙箱 | 多步登录、HTML 正则 | P4 |
| L3 | Wasm | 完全不信任的第三方代码 | 远期 |

升级路径：先用手写 Dart 插件跑通，再抽成 `RuleSandbox` 规则，最后开放规则仓库。

### 7.4 沙箱边界

- 规则只能调用 `PluginHostApi.fetch()`，不能直接接触网络、文件、数据库。
- 每次运行有超时、内存与调用次数上限。
- 输出必须是合法 `StandardEvent` 数组；非法输出直接丢弃。
- 沙箱内不可见云端 Key。

### 7.5 认证

- P3 使用内嵌 WebView 完成登录，截获 Cookie。
- Cookie 加密后写入系统 Keystore（`flutter_secure_storage`），按插件隔离。
- 掉线只标记该插件 `expired`，不阻塞其他插件。

### 7.6 同步

1. 读取缓存，立即渲染。
2. 前台触发同步，最多 3 个插件并发。
3. 各插件认证、拉取、归一化。
4. 结果 upsert 到 `EventStore`，UI 增量刷新。
5. 记录 `lastSyncAt` 与错误信息。

### 7.7 规则热更新

- 规则仓库以版本化 `.js` / `.json` 发布，App 启动时检查更新。
- 下载后校验哈希/签名，再写入本地规则目录。
- 规则与宿主 API 版本不兼容时拒绝加载。

## 8. AI 网关

```dart
abstract interface class AiGateway {
  Future<Map<String, Object?>> complete(AiRequest request);
}
```

- `AiRoute.local`：本地小模型（规划 Qwen 1.5B，llama.cpp FFI）。
- `AiRoute.cloud`：BYOK，云端大模型。
- `AiRoute.auto`：本地优先，置信度低或失败时转云端。
- `AiQuota`：默认单次运行 20 次、每分钟 5 次，防止脚本刷爆额度。

安全约束：

- Key 只存在于宿主层，永不下发沙箱。
- 模型输出必须按 JSON Schema 校验，失败即丢弃。
- 声明了 `aiCloud` 权限才允许走云端。
- 高风险动作（提交类）必须由用户在 UI 确认；当前版本不实现自动提交。

## 9. 数据

当前 `EventStore` 为内存实现，P2 替换为 Drift：

```sql
standard_events(
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  due_time INTEGER,
  source TEXT NOT NULL,
  raw_json TEXT,
  fetched_at INTEGER NOT NULL
);

plugin_state(
  plugin_id TEXT PRIMARY KEY,
  auth_state TEXT NOT NULL,
  last_sync_at INTEGER,
  cursor TEXT
);
```

缓存优先：UI 只读 `EventStore`，网络同步是后台增量写入。

## 10. 安全与合规

- 不使用动态原生代码或热更新 APK。
- 关闭明文流量，只允许 HTTPS。
- Cookie/Token 仅存 Keystore，不进日志。
- 只读聚合，不代提交；设置页展示免责声明与平台服务条款提示。
- 第三方平台风控、验证码、加密接口可能导致规则失效，需通过规则热更新修复。

## 11. 里程碑

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| P0 | Android SDK、首次构建 | `flutter doctor -v` 全绿，`flutter build apk --debug` 成功（已完成） |
| P1 | 工程骨架 | `flutter analyze`、`flutter test` 通过（已完成） |
| P2 | Drift 持久化 + 缓存优先 UI | 杀进程后数据仍在，冷启动先出缓存 |
| P3 | 学习通 Dart 插件 | 登录、拉取、入库、列表展示真实作业 |
| P4 | `RuleSandbox` + QuickJS | 同一学习通逻辑改为 `.js` 规则运行 |
| P5 | AI 网关 | HTML/文本 → `StandardEvent` 结构化链路 |
| P6 | 规则仓库热更新 | 不发版替换规则并生效 |

## 12. 决策记录

| 编号 | 决策 | 理由 |
| --- | --- | --- |
| D1 | 用 Flutter，不用原生 Android | 讨论稿的 `StandardEvent` 与插件包均为 Dart/Flutter 生态 |
| D2 | 命名 Tidarium，包名 `io.github.stellinora.tidarium` | `com.uni.class` 含保留字；GitHub 命名空间唯一 |
| D3 | 先定义 `EventStore` 接口，P2 再接 Drift | 避免骨架阶段引入代码生成 |
| D4 | Riverpod + MVVM | 与 Flutter 生态一致，便于插件状态隔离 |
| D5 | 规则层 JSONata → QuickJS → Wasm | 安全性与灵活性分层，不引入 Lua |
| D6 | AI 先云端 BYOK，本地模型独立里程碑 | 本地 1.5B 模型体积大，先验证链路 |
| D7 | 不上架 Play，保留 debug 后缀 | 项目发布为主，避免包名审核与签名约束 |

## 13. 验收

```powershell
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
```

最近一次验证（2026-10-25）：

- `flutter doctor -v`：Android toolchain 全绿，WHPX 可用
- `flutter analyze`：No issues found
- `flutter test`：5/5 通过
- `flutter build apk --debug`：`build\app\outputs\flutter-apk\app-debug.apk`，153.9 MB
- 模拟器：`emulator-5554` 在线，`sys.boot_completed=1`
- 安装与运行：`adb install` 成功，MainActivity `Fully drawn +5s411ms`，无崩溃

具体路径、命令与已知问题见 [`preparation.md`](preparation.md)。
