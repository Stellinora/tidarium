# Tidarium · 时匣

一体化日程助手：把学习通、中国大学 MOOC 等平台的课程、作业与线上课，聚合为一张统一日程表。

Tidarium 由日耳曼语 `*tīdiz`（时间）与拉丁语 `-ārium`（容器/场所）构成，字面意为「时匣」。

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

仓库：<https://github.com/Stellinora/tidarium>

## 状态

- [x] P0 Android 工程可构建、可安装运行
- [x] P1 工程骨架：领域模型、插件契约、注册中心、同步调度、AI 网关接口、基础 UI
- [ ] P2 本地持久化（Drift）+ 缓存优先 UI
- [ ] P3 学习通数据源
- [ ] P4 QuickJS 规则沙箱
- [ ] P5 AI 网关
- [ ] P6 规则仓库热更新

插件与同步目前是占位实现（返回空数据）。开发环境见 [docs/development.md](docs/development.md)。

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
  development.md               开发环境
basic.md                       插件与 AI 网关讨论稿
```

## 开发

依赖 Flutter stable、JDK 17+、Android SDK（platform 36、build-tools 36.0.0）。详细步骤见 [docs/development.md](docs/development.md)。

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run
```

## 文档

- [技术框架](docs/architecture.md)
- [开发环境](docs/development.md)
- [插件与 AI 网关讨论稿](basic.md)

## WakeUp 学校库

- 当前支持：正方、青果、URP、超星通用教务家族。
- 待支持：`kingo_new`、`jz`、`shuwei_*`、`cf` / `cf_new`、`south_soft` 及学校专用类型。
- 待支持学校仍可复制网址，或前往通用教务系统手动导入。

## 第三方数据

- `assets/wakeup_schools.json` 的学校名称、URL 与类型元数据来自
  [OpenWakeUp](https://github.com/LonelyMarch/OpenWakeUp) 的 `schools.json`。
  OpenWakeUp 以 AGPL-3.0-only 发布；Tidarium 仅使用事实性学校元数据，
  不包含其解析器代码。
- 通用教务脚本来自
  [拾光课程表适配仓库](https://github.com/ShiGuangSchedule/shiguang_warehouse)（MIT）。

## License

Tidarium is licensed under the [GNU General Public License v3.0](LICENSE).

分发修改版或 APK 时需同时提供对应源码，并保留本许可证与版权声明。
