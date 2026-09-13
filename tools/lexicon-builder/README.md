# 词库构建工具使用说明

把 ECDICT 的 `ecdict.csv` 转换成本项目使用的只读词库 `EgangnalLexicon.sqlite`。

- 规范依据：[ECDICT 离线词库构建契约](../../docs/design/ECDICT离线词库构建契约.md)
- 勘察基线：[ECDICT 数据勘察报告](../../docs/design/ECDICT数据勘察报告.md)
- **这个工具只在开发期运行，不进入 App，也不要求最终用户安装 Python。**

## 1. 它产出了什么

| 产物 | 位置 | 说明 |
| --- | --- | --- |
| `EgangnalLexicon.sqlite` | `Egangnal/Resources/Lexicon/` | App 使用的只读词库，需要提交到仓库 |
| `build-report.json` | `tools/lexicon-builder/output/` | 本次构建的全部统计与质量门槛结果 |
| `source-manifest.json` | `tools/lexicon-builder/output/` | 本次实际使用的来源身份（提交号与摘要） |
| 固定样例 | `tools/lexicon-builder/fixtures/normalization-cases.json` | Python 与 Swift 共用的规范化样例，需要提交 |

当前基线：**7,116 条**，产物约 **2.5 MB**，等级关系 14,536 条。

## 2. 前置条件

- macOS 自带的 `python3`（仅使用标准库，不需要 `pip install` 任何东西）
- 原始数据放在 `.lexicon-source/`（已在 `.gitignore` 中，不会进入仓库）

## 3. 三步上手

在项目根目录执行：

```bash
# 1. 快速自检：不读 63 MB 源文件，只验证规范化、换行还原和确定性 UUID
python3 tools/lexicon-builder/build_ecdict.py --self-test

# 2. 完整构建（使用默认路径）
python3 tools/lexicon-builder/build_ecdict.py

# 3. 查看产物
sqlite3 Egangnal/Resources/Lexicon/EgangnalLexicon.sqlite \
  "SELECT term, phonetic, chinese_translation FROM dictionary_entry WHERE term = 'abandon';"
```

第 2 步正常输出形如：

```text
来源校验通过：bc015ed2e24a 1a6947e04785db63…
规范化样例：18 条，状态 match
目标词条：7116 条

构建成功
  产物        Egangnal/Resources/Lexicon/EgangnalLexicon.sqlite（2617344 字节）
  sha256      6cc384a3f281e1357070c9d4bb5dc2f343b77da00b5c351db67431965c27c46d
  词条数      7116
    cet4        3849
    cet6        5407
    juniorHigh  1603
    seniorHigh  3677
  等级关系    14536
  构建报告    tools/lexicon-builder/output/build-report.json
  质量门槛    10 项全部通过
```

## 4. 如果原始数据丢了：重新取得

`.lexicon-source/` 不进仓库，换机器或清理磁盘后需要重新下载。**必须固定到契约记录的提交**，不要用“最新版”：

```bash
cd /Users/ly/Program/AllCode/MacProj/Egangnal
mkdir -p .lexicon-source && cd .lexicon-source

COMMIT=bc015ed2e24a7abef49fc6dbbb7fe32c1dadaf8b
BASE="https://raw.githubusercontent.com/skywind3000/ECDICT/$COMMIT"

for f in ecdict.csv ecdict.mini.csv LICENSE README.md; do
  curl -sSL --retry 2 -o "$f" "$BASE/$f"
done
```

然后重新生成来源清单（这一步会算出实测摘要）：

```bash
python3 - "$COMMIT" <<'PY'
import sys, json, hashlib, pathlib, datetime
commit = sys.argv[1]; d = pathlib.Path('.')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
# ecdict.csv 较大，分块读取避免一次性载入内存
def big(p):
    h = hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda: f.read(1<<20), b''): h.update(b)
    return h.hexdigest()
man = {
  "provider": "ECDICT",
  "provider_repository": "https://github.com/skywind3000/ECDICT",
  "provider_commit": commit,
  "source_filename": "ecdict.csv",
  "source_sha256": big(d/'ecdict.csv'),
  "license_sha256": sha(d/'LICENSE'),
  "readme_sha256": sha(d/'README.md'),
  "mini_sha256": sha(d/'ecdict.mini.csv'),
  "source_bytes": (d/'ecdict.csv').stat().st_size,
  "downloaded_at": datetime.date.today().isoformat(),
  "intended_use": "public-free",
  "distribution_decision": "plan-A: MIT attribution + exclude collins/oxford/audio/detail",
  "acquired_via": "raw.githubusercontent.com"
}
(d/'source-manifest.json').write_text(json.dumps(man, indent=2, ensure_ascii=False))
print(json.dumps(man, indent=2, ensure_ascii=False))
PY
```

如果算出的 `source_sha256` 与契约第 2.2 节记录的值不同，**不要直接构建**：那说明拿到的不是同一个版本，需要先确认差异并更新契约。

## 5. 命令行参数

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `--source` | `.lexicon-source/ecdict.csv` | 原始 CSV 路径 |
| `--manifest` | 源文件同目录的 `source-manifest.json` | 来源清单路径 |
| `--output` | `Egangnal/Resources/Lexicon/EgangnalLexicon.sqlite` | 产物路径 |
| `--report-dir` | `tools/lexicon-builder/output` | 报告输出目录 |
| `--fixtures` | `tools/lexicon-builder/fixtures/normalization-cases.json` | 固定样例路径 |
| `--generated-at` | 当前 UTC 时间 | 固定生成时间，用于验证可复现性 |
| `--write-fixtures` | — | 重新生成固定样例后退出 |
| `--self-test` | — | 只跑快速自检 |

退出码：`0` 成功；非 `0` 失败，并会打印可读原因。

## 6. 验证可复现性

契约要求“同一输入两次构建，除生成时间外产物一致”。用固定时间跑两次并比较摘要：

```bash
FIXED=2026-09-11T00:00:00Z
python3 tools/lexicon-builder/build_ecdict.py --generated-at "$FIXED" >/dev/null
A=$(shasum -a 256 Egangnal/Resources/Lexicon/EgangnalLexicon.sqlite | awk '{print $1}')
python3 tools/lexicon-builder/build_ecdict.py --generated-at "$FIXED" >/dev/null
B=$(shasum -a 256 Egangnal/Resources/Lexicon/EgangnalLexicon.sqlite | awk '{print $1}')
[ "$A" = "$B" ] && echo "可复现：$A" || echo "不可复现，需要排查"
```

## 7. 质量门槛（不通过就不会替换产物）

构建在临时文件里完成后先跑以下检查，**任何一条失败都会删除临时文件、保留上一次成功的产物**：

1. `entry_count` 为 7,116（容差 1%）；
2. 四个等级均非空且与基线一致（初中 1,603 / 高中 3,677 / 四级 3,849 / 六级 5,407，容差 1%）；
3. 中文释义为空的数量为 0；
4. 无未处理的查询键碰撞；
5. 查询键规范化与固定样例全部一致；
6. 还原后无字面 `\n` / `\r` 残留；
7. `PRAGMA integrity_check` 正常且无外键违规。

完整数字见 `output/build-report.json` 的 `quality_gates` 字段。

## 8. 遇到错误怎么办

| 报错 | 原因与处理 |
| --- | --- |
| `找不到源文件` | `.lexicon-source/ecdict.csv` 不存在，按第 4 节重新下载 |
| `找不到来源清单` | 缺少 `source-manifest.json`，按第 4 节生成 |
| `源文件摘要不符` | 拿到的不是契约记录的版本。**不要绕过**，先确认差异并更新契约 |
| `找不到规范化固定样例` | 运行 `--write-fixtures` 生成 |
| `质量门槛未通过` | 看打印的具体条目与 `build-report.json`；若确实需要改变基线，必须同步更新勘察报告与契约 |
| `ModuleNotFoundError` | 用到了非标准库，说明工具被改动过，检查 `import` 部分 |

## 9. 扩展词库规模

首版只取四个等级。若将来要把考研、托福、雅思、GRE 也纳入：

1. 在 `build_ecdict.py` 的 `LEVEL_BY_TAG` 中增加映射（例如 `"ky": "postgraduate"`）；
2. 同步更新 `BASELINE_ENTRY_COUNT` 与 `BASELINE_LEVEL_COUNTS`；
3. 同步更新契约第 4 节、勘察报告与 Swift 侧的等级枚举。

**schema 不需要改动**，只是重新构建。全部 8 个标签的并集为 14,942 条。

## 10. 必须遵守的约束

- **不要手工修改 SQLite 文件。** 它是可再生成的产物，任何改动都会在下次构建时丢失。
- **不要把原始 CSV 提交进仓库**（63 MB，且会掩盖 diff）。
- **不要为了“能跑通”而放宽摘要校验或质量门槛。** 门槛失败代表数据或规则发生了变化，应查清原因。
- **`Resources/Licenses/ECDICT-LICENSE.txt` 必须与 `license_sha256` 对应**，公开分发时随包提供。
- 公开或商业发布前，重新确认许可证与发布范围（契约第 3 节）。
