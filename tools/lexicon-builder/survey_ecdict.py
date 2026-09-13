#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ECDICT 数据勘察脚本（路线图阶段 5.1）。

只读分析 ecdict.csv，回答《词库实现设计》第 11 节遗留的数据问题：

- 四个目标等级标签（zk / gk / cet4 / cet6）的实际分布与并集规模；
- 各字段的真实缺失率（phonetic / translation / pos / definition / 词频）；
- translation 的形态：字面 ``\\n`` 还是真实换行、是否带词性前缀、长度分布；
- pos 字段的真实语义（本 CSV 中是否可用）；
- 词频字段的 0 值占比（0 表示无排名，排序时必须当作缺失）；
- 规范化查询键的碰撞情况；
- 产物体积量级估算，用于核对《词库实现设计》第 8 节。

本脚本只读：不创建数据库，不修改源文件，只输出报告。

用法：
    python3 tools/lexicon-builder/survey_ecdict.py .lexicon-source/ecdict.csv
"""

from __future__ import annotations

import csv
import json
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path

TARGET_TAGS = ("zk", "gk", "cet4", "cet6")
# 词性前缀，用于确认 translation 是否自带词性信息。
# 注意：ECDICT 用 `a.` 表示形容词（不是 adj.），因此必须包含单字母缩写，
# 否则会把大量形容词误判为"无词性前缀"。
POS_PREFIX = re.compile(
    r"^\s*(n|v|vt|vi|adj|adv|ad|a|prep|pron|conj|interj|int|num|art|aux|"
    r"abbr|pl|sing)\s*[.．]",
    re.IGNORECASE,
)
# 来源用字面 ``\n`` 表示换行，而不是真实换行符。
LITERAL_NEWLINE = "\\n"


def normalize_search_term(text: str) -> str:
    """与 Swift 侧 WordNormalizer.normalizedTerm(_:in:.english) 对齐。

    去首尾空白 -> 连续空白折叠为单空格 -> NFC -> 小写。
    注意：Python 的 str.lower() 与 Swift 的 en_US_POSIX 小写规则在极少数
    字符上可能不同，正式构建前需要用固定样例做跨语言断言。
    """
    collapsed = " ".join(text.split())
    return unicodedata.normalize("NFC", collapsed).lower()


def percentile(values: list[int], ratio: float) -> int:
    """就近取位的分位数。"""
    if not values:
        return 0
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(len(ordered) * ratio) - 1))
    return ordered[index]


def utf8_len(text: str) -> int:
    return len(text.encode("utf-8"))


def rate(numerator: int, denominator: int) -> float | None:
    return round(numerator / denominator, 4) if denominator else None


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    source = Path(sys.argv[1])
    if not source.is_file():
        print(f"源文件不存在：{source}", file=sys.stderr)
        return 2

    total_rows = 0
    parse_errors = 0
    column_empty: Counter[str] = Counter()
    header: list[str] = []

    tag_counter: Counter[str] = Counter()
    tags_per_row: Counter[int] = Counter()

    tagged_rows_total = 0
    tagged_rows_dropped = 0

    subset_rows = 0
    level_counter: Counter[str] = Counter()
    subset_phonetic_missing = 0
    subset_pos_missing = 0
    subset_definition_missing = 0
    frequency_rank_nonzero = 0
    bnc_rank_nonzero = 0
    translation_has_real_newline = 0
    translation_has_literal_newline = 0
    translation_starts_with_bracket = 0
    translation_has_literal_carriage_return = 0
    first_line_with_pos_prefix = 0
    translation_lengths: list[int] = []
    translation_utf8_bytes = 0
    term_utf8_bytes = 0
    search_term_utf8_bytes = 0
    pos_values: Counter[str] = Counter()
    normalized_terms: Counter[str] = Counter()
    raw_term_variants: Counter[str] = Counter()
    longest_samples: list[tuple[int, str, str]] = []
    no_pos_prefix_samples: list[dict[str, str]] = []

    with source.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        try:
            header = next(reader)
        except StopIteration:
            print("源文件为空", file=sys.stderr)
            return 1

        required = {"word", "phonetic", "translation", "pos", "tag", "frq", "bnc", "definition"}
        missing_columns = required.difference(header)
        if missing_columns:
            print(f"缺少必需列：{sorted(missing_columns)}", file=sys.stderr)
            return 1

        index = {name: header.index(name) for name in required}
        width = len(header)

        for row in reader:
            if len(row) != width:
                parse_errors += 1
                continue
            total_rows += 1

            for position, name in enumerate(header):
                if not row[position].strip():
                    column_empty[name] += 1

            tags = row[index["tag"]].split()
            for tag in tags:
                tag_counter[tag] += 1
            tags_per_row[len(tags)] += 1

            hit = [tag for tag in TARGET_TAGS if tag in tags]
            if not hit:
                continue
            tagged_rows_total += 1

            term = row[index["word"]].strip()
            translation = row[index["translation"]].strip()
            if not term or not translation:
                tagged_rows_dropped += 1
                continue

            subset_rows += 1
            for tag in hit:
                level_counter[tag] += 1

            phonetic = row[index["phonetic"]].strip()
            pos = row[index["pos"]].strip()
            definition = row[index["definition"]].strip()
            if not phonetic:
                subset_phonetic_missing += 1
            if not pos:
                subset_pos_missing += 1
            else:
                pos_values[pos] += 1
            if not definition:
                subset_definition_missing += 1

            # 0 表示"无排名"，必须与真实排名区分，否则排序会把生僻词排到最前。
            if row[index["frq"]].strip() not in ("", "0"):
                frequency_rank_nonzero += 1
            if row[index["bnc"]].strip() not in ("", "0"):
                bnc_rank_nonzero += 1

            if "\n" in translation:
                translation_has_real_newline += 1
            if LITERAL_NEWLINE in translation:
                translation_has_literal_newline += 1
            if translation.startswith("["):
                translation_starts_with_bracket += 1
            if "\\r" in translation:
                translation_has_literal_carriage_return += 1

            first_line = translation.split(LITERAL_NEWLINE)[0]
            if POS_PREFIX.match(first_line):
                first_line_with_pos_prefix += 1
            elif len(no_pos_prefix_samples) < 5:
                no_pos_prefix_samples.append(
                    {"term": term, "first_line": first_line[:120]}
                )

            length = len(translation)
            translation_lengths.append(length)
            translation_utf8_bytes += utf8_len(translation)
            term_utf8_bytes += utf8_len(term)
            search_term_utf8_bytes += utf8_len(normalize_search_term(term))

            normalized_terms[normalize_search_term(term)] += 1
            raw_term_variants[term] += 1

            if len(longest_samples) < 5 or length > longest_samples[0][0]:
                longest_samples.append((length, term, translation))
                longest_samples.sort(key=lambda item: item[0])
                if len(longest_samples) > 5:
                    longest_samples.pop(0)

    collisions = {key: count for key, count in normalized_terms.items() if count > 1}
    duplicate_variants = {key: count for key, count in raw_term_variants.items() if count > 1}

    # 体积估算：词形 + 搜索键 + 音标 + 释义 + 等级关系 + 行与索引开销。
    estimated_entry_bytes = (
        term_utf8_bytes
        + search_term_utf8_bytes
        + translation_utf8_bytes
        + subset_rows * (20 + 64)
    )

    report = {
        "source": str(source),
        "header": header,
        "total_rows": total_rows,
        "parse_errors": parse_errors,
        "column_empty_counts": dict(column_empty),
        "all_tags_top30": tag_counter.most_common(30),
        "tags_per_row": {str(k): v for k, v in sorted(tags_per_row.items())},
        "target_subset": {
            "tagged_rows_total": tagged_rows_total,
            "tagged_rows_dropped_empty_term_or_translation": tagged_rows_dropped,
            "rows": subset_rows,
            "level_counts": {tag: level_counter[tag] for tag in TARGET_TAGS},
            "phonetic_missing": subset_phonetic_missing,
            "phonetic_missing_rate": rate(subset_phonetic_missing, subset_rows),
            "definition_missing": subset_definition_missing,
            "definition_missing_rate": rate(subset_definition_missing, subset_rows),
            "pos_missing": subset_pos_missing,
            "pos_missing_rate": rate(subset_pos_missing, subset_rows),
            "frequency_rank_nonzero": frequency_rank_nonzero,
            "frequency_rank_nonzero_rate": rate(frequency_rank_nonzero, subset_rows),
            "bnc_rank_nonzero": bnc_rank_nonzero,
            "bnc_rank_nonzero_rate": rate(bnc_rank_nonzero, subset_rows),
            "translation_has_real_newline": translation_has_real_newline,
            "translation_has_literal_newline": translation_has_literal_newline,
            "translation_has_literal_newline_rate": rate(
                translation_has_literal_newline, subset_rows
            ),
            "translation_starts_with_bracket": translation_starts_with_bracket,
            "translation_has_literal_carriage_return": translation_has_literal_carriage_return,
            "first_line_with_pos_prefix": first_line_with_pos_prefix,
            "first_line_with_pos_prefix_rate": rate(
                first_line_with_pos_prefix, subset_rows
            ),
            "translation_length_chars": {
                "min": min(translation_lengths) if translation_lengths else None,
                "p50": percentile(translation_lengths, 0.50),
                "p90": percentile(translation_lengths, 0.90),
                "p99": percentile(translation_lengths, 0.99),
                "max": max(translation_lengths) if translation_lengths else None,
            },
            "distinct_normalized_terms": len(normalized_terms),
            "collision_keys": len(collisions),
            "collision_extra_rows": sum(collisions.values()) - len(collisions),
            "duplicate_raw_term_keys": len(duplicate_variants),
        },
        "pos_field_samples": pos_values.most_common(20),
        "no_pos_prefix_samples": no_pos_prefix_samples,
        "longest_translation_samples": [
            {"length": length, "term": term, "translation": text[:400]}
            for length, term, text in reversed(longest_samples)
        ],
        "estimated_sqlite_bytes": estimated_entry_bytes,
        "estimated_sqlite_mb": round(estimated_entry_bytes / 1048576, 2),
    }

    output = json.dumps(report, ensure_ascii=False, indent=2)
    print(output)

    report_path = source.parent / "survey-report.json"
    report_path.write_text(output, encoding="utf-8")
    print(f"\n[勘察报告已写入] {report_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
