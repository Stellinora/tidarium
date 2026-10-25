这份文档总结了关于“插件机制、JS规则引擎、AI网关接入以及其他替代插件形式”的全部架构设计讨论。

---

# 一体化日程助手：插件生态与 AI 网关架构设计

## 一、 移动端插件机制的核心约束
与桌面端（VS Code、Chrome）不同，移动端（尤其是 iOS 和国内 Android）**严禁在应用发布后动态下发并执行原生可执行代码**（如 `.so`、`.dex`）。
*   **合规底线**：所有第三方扩展逻辑必须运行在**解释器沙箱**（如 JavaScript、Lua）或**声明式规则**（如 JSON）中。
*   **架构结论**：采用 **“静态编译注册 + 解释器沙箱 + 配置驱动”** 的机制。

## 二、 插件系统的基础架构
App 主体作为“宿主（Host）”，向插件提供安全沙箱和标准化 API；插件仅作为“逻辑提供方”。

### 1. 统一契约（Interface & Event Model）
所有插件解析出的数据，必须转化为标准的 `StandardEvent` 结构，写入核心事件表。
```dart
class StandardEvent {
  final String id;          // 唯一标识 (用于去重)
  final String type;        // assignment / course / online_session
  final String title;
  final DateTime? dueTime;
  final String source;      // "chaoxing" / "mooc"
}
```

### 2. 插件生命周期与隔离
*   **注册中心**：App 启动时，静态注册内置插件。
*   **状态隔离**：每个插件独立维护自己的 `AuthState`（Valid, Expired, UserKicked）。某平台掉线，不影响其他平台。
*   **异常兜底**：网络超时、格式解析失败必须被捕获，防止拖垮主体。

### 3. 统一认证与调度
*   **Auth Manager**：统一使用内嵌 WebView 截获 Cookie，加密存入系统 Keychain。
*   **调度器（Foreground Sync）**：用户打开 App 时触发。**缓存优先秒开 UI**，后台开启并发池（如最大并发 3）静默拉取，平滑更新 UI。

---

## 三、 插件形式的演进与选型
不要在单一形式上死磕，应采用**分层组合**策略：

### 🥇 默认层：声明式 JSON 规则
*   **特点**：零代码执行，绝对安全。
*   **适用**：接口返回干净 JSON 的平台。
*   **实现**：利用 `jsonata_flutter` 等包，描述“请求哪个 URL、用 JSONata 语法提取哪个字段”。

### 🥈 增强层：QuickJS 规则引擎（主力推荐）
*   **特点**：灵活性极高，生态成熟（`quickjs-kt` / `flutter_qjs_next`）。
*   **适用**：需要多步登录、正则解析 HTML 的复杂平台。
*   **实现**：JS 代码在隔离沙箱中运行，通过 Bridge 调用宿主的 `hostApi.fetch()`，不直接接触底层网络和存储。

### 🥉 高安全层：WebAssembly (Wasm)（面向未来）
*   **特点**：规范级沙箱，隔离性最强。
*   **缺点**：作者门槛极高（需写 Rust/C++ 并编译）。
*   **定位**：当社区完全开放，需要运行**完全不信任的第三方代码**时再引入。

### (备选) Lua 解释器
*   **特点**：运行时极小（约 272KB），语法友好。
*   **缺点**：沙箱逃逸风险略高于 Wasm。

---

## 四、 终极扩展：插件系统接入 AI（AI 网关）
让插件不仅能“爬数据”，还能“用 AI 处理数据”。**核心原则：宿主层作为 AI 路由网关，JS 插件绝不直接加载模型或持有 API Key。**

### 1. 宿主注入的 AI API
```javascript
hostApi.ai = {
  // 调用本地小模型（Qwen 1.5B，默认离线）
  async local(prompt, jsonSchema) { ... },
  
  // 调用云端大模型（BYOK，如 Anthropic/DeepSeek）
  async cloud(prompt, jsonSchema, provider) { ... },
  
  // 智能路由（优先本地，置信度低或失败时走云端）
  async auto(prompt, jsonSchema) { ... }
}
```

### 2. 插件调用 AI 的三大场景
*   **场景 A：消灭正则地狱**。插件抓取 HTML 后，剥离纯文本，直接扔给 `hostApi.ai.auto()`，返回结构化 `StandardEvent`。
*   **场景 B：多模态识别**。遇到验证码或图片作业，插件调用 `hostApi.ai.cloud()` 进行视觉识别。
*   **场景 C：水课自动答题（Agent 行为）**。插件获取题目 -> 调用 `hostApi.ai.local()` 生成答案 -> 调用 `hostApi.submitAnswer()` 提交。

### 3. AI 安全与资源管控（防呆熔断）
*   **权限声明（Manifest）**：插件头部必须声明所需权限（如 `permissions: ["network", "ai:cloud", "submit:actions"]`）。未授权则拒绝调用。
*   **额度与频控**：限制单个脚本单次运行的 AI 调用次数（如最多 20 次）和频率（如每分钟 5 次），防止作恶或消耗光用户的 BYOK 余额。
*   **防 Prompt 注入**：云端 API Key 绝不下发到沙箱。如果模型返回非法格式，宿主层直接拦截丢弃。
*   **高风险动作强确认**：自动提交作业/交卷前，宿主必须在 UI 层弹窗让用户确认。

---

## 五、 开发者落地路径
1.  **单点跑通**：手写一个纯 Dart 的学习通爬虫，跑通“认证 -> 拉取 -> 入库”。
2.  **沙箱重构**：抽出 `DataSourcePlugin` 接口，将学习通改为 **QuickJS 规则**，在沙箱中跑通。
3.  **AI 接入**：在宿主层实现 1.5B 模型加载，暴露 `hostApi.ai.local` 接口给 JS，验证 AI 提取结构化数据。
4.  **动态更新**：搭建 GitHub 规则仓库，App 启动时检查更新 `.js` 文件，实现不发版热修爬虫。
5.  **生态开放**：制定规则开发文档，开放 BYOK 和自动答题权限，让极客用户自行编写和导入插件。