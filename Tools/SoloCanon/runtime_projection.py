#!/usr/bin/env python3
"""Compile a bounded, read-only runtime-safe projection from validated Canon."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from canon_store import CanonError, CanonStore, ROOT, canonical_bytes, parse_as_of
from validate_canon import ID_PATTERN, PREDICATES, TYPES

VERSION = "0.1"
POLICY_VERSION = "1.0"
OUTPUT_DEFAULT = Path(".solo-loop/cache/runtime-canon/projection.json")
AUDIENCES = ("runtime", "aurora", "stacks", "brio", "signal_tv", "rival", "founder")
FIELDS = {"id": "allow after explicit runtime_safe and block", "type": "allow",
          "title": "use runtime_projection only", "summary": "use runtime_projection only",
          "facts": "use runtime_projection only", "relationships": "use runtime_projection only; prune unsafe targets",
          "tags": "use runtime_projection only", "authority": "remove", "status": "filter then remove",
          "visibility": "filter then remove", "constraints": "remove", "sources": "remove",
          "evidence": "remove", "external_evidence": "remove", "supersession": "filter then remove"}
ALLOWED_STATUS = {"canonical", "accepted", "implemented"}
FORBIDDEN_TEXT = re.compile(
    r"(?:App/|Tools/|Documentation/|\.solo-loop/|\.swift\b|\.blend\b|\.usdz\b|"
    r"\bsimulation_internal\b|\bowner_locked\b|\bP[0-7]\b|\bLoop V3\b|\bcodex\b|"
    r"\bGameStore\b|\bSimulationEngine\b|\bdrift\b|\boverclaim\b|\blatent defect\b|"
    r"\brejected\b|\bblocked study\b|\b[0-9a-f]{40}\b)", re.IGNORECASE)


def _safe_text(value: str, field: str) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > 500 or FORBIDDEN_TEXT.search(value):
        raise CanonError("unsafe runtime projection text in " + field)
    return value


def _safe_block(record: dict) -> dict:
    block = record.get("runtime_projection")
    if not isinstance(block, dict) or set(block) != {"title", "summary", "facts", "relationships", "tags"}:
        raise CanonError("malformed runtime projection block: " + record["id"])
    title = _safe_text(block["title"], record["id"] + ".title")
    summary = _safe_text(block["summary"], record["id"] + ".summary")
    facts = block["facts"]
    if not isinstance(facts, dict) or len(facts) > 20:
        raise CanonError("malformed runtime projection facts: " + record["id"])
    safe_facts = {}
    for key, value in sorted(facts.items()):
        _safe_text(key, record["id"] + ".fact_key")
        if not re.fullmatch(r"[a-z][a-z0-9_]*", key) or type(value) not in (str, int, float, bool):
            raise CanonError("malformed runtime projection fact: " + record["id"])
        if isinstance(value, str):
            _safe_text(value, record["id"] + "." + key)
        if type(value) is float and not math.isfinite(value):
            raise CanonError("nonfinite runtime projection fact: " + record["id"])
        safe_facts[key] = value
    tags = block["tags"]
    if not isinstance(tags, list) or any(not isinstance(tag, str) for tag in tags) or len(tags) != len(set(tags)) or any(
            not isinstance(tag, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", tag)
            or FORBIDDEN_TEXT.search(tag) for tag in tags):
        raise CanonError("malformed runtime projection tags: " + record["id"])
    edges = block["relationships"]
    if not isinstance(edges, list):
        raise CanonError("malformed runtime projection relationships: " + record["id"])
    safe_edges = []
    original = {(edge["predicate"], edge["target"]) for edge in record["relationships"]}
    for edge in edges:
        if (not isinstance(edge, dict) or set(edge) != {"predicate", "target", "required"}
                or not isinstance(edge["predicate"], str) or edge["predicate"] not in PREDICATES
                or not isinstance(edge["target"], str) or not ID_PATTERN.fullmatch(edge["target"])
                or type(edge["required"]) is not bool
                or (edge["predicate"], edge["target"]) not in original):
            raise CanonError("malformed or unsupported runtime projection relationship: " + record["id"])
        safe_edges.append(edge)
    if len({(edge["predicate"], edge["target"]) for edge in safe_edges}) != len(safe_edges):
        raise CanonError("duplicate runtime projection relationship: " + record["id"])
    return {"id": _safe_text(record["id"], "id"), "type": record["type"],
            "title": title, "summary": summary, "facts": safe_facts,
            "relationships": safe_edges, "tags": sorted(tags)}


def _currently_superseded(store: CanonStore, record: dict, as_of: str) -> bool:
    for successor_id in record["superseded_by"]:
        successor = store.records[successor_id]
        validity = successor["validity"]
        if (validity["valid_from"] <= as_of and
                (validity["valid_until"] is None or validity["valid_until"] >= as_of)
                and successor["status"] in ALLOWED_STATUS):
            return True
    return False


def validate_projection(projection: dict) -> None:
    top = {"schema_version", "projection_version", "projection_policy_version", "canon_manifest_sha256",
           "as_of", "audience", "record_count", "eligible_record_ids", "records", "projection_sha256"}
    if not isinstance(projection, dict) or set(projection) != top:
        raise CanonError("projection schema failed: top-level fields")
    if (projection["schema_version"] != VERSION or projection["projection_version"] != VERSION
            or projection["projection_policy_version"] != POLICY_VERSION or projection["audience"] != "runtime"
            or not isinstance(projection["canon_manifest_sha256"], str)
            or not re.fullmatch(r"[0-9a-f]{64}", projection["canon_manifest_sha256"])):
        raise CanonError("projection schema failed: metadata")
    parse_as_of(projection["as_of"], projection["as_of"])
    records = projection["records"]
    ids = projection["eligible_record_ids"]
    if (not isinstance(records, list) or not isinstance(ids, list) or ids != sorted(set(ids))
            or projection["record_count"] != len(records) or ids != [item.get("id") for item in records if isinstance(item, dict)]):
        raise CanonError("projection schema failed: record IDs or count")
    for record in records:
        if not isinstance(record, dict) or set(record) != {"id", "type", "title", "summary", "facts", "relationships", "tags"}:
            raise CanonError("projection schema failed: record fields")
        if not isinstance(record["id"], str) or not ID_PATTERN.fullmatch(record["id"]) or record["type"] not in TYPES:
            raise CanonError("projection schema failed: id or type")
        _safe_text(record["title"], record["id"] + ".title")
        _safe_text(record["summary"], record["id"] + ".summary")
        if not isinstance(record["facts"], dict) or not isinstance(record["tags"], list) or not isinstance(record["relationships"], list):
            raise CanonError("projection schema failed: nested fields")
        if any(not isinstance(key, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", key)
               or type(value) not in (str, int, float, bool)
               or (isinstance(value, str) and FORBIDDEN_TEXT.search(value))
               or (type(value) is float and not math.isfinite(value))
               for key, value in record["facts"].items()):
            raise CanonError("projection schema failed: facts")
        if any(not isinstance(tag, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", tag)
               for tag in record["tags"]) or len(set(record["tags"])) != len(record["tags"]):
            raise CanonError("projection schema failed: tags")
        for edge in record["relationships"]:
            if (not isinstance(edge, dict) or set(edge) != {"predicate", "target"}
                    or edge["predicate"] not in PREDICATES or edge["target"] not in ids):
                raise CanonError("projection schema failed: relationship target")
    core = {key: value for key, value in projection.items() if key != "projection_sha256"}
    expected = hashlib.sha256(canonical_bytes(core)).hexdigest()
    if projection["projection_sha256"] != expected:
        raise CanonError("projection schema failed: fingerprint mismatch")


def build_projection(store: CanonStore, *, as_of: str | None = None) -> dict:
    as_of = parse_as_of(as_of, store.default_as_of)
    selected = {}
    for identifier in store.ids:
        record = store.records[identifier]
        validity = record["validity"]
        if not isinstance(record["visibility"], list):
            raise CanonError("runtime visibility cannot be evaluated: " + identifier)
        if "runtime_safe" not in record["visibility"] or record["status"] not in ALLOWED_STATUS:
            continue
        if validity["valid_from"] > as_of or (validity["valid_until"] is not None and validity["valid_until"] < as_of):
            continue
        if _currently_superseded(store, record, as_of):
            continue
        if identifier in selected:
            raise CanonError("duplicate projected ID: " + identifier)
        selected[identifier] = _safe_block(record)
    ids = sorted(selected)
    records = []
    for identifier in ids:
        item = selected[identifier]
        edges = []
        for edge in item["relationships"]:
            if edge["target"] not in selected:
                if edge["required"]:
                    raise CanonError("required runtime relationship target is not eligible: " + identifier)
                continue
            edges.append({"predicate": edge["predicate"], "target": edge["target"]})
        item["relationships"] = sorted(edges, key=lambda edge: (edge["predicate"], edge["target"]))
        records.append(item)
    core = {"schema_version": VERSION, "projection_version": VERSION,
            "projection_policy_version": POLICY_VERSION,
            "canon_manifest_sha256": store.manifest_sha256, "as_of": as_of,
            "audience": "runtime", "record_count": len(records),
            "eligible_record_ids": ids, "records": records}
    result = {**core, "projection_sha256": hashlib.sha256(canonical_bytes(core)).hexdigest()}
    validate_projection(result)
    return result


def run(argv=None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "inspect"))
    parser.add_argument("--format", choices=("json",), default="json")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--as-of")
    args = parser.parse_args(argv)
    try:
        projection = build_projection(CanonStore(root), as_of=args.as_of)
        if args.command == "inspect":
            if args.output:
                raise CanonError("inspect does not write output")
            output = {"record_count": projection["record_count"],
                      "eligible_record_ids": projection["eligible_record_ids"],
                      "projection_sha256": projection["projection_sha256"],
                      "canon_manifest_sha256": projection["canon_manifest_sha256"]}
        else:
            output = projection
            if args.output:
                path = args.output if args.output.is_absolute() else root / args.output
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(canonical_bytes(projection))
        sys.stdout.buffer.write(canonical_bytes(output))
        return 0
    except (CanonError, OSError, ValueError, KeyError, TypeError) as exc:
        print("ERROR: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(run())
