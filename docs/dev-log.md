# 肌肉放松沟通助手 · 开发日志

> 依据 [[需求说明书-v2.0]] 执行开发。本日志记录开发过程、关键决策与遇到的问题。

## 2026-09-08 20:40 · 环境检查

- ✅ Xcode 26.4 已安装（Build 17E192），Swift 6.3 工具链可用。
- ✅ 工作区为空目录，从零开始。
- 🔧 安装 XcodeGen（brew），用于从 `project.yml` 生成 `.xcodeproj`，避免手写 pbxproj。
- 📄 需求文档已存入工作区：`需求说明书-v2.0.md`。

### 初始技术决策

- 按需求 §12 MVP 裁剪建议 + §3.3 降级方案：**首发采用 2D 人体热区图**（SwiftUI 绘制，前/后两面），规避 3D 模型商用授权风险，包体 ≤30MB 目标更容易达成；SceneKit 3D 作为后续迭代预留。
- 零第三方依赖：不引入 CocoaPods/SPM 包，仅用系统框架（Core Data、CryptoKit、Keychain、Speech、NaturalLanguage、AVFoundation、Compression）。

## 进展记录

| 时间 | 事项 | 状态 |
| --- | --- | --- |
| 20:40 | 环境检查、XcodeGen 安装 | ✅ 完成 |
| 20:42 | 冻结接口契约（DomainModels.swift） | ✅ 完成 |
| 20:45 | 创建 GitHub 公开仓库 `jjbb013/muscle-relax-companion`，推送隐私政策 + 开发文档，启用 GitHub Pages | ✅ 完成 |
| 20:46 | XcodeGen 首次生成失败（沙箱缺 USER 环境变量）→ `USER=will xcodegen generate` 解决 | ✅ 已解决 |
| 20:47 | xcodebuild 插件加载失败：`/Library/Developer/PrivateFrameworks` 残留旧版（XcodeSystemResources 26.0.1 vs Xcode 26.4） | ⚠️ 待用户授权 |
| 20:50–21:30 | 三个并行子代理：数据层 / 静态内容（PubMed 循证）/ 服务层 | ✅ 完成 |
| 21:30–22:00 | UI 子代理：12 个 SwiftUI 文件全部页面完成 | ✅ 完成 |
| 22:10 | 全量类型检查排错 6 轮（详见下节）→ `swiftc -typecheck` 全绿 | ✅ 完成 |

## 2026-09-08 22:10 · 分层实现完成

### 交付结构（MuscleRelax/）

- **Models/**：DomainModels.swift（契约冻结）、BackupSchema.swift（备份 Schema v1）
- **Data/**：CoreDataStore（Core Data + 文件级保护 complete）、CryptoService（AES-256-GCM + CryptoKit）、KeychainService（kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly）、BackupService（LZ4RAW + JSON，导出密文打包，ID 冲突重映射）、手写 .xcdatamodeld
- **Content/**：20 部位（精细 12 + 基础 8）、67 条同义词、10 个内置模板、15 条舒缓教程（5 篇 PubMed 循证：PMID 25780258 / 35722759 / 34444189 / 29223884 / 35298696）
- **Services/**：SpeechInputService（on-device 分级降级，按语言判定）、SemanticParser（NLTokenizer + 词典 + 置信度规则）、BroadcastService（逐段高亮 + 系统增强音色优先 + 三语）、BackupReminderService（每周日 20:00 本地通知）
- **UI/**：免责声明（滚到底才可同意）、2D 人体热区图（前/背面、20 热区、spring 回弹）、四步记录流程、§6.2 部位冲突强制确认弹窗、播报页（34pt 粗体逐段高亮 + 暂停/继续/重播）、历史 + 30 天复盘、设置页（导出/导入/备份提醒/大字模式/隐私政策）

### 类型检查排错记录（6 轮）

1. `BackupReminderService` 缺 `ObservableObject` 遵循 → 补上。
2. `COMPRESSION_LZ4RAW` 找不到 → 真实符号为 `COMPRESSION_LZ4_RAW`（2 处）。
3. `Result<Data, OSStatus>`：OSStatus 不遵循 Error → 改用自定义 `ReadResult` 枚举。
4. Swift 6 `AVSpeechSynthesizerDelegate` 跨 actor 遵循 → `@preconcurrency`。
5. `NLTagger(tagSchemes: [.word])` 不存在该 scheme → 改用 `NLTokenizer(unit: .word)`（.simplifiedChinese）。
6. 第六轮全绿：`xcrun -sdk iphoneos swiftc -typecheck -target arm64-apple-ios16.0 -swift-version 6` 全项目 EXIT 0。

## ⚠️ 阻塞项：Xcode 系统组件待修复

- **现象**：`xcodebuild` 加载 `IDESimulatorFoundation` 插件失败（符号缺失），因 `/Library/Developer/PrivateFrameworks` 属于旧版 Xcode（pkg 版本 26.0.1.0.1758082578，Xcode.app 为 26.4）。
- **修复**：`xcodebuild -runFirstLaunch` 会重装 `XcodeSystemResources.pkg`，但需要 root；已触发 GUI 授权弹窗（SecurityAgent 进程确认在运行），**等用户输入管理员密码**。
- **临时验证手段**：已用 `xcrun -sdk iphoneos swiftc -typecheck` 对全部源码按 iOS 16 目标做完整类型检查（不经过损坏的插件系统），全绿；链接与资源打包待授权后 xcodebuild 复验。
- 若弹窗已消失：用户手动打开一次 Xcode.app 或在终端运行 `sudo xcodebuild -runFirstLaunch` 即可。

## 遗留风险（需真机/模拟器验证）

- 2D 热区归一化坐标在小屏机型的命中体验。
- 语音转写尾音：stopTranscribing 立即 deactivate 音频会话，真机若丢尾音需把 deactivate 移到 finishSession。
- Core Data 加密字段不参与全文搜索（§3.1 代价声明，符合预期）。
