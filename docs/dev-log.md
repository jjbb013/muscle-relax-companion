# 肌肉放松沟通助手 · 开发日志

> 本文件为开发日志的 GitHub 存档副本，实时版本位于 Obsidian 工作区 `开发日志.md`。

## 2026-09-08 20:40 · 环境检查

- ✅ Xcode 26.4 已安装（Build 17E192），Swift 6.3 工具链可用。
- ✅ 工作区为空目录，从零开始。
- 🔧 安装 XcodeGen 2.46.0（brew），用于从 `project.yml` 生成 `.xcodeproj`，避免手写 pbxproj。
- 📄 需求文档已存入工作区：`需求说明书-v2.0.md`。
- 🌐 创建公开仓库 `jjbb013/muscle-relax-companion`，用于托管隐私政策（GitHub Pages）与开发文档。

### 初始技术决策

- 按需求 §12 MVP 裁剪建议 + §3.3 降级方案：**首发采用 2D 人体热区图**（SwiftUI 绘制，前/后两面），规避 3D 模型商用授权风险，包体 ≤30MB 目标更容易达成；SceneKit 3D 作为后续迭代预留。
- 零第三方依赖：仅用系统框架（Core Data、CryptoKit、Keychain、Speech、NaturalLanguage、AVFoundation、Compression）。

### 接口契约（先于实现冻结）

- `DomainModels.swift`：RegionSide / SoreLevel / RecordSource / RegionCategory / AppLanguage / BodyRegion / PressPoint / SoreRecordData / UserTemplateData / AppSettingsData / SemanticMatch。
- 数据层、服务层、UI 层按目录拆分并行开发，统一以上述契约为准。
