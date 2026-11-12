# 三段日程 0.1.0 Demo

一个独立 Flutter Android 日程 App。每天固定三个可编辑模块，适合大学生记录学习、生活和共同活动。默认空白启动，所有业务功能完全离线。归属「我／对象／一起」只是本机标签，没有账号、配对或跨设备同步。

## 安装与使用

下载交付的 Debug APK，在安卓手机文件管理器中打开；按系统提示允许当前文件来源安装应用。最低 Android 7.0（API 24），支持 arm64-v8a、armeabi-v7a 和 x86_64。Debug 签名仅用于测试，非商店正式发布签名。卸载会移除本机数据，建议先导出备份。

1. **记事项**：日程页选择日期，在上午／下午／晚上卡片中点击「添加事项」。只填标题即可保存。勾选方框可完成或取消完成；点事项打开编辑表单，可修改标题、备注、归属、具体时间和排序序号。
2. **移动与删除**：编辑表单内更改日期或所属模块即可移动，稳定 ID 与完成状态保留。若原具体时间不适合目标模块，须调整或点「清除具体时间」。删除需要确认，删除最后一条后日期仍记为已建立。
3. **周模板**：进入「周计划 → 编辑周模板」，逐日添加事项，可「复制到其他星期」并确认替换目标星期。回到周计划选择目标周，点「应用模板到这一周」并核对日期范围。仅建立今天及未来尚未建立的日期；已建立日期与过去日期跳过，并显示清单。空模板也会标记已建立。
4. **看月历**：左右切换月份，周一为周首；日期下显示事项数量。描边表示今天，深色表示选中日期，点日期进入日程。日／周／月读取同一数据库。
5. **修改默认模块**：「设置 → 默认三段模块」可改名称、颜色与起止时间，模块不得重叠，可以留空隙。改动只影响新建立日期；若与周模板定时事项冲突，会列出冲突，须先调整模板。
6. **备份恢复**：「设置 → 导出完整备份」，在系统文件选择器保存 JSON。「从文件恢复」先校验，再确认完整替换当前数据。损坏、越界或版本不支持的文件不会覆盖原数据。清空全部数据需要独立的两次确认。

Debug/Profile 保留 Flutter 标准调试器所需的 INTERNET 权限，仅用于开发调试；业务代码没有网络请求，日程和文件备份可离线使用。没有演示数据入口，安装包不预置虚假任务。未完成事项停留在原日期，不自动转移到明天。

## 工程与环境

| 项目 | 实际使用版本／配置 |
| --- | --- |
| 工程名 | `day_blocks_demo` |
| Android 包名 / applicationId | `cn.bingbing.day_blocks_demo` |
| App 版本 | `0.1.0+1`（versionName 0.1.0 / versionCode 1） |
| Flutter | 3.35.7 stable，revision adc9010625 |
| Dart | 3.9.2 |
| JDK | Eclipse Temurin OpenJDK 21.0.13+9（完整 JDK） |
| Gradle Wrapper | 8.12 |
| Android Gradle Plugin | 8.9.1 |
| Kotlin | 2.1.0 |
| Android compileSdk / targetSdk | 36 / 36 |
| minSdk | 24（Android 7.0） |
| Android Build Tools | App 36.0.0；插件依赖另安装 35.0.0 |
| NDK / CMake | 27.0.12077973 / 3.22.1 |
| sqflite / path | 2.4.2 / 1.9.1 |
| 测试依赖 | sqflite_common_ffi 2.3.6 / sqlite3 2.9.4 / flutter_lints 5.0.0 |
| 数据库 | `day_blocks_demo_v1.sqlite`，schema version 1 |
| 备份 | JSON 格式版本 1 |
| 构建类型与签名 | Debug，Android SDK 自动生成的开发测试签名 |

完整依赖解析结果见 `pubspec.lock`。Flutter 与 Android 工具由官方源安装；没有改动其他 App 工程、数据库或构建配置。源码包不包含 SDK、构建缓存、签名私钥或机器专属 `local.properties`。

## 继续开发与构建

先安装上述 Flutter 稳定版、JDK 21 与 Android SDK。使用官方工具：

```bash
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true
flutter config --no-analytics
sdkmanager 'platforms;android-36' 'build-tools;36.0.0' 'build-tools;35.0.0' 'ndk;27.0.12077973' 'cmake;3.22.1'
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
```

产物：`build/app/outputs/flutter-apk/app-debug.apk`。默认构建为通用 APK；未使用 ABI 拆包。Linux 运行数据库测试需要系统 `libsqlite3`（Ubuntu 可安装 `libsqlite3-dev`）。云端此次系统仅提供 `libsqlite3.so.0`，使用工具目录内指向该库的链接补齐动态库名称，通过 `LD_LIBRARY_PATH` 加载真实 SQLite。

云端 Java 构建必须将当前会话 HTTP/HTTPS 代理传给 Gradle 系统属性；此次替换了过期的 `GRADLE_OPTS` 代理地址，同时让新 JDK 使用运行环境提供的系统 CA 信任库，保持代理与 TLS 校验，没有绕过网络策略。该配置属于本次会话，未写入工程。使用 `CI=true` 跳过 Flutter 官方 CLI 的云主机环境探测，关闭工具统计。

`.github/workflows/android-debug.yml` 可在将本工程根目录推入你授权的 GitHub 仓库后构建、分析、测试并保存 APK。本轮未连接或触发任何 GitHub 仓库。

架构与数据约束详见 `docs/architecture.md`。业务代码位于 `lib/data/` 和 `lib/ui/`；Android 文件选择器位于 `android/app/src/main/kotlin/cn/bingbing/day_blocks_demo/MainActivity.kt`。修改数据库结构时增加 schema version 并补充迁移测试。正式发布应自行配置受保护的 release 签名，不能沿用 Debug 签名。

## 验证与限制

- 核心数据测试 17 项通过：真实 SQLite 新增、修改、删除、完成、取消完成、移动、重开持久化；模块边界与快照；模板复制与重复应用；空日期已建立标记；完成隔离；跨月跨年；备份校验与事务回滚。
- 界面测试 3 项通过：320×640 小屏四页浏览、键盘遮挡与系统返回；新增、完成、取消及筛选一致性；长标题、长昵称与 1.3 倍字体布局。
- `flutter analyze` 无问题，通用 Debug APK 已实际构建且签名校验通过。**已编译，尚未做设备运行验证**：云端软件模拟器系统卡死、安装超时并退出，没有 App 实际运行截图；飞行模式、系统文件选择器和真机操作未验证。详见 `docs/verification.md`。
- 第一版仅单机；不含账号、云同步、聊天、通知、AI、OCR 或无限重复事件。
- 日期选择范围 1900—2100 年；完整备份上限 10 MiB，每类记录最多 50000。数据未做应用层加密，受 Android 应用沙盒保护；JSON 备份为明文。
- 已建立的日期即使清空事项也不会再次套用模板。如需修改该日，应手动添加或调整；仅「清空全部数据」重置所有建立标记。

官方资料：[Flutter SDK archive](https://docs.flutter.dev/install/archive)、[Android 构建说明](https://docs.flutter.dev/deployment/android)、[Android SDK tools](https://developer.android.com/studio)。版本以本次实际命令输出及锁定文件为准。
