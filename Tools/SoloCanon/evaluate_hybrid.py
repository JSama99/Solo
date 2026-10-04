#!/usr/bin/env python3
"""Evaluate structured, semantic candidates, and hybrid Canon retrieval."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from canon_store import CanonStore, ROOT, canonical_bytes
from hybrid_retrieval import hybrid_search

FIXTURE = Path(__file__).resolve().parent / "evaluation/hybrid_queries.json"
REPORT = Path("Canon/evaluation/C6_HYBRID_EVALUATION.md")


def visibility_violations(ids: list[str], allowed: set[str]) -> list[str]:
    return sorted(set(ids) - allowed)


def authority_violations(ids: list[str], store: CanonStore) -> list[str]:
    levels = [int(store.records[identifier]["authority"]["level"][1:]) for identifier in ids]
    return [ids[index] for index in range(1, len(ids)) if levels[index] < levels[index - 1]]


def evaluate(store: CanonStore, fixture: dict, *, path: Path | None = None) -> dict:
    k = fixture["k"]
    rows = []
    for case in fixture["queries"]:
        query = case["query"]
        expected = case["expected_ids"]
        structured = [item["record"]["id"] for item in store.search(query, limit=k)]
        result = hybrid_search(store, query, limit=k, path=path)
        hybrid = [item["record"]["id"] for item in result["records"]]
        semantic = [item["id"] for item in result["semantic_candidates"]]
        allowed = set(store.eligible_ids())
        rows.append({"query": query, "expected_ids": expected, "structured_top_k": structured,
                     "semantic_only_candidates": semantic, "hybrid_top_k": hybrid,
                     "semantic_additions": sorted(set(hybrid) - set(structured)),
                     "structured_recall_at_k": len(set(expected) & set(structured)) / len(expected),
                     "hybrid_recall_at_k": len(set(expected) & set(hybrid)) / len(expected),
                     "visibility_violations": visibility_violations(hybrid + semantic, allowed),
                     "authority_violations": authority_violations(hybrid, store),
                     "semantic_status": result["semantic_status"]})
    return {"schema_version": "0.1", "k": k, "manifest_sha256": store.manifest_sha256,
            "queries": rows, "structured_recall_at_k": sum(row["structured_recall_at_k"] for row in rows) / len(rows),
            "hybrid_recall_at_k": sum(row["hybrid_recall_at_k"] for row in rows) / len(rows),
            "visibility_violations": sorted({item for row in rows for item in row["visibility_violations"]}),
            "authority_violations": sorted({item for row in rows for item in row["authority_violations"]})}


def markdown(report: dict) -> str:
    lines = ["# C6 Hybrid Retrieval Evaluation", "", "Fixed corpus: `Tools/SoloCanon/evaluation/hybrid_queries.json`.",
             f"Canon manifest: `{report['manifest_sha256']}`. Top K: {report['k']}.",
             f"Mean structured recall@K: {report['structured_recall_at_k']:.3f}; hybrid: {report['hybrid_recall_at_k']:.3f}.",
             f"Visibility violations: {len(report['visibility_violations'])}; authority order violations: {len(report['authority_violations'])}.",
             "", "| Query | Expected | Structured top K | Semantic candidates | Hybrid top K | Recall S → H |", "|---|---|---|---|---|---|"]
    for row in report["queries"]:
        line = ("| " + row["query"].replace("|", "\\|") + " | " + ", ".join(row["expected_ids"])
                + " | " + ", ".join(row["structured_top_k"])
                + " | " + ", ".join(row["semantic_only_candidates"])
                + " | " + ", ".join(row["hybrid_top_k"])
                + f" | {row['structured_recall_at_k']:.2f} → {row['hybrid_recall_at_k']:.2f} |")
        lines.append(line)
    lines.extend(("", "Semantic additions are candidates only. The index is generated cache data, not Canon evidence. Recall reflects this small fixed corpus and local concept provider; it does not establish general semantic quality.", ""))
    return "\n".join(lines)


def run(argv=None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--write-report", action="store_true")
    args = parser.parse_args(argv)
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    report = evaluate(CanonStore(root), fixture)
    if args.write_report:
        output = root / REPORT
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(markdown(report), encoding="utf-8")
    sys.stdout.buffer.write(canonical_bytes(report) if args.format == "json" else markdown(report).encode())
    return 0 if not report["visibility_violations"] and not report["authority_violations"] else 2


if __name__ == "__main__":
    raise SystemExit(run())
