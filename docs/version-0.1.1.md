# ModuPlan 0.1.1 · 纸间

基于 0.1.0 的视觉升级，versionCode 由 1 增至 2。

## 视觉与操作

- 胡桃色封面、暖白纸页、淡横线与书脊阴影，减少大面积色块。
- 卡片、按钮、对话框使用连续曲率轮廓；中文正文保留系统字体与字号缩放。
- 日程支持前后一天按钮、横向轻扫、日期条与日期选择器。切换日期时旧页卷起，显示新日期的真实内容。
- 编辑表单保留原生键盘避让、系统返回、拖动关闭与确认逻辑，使用柔和的进出过渡。
- 尊重系统减少动态效果设置；快速翻页以最新目标日期为准，垂直滚动仍用于浏览事项。

## 功能边界

三段模块、事项新增/编辑/移动/排序/删除、完成状态、归属筛选、周模板编辑/复制/应用、月历、昵称、模块设置、JSON 备份/恢复及清空确认保持原有规则。数据库 schema 1、备份格式 1 和 Android 包名均保持不变；不预置演示事项，不新增网络依赖。

## 云端验证

GitHub Actions 安装明确的 Android SDK 包，避开已移除的 `tools` 包，执行 `flutter analyze`、`flutter test` 和通用 Debug APK 构建，导出 APK 元信息、签名与 SHA-256。后续修改通过 Pull Request 触发同一流程。

CI 页面截图仅在测试中装载 Noto 中文字体与 Material 图标字体，不包含设备系统栏；APK 使用系统字体，实机字形可能不同。

真实设备的安装升级、备份文件选择器和动画流畅度仍需验收；云端结果不能代表真机通过。Debug 签名可能与旧包不同，覆盖升级前须核对证书，不应通过卸载丢弃原数据。

## 实现参考

连续曲率采用 Flutter 的 [ContinuousRectangleBorder](https://api.flutter.dev/flutter/painting/ContinuousRectangleBorder-class.html)，不是对 Apple 私有曲线的精确复制。Android 工具安装参考 [setup-android](https://github.com/android-actions/setup-android)。
