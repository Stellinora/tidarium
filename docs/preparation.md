# 环境与验证记录

> 更新：2026-10-25
> 关联：[`architecture.md`](architecture.md)
> 状态：P0 已完成，P1 骨架已通过构建与真机（模拟器）验证

## 0. 已完成

- Flutter 工程骨架：`flutter create --org io.github.stellinora --project-name tidarium --empty`
- 依赖：Riverpod、Dio、html、intl、path_provider、flutter_secure_storage
- 领域模型、插件契约、注册中心、同步调度、AI 网关、基础 UI
- `applicationId = io.github.stellinora.tidarium`，debug 后缀 `.debug`
- 应用显示名「时匣」，主 Manifest 已声明 `INTERNET`
- `.fvmrc` 固定 Flutter 3.47.7；`fvm use 3.47.7` 已执行，`.fvm/flutter_sdk` 已生成
- Android SDK、emulator、AOSP system image、NDK、CMake 已安装
- AVD `tidarium_36` 已创建并成功启动
- `flutter doctor -v`：Android toolchain 全绿
- `flutter analyze`：0 issue
- `flutter test`：5 个测试全部通过
- `flutter build apk --debug`：成功，产物 153.9 MB
- 安装并启动到模拟器：`Success`，MainActivity 获得焦点，`Fully drawn +5s411ms`，无崩溃
- Git 仓库已初始化并推送到 <https://github.com/Stellinora/tidarium>（`main`，提交 `f1aabde`）
- LICENSE：GPL-3.0

## 1. 最终目录布局

| 内容 | 路径 | 占用 |
| --- | --- | --- |
| Android SDK | `C:\ProgramData\runtime\android-sdk` | 约 2.3 GB |
| 模拟器程序 | `C:\Program Files\Android\emulator` | 约 1.0 GB |
| SDK 内模拟器入口 | `C:\ProgramData\runtime\android-sdk\emulator` → junction 到上者 | 0 |
| AVD 与虚拟磁盘 | `C:\vhds\avd\tidarium_36.avd` | 约 4.1 GB |
| NDK | `C:\ProgramData\runtime\android-sdk\ndk\28.2.13676358` | 约 2.1 GB |
| WSL VHD（未移动） | `C:\WSL\Ubuntu\ext4.vhdx` | 约 11.8 GB |

模拟器实际文件放在 `Program Files`，SDK 内保留 junction，`flutter`、`sdkmanager`、`avdmanager` 仍按 `$ANDROID_HOME/emulator` 正常工作。

> 注意：`sdkmanager` 更新 `emulator` 包时可能重建目录；若 junction 被替换，重新执行：
>
> ```powershell
> Move-Item 'C:\ProgramData\runtime\android-sdk\emulator' 'C:\Program Files\Android\emulator'
> New-Item -ItemType Junction -Path 'C:\ProgramData\runtime\android-sdk\emulator' `
>     -Target 'C:\Program Files\Android\emulator'
> ```

## 2. 环境变量

用户级变量已写入：

```powershell
ANDROID_HOME      = C:\ProgramData\runtime\android-sdk
ANDROID_SDK_ROOT  = C:\ProgramData\runtime\android-sdk
ANDROID_AVD_HOME  = C:\vhds\avd
```

用户 PATH 追加：

```text
C:\ProgramData\runtime\android-sdk\platform-tools
C:\Program Files\Android\emulator
```

`JAVA_HOME` 由 mise 提供：

```text
C:\ProgramData\runtime\runtimes\mise\installs\java\21.0.2
```

### 当前 opencode 会话

本会话仍持有迁移前的 PATH/CARGO_HOME。执行 Flutter 命令时使用绝对路径或先刷新：

```powershell
$sdk  = 'C:\ProgramData\runtime\android-sdk'
$java = 'C:\ProgramData\runtime\runtimes\mise\installs\java\21.0.2'
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:ANDROID_AVD_HOME = 'C:\vhds\avd'
$env:JAVA_HOME = $java
$env:Path = "$java\bin;$sdk\platform-tools;$sdk\emulator;$sdk\cmdline-tools\latest\bin;$env:Path"
```

重启 opencode 后会自动继承干净环境。

## 3. SDK 安装实录

### 3.1 cmdline-tools

包：`commandlinetools-win-16111833_latest.zip`（约 148 MB），解压到：

```text
C:\ProgramData\runtime\android-sdk\cmdline-tools\latest
```

该版本使用新的 Android CLI：`sdkmanager` 已标记 deprecated，`--licenses` 不再需要，包路径改用 `/` 分隔。

### 3.2 安装组件

```powershell
$sdkmanager = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"

& $sdkmanager --sdk_root=$sdk --install `
    'platform-tools' `
    'platforms/android-36' `
    'build-tools/36.0.0' `
    'emulator' `
    'system-images/android-36/default/x86_64'
```

NDK 不能被 Flutter Gradle 插件自动安装（新 CLI 与插件的 `ndk;版本` 参数不兼容），需手动装：

```powershell
& $sdkmanager --sdk_root=$sdk --install 'ndk/28.2.13676358'
```

首次构建时 AGP 还会自动补装：

- `platforms/android-35`
- `cmake/3.22.1`

### 3.3 模拟器与 AVD

AVD 使用 AOSP（无 Google Play）镜像，体积约为 Google APIs 镜像的一半。

```powershell
$env:ANDROID_AVD_HOME = 'C:\vhds\avd'

& "$sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd `
    -n tidarium_36 `
    -k 'system-images;android-36;default;x86_64' `
    -d pixel_10
```

已调整 `C:\vhds\avd\tidarium_36.avd\config.ini`：

```ini
hw.ramSize=4096
hw.cpu.ncore=6
hw.gpu.enabled=yes
hw.gpu.mode=host
hw.keyboard=yes
vm.heapSize=512M
```

启动：

```powershell
& "C:\Program Files\Android\emulator\emulator.exe" -avd tidarium_36 -gpu host
```

验证：

```powershell
& "C:\Program Files\Android\emulator\emulator.exe" -accel-check
# WHPX(10.0.26200) is installed and usable.

& "$sdk\platform-tools\adb.exe" devices
# emulator-5554    device
& "$sdk\platform-tools\adb.exe" shell getprop sys.boot_completed
# 1
```

> opencode 的命令结束后会回收子进程，模拟器不会跨工具调用常驻。日常请在普通 PowerShell 窗口启动；App 已安装在 AVD 中，下次开机仍在。

## 4. Gradle 9.3.1 下载问题

官方 `services.gradle.org` 会 307 到 GitHub Releases，本网络下会超时。已用腾讯镜像填充 wrapper 缓存并校验 SHA-256：

```text
期望 SHA-256：17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43
缓存目录：C:\Users\Polaris\.gradle\wrapper\dists\gradle-9.3.1-all\9ot9r568e8zfvvd4mn8rbu1j0
```

这是机器本地缓存，不修改仓库里的 `distributionUrl`。其他机器如遇同样问题，可临时把 `android/gradle/wrapper/gradle-wrapper.properties` 指向镜像，或手工填充缓存。

## 5. 验证命令

```powershell
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$flutter = 'C:\ProgramData\runtime\runtimes\flutter\versions\3.47.7\bin\flutter.bat'

& $flutter doctor -v
& $flutter analyze
& $flutter test
& $flutter build apk --debug
```

最近一次结果：

- `flutter doctor -v`：Android toolchain 36.0.0、licenses accepted、WHPX 可用
- 清理重复 adb 后，doctor 不再报 `Multiple adb binaries found`
- `flutter analyze`：No issues found
- `flutter test`：5/5 passed
- `flutter build apk --debug`：`build\app\outputs\flutter-apk\app-debug.apk`（153.9 MB，约 311 秒）

doctor 仍会提示 Chrome 缺失与 GitHub 网络检查失败，这两项不影响 Android 构建和运行。

## 6. 安装与启动

```powershell
$adb  = "$sdk\platform-tools\adb.exe"
$apk  = 'build\app\outputs\flutter-apk\app-debug.apk'
$comp = 'io.github.stellinora.tidarium.debug/io.github.stellinora.tidarium.MainActivity'

& $adb install -r $apk
& $adb shell am start -n $comp
& $adb shell dumpsys window | Select-String mCurrentFocus
```

最近一次验证：

```text
Performing Streamed Install
Success
Starting: Intent { cmp=io.github.stellinora.tidarium.debug/...MainActivity }
mCurrentFocus=Window{... io.github.stellinora.tidarium.debug/...MainActivity}
ActivityTaskManager: Fully drawn io.github.stellinora.tidarium.debug/...MainActivity: +5s411ms
```

## 7. 已知问题与处理

| 现象 | 处理 |
| --- | --- |
| `Android sdkmanager did not install NDK 28.2.13676358` | 手动执行 `sdkmanager --install 'ndk/28.2.13676358'` |
| `Package ndk not found` | 同上；新 CLI 不接受 `ndk;版本` |
| Gradle 下载超时 | 用镜像填充 wrapper 缓存（见第 4 节） |
| `Multiple adb binaries found` | 已从 Machine PATH 移除 `C:\Program Files\adb`（文件保留），现在只解析 SDK 的 `platform-tools\adb.exe` |
| SDK XML version 4 警告 | 新版 cmdline-tools 与 AGP 的已知提示，可忽略 |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 卸载同 applicationId 的旧包 |
| `flutter` 命令找不到 | 本会话 PATH 陈旧，刷新或使用绝对路径 |
| 模拟器随命令退出 | 从普通终端启动；opencode 会回收子进程 |

## 8. 尚未完成

### 发布准备

- [x] `git init` 并确认 `.gitignore`（`.dart_tool/`、`build/`、`.fvm/`、`android/local.properties`、`.idea/`）
- [x] 创建 GitHub 仓库 `Stellinora/tidarium`（Public）
- [x] 选择 LICENSE：GPL-3.0
- [ ] 在 GitHub 网页补仓库描述与 topics（当前 token 无 Administration 权限）
- [ ] 补 README 截图、规则开发文档
- [ ] 分发 APK 前配置 release keystore（当前 release 仍用 debug 签名）
- [ ] 可选 GitHub Actions：Flutter 3.47.7 + `flutter build apk --release`

### 功能

- [ ] P2 Drift 持久化 + 缓存优先 UI
- [ ] P3 学习通数据源
- [ ] P4 QuickJS 沙箱
- [ ] P5 AI 网关
- [ ] P6 规则仓库热更新

### 可选

- [ ] 若需要把 WSL 的 `ext4.vhdx` 也放到 `C:\vhds`：
      `wsl --shutdown` 后执行 `wsl --manage Ubuntu-26.04 --move C:\vhds\Ubuntu`
- [x] 执行 `fvm use 3.47.7`，生成 `.fvm/flutter_sdk`
