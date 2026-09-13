# Egangnal 接入 WordNet 保姆级教程

> 文档状态：方案草案，尚未开始业务代码实现
> 编写日期：2026-09-10
> 适用工程：Egangnal（macOS 15.0+、Swift 6、SwiftUI、SwiftData）

## 1. 先纠正名称：是 WordNet，不是 WorkNet

WordNet 是普林斯顿大学维护的英语词汇语义数据库。它不是一个需要 API Key 的在线词典接口，也不是中学、CET4、CET6 考试词表。

WordNet 把单词按照“具体词义”组织成同义词集合，即 `synset`。例如 `bank` 至少包含“银行”和“河岸”两个不同词义。应用查询 `bank` 时，不应只取第一条释义，而应把多个词义呈现给用户选择。

WordNet 能提供：

- 英语单词及其词性；
- 每个词义的英文定义；
- 部分英文例句；
- 同义词；
- 上位词、下位词、反义词等语义关系；
- 名词、动词、形容词、副词的基础词形数据。

WordNet 不能直接提供：

- 中文释义；
- 音标和真人发音；
- 中学、CET4、CET6 等中国考试等级；
- 针对中国英语学习者排序过的常用义项；
- 每个单词的学习难度和复习计划。

因此，Egangnal 不能只靠 WordNet 完成整个词汇大全。推荐组合是：

```text
WordNet                 -> 英文词义、词性、同义词和语义关系
有授权的中文词典/API    -> 中文释义、音标、发音
有授权的分级词表         -> 中学、CET4、CET6 标签
Egangnal 本地数据        -> 收藏日期、个人释义、掌握和复习状态
```

## 2. 最终要得到什么

第一阶段的理想用户流程是：

```text
进入英语“学习资料”
    -> 选择中学 / CET4 / CET6，或输入单词搜索
    -> 查看单词的多个 WordNet 词义
    -> 选择一个词义并填写或确认中文释义
    -> 点击“加入单词本”
    -> 该词进入当天收录的生词
    -> 后续可以在单词本和单词刷中使用
```

要特别区分两类数据：

1. **公共词库数据**：所有用户都可以浏览，内容量很大，随应用只读提供。
2. **个人学习数据**：用户真正收藏的词、中文释义、收藏日期及未来的掌握状态。

公共词库不能全部写成现有的 `WordEntry`。`WordEntry` 只应该在用户明确收藏后产生或复用。

## 3. 推荐技术路线

### 3.1 不让正式应用依赖 Python

Python 只用于开发阶段的数据转换。发布后的 macOS 应用不启动 Python，也不要求用户安装 Python、NLTK 或其他运行时。

推荐流程：

```text
开发者下载 WordNet 官方数据
    -> 开发期转换脚本校验和解析
    -> 生成固定版本的 wordnet.sqlite
    -> 将 SQLite 作为只读资源打进 App
    -> Swift 使用 SQLite3 查询
```

这条路线的优点：

- 应用可以离线查询；
- 不需要 WordNet API Key；
- 没有请求限流；
- 查询结果不会因第三方接口变化而突然改变；
- 可以为数据版本、完整性和查询结果编写确定性测试。

### 3.2 为什么不用 SwiftData 保存整个 WordNet

SwiftData 适合 Egangnal 的个人数据，但不适合把一整份静态词典在首次启动时逐条导入。这样会带来启动慢、迁移复杂、应用容器膨胀和重复存储等问题。

推荐采用双存储结构：

```text
wordnet.sqlite（应用资源，只读）
    -> 公共词库、词义、例句、同义词

SwiftData（用户容器，可写）
    -> WordEntry、收藏来源、收藏日期、个人修改
```

## 4. 你必须亲自取得或确认的内容

下面这些内容涉及授权、产品选择或账号所有权，不能由代码替你决定。

### 4.1 WordNet 官方数据包

你需要从 WordNet 官方网站确认并下载准备使用的版本：

- 官方下载页：<https://wordnet.princeton.edu/download/current-version>
- 官方许可页：<https://wordnet.princeton.edu/license-and-commercial-use>

下载后不要急着加入 Xcode。先记录：

- 数据包名称；
- WordNet 版本，例如 3.1；
- 下载日期；
- 官方下载地址；
- 文件 SHA-256；
- 数据包内的许可证文件；
- 官方要求保留的版权和免责声明。

计算 SHA-256：

```bash
shasum -a 256 /你的下载目录/WordNet-数据包文件名
```

你需要把终端输出和文件名记录下来。后续转换脚本将拒绝处理来源或校验值不匹配的数据，避免误用损坏文件或错误版本。

### 4.2 WordNet 许可证确认

WordNet 的许可通常允许使用、复制、修改和分发，也允许商业使用，但要求在副本中保留版权声明和许可文本，并且不提供担保。

你仍需要亲自完成以下确认：

- 当前下载版本附带的实际许可证文本是否与官网一致；
- App 分发时是否允许一起分发转换后的 SQLite 数据库；
- 许可证文本需要展示在哪里；
- 是否需要在产品页面或关于页面增加署名。

建议最终放置：

```text
Egangnal/Resources/Licenses/WordNet-LICENSE.txt
```

并在应用的“设置 -> 关于与许可”中提供查看入口。不要只在仓库 README 中声明，因为最终用户未必能看到仓库。

### 4.3 中学、CET4、CET6 分级词表

WordNet 没有这些等级。你需要另外找到并确认可使用的分级词表。

每份候选词表至少要确认：

- 提供者和官方网站；
- 明确的版本或发布日期；
- 许可协议；
- 是否允许修改和随桌面应用再分发；
- 是否允许商业使用；
- 词表是单词原形还是包含各种词形；
- 是否包含短语、专有名词和缩写；
- CET4 与 CET6 是包含关系还是独立集合。

不要因为网页可以访问或文件可以下载，就默认可以随 App 打包。

建议最终整理成以下最小格式：

```csv
term,level,source_version
ability,middle_school,2026-verified
abandon,cet4,2026-verified
abnormal,cet6,2026-verified
```

同一个词允许出现多行，因为它可能同时属于多个等级。

### 4.4 中文释义、音标和发音来源

这部分也不属于 WordNet。你需要选择：

- 暂时让用户自己填写中文释义；或者
- 购买或取得一个允许使用的词典 API；或者
- 取得一份允许随应用分发的离线中英词典。

如果选择 API，你需要从服务商网站取得并确认：

- API 文档地址；
- 账号及套餐；
- API Key；
- 请求频率和每日配额；
- 返回字段说明和示例 JSON；
- 缓存和永久保存结果是否被许可；
- 是否允许商业应用使用；
- 服务的署名要求；
- 隐私政策和数据发送范围。

重要：商业 API Key 不能直接写入 macOS 客户端代码或 `Info.plist`。客户端中的秘密最终都可能被提取。真正需要保密的 Key 应放在自有服务端；如果只做个人工具，也可以让用户自己填写 Key，并存入 Keychain，但仍需遵守供应商条款。

## 5. 我可以完成的工作

当你把上一节中的资料或选择交给我以后，我可以完成以下工程工作：

| 工作 | 我可以完成的内容 | 需要你提供或确认 |
| --- | --- | --- |
| WordNet 数据导入 | 编写解析、校验、SQLite 建库和索引脚本 | 官方数据包、版本、SHA-256、许可证 |
| 数据质量报告 | 统计单词、词义、词性、例句数量，检查孤立引用和重复数据 | 接受的异常规则 |
| Swift 查询层 | 建立协议、SQLite 连接、参数化查询、错误类型和并发边界 | 第一版需要展示的字段 |
| 等级分类 | 导入中学/CET4/CET6 词表并处理交集和重复 | 有授权的词表和等级定义 |
| 中文词典 API | 生成 DTO、网络客户端、超时、重试和缓存代码 | API 文档、示例响应、鉴权方式 |
| 收藏闭环 | 扩展 SwiftData 模型和仓储事务，接入当天收录 | 重复收藏、首次释义等产品规则 |
| 界面 | 搜索、筛选、详情、多义项选择、收藏和错误状态 | 最终交互取舍 |
| 测试 | 转换测试、查询测试、仓储测试、迁移测试和 UI 测试 | 验收标准确认 |
| 文档 | ADR、实现设计、数据清单、许可证清单和阶段复盘 | 对重大方案的批准 |

我不能替你完成的部分：

- 代表你接受第三方服务条款；
- 判断一份来源不明词表必然可以商用；
- 替你购买 API 套餐或持有生产账号；
- 猜测你希望采用哪套 CET/中学词表标准；
- 在未获得密钥的情况下完成真实鉴权联调；
- 承诺第三方数据绝对正确。

## 6. 动手前的目录规划

建议未来采用以下目录。现在不需要一次性创建全部文件：

```text
Egangnal/
├── Domain/
│   └── LexiconModels.swift
├── Data/
│   ├── EnglishLexiconRepository.swift
│   └── SQLiteWordNetRepository.swift
├── Features/
│   └── LearningMaterials/
│       ├── VocabularyCatalogView.swift
│       └── VocabularyCatalogStore.swift
└── Resources/
    ├── Lexicon/
    │   └── wordnet.sqlite
    └── Licenses/
        └── WordNet-LICENSE.txt

tools/
└── wordnet-builder/
    ├── build_wordnet.py
    ├── verify_wordnet.py
    ├── requirements.lock
    └── README.md

docs/
├── architecture/
│   └── 架构决策-003-离线公共词库与个人收藏分离.md
└── design/
    └── WordNet离线词库实现设计.md
```

原始下载文件建议放在未纳入 Git 的开发输入目录，转换产物是否纳入 Git 要在确认体积和发布方式后决定。任何 API Key、私钥和账号配置都必须被 `.gitignore` 排除。

## 7. 第一步：只做 WordNet 概念验证

这一阶段不修改 Egangnal，不做 UI，也不导入完整数据库。目的只是确认我们理解 WordNet 的返回结构。

### 7.1 创建隔离的 Python 环境

在项目外或临时目录中执行：

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install nltk
```

打开 Python：

```bash
python
```

下载 NLTK 的演示语料：

```python
import nltk

nltk.download("wordnet")
nltk.download("omw-1.4")
```

注意：NLTK 下载的语料适合概念验证，但它不自动等同于你最后决定随 App 发布的官方数据版本。正式构建必须锁定并校验独立下载的数据包。

### 7.2 查询一个多义词

```python
from nltk.corpus import wordnet as wn

for synset in wn.synsets("bank"):
    print("ID:", synset.name())
    print("词性:", synset.pos())
    print("英文释义:", synset.definition())
    print("例句:", synset.examples())
    print("同义词:", synset.lemma_names())
    print("---")
```

你应该看到多个结果。每个结果代表一个具体词义，而不是重复数据。

### 7.3 查询词形

```python
from nltk.corpus import wordnet as wn

print(wn.morphy("cars", wn.NOUN))
print(wn.morphy("running", wn.VERB))
print(wn.morphy("better", wn.ADJ))
```

这个实验用于确认“用户输入的表面词形”和“词典中的词元”不同。正式产品必须规定：搜索时可以做词形还原，但收藏时保留用户实际选择的展示词。

### 7.4 本阶段验收

- `bank` 能返回多个词义；
- 每个结果包含稳定 ID、词性和英文释义；
- 能看到部分例句和同义词；
- 能解释为什么 `bank` 不能只保存第一条释义；
- 没有修改 Egangnal 业务代码。

## 8. 第二步：确定第一版数据范围

不要一开始实现 WordNet 的全部语义网络。Egangnal 第一版只需要：

- 精确单词查询；
- 不区分大小写的规范化查询；
- 词性；
- 多个英文义项；
- 每个义项的同义词；
- 可用的英文例句；
- 稳定的 WordNet 词义 ID。

第一版暂不实现：

- 上位词和下位词图谱；
- 语义路径可视化；
- 相似度算法；
- 全文模糊搜索；
- 自动生成中文释义；
- 自动推断 CET 等级。

先固定范围可以显著降低解析、数据模型和 UI 的复杂度。

## 9. 第三步：构建只读 SQLite

### 9.1 推荐表结构

以下是实现方向，不应在未写 ADR 和实现设计前直接复制进生产代码：

```sql
CREATE TABLE metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE synset (
    id TEXT PRIMARY KEY,
    part_of_speech TEXT NOT NULL,
    definition TEXT NOT NULL
);

CREATE TABLE lemma (
    id INTEGER PRIMARY KEY,
    synset_id TEXT NOT NULL,
    term TEXT NOT NULL,
    normalized_term TEXT NOT NULL,
    sense_rank INTEGER NOT NULL,
    FOREIGN KEY (synset_id) REFERENCES synset(id)
);

CREATE TABLE example (
    id INTEGER PRIMARY KEY,
    synset_id TEXT NOT NULL,
    content TEXT NOT NULL,
    FOREIGN KEY (synset_id) REFERENCES synset(id)
);

CREATE INDEX lemma_normalized_term_index
ON lemma(normalized_term);
```

`metadata` 至少保存：

```text
schema_version
wordnet_version
source_filename
source_sha256
generated_at
builder_version
```

### 9.2 查询必须参数化

Swift 最终执行的查询应类似：

```sql
SELECT
    lemma.term,
    lemma.sense_rank,
    synset.id,
    synset.part_of_speech,
    synset.definition
FROM lemma
JOIN synset ON synset.id = lemma.synset_id
WHERE lemma.normalized_term = ?
ORDER BY lemma.sense_rank ASC;
```

用户输入只能通过 SQLite 参数绑定传入，不能拼接到 SQL 字符串中。

### 9.3 转换脚本必须检查什么

转换过程应在任何异常时整体失败，不留下看似成功的不完整数据库。至少检查：

- 输入文件 SHA-256 与配置一致；
- WordNet 版本与预期一致；
- 每个 lemma 引用的 synset 存在；
- 主键没有重复；
- 必填定义不为空；
- 事务成功后才替换旧产物；
- 临时数据库通过 `PRAGMA integrity_check`；
- 构建相同输入时内容可重复生成；
- 输出统计与批准的基线范围一致。

生成时先写临时文件，全部验证通过后再原子替换正式产物。代码中需要用简洁中文注释说明这一事务边界，而不是给每一行写解释性注释。

### 9.4 建议生成的数据报告

```text
WordNet 版本：3.1
数据库 schema：1
synset 数量：...
lemma 数量：...
example 数量：...
数据库大小：...
来源 SHA-256：...
SQLite integrity_check：ok
```

数量不能事先硬编码猜测。第一次从已确认的数据包成功生成后，再把统计结果保存为该版本的测试基线。

## 10. 第四步：建立 Swift 查询边界

领域模型不应该暴露 SQLite 行或 NLTK 对象：

```swift
struct WordNetSense: Identifiable, Equatable, Sendable {
    let id: String
    let term: String
    let partOfSpeech: WordPartOfSpeech
    let definition: String
    let examples: [String]
    let synonyms: [String]
}

enum WordPartOfSpeech: String, Sendable {
    case noun
    case verb
    case adjective
    case adverb
}

protocol EnglishLexiconRepository: Sendable {
    func lookup(term: String) async throws -> [WordNetSense]
}
```

实现层建议叫 `SQLiteWordNetRepository`。它只负责：

- 打开 App Bundle 中的只读数据库；
- 校验 schema 和 WordNet 版本；
- 规范化用户查询；
- 使用参数绑定查询；
- 把 SQLite 行转换为领域模型；
- 将底层错误转换成用户可理解的仓储错误；
- 在正确的并发边界内访问连接。

SwiftUI `View` 不应自己打开数据库或写 SQL。建议调用链为：

```text
VocabularyCatalogView
    -> VocabularyCatalogStore
        -> EnglishLexiconRepository
            -> SQLiteWordNetRepository
```

### 10.1 第一版错误类型

至少区分：

```swift
enum LexiconRepositoryError: LocalizedError {
    case resourceMissing
    case unsupportedSchema
    case unsupportedWordNetVersion
    case databaseCorrupted
    case queryFailed
}
```

“没有查到单词”不是数据库错误，应正常返回空数组。

### 10.2 数据库打开方式

数据库是 App Bundle 资源，必须只读打开。不要在应用启动时把它复制到 SwiftData 容器，也不要尝试修改 Bundle 内容。

测试中不直接依赖完整生产数据库。应准备一个很小的测试数据库，固定包含 `bank`、`run` 等有限样例，用来验证多义项、排序、词性、空结果和损坏数据库错误。

## 11. 第五步：接入现有个人单词本

现有模型中：

- `WordEntry` 是个人主词条；
- `WordImportBatch` 表示一次 Markdown 导入；
- `WordOccurrence` 表示单词出现在哪个 Markdown 文档日期；
- 高频词由不同文档日期数量推导；
- 纯手动新增词没有日期，当前不会进入单词刷候选池。

因此，不能通过伪造 Markdown 导入批次来表示“今天从 WordNet 收藏”。否则会错误改变按日期浏览、高频词和单词刷语义。

建议新增独立的收藏记录，概念结构如下：

```swift
@Model
final class WordBookAcquisition {
    @Attribute(.unique) var acquisitionKey: String
    var languageSpaceID: String
    var wordEntryID: UUID
    var sourceKindRawValue: String
    var provider: String?
    var providerSenseID: String?
    var collectedDateKey: String
    var collectedYear: Int
    var collectedMonth: Int
    var collectedDay: Int
    var createdAt: Date
}
```

这只是概念草图。正式编码前必须另写数据模型设计和迁移方案。

用户点击“加入单词本”时，仓储应在一个事务内：

1. 清理并规范化 term；
2. 在英语空间查找现有 `WordEntry`；
3. 不存在则创建主词条，存在则按产品规则复用；
4. 写入 WordNet provider 和稳定 sense ID；
5. 写入用户本地当天的收藏日期；
6. 同一天重复收藏保持幂等；
7. 任意一步失败则整体回滚；
8. 成功后刷新当天生词页面。

必须由产品规则明确：

- 同一单词选择两个不同 WordNet 义项，是一个词条还是两个词条；
- 现有词条已有中文释义时是否允许覆盖；
- 第二天再次收藏是否新增日期；
- 在线收藏是否参与“高频词”计算；
- 纯手动词、Markdown 导入词和在线收藏词是否都进入单词刷。

推荐首版规则：

- 同一语言空间的同一规范化 term 仍只有一个 `WordEntry`；
- 首次中文释义优先，除非用户主动编辑；
- 同一天重复收藏不产生第二条记录；
- 收藏日期与 Markdown 文档日期分开；
- 现有高频词继续只由 Markdown 出现日期计算；
- 在线收藏词可以进入单词刷，但通过新收藏记录判断，不伪造 `WordOccurrence`。

## 12. 第六步：加入中学、CET4、CET6 标签

等级属于公共目录，不属于用户个人 `WordEntry` 的单值属性。同一单词可以属于多个等级。

可以在只读 SQLite 中增加：

```sql
CREATE TABLE word_level (
    normalized_term TEXT NOT NULL,
    level TEXT NOT NULL,
    source_id TEXT NOT NULL,
    PRIMARY KEY (normalized_term, level, source_id)
);

CREATE INDEX word_level_level_index
ON word_level(level, normalized_term);
```

等级筛选应先得到词元列表，再查询 WordNet 义项。WordNet 中没有结果的等级词仍应被数据报告列出，不能静默丢弃。

数据报告应额外包含：

- 每个等级的原始词数；
- 规范化后的唯一词数；
- 等级之间的交集数量；
- 在 WordNet 中找不到的词；
- 短语、缩写和专有名词数量；
- 因数据错误而被拒绝的行及原因。

## 13. UI 第一版应该包含什么

学习资料中的词汇大全建议采用工作型界面，不需要一次展示 WordNet 的所有关系。

第一版包含：

- 搜索框；
- 中学、CET4、CET6 分段筛选；
- 结果列表；
- 词性；
- 多义项英文释义；
- 同义词和可用例句；
- 中文释义输入或确认；
- “加入单词本”按钮；
- 已收藏状态；
- 空结果、数据库损坏和资源缺失状态。

第一版不包含：

- 复杂语义关系图；
- 无限滚动整个 WordNet；
- 自动播放发音；
- 在线账号和跨设备同步；
- 自动判定用户掌握程度。

## 14. 测试和质量门槛

你的开发准则应落实成可检查的门槛，而不只是一句目标。

### 14.1 每个阶段都必须满足

- 有对应设计文档或 ADR；
- 代码职责单一，View 不解析词库、不写 SQL、不直接操作 SwiftData；
- 所有数据库查询使用参数绑定；
- 所有可失败操作返回明确错误；
- 写入个人单词本使用事务并可回滚；
- 英语和日语数据保持隔离；
- 不提交密钥、私钥、用户配置和临时产物；
- 新代码只在关键约束、事务边界和不直观算法前添加简洁中文注释；
- 单元测试通过；
- 涉及界面时验证默认窗口和 `820 x 560` 最小窗口；
- 完成一小步后单独提交，不混入无关重构。

### 14.2 转换工具测试

- 正确版本可以生成数据库；
- SHA-256 不匹配时拒绝生成；
- 缺文件或损坏输入时整体失败；
- 重复主键和孤立引用被发现；
- 临时构建失败不会覆盖上一个正确数据库；
- 相同输入得到相同的数据内容；
- 完整性检查为 `ok`。

### 14.3 Swift 查询测试

- 精确查询；
- 大小写规范化；
- 多义词返回多个结果；
- 结果按稳定规则排序；
- 不存在的词返回空数组；
- 特殊字符不会改变 SQL 结构；
- schema 不兼容时明确失败；
- 数据库缺失和损坏时明确失败；
- 多次并发查询不会崩溃或串结果。

### 14.4 收藏仓储测试

- 首次收藏创建 `WordEntry` 和当天收藏记录；
- 同日重复收藏幂等；
- 已存在主词条时不重复创建；
- 首次中文释义不被静默覆盖；
- 收藏日期使用本地自然日；
- 写入失败整体回滚；
- 日语与英语不串数据；
- Markdown 出现日期和在线收藏日期互不污染；
- 在线收藏词按规则进入单词刷。

## 15. 推荐的阶段和提交粒度

### 阶段 A：来源和许可确认

交付物：

- 数据来源清单；
- WordNet 版本和 SHA-256；
- 许可证副本；
- CET/中学词表候选及授权结论；
- 是否接入中文释义 API 的决定。

验收后再提交，不写业务代码。

### 阶段 B：WordNet 转换工具

交付物：

- 锁定依赖的转换脚本；
- SQLite schema；
- 数据完整性校验；
- 统计报告；
- 自动化测试。

这一阶段不做 SwiftUI。

### 阶段 C：Swift 只读查询层

交付物：

- 领域模型和仓储协议；
- SQLite 只读实现；
- 小型测试数据库；
- 查询和错误测试。

这一阶段可以先用测试或调试入口验证，不做完整收藏流程。

### 阶段 D：词汇大全最小界面

交付物：

- 搜索和等级筛选；
- 多义项详情；
- 空态和错误态；
- 最小窗口及辅助功能测试。

### 阶段 E：收藏到当天生词

交付物：

- 收藏数据模型设计和迁移说明；
- 原子收藏仓储；
- 当天生词浏览；
- 与现有单词本、单词刷的衔接；
- 数据和 UI 回归测试。

每个阶段建议单独提交。不要把数据转换、数据库迁移、UI 重构和 API 接入放进同一个提交。

## 16. 第一次正式实施前，你要给我的资料

准备开始阶段 A 时，请提供以下清单：

```text
[ ] WordNet 官方数据包文件
[ ] WordNet 版本号
[ ] 下载页面地址
[ ] 下载文件 SHA-256
[ ] 数据包附带的许可证文件
[ ] 是否计划商业发布
[ ] 中学词表来源和许可证
[ ] CET4 词表来源和许可证
[ ] CET6 词表来源和许可证
[ ] 中文释义采用“用户填写 / 离线词典 / API”中的哪一种
[ ] 若使用 API：官方文档、鉴权方式和一份脱敏响应样例
```

不要在聊天、源码或 Git 中直接发送生产 API Key。需要联调时，应通过本机环境变量、Keychain 或不纳入版本控制的配置文件提供。

## 17. 常见误区

### 误区一：WordNet 是一个在线 API

它首先是一份词汇数据库。第三方可能把它包装成 API，但第三方 API 的许可、稳定性和费用与 WordNet 数据本身不是一回事。

### 误区二：WordNet 有 CET4/CET6 分类

没有。考试等级必须来自另一份有授权的词表。

### 误区三：把所有 WordNet 单词导入个人单词本

这会混淆公共目录和用户收藏。用户未选择的公共词不应该成为 `WordEntry`。

### 误区四：只保存单词，不保存具体词义 ID

多义词会失去来源定位。至少应保存 provider、WordNet 版本和稳定 sense/synset ID。

### 误区五：把在线收藏伪装成 Markdown 导入

这会污染现有日期浏览、高频词和单词刷规则。收藏需要独立的来源和日期模型。

### 误区六：把商业 API Key 放进 App

桌面客户端中的固定密钥无法真正保密。生产服务必须设计安全的鉴权方案。

### 误区七：先写完整 UI，再决定数据来源

数据许可、字段和义项结构会直接决定 UI。应先完成阶段 A 和 B，再开始完整界面。

## 18. 当前建议结论

Egangnal 第一版 WordNet 接入应采用以下边界：

1. WordNet 作为固定版本、随 App 打包的只读 SQLite 词义库；
2. Python 只作为开发期构建工具，不进入正式应用；
3. 中学/CET4/CET6 使用单独的、有授权的等级词表；
4. 中文释义第一版优先让用户确认或填写，之后再独立接 API；
5. 公共词库与 SwiftData 个人单词本严格分开；
6. 在线或公共词库收藏使用独立记录，不复用 Markdown `WordOccurrence`；
7. 每个大阶段先写文档，再小步编码、测试、验收和提交；
8. 后续生成的代码在关键设计原因、异常处理和事务边界处使用简洁清晰的中文注释。

按照这条路线，第一项真正的开发工作不是写 SwiftUI，而是完成“数据来源与许可清单”，然后用少量单词验证 WordNet 的多义项结构。
