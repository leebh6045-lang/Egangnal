# Egangnal

Egangnal 是一个面向个人使用的 macOS 语言学习空间。它不安排任务，也不评价学习进度，而是通过独立的语言空间、长期累计学习时长和本地资料库，降低开始学习的阻力并保留真实投入。

## 当前状态

应用的基础工作台、独立主题、单词本、长期计时以及设置与个性化功能已经落地。目前具备：

- 单主窗口的总览、设置、日语空间、英语空间及对应单词本。
- `Command + 1 / 2 / 3` 页面导航。
- 水印下方的日语、英语卡片入口，以及首页右上角可展开的当年月份挂历。
- 日语、英语相互独立且不可手工修改的长期累计学习时长；仅在对应语言空间活动时计时。
- 按固定 Markdown 模板导入的本地单词本，支持分页、按日期浏览、高频词标记和显式编辑。
- 单词或词义遮盖、批量记忆模式及阅读状态重置。
- 不跟随系统的浅色、深色主题和本地主题偏好保存。
- 品牌文字重排动效，以及深色主题的红、蓝边缘环境光。
- 从右下角按钮起点展开并覆盖标题栏的柔和圆形主题切换波纹。
- 与页面连续融合、无分隔线的标题栏，同时保留原生窗口控制按钮。
- 可关闭的语言卡片封面和全局细网格背景，两项偏好均在本地保存。
- 可配置的 Markdown 模板默认导出目录；目录不可用时自动回退到系统保存面板。
- 最小窗口、键盘导航和基础辅助功能适配。

## 技术基线

- macOS 15.0+
- Swift 6
- SwiftUI
- SwiftData 本地持久化
- Xcode 16.4+
- 无云端服务和第三方运行时依赖

## 项目文档

- [产品需求](docs/产品需求.md)
- [开发路线图](docs/开发路线图.md)
- [开发规范](docs/开发规范.md)
- [ADR-001：本地优先与长期计时](docs/architecture/架构决策-001-本地优先学习计时.md)
- [ADR-002：本地结构化单词本](docs/architecture/架构决策-002-本地结构化单词本.md)
- [独立主题系统](docs/design/独立主题系统.md)
- [长期学习计时实现设计](docs/design/长期学习计时实现设计.md)
- [设置与个性化实现设计](docs/design/设置与个性化实现设计.md)

## 本地验证

```bash
xcodebuild build \
  -project Egangnal.xcodeproj \
  -scheme Egangnal \
  -configuration Debug \
  -destination 'platform=macOS'

xcodebuild test \
  -project Egangnal.xcodeproj \
  -scheme Egangnal \
  -configuration Debug \
  -destination 'platform=macOS'
```
