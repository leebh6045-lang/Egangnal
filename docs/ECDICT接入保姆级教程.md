# Egangnal 接入 ECDICT 保姆级教程

> 文档状态：实施前教程，尚未修改业务代码
>
> 编写日期：2026-09-10
>
> 适用工程：Egangnal（macOS 15.0+、Swift 6、SwiftUI、SwiftData）

## 1. 这份教程解决什么问题

这份教程说明如何把 ECDICT 中的英文词条、中文释义、英文释义、音标和考试标签，经过可重复、可检查的开发期转换，生成 Egangnal 自己的只读 SQLite 词库。

最终目标不是“把 ECDICT 整个仓库塞进应用”，而是形成下面这条数据链路：

```text
固定版本的 ECDICT ecdict.csv
    -> 校验来源和文件摘要
    -> 按明确规则解析、筛选和清洗
    -> 生成 EgangnalLexicon.sqlite.tmp
    -> 完整性检查和质量报告
    -> 原子替换为 EgangnalLexicon.sqlite
    -> 随 macOS App 只读打包
    -> Swift 仓储查询
    -> 用户确认并收藏
    -> 写入现有 SwiftData 个人单词本
```

这份文档同时明确：

- 哪些资料需要你从 ECDICT 项目取得或亲自确认；
- 哪些工程工作可以由我完成；
- 每一个阶段应该产生什么文件；
- 每一步如何验收；
- 哪些事情现在不应该提前做。

## 2. 先统一术语

你前面提到的“中英文词源”，在当前需求中更准确的说法是“英文词条及其中英文释义”。

严格意义上的“词源”是 etymology，例如一个英语单词来自拉丁语还是法语。ECDICT 的核心能力不是系统性的历史词源学，而是英汉词典数据。

本教程使用以下术语：

- **词条**：例如 `abandon`。
- **英文释义**：ECDICT 的 `definition` 字段。
- **中文释义**：ECDICT 的 `translation` 字段。
- **音标**：ECDICT 的 `phonetic` 字段。
- **等级标签**：ECDICT 的 `tag` 字段，例如 `zk`、`gk`、`cet4`、`cet6`。
- **公共词库**：所有用户可浏览的 ECDICT 派生数据。
- **个人单词本**：用户明确收藏后写入 Egangnal SwiftData 的数据。
- **构建工具**：只在开发期间运行、负责 CSV 到 SQLite 转换的程序。

## 3. ECDICT 是什么

ECDICT 项目地址：<https://github.com/skywind3000/ECDICT>

ECDICT 是一份可供程序处理的英汉词典数据库。仓库当前提供的主要文件包括：

| 文件 | 用途 | 第一阶段是否需要 |
| --- | --- | --- |
| `README.md` | 字段、标签和工具说明 | 必须阅读并保存版本 |
| `LICENSE` | 项目许可证 | 必须取得并审核 |
| `ecdict.csv` | 主要词典数据 | 必须 |
| `ecdict.mini.csv` | 很小的格式样例 | 适合最初开发和测试 |
| `lemma.en.txt` | 单词变形到原形的辅助数据 | 暂不需要 |
| `stardict.py` | 项目自带的 CSV/SQLite 操作工具 | 只作参考 |
| `stardict.7z` | 项目预生成的较大词典包 | 第一阶段不采用 |

根据当前仓库说明，`ecdict.csv` 字段为：

```csv
word,phonetic,definition,translation,pos,collins,oxford,tag,bnc,frq,exchange,detail,audio
```

常用字段的含义：

| 字段 | 含义 | Egangnal 第一版处理方式 |
| --- | --- | --- |
| `word` | 英文词条 | 必须，原样保存展示值 |
| `phonetic` | 音标 | 可为空，原样保存 |
| `definition` | 英文释义 | 可为空，原样保存 |
| `translation` | 中文释义 | 第一版要求非空 |
| `pos` | 词性及其比例信息 | 可为空，先原样保存 |
| `tag` | 考试和用途标签 | 解析成多值关系 |
| `bnc` | BNC 词频排名 | 正整数保存，否则置空 |
| `frq` | 当代词频排名 | 正整数保存，否则置空 |
| `exchange` | 复数、时态、原形等变化 | 可为空，先原样保存 |
| `collins` | Collins 标记 | 第一版不导入 |
| `oxford` | Oxford 标记 | 第一版不导入 |
| `detail` | 扩展 JSON | 第一版不导入 |
| `audio` | 音频地址 | 第一版不导入 |

不导入某个字段不代表它永久无用，而是避免在来源、完整度和产品用途尚未确认时扩大范围。

## 4. ECDICT 与 WordNet 的关系

第一阶段不需要同时接入 WordNet。

ECDICT 更适合作为 Egangnal 当前的主词汇目录，因为它已经包含中文释义、音标和中国考试标签。WordNet 更适合未来补充多义项结构、同义词和语义关系。

推荐顺序：

```text
第一阶段：ECDICT -> 中英文查询、等级浏览、收藏
第二阶段：优化 ECDICT 数据质量和词形查询
第三阶段：确实需要语义关系时再评估 WordNet
```

不要在第一阶段同时处理 ECDICT、WordNet、在线翻译 API、发音 API 和复习算法。它们分别有不同的数据结构、许可证和失败方式，一次接入会让问题难以定位。

## 5. 必须遵守的开发准则

你的三条标准在本功能中具体落实为以下约束。

### 5.1 质量、健壮性和可维护性

- 原始 CSV 只通过标准 CSV 解析器读取，不能按行手工切逗号。
- 数据来源必须固定版本并记录 SHA-256。
- 转换必须在事务中进行，失败不能留下半成品数据库。
- 正式数据库只能在全部检查通过后替换。
- App 对公共 SQLite 只读访问。
- SwiftUI View 不解析 CSV、不写 SQL，也不直接修改 SwiftData。
- 查询使用 SQLite 参数绑定，不能拼接用户输入。
- 所有可失败操作使用清晰、可测试的错误类型。
- 公共词库和个人数据严格分开。
- 数据库 schema、构建工具和数据源分别拥有版本号。
- 大数据测试与小型固定样本测试分开。

### 5.2 小步开发、文档先行

实现拆成独立阶段，每个阶段开始前有文档，结束时有验收结果和单独 Git 提交。不能把数据下载、转换器、Swift 查询层、SwiftData 迁移和完整 UI 放入同一个提交。

### 5.3 简洁清晰的中文注释

代码标识符使用清晰英文，中文注释只解释：

- 为什么采用当前存储或状态策略；
- 事务和原子替换边界；
- 容易被破坏的业务不变量；
- CSV、SQLite、Swift 之间不直观的格式差异；
- 并发、文件或错误恢复行为。

应该写：

```swift
// 公共词库随 App 只读发布，用户修改必须写入独立的 SwiftData 个人数据。
```

不应该写：

```swift
// 把 term 赋值给 term。
self.term = term
```

## 6. 数据为什么不能全部写进 SwiftData

现有 SwiftData 模型服务于个人单词本：

- `WordEntry` 表示用户个人空间中的主词条；
- `WordImportBatch` 表示一次 Markdown 文档导入；
- `WordOccurrence` 表示词条出现在哪个 Markdown 文档日期；
- 高频状态来自不同 Markdown 文档日期数量；
- 单词刷当前从已导入的个人词条中抽题。

如果把 ECDICT 的大量公共词条全部创建为 `WordEntry`，会造成：

- 用户没有收藏的词也出现在个人单词本；
- SwiftData 容器无意义地膨胀；
- 首次启动需要进行大量写入；
- 数据升级和个人数据迁移耦合；
- 现有分页、日期、高频词和单词刷语义被污染。

正确边界是：

```text
EgangnalLexicon.sqlite
    公共、只读、可整体替换

SwiftData
    私人、可写、必须迁移和长期保留
```

只有用户点击“加入单词本”后，才创建或复用 `WordEntry`。

## 7. 你需要从 ECDICT 项目取得或确认什么

这一节是你的责任清单。下载操作可以由我协助执行，但许可证接受、发布目的和产品规则必须由你确认。

### 7.1 必须取得的文件

至少取得：

```text
ECDICT/LICENSE
ECDICT/README.md
ECDICT/ecdict.csv
ECDICT/ecdict.mini.csv
```

其中：

- `ecdict.mini.csv` 用于最早期转换器测试；
- `ecdict.csv` 用于生成正式候选数据库；
- `README.md` 用于确认字段和标签语义；
- `LICENSE` 用于保留许可证文本和完成发布审查。

### 7.2 必须记录的来源信息

在 ECDICT 仓库目录运行：

```bash
git rev-parse HEAD
git remote get-url origin
shasum -a 256 ecdict.csv
shasum -a 256 README.md
shasum -a 256 LICENSE
```

把结果记录为数据清单：

```text
provider: ECDICT
repository: https://github.com/skywind3000/ECDICT
commit: <完整 40 位 Git 提交号>
source_file: ecdict.csv
source_sha256: <SHA-256>
license_file_sha256: <SHA-256>
downloaded_at: <本地日期>
intended_use: personal / public-free / commercial
```

不要只记录“最新版”。“最新版”会变化，无法复现过去发布的数据库。

### 7.3 你必须确认的许可问题

ECDICT 仓库当前带有 MIT License，但 README 也说明词典由多个历史词库、语料和贡献内容整理而成。因此不能把“仓库存在 MIT 文件”简单等同于“每个字段的所有上游内容都没有再分发风险”。

你需要确认并记录：

- Egangnal 是仅个人使用，还是未来公开发布；
- 是否计划收费或商业发布；
- 当前许可证是否明确覆盖你准备分发的数据文件；
- 是否需要联系维护者确认数据集再分发范围；
- App 中如何展示版权和许可证；
- 是否排除来源需要额外审查的字段。

第一版建议排除：

- `collins`；
- `oxford`；
- `audio`；
- 来源和格式尚未核实的 `detail`。

这不是法律意见。正式公开或商业发布时，应由你完成许可证判断，必要时寻求专业意见。

### 7.4 你必须确认的产品规则

开始个人收藏模型设计前，你需要决定：

1. 界面显示“初中、高中、四级、六级”，还是把初高中合并为“中学”。
2. 如果合并，“中学”是否明确等于 `zk + gk` 的并集。
3. 一个词属于多个等级时是否在多个列表中出现。
4. 没有中文释义的词是否完全排除。
5. 没有等级标签但可以搜索到的词是否保留。
6. 用户收藏时是否允许编辑 ECDICT 中文释义。
7. 已存在个人词条时，ECDICT 释义是否禁止自动覆盖。
8. 第二天再次收藏同一个词是否新增一条收藏日期。
9. 在线/公共词库收藏是否参与现有“高频词”计算。
10. 公共词库收藏的词是否进入单词刷。

本教程的推荐默认值是：

- 初中和高中分开展示；
- 多等级词允许出现在多个筛选结果中，但公共目录中只有一条词条记录；
- 第一版等级浏览仅保留有中文释义的词；
- 无等级但有中文释义的词暂不进入等级列表；
- 用户收藏前可以修改中文释义；
- 已有个人释义不被自动覆盖；
- 同一天重复收藏幂等；
- 收藏日期与 Markdown 日期分离，不改变现有高频计算；
- 已收藏的公共词库词可以进入单词刷。

## 8. 哪些工作可以由我完成

你确认上一节的资料和规则后，我可以完成下面的工程工作。

| 工作 | 我可以完成 | 需要你提供或确认 |
| --- | --- | --- |
| 固定数据版本 | 下载或读取本地 ECDICT，生成来源清单和摘要 | 接受哪个提交和使用目的 |
| 许可证文件 | 将许可证加入工程并建立展示入口 | 确认使用范围和署名方式 |
| CSV 分析 | 统计字段完整度、标签分布、重复、异常和体积 | 确认哪些异常可以接受 |
| 转换工具 | 编写 CSV 解析、清洗、SQLite 建库和原子替换代码 | 确认保留字段和筛选规则 |
| 数据验证 | 编写完整性检查、固定样例和质量报告 | 确认质量门槛 |
| SQLite schema | 设计表、索引、metadata 和 schema 版本 | 批准架构设计文档 |
| Xcode 配置 | 添加 SQLite 资源、系统链接库和构建配置 | 是否把数据库纳入 Git |
| Swift 查询层 | 建立领域模型、协议、只读仓储和错误类型 | 首版要展示的字段 |
| 等级浏览 | 解析多标签、筛选、分页和排序 | 等级名称和排序规则 |
| 收藏闭环 | 设计 SwiftData 收藏记录、事务、幂等和迁移 | 收藏及覆盖规则 |
| UI | 实现搜索、列表、详情、收藏、加载和错误状态 | 交互与视觉确认 |
| 测试 | 编写转换器、查询、仓储、迁移和 UI 测试 | 验收规则确认 |
| 文档 | 编写 ADR、实现设计、数据报告和阶段复盘 | 批准重大决策 |

我不能替你决定或承诺：

- 代表你接受 ECDICT 或任何上游数据的许可证；
- 判断一份聚合词典必然可以商业再分发；
- 决定产品中的“中学”具体覆盖范围；
- 保证第三方释义完全准确；
- 未经你批准改变现有高频词和首次释义规则；
- 把未审查的字段默认加入正式发行版。

## 9. 推荐的工程目录

最终目录建议如下，但应按阶段逐步建立，不要现在一次创建所有空文件：

```text
Egangnal/
├── Domain/
│   ├── LexiconModels.swift
│   └── VocabularyLevel.swift
├── Data/
│   ├── EnglishLexiconRepository.swift
│   └── SQLiteEnglishLexiconRepository.swift
├── Features/
│   └── LearningMaterials/
│       ├── VocabularyCatalogStore.swift
│       ├── VocabularyCatalogView.swift
│       └── VocabularyEntryDetailView.swift
└── Resources/
    ├── Lexicon/
    │   └── EgangnalLexicon.sqlite
    └── Licenses/
        └── ECDICT-LICENSE.txt

tools/
└── ecdict-builder/
    ├── build_ecdict.py
    ├── verify_ecdict.py
    ├── schema.sql
    ├── source-manifest.example.json
    └── README.md

tests/
└── fixtures/
    └── ecdict-sample.csv

docs/
├── architecture/
│   └── 架构决策-003-公共词库与个人单词本分离.md
└── design/
    ├── ECDICT离线词库构建设计.md
    └── 公共词库收藏实现设计.md
```

原始 `ecdict.csv` 不建议提交到 Egangnal Git 仓库。它属于可重新取得的构建输入，体积大，并且会掩盖代码 diff。

## 10. 第一步：在隔离位置取得 ECDICT

### 10.1 不要直接克隆到业务源码目录

建议使用项目中的未跟踪输入目录：

```text
VendorInputs/ECDICT/
```

正式执行前，应先把以下规则加入 `.gitignore`：

```gitignore
# 第三方原始词库只作为开发期输入，不进入业务仓库。
VendorInputs/
```

然后运行：

```bash
git clone https://github.com/skywind3000/ECDICT.git VendorInputs/ECDICT
```

注意：增加 `.gitignore` 和下载数据应成为一个明确的小阶段。下载前先确认磁盘空间和网络；下载后不能直接开始改 UI。

### 10.2 固定具体提交

进入仓库并查看提交：

```bash
cd VendorInputs/ECDICT
git rev-parse HEAD
```

得到完整提交号后，回到 Egangnal 的数据清单中记录它。以后可以通过下面的方式恢复相同输入：

```bash
git checkout <已经批准的完整提交号>
```

不要在构建脚本中自动执行 `git pull`。自动更新会让相同代码在不同日期产生不同数据库。

### 10.3 计算摘要

```bash
shasum -a 256 VendorInputs/ECDICT/ecdict.csv
shasum -a 256 VendorInputs/ECDICT/LICENSE
```

构建脚本应读取数据清单，并在摘要不匹配时立即失败。

### 10.4 本阶段验收

- ECDICT 仓库存在且能读取；
- 已记录完整 Git commit；
- 已记录 `ecdict.csv` SHA-256；
- 已保存许可证副本；
- `VendorInputs/` 没有出现在 Git 暂存列表中；
- 尚未修改 SwiftData 或 SwiftUI。

## 11. 第二步：先分析 CSV，不急着建库

### 11.1 为什么必须使用标准 CSV 解析器

ECDICT 的释义字段可能包含：

- 逗号；
- 双引号；
- 多行文本；
- 中英文标点；
- 空字段。

因此不能使用下面的方式：

```python
# 错误示例：释义中的逗号和换行会破坏列结构。
columns = line.split(",")
```

必须使用 Python 标准库：

```python
import csv

with open(source_path, "r", encoding="utf-8", newline="") as source:
    reader = csv.DictReader(source)
    for row in reader:
        word = row["word"]
        translation = row["translation"]
```

`newline=""` 必须保留，让 `csv` 模块正确处理引号中的换行。

### 11.2 第一份分析报告应包含什么

在建库前只扫描 CSV，生成报告：

```text
总记录数
字段名是否完全符合预期
空 word 数
空 translation 数
空 definition 数
空 phonetic 数
zk/gk/cet4/cet6 各自数量
各等级交集数量
无目标等级的数量
大小写不敏感重复数量
规范化后冲突数量
最长单词、释义和音标长度
包含控制字符的记录数量
无法解析的整数排名数量
```

报告必须给异常样例，但应限制数量，例如每类最多输出前 20 条，防止日志失控。

### 11.3 正确解析标签

`tag` 是以空格分隔的多个值，应这样判断：

```python
tags = set(row["tag"].split())
is_cet4 = "cet4" in tags
```

不能使用模糊子串判断：

```python
# 不推荐：未来若出现名称相似标签，可能误判。
is_cet4 = "cet4" in row["tag"]
```

### 11.4 推荐等级映射

```python
LEVEL_MAPPING = {
    "zk": "middle_school",
    "gk": "high_school",
    "cet4": "cet4",
    "cet6": "cet6",
}
```

如果产品最终合并为“中学”，也不要在原始导入时销毁 `zk` 和 `gk` 的差异。可以在 UI 或查询层组合，底层仍保留原始等级映射。

### 11.5 本阶段验收

- 能完整扫描 `ecdict.mini.csv` 和 `ecdict.csv`；
- CSV 中的多行释义没有被拆成错误记录；
- 字段缺失会明确失败；
- 标签以集合方式解析；
- 报告包含数量和有限异常样例；
- 没有生成正式 SQLite；
- 扫描结果经过人工阅读并批准。

## 12. 第三步：确定首版筛选范围

ECDICT 的词条量很大，但 Egangnal 第一阶段只需要等级词库闭环。

推荐首版只导入同时满足以下条件的记录：

1. `word` 清理后不为空；
2. `translation` 清理后不为空；
3. `tag` 至少包含 `zk`、`gk`、`cet4`、`cet6` 中一个；
4. 字段长度没有超过经过报告批准的上限；
5. 记录能通过规范化和基础字符检查。

这会生成“分级学习词库”，不是 ECDICT 的完整镜像。

未来需要任意英文查询时，再单独评估第二种模式：

```text
graded：只包含目标考试等级，体积小，适合第一版
full：保留所有具有中文释义的词，适合后续全文查询
```

两种模式不能共享模糊不清的输出文件名，应分别记录构建配置。

## 13. 第四步：设计 Egangnal 自己的 SQLite

### 13.1 为什么不直接使用 `stardict.7z`

ECDICT 自带的预构建数据库方便人工使用，但 Egangnal 第一阶段更适合从 CSV 建立自己的 schema，因为这样可以：

- 明确只保留哪些字段；
- 记录来源 commit 和 SHA-256；
- 对等级建立结构化关系；
- 控制索引和 schema 版本；
- 对异常执行一致的拒绝规则；
- 编写完全属于 Egangnal 的确定性测试。

`stardict.py` 可以作为格式参考，不建议直接成为 App 的运行时依赖。

### 13.2 推荐 schema

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE dictionary_entry (
    id INTEGER PRIMARY KEY,
    source_id TEXT NOT NULL UNIQUE,
    term TEXT NOT NULL,
    search_term TEXT NOT NULL,
    phonetic TEXT,
    english_definition TEXT,
    chinese_translation TEXT NOT NULL,
    part_of_speech TEXT,
    bnc_rank INTEGER,
    frequency_rank INTEGER,
    exchange TEXT
);

CREATE TABLE entry_level (
    entry_id INTEGER NOT NULL,
    level TEXT NOT NULL,
    source_tag TEXT NOT NULL,
    PRIMARY KEY (entry_id, level),
    FOREIGN KEY (entry_id) REFERENCES dictionary_entry(id)
        ON DELETE CASCADE
);

CREATE INDEX dictionary_entry_search_term_index
ON dictionary_entry(search_term);

CREATE INDEX dictionary_entry_frequency_index
ON dictionary_entry(frequency_rank, bnc_rank);

CREATE INDEX entry_level_level_index
ON entry_level(level, entry_id);
```

### 13.3 字段设计说明

- `source_id`：转换器生成的稳定来源标识，不能依赖 SQLite 自增 ID 作为跨版本身份。
- `term`：保留 ECDICT 原始展示词条。
- `search_term`：按固定协议生成的查询键，可以有相同值，因此只建普通索引。
- `chinese_translation`：第一版筛选要求非空。
- `english_definition` 和 `phonetic`：允许为空，因为源数据可能缺失。
- `entry_level`：保存多等级关系，不能把等级压成一个字符串。
- `source_tag`：保留 `zk`、`gk` 等原始标签，方便诊断映射。

不要默认 `search_term` 唯一。大小写、空格、连接符和 Unicode 规范化后可能发生冲突。转换器应记录冲突并按批准规则处理，不能静默覆盖。

### 13.4 metadata 必须保存什么

```text
schema_version
builder_version
build_profile
provider
provider_repository
provider_commit
source_filename
source_sha256
license_sha256
generated_at
entry_count
level_relation_count
normalization_version
```

App 打开数据库时首先检查 `schema_version`。版本不兼容时应显示明确错误，而不是继续查询未知结构。

## 14. 第五步：编写可重复的构建工具

### 14.1 工具只依赖 Python 标准库

第一版可以只使用：

```python
csv
hashlib
json
os
pathlib
sqlite3
tempfile
unicodedata
```

这样不需要用户安装额外 Python 包，也减少构建环境差异。

Python 只用于开发期生成数据库。正式 macOS App 不启动 Python，也不要求最终用户安装 Python。

### 14.2 查询键规范化

规范化协议必须写进设计文档并拥有版本号。建议与现有英语 `WordNormalizer` 保持同一思路：

```text
去除首尾空白
连续空白折叠成一个 ASCII 空格
Unicode NFC 组合规范化
使用稳定英语规则转小写
```

Python 与 Swift 的 Unicode 小写规则并非在所有字符上天然完全一致，因此必须准备跨语言固定样例测试。不要只凭肉眼认为两边结果相同。

### 14.3 整数字段解析

`bnc` 和 `frq` 只有正整数才写入：

```python
def positive_integer_or_none(raw_value: str):
    cleaned = raw_value.strip()
    if not cleaned:
        return None

    value = int(cleaned)
    return value if value > 0 else None
```

无法转换的非空值应该记录并按批准规则失败或跳过，不能随意变成 `0`。

### 14.4 用事务构建

构建顺序：

```text
读取并验证来源清单
    -> 校验 CSV SHA-256
    -> 创建临时 SQLite
    -> 创建 schema
    -> BEGIN IMMEDIATE
    -> 批量插入词条和等级关系
    -> 检查数量、外键和冲突
    -> COMMIT
    -> 创建或确认索引
    -> PRAGMA foreign_key_check
    -> PRAGMA integrity_check
    -> 执行固定查询样例
    -> 写出质量报告
    -> 原子替换正式输出
```

任何一步失败时：

- 回滚事务；
- 删除临时输出；
- 保留上一个已经验证的正式数据库；
- 返回非零退出码；
- 输出可定位的错误信息。

### 14.5 不允许静默覆盖冲突

不能使用没有报告的 `INSERT OR REPLACE`。它可能让后出现的记录静默覆盖先出现的词条。

遇到重复或规范化冲突时，应：

1. 收集原始行号和两个词条；
2. 输出到质量报告；
3. 按设计文档中的确定规则选择保留、合并或拒绝；
4. 为该规则编写测试。

## 15. 第六步：验证生成的 SQLite

### 15.1 数据库级检查

构建后至少运行：

```sql
PRAGMA integrity_check;
PRAGMA foreign_key_check;
```

期望：

```text
integrity_check -> ok
foreign_key_check -> 0 行
```

### 15.2 固定样例查询

查询一个单词：

```sql
SELECT
    term,
    phonetic,
    english_definition,
    chinese_translation,
    part_of_speech
FROM dictionary_entry
WHERE search_term = 'abandon';
```

查询 CET4：

```sql
SELECT
    entry.id,
    entry.term,
    entry.chinese_translation
FROM dictionary_entry AS entry
JOIN entry_level AS level
    ON level.entry_id = entry.id
WHERE level.level = 'cet4'
ORDER BY
    COALESCE(entry.frequency_rank, 2147483647),
    entry.search_term
LIMIT 20 OFFSET 0;
```

查询一个词的全部等级：

```sql
SELECT level, source_tag
FROM entry_level
WHERE entry_id = ?
ORDER BY level;
```

最后一个查询中的 `?` 表示绑定参数，不是字符串替换。

### 15.3 质量报告

每次正式构建都生成 JSON 和适合阅读的 Markdown 报告，至少包含：

```text
来源 commit 和 SHA-256
构建配置和工具版本
读取、导入、跳过的记录数
每种等级词数
等级交集数量
空字段统计
冲突和拒绝记录统计
数据库文件大小
固定样例查询结果
integrity_check 结果
foreign_key_check 结果
```

质量报告是发布证据，不应该只打印在终端后丢失。

## 16. 第七步：把 SQLite 加入 Xcode

只有转换器和数据库检查稳定后，才进入这一阶段。

### 16.1 放置数据库

目标位置：

```text
Egangnal/Resources/Lexicon/EgangnalLexicon.sqlite
```

许可证放置：

```text
Egangnal/Resources/Licenses/ECDICT-LICENSE.txt
```

### 16.2 Xcode 中检查资源

1. 将 SQLite 和许可证文件加入 Xcode 工程。
2. 确认 Target Membership 包含 `Egangnal`。
3. 在 Build Phases 的 Copy Bundle Resources 中确认两个文件存在。
4. 链接系统库 `libsqlite3.tbd`。
5. 构建后检查 `.app` 包内确实存在数据库和许可证。

如果使用 Xcode 的文件系统同步分组，也必须通过构建产物验证，不能只看项目导航器里显示了文件。

### 16.3 是否提交生成数据库

必须在看到实际体积和发布流程后决定：

- 数据库较小且许可允许时，可以随源码提交；
- 体积较大时，可以使用 Git LFS 或受校验的发布构建输入；
- 无论采用哪种方式，构建工具、schema、来源清单和质量报告都应进入版本控制；
- 不能在构建时无校验地下载 `master` 最新词库。

这项选择应写入 ADR，不由脚本临时决定。

## 17. 第八步：建立 Swift 只读查询层

### 17.1 领域模型

SQLite 行不能直接进入 SwiftUI。先转换为领域快照：

```swift
enum VocabularyLevel: String, CaseIterable, Sendable {
    case middleSchool
    case highSchool
    case cet4
    case cet6
}

struct LexiconEntrySnapshot: Identifiable, Equatable, Sendable {
    let id: Int64
    let term: String
    let phonetic: String?
    let englishDefinition: String?
    let chineseTranslation: String
    let partOfSpeech: String?
    let levels: Set<VocabularyLevel>
}
```

正式类型还需要根据产品规则决定命名和字段，不应未经设计直接复制概念代码。

### 17.2 仓储协议

```swift
protocol EnglishLexiconRepository: Sendable {
    func lookup(term: String) async throws -> [LexiconEntrySnapshot]

    func entries(
        level: VocabularyLevel,
        limit: Int,
        offset: Int
    ) async throws -> [LexiconEntrySnapshot]
}
```

SwiftUI 只能依赖协议，不能依赖 SQLite C API。

### 17.3 只读打开数据库

```swift
guard let databaseURL = Bundle.main.url(
    forResource: "EgangnalLexicon",
    withExtension: "sqlite",
    subdirectory: "Lexicon"
) else {
    throw LexiconRepositoryError.resourceMissing
}
```

使用 SQLite 只读标志：

```swift
let result = sqlite3_open_v2(
    databaseURL.path,
    &database,
    SQLITE_OPEN_READONLY,
    nil
)
```

不要把公共数据库复制到 SwiftData 目录后再修改。词库版本升级应整体替换 App Bundle 中的资源。

### 17.4 查询必须绑定参数

SQL：

```sql
SELECT id, term, phonetic, english_definition, chinese_translation
FROM dictionary_entry
WHERE search_term = ?
ORDER BY term;
```

Swift 使用 `sqlite3_bind_text` 绑定查询键。不能这样写：

```swift
// 错误示例：用户输入不允许拼接进 SQL。
let sql = "SELECT * FROM dictionary_entry WHERE search_term = '\(term)'"
```

### 17.5 错误类型

至少区分：

```swift
enum LexiconRepositoryError: LocalizedError {
    case resourceMissing
    case openFailed
    case unsupportedSchema
    case corruptedDatabase
    case statementPreparationFailed
    case parameterBindingFailed
    case queryFailed
}
```

没有查到单词应正常返回空数组，不属于数据库错误。

### 17.6 并发边界

SQLite 连接应由单一仓储或 actor 管理，不能让多个 View 各自持有并随意跨线程使用同一个裸指针。具体采用 actor、每次查询独立只读连接还是串行访问，需要在实现设计中结合查询性能测试决定。

## 18. 第九步：实现词汇大全界面

第一版界面只实现完整但克制的操作闭环：

- 搜索框；
- 初中、高中、CET4、CET6 分段筛选；
- 稳定分页；
- 英文词条；
- 音标；
- 中文释义；
- 可选英文释义和词性；
- 多等级标记；
- 加入个人单词本；
- 已收藏状态；
- 空结果、加载、资源缺失和数据库错误状态。

第一版不做：

- 全量无限滚动；
- Collins/Oxford 标记；
- 在线发音；
- WordNet 语义图；
- 云端账号；
- 自动翻译；
- 间隔复习算法。

页面调用关系：

```text
VocabularyCatalogView
    -> VocabularyCatalogStore
        -> EnglishLexiconRepository
            -> SQLiteEnglishLexiconRepository
```

View 只渲染状态和发送用户意图。搜索防抖、取消旧查询、分页状态和错误转换由 Store 协调。

## 19. 第十步：收藏到个人单词本

### 19.1 不复用 Markdown 出现记录

现有 `WordOccurrence` 的日期是 Markdown 文档内容元数据，不是用户收藏日期。不能通过伪造 `WordImportBatch` 或 `sourceFilename` 来表示“今天从 ECDICT 收藏”。

否则会错误影响：

- 按 Markdown 日期浏览；
- 高频词判断；
- 导入批次诊断；
- 单词刷候选范围。

### 19.2 新增独立收藏记录

正式编码前需要单独的数据模型设计和 SwiftData 迁移文档。概念模型可以是：

```swift
@Model
final class WordBookAcquisition {
    @Attribute(.unique) var acquisitionKey: String
    var languageSpaceID: String
    var wordEntryID: UUID
    var sourceKindRawValue: String
    var provider: String
    var providerEntryID: String
    var providerCommit: String
    var collectedDateKey: String
    var collectedYear: Int
    var collectedMonth: Int
    var collectedDay: Int
    var createdAt: Date
}
```

这是方向说明，不是已批准的生产模型。

### 19.3 收藏事务

点击“加入单词本”后：

```text
读取用户选中的公共词条快照
    -> 使用现有 WordNormalizer 规范化
    -> 在英语空间查询 WordEntry
    -> 不存在则创建，存在则按首次释义规则复用
    -> 创建当天 WordBookAcquisition
    -> 同日重复收藏保持幂等
    -> 一次 SwiftData save
    -> 任意失败则 rollback
```

收藏时应保存中文释义快照。未来 ECDICT 升级时不能静默改写用户已经确认或编辑过的释义。

收藏日期使用用户本地自然日，由仓储参数明确传入，不使用词库构建时间或网络服务器时间。

## 20. 测试要求

### 20.1 CSV 分析和转换测试

- UTF-8 CSV 可以读取；
- 带逗号、双引号和多行释义的记录正确解析；
- 缺少必需列时明确失败；
- SHA-256 不匹配时拒绝构建；
- 标签使用精确集合匹配；
- 空单词和空中文释义按规则处理；
- 多等级词产生多条 `entry_level`；
- 重复和规范化冲突不会静默覆盖；
- 非法排名不会变成合法排名；
- 构建失败不会覆盖旧数据库；
- 相同输入和配置产生相同业务数据。

### 20.2 SQLite 验证测试

- `integrity_check` 返回 `ok`；
- `foreign_key_check` 没有结果；
- metadata 完整且版本匹配；
- 目标表和索引存在；
- 固定样例能查到中英文释义；
- CET4/CET6 分页没有同一关系重复；
- 查询计划使用目标索引；
- 数据库大小和记录数没有异常突变。

### 20.3 Swift 查询层测试

- 精确查询；
- 大小写和空白规范化；
- 不存在的词返回空数组；
- 特殊字符不能改变 SQL 结构；
- 等级分页在 0、1、20、21、40、41 条边界正确；
- 多等级正确映射；
- schema 不兼容时明确失败；
- 数据库缺失和损坏时明确失败；
- 查询取消不会覆盖较新的页面状态；
- 并发查询不会崩溃或串结果。

### 20.4 收藏仓储测试

- 首次收藏创建个人词条和当天收藏记录；
- 同一天重复收藏幂等；
- 已有个人词条不会重复创建；
- 已有中文释义不会被静默覆盖；
- 收藏使用英语空间；
- 写入失败整体回滚；
- Markdown 日期和收藏日期互不污染；
- ECDICT 升级不改写历史个人释义；
- 已收藏词按批准规则进入单词刷。

### 20.5 UI 验收

- 默认窗口和 `820 x 560` 最小窗口没有重叠或截断；
- 键盘可以聚焦搜索、筛选、分页和收藏；
- VoiceOver 能读出词条、等级和收藏状态；
- 深浅主题清晰；
- 搜索中、空结果和失败状态不会造成布局跳动；
- 快速连续搜索不会显示旧结果；
- 重复点击收藏不会创建重复数据。

## 21. 推荐阶段与 Git 提交粒度

### 阶段 A：数据来源和许可清单

交付物：

- 固定 ECDICT commit；
- CSV 与许可证 SHA-256；
- 数据用途说明；
- 保留和排除字段；
- 许可证展示方案；
- 产品规则确认。

验收：只有文档和来源清单，不修改业务代码。

建议提交：

```text
docs: define ECDICT source and licensing boundary
```

### 阶段 B：CSV 分析器

交付物：

- 小样本 fixture；
- CSV 扫描工具；
- 字段和标签统计；
- 异常报告；
- 自动化测试。

验收：能分析完整 CSV，但不生成生产数据库。

### 阶段 C：SQLite 构建器

交付物：

- schema；
- 构建工具；
- 来源摘要检查；
- 临时文件和原子替换；
- 完整性检查；
- 质量报告。

验收：只生成首版分级词库，不修改 SwiftUI。

### 阶段 D：Swift 只读查询层

交付物：

- 领域模型和仓储协议；
- SQLite 只读实现；
- 小型测试数据库；
- 查询、错误和并发测试。

验收：通过单元测试查询，不建立收藏模型。

### 阶段 E：词汇大全界面

交付物：

- 搜索、等级筛选和分页；
- 词条详情；
- 空态和错误态；
- 最小窗口与辅助功能测试。

验收：只能浏览，暂不写个人数据。

### 阶段 F：收藏闭环

交付物：

- 新 ADR 或数据模型设计；
- SwiftData 迁移方案；
- 收藏事务；
- 当天生词浏览；
- 单词刷候选规则；
- 数据和 UI 回归测试。

验收：公共数据和个人数据边界保持清晰。

每个阶段完成后：

1. 审查 `git diff`；
2. 执行对应单元测试；
3. 执行 Debug 构建；
4. 涉及 UI 时执行相关 UI 测试；
5. 更新文档状态和验证记录；
6. 创建单一目的的 Git 提交。

## 22. 第一次开始实施时，你要给我的内容

可以按照下面的清单准备：

```text
[ ] Egangnal 是仅个人使用、公开免费还是计划商业发布
[ ] 批准使用的 ECDICT 完整 Git commit
[ ] ECDICT 仓库或 ecdict.csv 的本地路径
[ ] ecdict.csv SHA-256
[ ] LICENSE 文件
[ ] README.md 文件或对应 commit
[ ] 是否保留英文释义
[ ] 是否保留音标
[ ] 是否保留词性
[ ] 是否保留词频排名
[ ] 是否保留词形变化
[ ] 等级展示为“初中/高中/CET4/CET6”还是“中学/CET4/CET6”
[ ] 没有等级标签的词是否允许通过搜索出现
[ ] 用户是否可以编辑收藏前的中文释义
[ ] 已存在个人词条时是否保持首次释义
[ ] 收藏词是否进入单词刷
```

如果 ECDICT 已经位于你的电脑上，只需要告诉我本地目录，不要复制 60 MB 以上的 CSV 内容到聊天中。

你不需要提供 API Key。ECDICT 的推荐第一版是完全离线的 SQLite 资源，不涉及网络接口鉴权。

## 23. 常见错误及处理方式

### 23.1 用 Excel 打开再另存 CSV

风险：编码、引号、多行释义和字段格式可能被改变。

处理：转换器直接读取原始 UTF-8 `ecdict.csv`，不经过电子表格另存。

### 23.2 按逗号手工切割

风险：释义中的逗号和换行破坏列结构。

处理：只使用标准 CSV 解析器。

### 23.3 直接使用 `master` 最新数据

风险：今天和下个月生成的 App 数据不同，无法复现错误。

处理：固定完整 commit 和 SHA-256。

### 23.4 直接采用预构建 `stardict.7z`

风险：字段、schema、筛选范围和构建证据不由 Egangnal 控制。

处理：第一版从固定 CSV 构建自己的数据库。

### 23.5 把等级保存在一个字符串中

风险：多等级查询困难，容易发生子串误判。

处理：使用 `entry_level` 关系表。

### 23.6 把公共词条写进 SwiftData

风险：个人数据和公共目录混合，升级和查询语义混乱。

处理：公共 SQLite 只读；收藏后才写 SwiftData。

### 23.7 用 ECDICT 覆盖用户释义

风险：词库升级破坏用户已经整理的内容。

处理：收藏时保存快照，之后只由用户主动编辑。

### 23.8 在 View 中直接写 SQL

风险：无法测试、状态难管理、错误处理重复。

处理：使用 View -> Store -> Repository 单向依赖。

### 23.9 认为 MIT 文件自动解决所有数据来源问题

风险：聚合数据的部分上游字段可能需要额外核查。

处理：记录发布用途、排除高风险字段，并在正式发行前完成许可审查。

## 24. 当前推荐结论

Egangnal 的 ECDICT 第一版应采用以下方案：

1. 固定一个经过确认的 ECDICT commit；
2. 记录 `ecdict.csv` 和许可证 SHA-256；
3. 原始 ECDICT 放在 Git 忽略的开发输入目录；
4. 先用 `ecdict.mini.csv` 开发解析器；
5. 首版只构建 `zk`、`gk`、`cet4`、`cet6` 且有中文释义的分级词库；
6. 排除 `collins`、`oxford`、`detail` 和 `audio`；
7. 使用自己的、带 schema 版本和来源 metadata 的 SQLite；
8. App 只读查询 SQLite，不依赖 Python 和在线 API；
9. 公共词库不写入 SwiftData；
10. 用户收藏后才创建个人词条和独立收藏日期；
11. 不复用 Markdown `WordOccurrence` 表示收藏；
12. 每个阶段先文档、再实现、测试、验收和单独提交；
13. 后续代码只在关键约束、异常边界和设计原因处写简洁中文注释。

按这条路线，真正的第一项工作是“阶段 A：固定数据来源、许可边界和产品规则”，而不是立即修改词汇大全页面。阶段 A 通过后，再开始小样本 CSV 分析器。
