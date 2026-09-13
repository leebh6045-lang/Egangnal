# ECDICT 离线词库构建契约

- 状态：设计评审通过（2026-09-11）；已按[数据勘察报告](ECDICT数据勘察报告.md)修正 schema
- 日期：2026-09-11
- 关联文档：[ADR-003：公共词库与个人单词本分离](../architecture/架构决策-003-公共词库与个人单词本分离.md)；[词库实现设计](词库实现设计.md)；[ECDICT 数据勘察报告](ECDICT数据勘察报告.md)；[ECDICT 接入保姆级教程](../ECDICT接入保姆级教程.md)

## 1. 目的与定位

本文档是**规范性契约**，定义 ECDICT 到 `EgangnalLexicon.sqlite` 之间必须满足的规则：数据来源清单、许可证前置条件、等级映射、筛选规则、数据库结构、规范化协议、构建工具契约、质量门槛与版本策略。

[ECDICT 接入保姆级教程](../ECDICT接入保姆级教程.md) 是**操作手册**，负责解释每一步怎么做、为什么这么做。两者冲突时，以本文档（契约）为准；教程可随实践修订。

本契约服务于路线图阶段 **5.1**。在 5.1 完成并通过质量门槛之前，**不得开始 5.2 的 Swift 查询层**。

## 2. 数据来源与来源清单

### 2.1 数据源

- 提供方：ECDICT（<https://github.com/skywind3000/ECDICT>）
- 使用文件：`ecdict.csv`（正式构建）、`ecdict.mini.csv`（工具早期测试）、`README.md`、`LICENSE`
- 原始数据**不进入** Egangnal 仓库，只作为可重新取得的开发期输入，放在工程之外，或工程内已列入 `.gitignore` 的隔离目录 `.lexicon-source/`。
- 仓库中的 `ecdict.csv` 是**基础版本（76 万词条）**；更完整的数据在 `stardict.7z` 中。本契约**明确不采用** `stardict.7z`。

### 2.2 来源清单（source manifest）

每次构建都必须生成 `source-manifest.json`，字段如下。**所有值为实测值，不接受“最新版”之类描述。**

| 字段 | 值 |
| --- | --- |
| `provider` | `ECDICT` |
| `provider_repository` | `https://github.com/skywind3000/ECDICT` |
| `provider_commit` | `bc015ed2e24a7abef49fc6dbbb7fe32c1dadaf8b` |
| `source_filename` | `ecdict.csv` |
| `source_sha256` | `1a6947e04785db63613a92e14903cdae7954f7e84860b10e68e5c7cbb3f9c3cf` |
| `source_bytes` | `65933428` |
| `license_sha256` | `f8552dd246f61a4e064569eae6194a01c6b3d63b03bf27c6ca863593c549ed0f` |
| `readme_sha256` | `0c3f95fc7e15f7eccf65feedb58ba3ebace1fe7b7cbdd1af60c9ace4cef9094b` |
| `mini_sha256` | `6133bcc38ccfc1ed8eaf8f52a5cb567fb78f028d079647a85b4b92a99c3cf025` |
| `downloaded_at` | `2026-09-11` |
| `intended_use` | `public-free` |
| `distribution_decision` | `plan-A: MIT attribution + exclude collins/oxford/audio/detail` |
| `acquired_via` | `raw.githubusercontent.com`（直接下载，未使用 git clone） |

约束：

- 构建工具必须把 `source_sha256` 写入 SQLite 的 `metadata` 表；运行时可通过它核对产物身份。
- 若源文件摘要与清单不一致，构建必须**失败退出**，不能继续生成产物。

## 3. 许可证与发布范围

### 3.1 已记录的处置结论（2026-09-11）

**采用方案 A**：公开分发，保留 MIT 署名与许可证文本，并排除不必要的来源字段。

| 项目 | 结论 |
| --- | --- |
| 许可证 | MIT License，`Copyright (c) 2025 Linwei` |
| 分发范围 | 公开免费（Egangnal 已通过 GitHub Releases + Sparkle appcast 公开分发） |
| 署名义务 | App 内需保留完整 MIT 许可证文本与版权行 |
| 字段处置 | 首版**排除** `collins`、`oxford`、`audio`、`detail`、`pos`、`definition`、`exchange` |
| 文本处置 | `translation` 与 `phonetic` 随包分发 |

### 3.2 对来源风险的准确描述

勘察后修正了此前的一个不准确判断：

- `collins` 是**柯林斯星级**、`oxford` 是**牛津三千核心词的布尔标记**（README 明确说明），**不是**这两部词典的释义原文。二者在本 CSV 中几乎全空（空值率 98.2% / 99.5%），已排除，不构成实质风险。
- 真正需要关注的是 `translation` 文本本身。README 说明数据由 EDictAZ 文本、一份四六级至 GRE 词汇表、爬取补充的音标、以及 `cdict-1.0-1.rpm` 开源词典数据与 BNC 语料校对合并而成，属于**聚合来源**。
- 这正是选择方案 A（保留署名、最小化分发的字段集合）的依据。

### 3.3 首次公开发布前的检查项

1. 工程内存在 `Resources/Licenses/ECDICT-LICENSE.txt`，内容与 `license_sha256` 对应。
2. 设置页或关于信息中有可见的版权与许可证展示入口。
3. `source-manifest.json` 与 `build-report.json` 已提交。
4. 发布说明中记录本次使用的 `provider_commit` 与产物版本。

> 本节不是法律意见。若将来收费或商业发布，应重新判断，必要时寻求专业意见。

## 4. 等级映射

首版只保留带有目标等级标签的词条。标签到应用等级的映射固定如下：

| ECDICT 标签 | 应用等级 | 中文展示 | 勘察词条数 |
| --- | --- | --- | --- |
| `zk` | `juniorHigh` | 初中 | 1,603 |
| `gk` | `seniorHigh` | 高中 | 3,677 |
| `cet4` | `cet4` | 四级 | 3,849 |
| `cet6` | `cet6` | 六级 | 5,407 |
| — | 并集 | — | **7,116** |

约束：

- 标签解析必须按**空格切分后精确比对**，禁止子串匹配（避免未来出现名称相近标签时误判）。勘察确认 ECDICT 的 `tag` 以空格分隔，单行最多 8 个标签。
- 一个词条可属于多个等级，使用关系表保存，**不得**压成逗号拼接字符串。
- 未命中上述四类的标签（`ky`、`toefl`、`ielts`、`gre`）本阶段忽略，但原始标签值保留在 `entry_level.source_tag` 中以便诊断。
- 初中与高中**分开**展示（已确认）。
- **扩展选项**：全部 8 个标签的并集为 14,942 条。若需要更大词表，只需调整 `build_profile` 与等级映射，无需改 schema。

## 5. 首版筛选规则

一条记录进入产物，必须**同时**满足：

1. `word` 去除首尾空白后非空；
2. `translation` 去除首尾空白后非空；
3. `tag` 至少命中第 4 节四个等级之一；
4. 字段长度未超过经勘察报告批准的上限；
5. 通过规范化与基础字符检查。

勘察结果：命中四个等级的行共 7,116 条，**全部满足第 1、2 条**（被筛掉 0 行）。不满足的记录必须计入构建报告的**拒绝分类统计**，不允许静默丢弃。

本产物是“**分级学习词库**”，不是 ECDICT 完整镜像。`full` 模式（保留全部 76 万条含中文释义的词条）属于后续独立评估项，两种模式必须使用不同的 `build_profile` 与输出文件名，不得混用。

## 6. SQLite 结构

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE metadata (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE dictionary_entry (
    id                 INTEGER PRIMARY KEY,
    source_id          TEXT NOT NULL UNIQUE,  -- 稳定来源标识，跨版本不变
    entry_uuid         TEXT NOT NULL UNIQUE,  -- 构建期确定性 UUID，供 Swift 侧使用
    term               TEXT NOT NULL,         -- 展示词形
    search_term        TEXT NOT NULL,         -- 规范化查询键，普通索引
    phonetic           TEXT,                  -- 允许为空（目标子集缺失率 0.94%）
    chinese_translation TEXT NOT NULL,        -- 词性词义，换行已在构建期还原
    frequency_rank     INTEGER,               -- 0 表示无排名，排序时按缺失处理
    bnc_rank           INTEGER                -- 同上
);

CREATE TABLE entry_level (
    entry_id   INTEGER NOT NULL,
    level      TEXT    NOT NULL,
    source_tag TEXT    NOT NULL,
    PRIMARY KEY (entry_id, level),
    FOREIGN KEY (entry_id) REFERENCES dictionary_entry(id) ON DELETE CASCADE
);

CREATE INDEX dictionary_entry_search_term_index
    ON dictionary_entry(search_term);

CREATE INDEX dictionary_entry_frequency_index
    ON dictionary_entry(frequency_rank, bnc_rank);

CREATE INDEX entry_level_level_index
    ON entry_level(level, entry_id);
```

字段设计约束（含勘察修正 D1、D2、D4、D6）：

- `source_id` 与 `entry_uuid` 是**跨版本身份**，不得依赖自增 `id`。
- `search_term` 可以重复（规范化后可能碰撞），只建普通索引，**不设唯一约束**；碰撞必须记录在报告中并按批准规则处理，不得静默覆盖。勘察显示目标子集零碰撞，但检查仍保留为构建门槛。
- `entry_uuid` 生成规则：以固定命名空间字符串与 `source_id` 拼接后取 SHA-256，截断为 16 字节，设置 UUID v5 版本位与 RFC 4122 变体位，转标准 UUID 字符串。同一 `source_id` 在任意次构建中必须得到同一 UUID。
- **不使用 `pos` 字段**（D1）：勘察确认 `ecdict.csv` 中该列 100% 为空，`pos` 在 `stardict.7z` 中才有值，本契约不采用该文件。词性信息一律从 `translation` 前缀获得。
- **不保留英文释义 `definition`**（D2）：首版界面不展示；目标子集中 99.76% 有值，将来需要时可加列重建。
- **`chinese_translation` 的换行在构建期还原**（D4）：源文件用字面 `\n`（反斜杠 + n）表示换行，勘察确认**不存在真实换行符**，因此还原无歧义。规则：`\n` → 换行；字面 `\r`（勘察中仅 1 条）→ 视为行分隔。还原版本记录在 `translation_unescape_version`。
- **`frequency_rank` / `bnc_rank` 的 `0` 表示无排名**（D6），不是"第 0 名"；排序实现必须把 `0` 当作缺失并排在最后。目标子集中非 0 占比分别为 97.36% 与 98.48%。
- 派生“测验用简短释义”在 Swift 侧完成，不写入数据库。

### 6.1 `metadata` 必需键

```text
schema_version              产物结构版本，App 打开时首先校验
builder_version             构建工具版本
build_profile               graded / full
normalization_version       查询键规范化协议版本
translation_unescape_version 换行还原协议版本
provider                    ECDICT
provider_repository
provider_commit
source_filename
source_sha256
license_sha256
generated_at
entry_count
level_relation_count
rejected_record_count
```

## 7. 查询键规范化协议

`search_term` 必须与 Swift 侧英语 `WordNormalizer.normalizedTerm(_:in:.english)` 保持一致：

1. 去除首尾空白；
2. 连续空白折叠为单个 ASCII 空格；
3. Unicode NFC 规范化；
4. 按 `en_US_POSIX` 规则转小写。

```text
normalization_version = "en-v1"
```

约束：

- 协议必须版本化；一旦变更，`search_term` 需整体重建并提升版本号。
- Python 与 Swift 的大小写与 Unicode 规则并非天然一致，**必须**准备同一份固定样例集，在构建期与运行期各跑一次并断言结果相同。仅靠肉眼比对不算通过。
- 前缀检索在 Swift 侧使用范围查询（`>=` 与 `<` 上界），不使用 `LIKE` 拼接。
- ECDICT 自身还有一个隐藏字段 `sw`（去除所有非字母数字后小写）用于模糊匹配。首版**不采用**；是否需要额外的变体匹配留待 5.2 评估。

## 8. 构建工具契约

位置：`tools/lexicon-builder/`（Python，**仅在开发期运行，不进入 App，也不要求最终用户安装 Python**）。

- 只依赖 Python 标准库（`csv`、`hashlib`、`json`、`sqlite3`、`unicodedata`、`tempfile`、`pathlib` 等），避免构建环境差异。
- CSV 必须由标准 CSV 解析器读取，**禁止**按行切逗号。勘察确认 770,611 行可用标准解析器零错误读完。
- 构建流程：校验来源摘要 → 解析 → 清洗筛选 → 还原换行 → 建临时库 → 完整性检查 → 生成报告 → **原子替换**正式产物。
- 全过程在事务中完成；任何一步失败都不得留下半成品或替换正式产物。
- 输出：
  - `EgangnalLexicon.sqlite`
  - `source-manifest.json`
  - `build-report.json`
- 退出码约定：`0` 成功；非 `0` 表示失败，且必须输出可读原因，不得“部分成功”。

## 9. 质量门槛与校验报告

`build-report.json` 至少包含：

- 源文件摘要与记录总数；
- 各等级命中数量与多标签分布；
- 各拒绝原因的分类计数（空词、空释义、无目标标签、超长字段、字符检查失败）；
- `search_term` 碰撞数量与处理结果；
- 音标缺失率、释义为空率（应为 0）、释义长度分布（最大 / 中位）；
- 最终 `entry_count`、`level_relation_count`；
- 产物文件大小。

通过门槛（基于勘察基线，可在实现时收紧）：

1. `entry_count` = **7,116**（允许因规范化或清洗规则微调，但偏离超过 1% 必须说明原因）；
2. 四个等级均非空，且各等级数量与勘察值（1,603 / 3,677 / 3,849 / 5,407）偏差不超过 1%；
3. `chinese_translation` 为空的数量为 0；
4. 无未处理的 `search_term` 碰撞（勘察基线为 0）；
5. 同一输入两次构建，除 `generated_at` 外产物内容一致（可复现）；
6. App 侧 `schema_version` 校验通过；
7. 固定样例集在 Python 与 Swift 两侧规范化结果一致；
8. 换行还原后不存在字面 `\n` 残留。

## 10. 版本与更新策略

四个版本号各自独立演进：

| 版本 | 变化时机 | 影响 |
| --- | --- | --- |
| `schema_version` | 表结构或必需 `metadata` 键变化 | App 必须能明确拒绝不兼容产物 |
| `builder_version` | 构建逻辑变化 | 记录可追溯性 |
| `normalization_version` | 查询键协议变化 | 必须重建 `search_term` |
| `translation_unescape_version` | 换行/转义还原规则变化 | 必须重建 `chinese_translation` |

- 产物随 App 发版整体替换；本阶段不做热更新。
- App 打开数据库时先读 `schema_version`；不兼容时显示明确错误，不尝试查询未知结构。
- 产物与 App 版本必须成对记录在构建报告与发布说明中。

## 11. 产物交付与 Git 策略

| 内容 | 是否提交 | 理由 |
| --- | --- | --- |
| `EgangnalLexicon.sqlite` | 提交 | 实测约 2.5 MB，无它则无法构建可运行 App |
| `source-manifest.json`、`build-report.json` | 提交 | 可追溯性与评审依据 |
| `tools/lexicon-builder/` 源码 | 提交 | 可复现 |
| 原始 `ecdict.csv` / `.lexicon-source/` | **不提交** | 可重新取得的构建输入，63 MB 且会掩盖 diff |
| ECDICT `LICENSE` 文本 | 提交到 `Resources/Licenses/` | 许可证义务（首次发版前完成） |

若将来产物超过约 50 MB，再评估 Git LFS 或服务端增量更新（见 ADR-003 决策 3）。

## 12. 验收标准

5.1 完成的判定条件：

- 来源清单与实际文件摘要一致，且可被构建工具复核。
- 许可证处置结论已记录（方案 A），并已完成第 3.3 节检查项。
- 构建工具可在干净环境用标准库重复运行，并生成一致的产物。
- `build-report.json` 满足第 9 节全部门槛。
- 数据库可被只读打开，`schema_version` 与 `metadata` 完整。
- 固定样例的规范化结果与 Swift 侧一致。
- 本阶段**不产生任何业务代码改动**，只有工具、数据产物与文档。
