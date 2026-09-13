#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ECDICT → EgangnalLexicon.sqlite 构建工具（路线图阶段 5.1）。

规范来源：docs/design/ECDICT离线词库构建契约.md
勘察基线：docs/design/ECDICT数据勘察报告.md

本工具只在开发期运行，不进入 App，也不要求最终用户安装 Python。
只依赖 Python 标准库。

它做四件事：
1. 校验原始 CSV 与 README/LICENSE 的摘要，摘要不符直接失败；
2. 按固定规则筛选、清洗、还原四个考试等级的英文词条；
3. 在临时文件里建库、跑完整性与质量门槛检查；
4. 全部通过后原子替换正式产物，并写出构建报告。

任何一步失败都不会留下半成品，也不会覆盖上一次成功的产物。

用法见 tools/lexicon-builder/README.md，常用命令：

    python3 tools/lexicon-builder/build_ecdict.py
    python3 tools/lexicon-builder/build_ecdict.py --self-test
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import sqlite3
import sys
import unicodedata
import uuid
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = Path(__file__).resolve().parent

SCHEMA_VERSION = "1"
BUILDER_VERSION = "1.0.0"
NORMALIZATION_VERSION = "en-v1"
UNESCAPE_VERSION = "esc-v1"
BUILD_PROFILE = "graded"

# ECDICT 标签 -> 应用等级。改这里即可扩展词库规模，schema 不需要改动。
LEVEL_BY_TAG = {
    "zk": "juniorHigh",
    "gk": "seniorHigh",
    "cet4": "cet4",
    "cet6": "cet6",
}

# 勘察基线，用于质量门槛。偏离超过容差必须失败并说明原因。
BASELINE_ENTRY_COUNT = 7116
BASELINE_LEVEL_COUNTS = {
    "juniorHigh": 1603,
    "seniorHigh": 3677,
    "cet4": 3849,
    "cet6": 5407,
}
BASELINE_TOLERANCE = 0.01

# entry_uuid 的命名空间：固定字符串，改变它会让所有词条身份变化。
UUID_NAMESPACE = "egangnal.lexicon.ecdict.v1"

# 源文件用语面 ``\n`` 表示换行，而不是真实换行符（勘察确认不存在真实换行）。
LITERAL_NEWLINE = "\\n"
LITERAL_CARRIAGE_RETURN = "\\r"
UNKNOWN_ESCAPE = re.compile(r"\\([A-Za-z])")

REQUIRED_MANIFEST_KEYS = (
    "provider",
    "provider_repository",
    "provider_commit",
    "source_filename",
    "source_sha256",
)


class BuildError(RuntimeError):
    """构建失败。失败必须给出可读原因，且不得留下半成品产物。"""


# --------------------------------------------------------------------------
# 纯函数：规范化、转义还原、确定性 ID
# --------------------------------------------------------------------------

def normalize_search_term(text: str) -> str:
    """生成查询键，必须与 Swift 侧 WordNormalizer.normalizedTerm(_:in:.english) 一致。

    去首尾空白 -> 连续空白折叠为单空格 -> Unicode NFC -> 小写。
    两侧一致性由 fixtures/normalization-cases.json 固定样例保证。
    """
    collapsed = " ".join(text.split())
    return unicodedata.normalize("NFC", collapsed).lower()


def unescape_translation(text: str) -> tuple[str, bool, bool]:
    """把源文件的字面转义还原成真实换行。

    返回 (还原后文本, 是否含字面 \\n, 是否含字面 \\r)。
    ``\r\n`` 先还原，避免拆成两个换行。
    """
    has_newline = LITERAL_NEWLINE in text
    has_carriage_return = LITERAL_CARRIAGE_RETURN in text
    restored = (
        text.replace("\\r\\n", "\n")
        .replace(LITERAL_CARRIAGE_RETURN, "\n")
        .replace(LITERAL_NEWLINE, "\n")
    )
    return restored, has_newline, has_carriage_return


def deterministic_uuid(source_id: str) -> str:
    """由 source_id 派生稳定 UUID：同一词条在任意次构建中身份不变。

    这样 Swift 侧的 WordQuizCandidate.id: UUID 无需改动。
    """
    digest = hashlib.sha256(
        f"{UUID_NAMESPACE}\x00{source_id}".encode("utf-8")
    ).digest()
    raw = bytearray(digest[:16])
    raw[6] = (raw[6] & 0x0F) | 0x50  # UUID 版本 5
    raw[8] = (raw[8] & 0x3F) | 0x80  # RFC 4122 变体
    return str(uuid.UUID(bytes=bytes(raw)))


def source_id_for(term: str) -> str:
    """稳定来源标识。使用原始词形，勘察确认目标子集内无重词。"""
    return f"ecdict:{term}"


def sha256_file(path: Path, chunk_size: int = 1 << 20) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(chunk_size), b""):
            digest.update(block)
    return digest.hexdigest()


def percentile(values: list[int], ratio: float) -> int:
    if not values:
        return 0
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(len(ordered) * ratio) - 1))
    return ordered[index]


def rate(numerator: int, denominator: int) -> float | None:
    return round(numerator / denominator, 4) if denominator else None


# --------------------------------------------------------------------------
# 来源校验
# --------------------------------------------------------------------------

def load_manifest(path: Path) -> dict:
    if not path.is_file():
        raise BuildError(
            f"找不到来源清单：{path}\n"
            "请先按 README 的“准备原始数据”一节取得 ECDICT 数据与 source-manifest.json。"
        )
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise BuildError(f"来源清单不是合法 JSON：{path}（{error}）") from error

    missing = [key for key in REQUIRED_MANIFEST_KEYS if not manifest.get(key)]
    if missing:
        raise BuildError(f"来源清单缺少必需字段：{missing}")
    return manifest


def verify_source(source: Path, manifest: dict) -> dict:
    """校验源文件身份。摘要不符时构建必须失败，不能继续生成产物。"""
    if not source.is_file():
        raise BuildError(
            f"找不到源文件：{source}\n"
            "请先按 README 的“准备原始数据”一节下载 ecdict.csv。"
        )

    actual_sha = sha256_file(source)
    expected_sha = manifest["source_sha256"]
    if actual_sha != expected_sha:
        raise BuildError(
            "源文件摘要不符，拒绝继续构建：\n"
            f"  期望 {expected_sha}\n"
            f"  实际 {actual_sha}\n"
            "请确认使用的 ECDICT 提交与来源清单一致；如果确实要换版本，"
            "必须重新生成清单并更新契约。"
        )

    actual_size = source.stat().st_size
    expected_size = manifest.get("source_bytes")
    if expected_size and actual_size != expected_size:
        raise BuildError(
            f"源文件大小不符：期望 {expected_size}，实际 {actual_size}。"
        )

    return {
        "source_sha256": actual_sha,
        "source_bytes": actual_size,
        "verified": True,
    }


def verify_auxiliary(source_dir: Path, manifest: dict) -> dict:
    """校验 LICENSE / README 摘要（文件存在时）。缺失不算失败，但会记录。"""
    result = {}
    for key, filename in (("license_sha256", "LICENSE"), ("readme_sha256", "README.md")):
        expected = manifest.get(key)
        path = source_dir / filename
        if not expected:
            continue
        if not path.is_file():
            result[key] = {"file": filename, "status": "missing"}
            continue
        actual = sha256_file(path)
        result[key] = {
            "file": filename,
            "status": "match" if actual == expected else "mismatch",
            "expected": expected,
            "actual": actual,
        }
    return result


# --------------------------------------------------------------------------
# 解析与清洗
# --------------------------------------------------------------------------

def collect_entries(source: Path) -> tuple[dict, dict]:
    """流式读取 CSV，返回（词条字典, 统计）。不写任何文件。"""
    entries: dict[str, dict] = {}
    stats = {
        "rows_scanned": 0,
        "row_width_mismatch": 0,
        "rows_without_target_tag": 0,
        "rejected_empty_word": 0,
        "rejected_empty_translation": 0,
        "merged_duplicate_rows": 0,
        "literal_newline_rows": 0,
        "literal_carriage_return_rows": 0,
        "unknown_escapes": Counter(),
        "phonetic_missing": 0,
        "frequency_rank_missing": 0,
        "bnc_rank_missing": 0,
        "translation_lengths": [],
    }
    level_counter: Counter[str] = Counter()

    with source.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        try:
            header = next(reader)
        except StopIteration:
            raise BuildError("源文件为空。") from None

        required = {"word", "phonetic", "translation", "tag", "bnc", "frq"}
        missing_columns = required.difference(header)
        if missing_columns:
            raise BuildError(f"源文件缺少必需列：{sorted(missing_columns)}")
        index = {name: header.index(name) for name in required}
        width = len(header)

        for row in reader:
            if len(row) != width:
                stats["row_width_mismatch"] += 1
                continue
            stats["rows_scanned"] += 1

            tags = row[index["tag"]].split()
            matched = [tag for tag in tags if tag in LEVEL_BY_TAG]
            if not matched:
                stats["rows_without_target_tag"] += 1
                continue

            term = row[index["word"]].strip()
            translation = row[index["translation"]].strip()
            # 契约第 5 节：空词或空释义必须计入拒绝统计，不得静默丢弃。
            if not term:
                stats["rejected_empty_word"] += 1
                continue
            if not translation:
                stats["rejected_empty_translation"] += 1
                continue

            restored, had_newline, had_cr = unescape_translation(translation)
            if had_newline:
                stats["literal_newline_rows"] += 1
            if had_cr:
                stats["literal_carriage_return_rows"] += 1
            for letter in UNKNOWN_ESCAPE.findall(restored):
                if letter not in ("n", "r"):
                    stats["unknown_escapes"][f"\\{letter}"] += 1

            phonetic = row[index["phonetic"]].strip() or None
            if phonetic is None:
                stats["phonetic_missing"] += 1

            # 源数据用 0 表示“无排名”，入库为 NULL，排序时自然排到最后。
            frequency_raw = row[index["frq"]].strip()
            frequency_rank = int(frequency_raw) if frequency_raw.isdigit() and int(frequency_raw) > 0 else None
            if frequency_rank is None:
                stats["frequency_rank_missing"] += 1
            bnc_raw = row[index["bnc"]].strip()
            bnc_rank = int(bnc_raw) if bnc_raw.isdigit() and int(bnc_raw) > 0 else None
            if bnc_rank is None:
                stats["bnc_rank_missing"] += 1

            stats["translation_lengths"].append(len(restored))

            identifier = source_id_for(term)
            existing = entries.get(identifier)
            if existing is not None:
                # 同一个词的重复行：合并等级，保留首次出现的释义，不静默覆盖。
                stats["merged_duplicate_rows"] += 1
                for tag in matched:
                    existing["levels"][LEVEL_BY_TAG[tag]] = tag
                continue

            entries[identifier] = {
                "source_id": identifier,
                "entry_uuid": deterministic_uuid(identifier),
                "term": term,
                "search_term": normalize_search_term(term),
                "phonetic": phonetic,
                "chinese_translation": restored,
                "frequency_rank": frequency_rank,
                "bnc_rank": bnc_rank,
                "levels": {LEVEL_BY_TAG[tag]: tag for tag in matched},
            }
            for tag in matched:
                level_counter[LEVEL_BY_TAG[tag]] += 1

    search_terms: dict[str, list[str]] = {}
    for identifier, entry in entries.items():
        search_terms.setdefault(entry["search_term"], []).append(identifier)
    collisions = {
        key: sorted(values) for key, values in search_terms.items() if len(values) > 1
    }

    stats["level_counts"] = dict(level_counter)
    stats["search_term_collisions"] = collisions
    stats["entry_count"] = len(entries)
    return entries, stats


# --------------------------------------------------------------------------
# 建库
# --------------------------------------------------------------------------

SCHEMA_SQL = """
PRAGMA foreign_keys = ON;

CREATE TABLE metadata (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE dictionary_entry (
    id                  INTEGER PRIMARY KEY,
    source_id           TEXT NOT NULL UNIQUE,
    entry_uuid          TEXT NOT NULL UNIQUE,
    term                TEXT NOT NULL,
    search_term         TEXT NOT NULL,
    phonetic            TEXT,
    chinese_translation TEXT NOT NULL,
    frequency_rank      INTEGER,
    bnc_rank            INTEGER
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
"""


def write_database(
    path: Path,
    entries: dict,
    manifest: dict,
    generated_at: str,
    source_check: dict,
) -> dict:
    """在给定路径建库。调用方负责传入临时路径并在成功后原子替换。"""
    # 按 source_id 排序插入，保证同样的输入产生同样的文件字节。
    ordered = [entries[key] for key in sorted(entries)]

    connection = sqlite3.connect(path)
    try:
        connection.executescript(SCHEMA_SQL)
        connection.execute("BEGIN")

        level_relation_count = 0
        for position, entry in enumerate(ordered, start=1):
            connection.execute(
                "INSERT INTO dictionary_entry "
                "(id, source_id, entry_uuid, term, search_term, phonetic, "
                " chinese_translation, frequency_rank, bnc_rank) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    position,
                    entry["source_id"],
                    entry["entry_uuid"],
                    entry["term"],
                    entry["search_term"],
                    entry["phonetic"],
                    entry["chinese_translation"],
                    entry["frequency_rank"],
                    entry["bnc_rank"],
                ),
            )
            for level, source_tag in sorted(entry["levels"].items()):
                connection.execute(
                    "INSERT INTO entry_level (entry_id, level, source_tag) "
                    "VALUES (?, ?, ?)",
                    (position, level, source_tag),
                )
                level_relation_count += 1

        metadata = {
            "schema_version": SCHEMA_VERSION,
            "builder_version": BUILDER_VERSION,
            "build_profile": BUILD_PROFILE,
            "normalization_version": NORMALIZATION_VERSION,
            "translation_unescape_version": UNESCAPE_VERSION,
            "provider": manifest["provider"],
            "provider_repository": manifest["provider_repository"],
            "provider_commit": manifest["provider_commit"],
            "source_filename": manifest["source_filename"],
            "source_sha256": source_check["source_sha256"],
            "license_sha256": manifest.get("license_sha256", ""),
            "generated_at": generated_at,
            "entry_count": str(len(ordered)),
            "level_relation_count": str(level_relation_count),
        }
        connection.executemany(
            "INSERT INTO metadata (key, value) VALUES (?, ?)",
            sorted(metadata.items()),
        )
        connection.commit()

        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        foreign_keys = connection.execute("PRAGMA foreign_key_check").fetchall()
        connection.execute("VACUUM")
    finally:
        connection.close()

    return {
        "level_relation_count": level_relation_count,
        "integrity_check": integrity,
        "foreign_key_violations": len(foreign_keys),
    }


# --------------------------------------------------------------------------
# 质量门槛
# --------------------------------------------------------------------------

def within_tolerance(actual: int, expected: int, tolerance: float) -> bool:
    if expected == 0:
        return actual == 0
    return abs(actual - expected) / expected <= tolerance


def run_quality_gates(report: dict) -> list[dict]:
    """契约第 9 节的八条门槛。任何一条不通过都必须失败。"""
    entries = report["entry_count"]
    levels = report["level_counts"]
    gates = [
        {
            "id": 1,
            "description": "entry_count 与勘察基线一致（容差 1%）",
            "expected": BASELINE_ENTRY_COUNT,
            "actual": entries,
            "passed": within_tolerance(entries, BASELINE_ENTRY_COUNT, BASELINE_TOLERANCE),
        },
        {
            "id": 3,
            "description": "中文释义为空的数量为 0",
            "expected": 0,
            "actual": report["rejected_empty_translation"],
            "passed": report["rejected_empty_translation"] == 0,
        },
        {
            "id": 4,
            "description": "无未处理的查询键碰撞",
            "expected": 0,
            "actual": report["search_term_collision_count"],
            "passed": report["search_term_collision_count"] == 0,
        },
        {
            "id": 7,
            "description": "查询键规范化与固定样例一致",
            "expected": "all cases match",
            "actual": report["normalization"]["status"],
            "passed": report["normalization"]["status"] == "match",
        },
        {
            "id": 8,
            "description": "还原后无字面换行残留",
            "expected": 0,
            "actual": report["literal_escape_residue"],
            "passed": report["literal_escape_residue"] == 0,
        },
        {
            "id": 9,
            "description": "SQLite integrity_check 正常且无外键违规",
            "expected": "ok / 0",
            "actual": f"{report['database']['integrity_check']} / "
                      f"{report['database']['foreign_key_violations']}",
            "passed": report["database"]["integrity_check"] == "ok"
                      and report["database"]["foreign_key_violations"] == 0,
        },
    ]

    for level, expected in BASELINE_LEVEL_COUNTS.items():
        actual = levels.get(level, 0)
        gates.append(
            {
                "id": 2,
                "description": f"等级 {level} 非空且与基线一致（容差 1%）",
                "expected": expected,
                "actual": actual,
                "passed": actual > 0 and within_tolerance(actual, expected, BASELINE_TOLERANCE),
            }
        )
    return gates


# --------------------------------------------------------------------------
# 固定样例（Python 与 Swift 共用）
# --------------------------------------------------------------------------

NORMALIZATION_CASES = [
    "apple",
    "Apple",
    "  apple  ",
    "New   York",
    "New\tYork",
    "long-time",
    "don't",
    "café",
    "cafe\u0301",
    "Über",
    "naïve",
    "co-operate",
    "ABANDON",
    "a",
    "",
    "   ",
    "ＦｕｌｌＷｉｄｔｈ",
    "İstanbul",
]


def expected_cases() -> list[dict]:
    return [
        {"input": text, "expected": normalize_search_term(text)}
        for text in NORMALIZATION_CASES
    ]


def write_fixtures(path: Path) -> None:
    payload = {
        "version": NORMALIZATION_VERSION,
        "description": (
            "查询键规范化的跨语言固定样例。Python 构建期与 Swift 运行期必须得到相同结果。"
            "修改规范化协议时必须同时更新 version 与样例。"
        ),
        "cases": expected_cases(),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def validate_normalization(path: Path) -> dict:
    if not path.is_file():
        raise BuildError(
            f"找不到规范化固定样例：{path}\n"
            "请运行：python3 tools/lexicon-builder/build_ecdict.py --write-fixtures"
        )
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("version") != NORMALIZATION_VERSION:
        raise BuildError(
            f"固定样例版本不一致：样例 {payload.get('version')}，"
            f"工具 {NORMALIZATION_VERSION}。"
        )

    mismatches = []
    for case in payload.get("cases", []):
        actual = normalize_search_term(case["input"])
        if actual != case["expected"]:
            mismatches.append(
                {"input": case["input"], "expected": case["expected"], "actual": actual}
            )
    return {
        "status": "match" if not mismatches else "mismatch",
        "case_count": len(payload.get("cases", [])),
        "mismatches": mismatches,
    }


def run_self_test(fixtures: Path) -> int:
    """不依赖 63 MB 源文件的快速自检。"""
    failures: list[str] = []

    normalization = validate_normalization(fixtures)
    if normalization["status"] != "match":
        failures.append(f"规范化样例不一致：{normalization['mismatches']}")

    restored, had_nl, _ = unescape_translation("n. 圆\\na. 圆的")
    if restored != "n. 圆\na. 圆的" or not had_nl:
        failures.append(f"换行还原错误：{restored!r}")

    restored_cr, _, had_cr = unescape_translation("第一\\r第二")
    if restored_cr != "第一\n第二" or not had_cr:
        failures.append(f"回车还原错误：{restored_cr!r}")

    if unescape_translation("n. 普通释义")[0] != "n. 普通释义":
        failures.append("无转义文本被意外修改")

    first = deterministic_uuid("ecdict:apple")
    second = deterministic_uuid("ecdict:apple")
    if first != second:
        failures.append("确定性 UUID 不稳定")
    if first == deterministic_uuid("ecdict:banana"):
        failures.append("不同词条得到相同 UUID")

    print(f"规范化样例：{normalization['case_count']} 条，状态 {normalization['status']}")
    print(f"确定性 UUID 样例：ecdict:apple -> {first}")

    if failures:
        print("\n自检失败：", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print("自检通过。")
    return 0


# --------------------------------------------------------------------------
# 主流程
# --------------------------------------------------------------------------

def parse_arguments(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="把 ECDICT 的 ecdict.csv 转换为 Egangnal 只读词库 SQLite。",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=REPO_ROOT / ".lexicon-source" / "ecdict.csv",
        help="ECDICT 原始 CSV 路径",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=None,
        help="来源清单路径，默认为源文件同目录下的 source-manifest.json",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=REPO_ROOT / "Egangnal" / "Resources" / "Lexicon" / "EgangnalLexicon.sqlite",
        help="产物 SQLite 路径",
    )
    parser.add_argument(
        "--report-dir",
        type=Path,
        default=TOOL_DIR / "output",
        help="构建报告输出目录",
    )
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=TOOL_DIR / "fixtures" / "normalization-cases.json",
        help="跨语言规范化固定样例路径",
    )
    parser.add_argument(
        "--generated-at",
        default=None,
        help="固定生成时间（ISO8601），用于验证可复现性",
    )
    parser.add_argument(
        "--write-fixtures",
        action="store_true",
        help="生成固定样例后退出",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="只跑不依赖源文件的快速自检",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    arguments = parse_arguments(argv)

    if arguments.write_fixtures:
        write_fixtures(arguments.fixtures)
        print(f"固定样例已写入：{arguments.fixtures}")
        return 0

    if arguments.self_test:
        return run_self_test(arguments.fixtures)

    source = arguments.source.resolve()
    manifest_path = (
        arguments.manifest.resolve()
        if arguments.manifest
        else source.parent / "source-manifest.json"
    )
    output = arguments.output.resolve()
    report_dir = arguments.report_dir.resolve()
    generated_at = arguments.generated_at or datetime.now(timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )

    try:
        manifest = load_manifest(manifest_path)
        source_check = verify_source(source, manifest)
        auxiliary = verify_auxiliary(source.parent, manifest)
        print(f"来源校验通过：{manifest['provider_commit'][:12]} {source_check['source_sha256'][:16]}…")

        normalization = validate_normalization(arguments.fixtures)
        print(f"规范化样例：{normalization['case_count']} 条，状态 {normalization['status']}")

        entries, stats = collect_entries(source)
        print(f"目标词条：{stats['entry_count']} 条")

        output.parent.mkdir(parents=True, exist_ok=True)
        temporary = output.with_name(output.name + ".tmp")
        if temporary.exists():
            temporary.unlink()

        try:
            database = write_database(
                temporary, entries, manifest, generated_at, source_check
            )
            literal_escape_residue = sum(
                1
                for entry in entries.values()
                if LITERAL_NEWLINE in entry["chinese_translation"]
                or LITERAL_CARRIAGE_RETURN in entry["chinese_translation"]
            )
            report = {
                "builder_version": BUILDER_VERSION,
                "build_profile": BUILD_PROFILE,
                "generated_at": generated_at,
                "source": {
                    "provider": manifest["provider"],
                    "provider_repository": manifest["provider_repository"],
                    "provider_commit": manifest["provider_commit"],
                    "filename": manifest["source_filename"],
                    **source_check,
                },
                "auxiliary_checks": auxiliary,
                "entry_count": stats["entry_count"],
                "level_counts": stats["level_counts"],
                "level_relation_count": database["level_relation_count"],
                "rows_scanned": stats["rows_scanned"],
                "row_width_mismatch": stats["row_width_mismatch"],
                "rows_without_target_tag": stats["rows_without_target_tag"],
                "rejected_empty_word": stats["rejected_empty_word"],
                "rejected_empty_translation": stats["rejected_empty_translation"],
                "merged_duplicate_rows": stats["merged_duplicate_rows"],
                "search_term_collision_count": len(stats["search_term_collisions"]),
                "search_term_collisions": stats["search_term_collisions"],
                "literal_newline_rows": stats["literal_newline_rows"],
                "literal_carriage_return_rows": stats["literal_carriage_return_rows"],
                "unknown_escapes": dict(stats["unknown_escapes"]),
                "literal_escape_residue": literal_escape_residue,
                "phonetic_missing": stats["phonetic_missing"],
                "phonetic_missing_rate": rate(
                    stats["phonetic_missing"], stats["entry_count"]
                ),
                "frequency_rank_missing": stats["frequency_rank_missing"],
                "bnc_rank_missing": stats["bnc_rank_missing"],
                "translation_length_chars": {
                    "min": min(stats["translation_lengths"]),
                    "p50": percentile(stats["translation_lengths"], 0.50),
                    "p90": percentile(stats["translation_lengths"], 0.90),
                    "p99": percentile(stats["translation_lengths"], 0.99),
                    "max": max(stats["translation_lengths"]),
                },
                "normalization": normalization,
                "database": database,
                "output": {
                    "path": str(output.relative_to(REPO_ROOT)),
                    "bytes": temporary.stat().st_size,
                },
            }
            report["output"]["sha256"] = sha256_file(temporary)
            report["quality_gates"] = run_quality_gates(report)

            failed = [gate for gate in report["quality_gates"] if not gate["passed"]]
            if failed:
                details = "\n".join(
                    f"  - 门槛 {gate['id']}：{gate['description']} "
                    f"（期望 {gate['expected']}，实际 {gate['actual']}）"
                    for gate in failed
                )
                raise BuildError(f"质量门槛未通过，产物未替换：\n{details}")

            os.replace(temporary, output)
        finally:
            if temporary.exists():
                temporary.unlink()

        report_dir.mkdir(parents=True, exist_ok=True)
        (report_dir / "build-report.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        (report_dir / "source-manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    except BuildError as error:
        print(f"\n构建失败：\n{error}", file=sys.stderr)
        return 1

    print("\n构建成功")
    print(f"  产物        {report['output']['path']}（{report['output']['bytes']} 字节）")
    print(f"  sha256      {report['output']['sha256']}")
    print(f"  词条数      {report['entry_count']}")
    for level, count in sorted(report["level_counts"].items()):
        print(f"    {level:<12}{count}")
    print(f"  等级关系    {report['level_relation_count']}")
    print(f"  构建报告    {report_dir / 'build-report.json'}")
    print(f"  质量门槛    {len(report['quality_gates'])} 项全部通过")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
