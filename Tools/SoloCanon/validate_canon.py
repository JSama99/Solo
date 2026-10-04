#!/usr/bin/env python3
"""Validate SOLO Canon C0 and check or generate its deterministic manifest."""

import argparse
import datetime as dt
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEVELS = dict(zip((f"P{i}" for i in range(8)), (
    "owner_locked", "production_canon", "accepted", "implemented",
    "proposed", "experimental", "historical", "deprecated")))
STATUSES = set(("canonical", "accepted", "implemented", "proposed", "experimental", "historical", "deprecated", "blocked"))
TYPES = set(("system", "mechanic", "entity", "asset", "character", "location", "rule", "decision", "experiment", "evidence", "agent"))
SCOPES = set(("developer", "simulation_internal", "founder_known", "agent_known", "public", "media", "rival", "runtime_safe"))
PREDICATES = set(("depends_on", "reads", "writes", "produces", "affects", "implemented_by", "presented_by", "located_in", "governed_by", "supersedes", "evidenced_by", "related_to"))
SOURCE_KINDS = set(("source_file", "test", "evidence_file", "owner_acceptance", "documentation", "commit", "asset"))
REQUIRED = set(("schema_version", "id", "type", "title", "status", "authority", "summary", "validity", "visibility", "facts", "relationships", "constraints", "sources", "evidence", "supersedes", "superseded_by", "tags"))
OPTIONAL = {"external_evidence", "runtime_projection"}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9]*(?:[._][a-z0-9]+)*$")


def canonical_json(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def repository_path(root, value):
    if not isinstance(value, str) or not value or "\\" in value:
        return None
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        return None
    resolved = (root / path).resolve()
    return resolved if resolved.is_relative_to(root.resolve()) else None


def parse_date(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        return None
    try:
        return dt.date.fromisoformat(value)
    except ValueError:
        return None


def validate_record(record, root):
    errors = []
    if not isinstance(record, dict):
        return ["record must be an object"]
    missing = REQUIRED - record.keys()
    if missing:
        errors.append("missing fields: " + ", ".join(sorted(missing)))
    extra = record.keys() - REQUIRED - OPTIONAL
    if extra:
        errors.append("unknown fields: " + ", ".join(sorted(extra)))
    if record.get("schema_version") != "0.1":
        errors.append("unsupported schema_version")
    if not isinstance(record.get("id"), str) or not ID_PATTERN.fullmatch(record["id"]):
        errors.append("invalid id")
    if not isinstance(record.get("type"), str) or record["type"] not in TYPES:
        errors.append("unsupported type")
    if not isinstance(record.get("title"), str) or not record["title"].strip():
        errors.append("title must be nonempty")
    if not isinstance(record.get("summary"), str) or not record["summary"].strip():
        errors.append("summary must be nonempty")
    status = record.get("status")
    if not isinstance(status, str) or status not in STATUSES:
        errors.append("unsupported status")
    authority = record.get("authority")
    if not isinstance(authority, dict) or set(authority) != {"level", "kind"} or not isinstance(authority.get("level"), str) or LEVELS.get(authority["level"]) != authority.get("kind"):
        errors.append("invalid authority level/kind")
        level = None
    else:
        level = authority["level"]
    expected_status = {"P0": "canonical", "P1": "canonical", "P2": "accepted", "P3": "implemented", "P4": "proposed", "P5": "experimental", "P6": "historical", "P7": "deprecated"}
    if level and status != expected_status[level] and status != "blocked":
        errors.append("status conflicts with authority")
    visibility = record.get("visibility")
    if not isinstance(visibility, list) or not visibility or any(not isinstance(v, str) or v not in SCOPES for v in visibility) or len(visibility) != len(set(map(str, visibility))):
        errors.append("invalid visibility scopes")
    projection = record.get("runtime_projection")
    if projection is not None:
        if not isinstance(projection, dict) or set(projection) != {"title", "summary", "facts", "relationships", "tags"}:
            errors.append("invalid runtime_projection fields")
        else:
            if any(not isinstance(projection.get(key), str) or not projection[key].strip() for key in ("title", "summary")):
                errors.append("invalid runtime_projection title/summary")
            if not isinstance(projection["facts"], dict) or any(
                    not isinstance(key, str) or not key or type(value) not in (str, int, float, bool)
                    for key, value in projection["facts"].items()):
                errors.append("invalid runtime_projection facts")
            if not isinstance(projection["tags"], list) or any(not isinstance(tag, str) or not tag for tag in projection["tags"]):
                errors.append("invalid runtime_projection tags")
            if not isinstance(projection["relationships"], list) or any(
                    not isinstance(edge, dict) or set(edge) != {"predicate", "target", "required"}
                    or not isinstance(edge["predicate"], str) or edge["predicate"] not in PREDICATES
                    or not isinstance(edge["target"], str)
                    or type(edge["required"]) is not bool for edge in projection["relationships"]):
                errors.append("invalid runtime_projection relationships")
    if isinstance(visibility, list) and "runtime_safe" in visibility and projection is None:
        errors.append("runtime_safe visibility requires explicit runtime_projection")
    validity = record.get("validity")
    if not isinstance(validity, dict) or set(validity) != {"valid_from", "valid_until"}:
        errors.append("invalid validity object")
    else:
        start = parse_date(validity["valid_from"])
        end = parse_date(validity["valid_until"]) if validity["valid_until"] is not None else None
        if not start or (validity["valid_until"] is not None and not end) or (start and end and end < start):
            errors.append("invalid date interval")
        if status in {"canonical", "accepted", "implemented"} and end is not None:
            errors.append("active status has closed validity")
        if status in {"historical", "deprecated"} and end is None:
            errors.append("historical/deprecated status needs valid_until")
    for name in ("facts",):
        if not isinstance(record.get(name), dict):
            errors.append(f"{name} must be an object")
    for name in ("constraints", "tags", "evidence", "supersedes", "superseded_by"):
        value = record.get(name)
        if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value) or len(value) != len(set(map(str, value))):
            errors.append(f"{name} must be a unique string array")
    sources = record.get("sources")
    if not isinstance(sources, list):
        errors.append("sources must be an array")
        sources = []
    if level in {"P0", "P1", "P2"} and not sources:
        errors.append("missing P0/P1/P2 provenance")
    for source in sources:
        if not isinstance(source, dict) or not isinstance(source.get("kind"), str) or source["kind"] not in SOURCE_KINDS:
            errors.append("invalid source kind")
            continue
        if set(source) - {"kind", "path", "sha"}:
            errors.append("unknown source fields")
        if source["kind"] == "commit":
            if not isinstance(source.get("sha"), str) or not re.fullmatch(r"[0-9a-f]{40}", source["sha"]):
                errors.append("commit source needs full SHA")
        else:
            path = repository_path(root, source.get("path"))
            if path is None or not path.is_file():
                errors.append(f"source path missing or unsafe: {source.get('path')}")
    external = record.get("external_evidence", [])
    if not isinstance(external, list):
        errors.append("external_evidence must be an array")
    else:
        seen_paths = set()
        for reference in external:
            if not isinstance(reference, dict) or set(reference) != {"system", "path", "sha256", "run_id", "graph_id", "ledger_head"}:
                errors.append("invalid external evidence reference")
                continue
            value = reference["path"]
            path = repository_path(root, value)
            if (reference["system"] != "solo_loop_v3" or not isinstance(value, str)
                    or not re.fullmatch(r"\.solo-loop/runs/[a-zA-Z0-9._-]+/evidence\.jsonl", value)
                    or path is None):
                errors.append("invalid external evidence path/system")
                continue
            if value in seen_paths:
                errors.append("duplicate external evidence path")
            seen_paths.add(value)
            if any(not isinstance(reference[field], str) or not re.fullmatch(r"[0-9a-f]{64}", reference[field]) for field in ("sha256", "ledger_head")):
                errors.append("invalid external evidence hash")
            if any(not isinstance(reference[field], str) or not reference[field] for field in ("run_id", "graph_id")):
                errors.append("invalid external evidence identifiers")
            if path.is_file():
                if hashlib.sha256(path.read_bytes()).hexdigest() != reference["sha256"]:
                    errors.append(f"external evidence SHA-256 mismatch: {value}")
                try:
                    lines = path.read_text(encoding="utf-8").splitlines()
                    first = json.loads(lines[0])
                    last = json.loads(lines[-1])
                    if (first.get("run_id") != reference["run_id"]
                            or first.get("graph_id") != reference["graph_id"]
                            or last.get("record_sha256") != reference["ledger_head"]):
                        errors.append(f"external evidence identity/head mismatch: {value}")
                except (UnicodeError, IndexError, json.JSONDecodeError):
                    errors.append(f"invalid external evidence JSONL: {value}")
    relationships = record.get("relationships")
    if not isinstance(relationships, list):
        errors.append("relationships must be an array")
    else:
        for relation in relationships:
            if not isinstance(relation, dict) or set(relation) != {"predicate", "target"} or not isinstance(relation.get("predicate"), str) or relation["predicate"] not in PREDICATES or not isinstance(relation.get("target"), str):
                errors.append("invalid relationship")
    return errors


def make_manifest(records):
    entries = []
    for path, record in records:
        entries.append({"id": record["id"], "type": record["type"], "status": record["status"],
                        "authority": record["authority"]["level"], "path": path,
                        "sha256": hashlib.sha256(canonical_json(record)).hexdigest(),
                        "visibility": sorted(record["visibility"])})
    entries.sort(key=lambda entry: (entry["id"], entry["path"]))
    return {"schema_version": "0.1", "canon_version": "C0", "generated_from": "Canon/records/**/*.json",
            "record_count": len(entries), "records": entries}


def validate_tree(root, check_manifest=True):
    errors = []
    records = []
    for file in sorted((root / "Canon/records").rglob("*.json")):
        path = file.relative_to(root).as_posix()
        try:
            record = json.loads(file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"[{path}] invalid JSON: {exc}")
            continue
        record_id = record.get("id", path) if isinstance(record, dict) else path
        errors.extend(f"[{record_id}] {message}" for message in validate_record(record, root))
        if isinstance(record, dict):
            records.append((path, record))
    if not records:
        errors.append("[tree] no Canon records")
    by_id = {}
    active_truth = {}
    for path, record in records:
        record_id = record.get("id")
        if not isinstance(record_id, str):
            continue
        if record_id in by_id:
            errors.append(f"[{record_id}] duplicate ID: {by_id[record_id][0]} and {path}")
        else:
            by_id[record_id] = (path, record)
        facts = record.get("facts")
        authority = record.get("authority")
        if (isinstance(facts, dict) and isinstance(authority, dict)
                and authority.get("level") in {"P0", "P1"}
                and record.get("status") == "canonical"
                and isinstance(record.get("validity"), dict)
                and record["validity"].get("valid_until") is None
                and "truth_key" in facts):
            key = facts["truth_key"]
            value = facts.get("truth_value")
            if not isinstance(key, str) or not key or value is None:
                errors.append(f"[{record_id}] truth_key requires truth_value")
            elif key in active_truth and active_truth[key][1] != value:
                errors.append(f"[{record_id}] contradictory active P0/P1 truth_key: {key} (also {active_truth[key][0]})")
            else:
                active_truth[key] = (record_id, value)
    for _, record in records:
        owner = record.get("id", "unknown")
        for relation in record.get("relationships", []) if isinstance(record.get("relationships"), list) else []:
            if not isinstance(relation, dict):
                continue
            target = relation.get("target")
            if not isinstance(target, str) or target not in by_id:
                errors.append(f"[{owner}] unresolved relationship target: {target}")
            if target == owner and relation.get("predicate") != "related_to":
                errors.append(f"[{owner}] prohibited self relationship: {relation.get('predicate')}")
        for evidence in record.get("evidence", []) if isinstance(record.get("evidence"), list) else []:
            if not isinstance(evidence, str) or evidence not in by_id or by_id[evidence][1].get("type") != "evidence":
                errors.append(f"[{owner}] missing evidence target: {evidence}")
        for field, inverse in (("supersedes", "superseded_by"), ("superseded_by", "supersedes")):
            for target in record.get(field, []) if isinstance(record.get(field), list) else []:
                if target == owner:
                    errors.append(f"[{owner}] self-supersession")
                if not isinstance(target, str) or target not in by_id:
                    errors.append(f"[{owner}] unresolved {field} target: {target}")
                elif owner not in by_id[target][1].get(inverse, []):
                    errors.append(f"[{owner}] {field} lacks reciprocal {inverse}: {target}")
                if field == "supersedes" and isinstance(target, str) and target in by_id:
                    older = by_id[target][1]
                    old_validity = older.get("validity")
                    new_validity = record.get("validity")
                    if isinstance(old_validity, dict) and isinstance(new_validity, dict):
                        old_end = parse_date(old_validity.get("valid_until"))
                        new_start = parse_date(new_validity.get("valid_from"))
                        if old_end and new_start and old_end >= new_start:
                            errors.append(f"[{owner}] supersession overlaps validity: {target}")
    manifest = make_manifest([(p, r) for p, r in records if all(k in r for k in ("id", "type", "status", "authority", "visibility")) and all(isinstance(r[k], str) for k in ("id", "type", "status")) and isinstance(r["authority"], dict) and isinstance(r["authority"].get("level"), str) and isinstance(r["visibility"], list) and all(isinstance(v, str) for v in r["visibility"])])
    if check_manifest:
        file = root / "Canon/manifests/canon-manifest.json"
        try:
            actual = file.read_bytes()
        except OSError:
            errors.append("[manifest] missing manifest")
        else:
            if actual != canonical_json(manifest):
                errors.append("[manifest] entries or formatting differ from deterministic generated manifest")
    return sorted(errors), manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", help="show validation context for one exact Canon ID")
    parser.add_argument("--write-manifest", action="store_true", help="regenerate manifest after validating records")
    args = parser.parse_args()
    errors, manifest = validate_tree(ROOT, check_manifest=not args.write_manifest)
    if args.record and args.record not in {entry["id"] for entry in manifest["records"]}:
        errors.append(f"[{args.record}] record not found")
    if args.write_manifest and not errors:
        path = ROOT / "Canon/manifests/canon-manifest.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(canonical_json(manifest))
    print("SOLO Canon v0.1")
    print(f"Records: {manifest['record_count']}")
    for error in sorted(errors):
        print("ERROR " + error)
    print(f"Errors: {len(errors)}")
    print("Warnings: 0")
    print("Result: " + ("FAIL" if errors else "PASS"))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
