# Tidarium · 时匣

一体化日程助手：把学习通、中国大学 MOOC 等平台的课程、作业与线上课，聚合为一张统一日程表。

Tidarium 由日耳曼语 `*tīdiz`（时间）与拉丁语 `-ārium`（容器/场所）构成，字面意为「时匣」。

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

仓库：<https://github.com/Stellinora/tidarium>

## 状态

- [x] P0 Android SDK / emulator / AVD 安装，首次构建成功
- [x] P1 工程骨架：领域模型、插件契约、注册中心、同步调度、AI 网关接口、基础 UI
- [x] 模拟器安装、启动、安装 App 验证通过
- [ ] P2 本地持久化（Drift）+ 缓存优先 UI
- [ ] P3 学习通数据源
- [ ] P4 QuickJS 规则沙箱
- [ ] P5 AI 网关
- [ ] P6 规则仓库热更新

插件与同步目前是占位实现（返回空数据）。环境、路径与验证记录见 [docs/preparation.md](docs/preparation.md)。

## 技术栈

| 层 | 选择 |
| --- | --- |
| UI | Flutter 3.47.7 / Dart 3.13.5 / Material 3 |
| 状态 | Riverpod 3.4.3 |
| 网络 | Dio 5.11.1 |
| 解析 | html 0.15.7 |
| 存储 | 当前 InMemoryEventStore，P2 切换 Drift + SQLite |
| 凭证 | flutter_secure_storage 11.2.0 |
| Android | Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0 / compileSdk 36 / minSdk 24 |
| SDK | `C:\ProgramData\runtime\android-sdk`（NDK 28.2.13676358、CMake 3.22.1） |
| 模拟器 | `C:\Program Files\Android\emulator`；AVD `C:\vhds\avd\tidarium_36` |

## 目录

```
lib/
  main.dart, app.dart          应用入口与根组件
  ui/theme.dart                Material 3 主题
  core/
    model/standard_event.dart  统一事件模型
    plugin/                    插件契约、注册中心、沙箱接口
    auth/                      认证接口
    sync/                      前台同步调度器
    ai/                        AI 网关与配额
    db/                        事件存储接口与内存实现
  plugins/
    chaoxing/                  学习通插件（占位）
    mooc/                      中国大学 MOOC 插件（占位）
  features/
    home/                      首页与 Provider
    settings/                  设置页
docs/
  architecture.md              技术框架
  preparation.md               剩余准备工作
basic.md                       插件与 AI 网关讨论稿
```

## 文档

- [技术框架](docs/architecture.md)
- [环境与验证记录](docs/preparation.md)
- [插件与 AI 网关讨论稿](basic.md)

## 常用命令

```powershell
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
```

启动模拟器（在普通 PowerShell 窗口执行，不要在 opencode 命令里后台启动）：

```powershell
& "C:\Program Files\Android\emulator\emulator.exe" -avd tidarium_36 -gpu host
```

安装并启动 debug 包：

```powershell
& "C:\ProgramData\runtime\android-sdk\platform-tools\adb.exe" install -r build\app\outputs\flutter-apk\app-debug.apk
& "C:\ProgramData\runtime\android-sdk\platform-tools\adb.exe" shell am start -n io.github.stellinora.tidarium.debug/io.github.stellinora.tidarium.MainActivity
```

当前 opencode 会话仍缓存迁移前的环境变量，`fvm` 在本会话可能挂起。新开终端或重启会话后正常；临时可改用绝对路径：

```powershell
& "C:\ProgramData\runtime\runtimes\flutter\versions\3.47.7\bin\flutter.bat" analyze
```

## License

Tidarium is licensed under the [GNU General Public License v3.0](LICENSE).

分发修改版或 APK 时需同时提供对应源码，并保留本许可证与版权声明。
