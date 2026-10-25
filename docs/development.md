# 开发环境

项目按标准 Flutter Android 工程组织，不依赖特定机器、目录布局或私有工具链。

## 依赖

- Flutter stable（项目固定 3.47.7；`.fvmrc` 可选）
- JDK 17 或更高（Gradle / AGP 要求）
- Android SDK：`platform-tools`、`platforms/android-36`、`build-tools/36.0.0`
- 可选：Android Emulator + API 36 system image
- 可选：NDK 28.2.13676358（引入原生插件时需要）

## 环境变量

```text
ANDROID_HOME=<Android SDK 路径>
JAVA_HOME=<JDK 路径>
PATH=%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\emulator;%PATH%
```

Linux/macOS 使用对应的 `export` 写法。

## 安装 SDK 组件

新版 cmdline-tools 使用 `/` 分隔，旧版使用 `;`：

```bash
# 新版
sdkmanager --install "platform-tools" "platforms/android-36" "build-tools/36.0.0"

# 旧版
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

NDK 仅在引入原生插件时需要：

```bash
sdkmanager --install "ndk/28.2.13676358"   # 新版
sdkmanager "ndk;28.2.13676358"             # 旧版
```

旧版 sdkmanager 需要接受许可：

```bash
sdkmanager --licenses
```

## 构建与测试

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

产物：`build/app/outputs/flutter-apk/app-debug.apk`。

## 模拟器

```bash
sdkmanager --install "emulator" "system-images/android-36/default/x86_64"

avdmanager create avd \
  -n tidarium_36 \
  -k "system-images;android-36;default;x86_64" \
  -d pixel_10

emulator -avd tidarium_36
```

安装并启动 debug 包：

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start \
  -n io.github.stellinora.tidarium.debug/io.github.stellinora.tidarium.MainActivity
```

## 常见问题

| 现象 | 处理 |
| --- | --- |
| NDK 版本未安装 | 安装 Flutter 3.47.7 默认的 NDK 28.2.13676358 |
| Gradle 下载慢或超时 | 官方分发会重定向到 GitHub；可配置镜像或预置 wrapper 缓存 |
| 多个 adb 冲突 | PATH 中只保留一套 `platform-tools` |
| licenses 未接受 | 旧版 sdkmanager 执行 `--licenses` |
| 模拟器无法启动 | 确认主机虚拟化与 Hypervisor 加速可用 |
| 设备未识别 | `adb kill-server` 后重新 `adb devices` |
