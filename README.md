# 肌肉放松沟通助手（iOS）

纯本地隐私型 iOS 应用：身体酸痛记录、按摩放松需求可视化沟通、自助舒缓参考。MIT 开源。

- **零服务端**：无后端、无账号、无数据上传
- **零外部 AI**：语音转写 / 语义识别 / 语音播报全部使用 iOS 系统框架，设备本地完成
- **本地加密**：用户自由文本 AES-256-GCM 加密存储，密钥仅存于设备 Keychain
- **手动备份**：LZ4 压缩 JSON，导出 / 导入完全由用户触发
- **无障碍**：视障（语音播报）/ 听障（34pt 大字展示）双通道兜底，VoiceOver 适配

## 构建运行

```bash
cd MuscleRelax
brew install xcodegen   # 如未安装
xcodegen generate
open MuscleRelax.xcodeproj
```

要求：Xcode 26+，iOS 16+ 部署目标。模拟器运行需安装 iOS Simulator 运行时（Xcode → Settings → Components）。

## 仓库内容

| 路径 | 说明 |
| --- | --- |
| [`MuscleRelax/`](MuscleRelax) | iOS 应用完整源码（SwiftUI，零第三方依赖） |
| [`MuscleRelax/LICENSE`](MuscleRelax/LICENSE) | MIT 开源协议 |
| [`index.html`](index.html) | 隐私政策（GitHub Pages 托管，页面本身不收集任何数据） |
| [`docs/spec-v2.0.md`](docs/spec-v2.0.md) | 完整需求说明书 & 开发指南（v2.0 定稿） |
| [`docs/dev-log.md`](docs/dev-log.md) | 开发日志（过程、决策与问题记录） |

## 隐私政策

<https://jjbb013.github.io/muscle-relax-companion/>

## 免责声明

本应用仅为身体状态记录、按摩放松沟通与日常舒缓参考工具，不具备医疗功能，不能替代专业医疗建议；身体不适请及时前往正规医疗机构就诊。
