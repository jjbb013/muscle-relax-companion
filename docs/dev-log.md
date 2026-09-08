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

## ⚠️ 阻塞项：Xcode 系统组件（已解决）

- 用户执行 `sudo xcodebuild -runFirstLaunch` 重装系统组件成功；随后在 Xcode GUI 下载 iOS 26.4 Simulator（23E244，8.46 GB）完成。
- ✅ 模拟器目标 `BUILD SUCCEEDED`；真机目标 `BUILD SUCCEEDED`。

## 2026-09-09 00:25 · 模拟器冒烟测试（发现并修复 2 个真机级缺陷）

1. **Keychain 权限缺失（errSecMissingEntitlement -34018）**：无签名构建缺少 keychain-access-groups entitlement，数据层初始化失败 → 致命错误页。修复：新增 `MuscleRelax.entitlements`（keychain-access-groups = AppIdentifierPrefix + bundle id），project.yml 加 `CODE_SIGN_ENTITLEMENTS`，改为 adhoc 签名构建。
2. **启动即崩溃（NSUnknownKeyException）**：`CoreDataStore.init` 用 KVC `setValue(_:forKey:)` 给 NSPersistentStoreDescription 设置文件保护选项 → 运行时抛异常。修复：改用 `setOption(_:forKey:)`，值用 `FileProtectionType.complete.rawValue as NSString`。
   - 教训：类型检查无法发现此类运行时 API 误用，冒烟测试（模拟器 install + launch + 截图 + log）是必要环节。
3. 修复后：免责声明首屏正常渲染，合规文案与"滚到底后继续"提示就位。

### 待人工确认项

- 免责声明"同意并进入"按钮在模拟器截图中呈蓝色，需人工滑动验证"未滚到底不可点"的禁用态是否生效（§8.2.1）。
- 语音输入/播报、备份导出导入、热区点击体验需真机或 GUI 模拟器人工过一遍。

### 复验命令

```bash
cd MuscleRelax
USER=will xcodegen generate   # 仅当新增/删除文件后需要
xcodebuild -project MuscleRelax.xcodeproj -scheme MuscleRelax \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

## 遗留风险（需真机/模拟器验证）

- 2D 热区归一化坐标在小屏机型的命中体验。
- 语音转写尾音：stopTranscribing 立即 deactivate 音频会话，真机若丢尾音需把 deactivate 移到 finishSession。
- Core Data 加密字段不参与全文搜索（§3.1 代价声明，符合预期）。

## 2026-09-09 00:35 · 修复「同意并进入」无响应 + 代码开源

### Bug：免责声明按钮点击无响应

- **现象**：用户滚到底后点击「同意并进入」无反应。
- **根因**：SwiftUI 订阅断链。门控判断 `needsDisclaimer` 在 `ContentView` 里读取 `appState.store?.settings`，但 `AppState.store` 不是 @Published——`DisclaimerView` 内部的 store 写入成功（数据已落盘），ContentView 却收不到变更通知，页面不切换。
- **修复**：抽出 `ReadyRootView`（@EnvironmentObject 直接订阅 CoreDataStore），门控改在其中判断。已在注释中记录该模式陷阱。
- 重新编译 BUILD SUCCEEDED，模拟器重启 0 崩溃，免责声明页渲染正常。待用户在模拟器里复测点击跳转。

### 开源发布（commit fa5b8913）

- 全部源码（40 个文件）+ MIT LICENSE + .gitignore 推送至 `jjbb013/muscle-relax-companion` 的 `MuscleRelax/` 目录，README 更新为含构建说明的开源版本。
- 注意：本机 git 直连 github.com:443 不通（gh CLI 走 API 正常），发布改用 GitHub Git Data API（blobs → tree → commit → ref）完成，未走 git clone。
- 仓库现为公开仓库，含：源码、隐私政策（GitHub Pages）、需求说明书、开发日志。

## 2026-09-09 01:30 · 首页 3D 人体模型（commit 90f39881）

- **需求**：用户要求首页人物模型为 3D，支持双指捏合缩放、旋转，参考低模肌肉分区示意图。
- **方案**：`BodyScene3DView`（UIViewRepresentable 包装 SCNView），**程序化低模人形**（SCN 几何体拼装，约 1.75 场景单位），零外部 3D 资产、零授权风险；20 个部位节点 name = regionId 全覆盖，肌肉分区柔和着色（#3D8BFF 蓝色系 + 颈肩暖杏点缀）。
- **交互**：allowsCameraControl（单指旋转 / 双指捏合缩放 / 双指平移）+ 单击 SCNHitTest 选部位 + 双击复位相机；选中部位 emission 高亮 + 1.05× 弹簧动画，相机向该侧微倾（§6.1.4）。
- **集成**：HomeView 默认 3D、右上角「2D」胶囊切回 2D 热区图（§3.3 降级路径保留）；RecordFlowView 第①步同步 3D；DEBUG 启动参数 `-SkipDisclaimerPreview` 供自动化截图。
- **验证迭代（3 轮截图）**：① SCNView 子类 init 崩溃修复 → ② 相机 pivot 导致模型出视锥（改圆周机位 + defaultCameraController.target）→ ③ 渲染正常；另修复「列表」入口与 3D/2D 切换胶囊的布局重叠。
- **遗留**：3D 区在 ScrollView 内，单指旋转与页面滚动可能竞争；点选有约 0.25s 双击识别延迟；模型占比偏小可调 cameraHomeDistance 3.1 → 2.7。
- 截图：`smoke-3d-2.png`（首页 3D 渲染正常，界面无重叠）。
