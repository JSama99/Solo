#!/usr/bin/env python3
"""Reduce a C7 projection and authorized state to one consumer's context."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from canon_store import CanonError, ROOT, canonical_bytes, parse_as_of
from runtime_projection import validate_projection

POLICY_VERSION = "0.1"
DEFAULT_PROJECTION = Path(".solo-loop/cache/runtime-canon/projection.json")
MANIFEST = Path("Canon/manifests/canon-manifest.json")
CONSUMERS = ("aurora", "stacks", "brio", "signal_tv", "tech_com", "founder", "rival")
VISIBILITY = {
    "public": frozenset(CONSUMERS),
    "founder": frozenset(("founder",)),
    "aurora": frozenset(("aurora",)),
    "stacks": frozenset(("stacks",)),
    "brio": frozenset(("brio",)),
    "agent_shared": frozenset(("aurora", "stacks", "brio")),
    "signal_tv": frozenset(("signal_tv",)),
    "tech_com": frozenset(("tech_com",)),
    "media_shared": frozenset(("signal_tv", "tech_com")),
    "rival": frozenset(("rival",)),
    "simulation_internal": frozenset(),
}
# These IDs are only filters over records already admitted by C7. They grant nothing.
CANON_IDS = {
    "aurora": frozenset(("agent.aurora", "location.founder_garage", "location.atlantis")),
    "stacks": frozenset(("agent.stacks", "location.founder_garage", "location.atlantis")),
    "brio": frozenset(("agent.brio", "entity.tech_com", "system.signal_tv", "location.founder_garage", "location.atlantis")),
    "signal_tv": frozenset(("system.signal_tv", "entity.tech_com", "location.atlantis")),
    "tech_com": frozenset(("entity.tech_com", "system.signal_tv", "location.atlantis")),
    "founder": frozenset(("agent.aurora", "agent.stacks", "agent.brio", "entity.tech_com", "system.signal_tv", "location.founder_garage", "location.atlantis")),
    "rival": frozenset(("entity.tech_com", "system.signal_tv", "location.atlantis")),
}
ID_RE = re.compile(r"runtime\.[a-z][a-z0-9_]*\.[a-z0-9_]+\Z")
KINDS = frozenset(("event", "fact", "assignment", "metric"))


def validate_state(state: object) -> dict:
    """Validate the intentionally small input schema without reading GameStore."""
    if not isinstance(state, dict) or set(state) != {"schema_version", "state_version", "knowledge"}:
        raise CanonError("runtime state schema failed: envelope")
    if state["schema_version"] != "0.1" or type(state["state_version"]) is not int or state["state_version"] < 0:
        raise CanonError("runtime state schema failed: version")
    items = state["knowledge"]
    if not isinstance(items, list):
        raise CanonError("runtime state schema failed: knowledge list")
    seen = set()
    for item in items:
        if not isinstance(item, dict) or set(item) != {"id", "kind", "summary", "visibility"}:
            raise CanonError("runtime state schema failed: knowledge fields")
        identifier = item["id"]
        if not isinstance(identifier, str) or not ID_RE.fullmatch(identifier):
            raise CanonError("runtime state schema failed: knowledge ID")
        if identifier in seen:
            raise CanonError("duplicate runtime knowledge ID: " + identifier)
        seen.add(identifier)
        if not isinstance(item["kind"], str) or item["kind"] not in KINDS or not isinstance(item["summary"], str) or not item["summary"].strip() or len(item["summary"]) > 500:
            raise CanonError("runtime state schema failed: kind or summary")
        labels = item["visibility"]
        if not isinstance(labels, list) or not labels or any(not isinstance(label, str) or label not in VISIBILITY for label in labels):
            raise CanonError("unknown or missing runtime visibility label")
        if len(labels) != len(set(labels)) or ("simulation_internal" in labels and len(labels) != 1):
            raise CanonError("runtime state schema failed: conflicting visibility")
    return {"schema_version": "0.1", "state_version": state["state_version"],
            "knowledge": [{**item, "visibility": sorted(item["visibility"])} for item in sorted(items, key=lambda i: i["id"])]}


def build_context(projection: dict, state: dict, consumer: str, *,
                  expected_manifest_sha256: str, as_of: str | None = None,
                  audit: bool = False) -> dict:
    if consumer not in CONSUMERS:
        raise CanonError("unknown runtime consumer")
    validate_projection(projection)
    if (not isinstance(expected_manifest_sha256, str) or
            not re.fullmatch(r"[0-9a-f]{64}", expected_manifest_sha256) or
            projection["canon_manifest_sha256"] != expected_manifest_sha256):
        raise CanonError("runtime projection stale relative to Canon manifest")
    effective_date = parse_as_of(as_of, projection["as_of"])
    if effective_date != projection["as_of"]:
        raise CanonError("runtime projection date differs from requested as-of")
    normalized_state = validate_state(state)
    state_hash = hashlib.sha256(canonical_bytes(normalized_state)).hexdigest()
    allowed_ids = CANON_IDS[consumer]
    canon = [record for record in projection["records"] if record["id"] in allowed_ids]
    included_ids = {record["id"] for record in canon}
    for record in canon:
        if any(edge["target"] not in included_ids for edge in record["relationships"]):
            raise CanonError("consumer policy excludes a required projected relationship")
    included = []
    excluded = []
    for item in normalized_state["knowledge"]:
        permitted = any(consumer in VISIBILITY[label] for label in item["visibility"])
        if permitted:
            included.append({key: item[key] for key in ("id", "kind", "summary")})
        elif audit:
            excluded.append({"id": item["id"], "reason": "visibility policy"})
    fingerprint_input = {
        "consumer": consumer, "projection_sha256": projection["projection_sha256"],
        "state_sha256": state_hash, "policy_version": POLICY_VERSION, "as_of": effective_date,
        "canon_ids": [record["id"] for record in canon],
        "knowledge_ids": [item["id"] for item in included],
    }
    result = {"consumer": consumer, "canon": canon, "state": included,
              "withheld_count": len(normalized_state["knowledge"]) - len(included),
              "policy_version": POLICY_VERSION,
              "projection_sha256": projection["projection_sha256"],
              "state_sha256": state_hash,
              "context_fingerprint": hashlib.sha256(canonical_bytes(fingerprint_input)).hexdigest(),
              "as_of": effective_date}
    if audit:
        result["audit"] = {"included_canon_ids": [record["id"] for record in canon],
                           "excluded_canon": [{"id": record["id"], "reason": "consumer Canon policy"}
                                              for record in projection["records"] if record["id"] not in allowed_ids],
                           "included_state_ids": [item["id"] for item in included],
                           "excluded_state": excluded}
    return result


def run(argv=None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--consumer", required=True)
    parser.add_argument("--state-fixture", type=Path, required=True)
    parser.add_argument("--projection", type=Path, default=DEFAULT_PROJECTION)
    parser.add_argument("--expected-manifest-sha256")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--as-of")
    parser.add_argument("--audit", action="store_true", help="developer-only exclusion detail")
    args = parser.parse_args(argv)
    try:
        projection_path = args.projection if args.projection.is_absolute() else root / args.projection
        state_path = args.state_fixture if args.state_fixture.is_absolute() else root / args.state_fixture
        projection = json.loads(projection_path.read_text())
        state = json.loads(state_path.read_text())
        manifest_hash = args.expected_manifest_sha256 or hashlib.sha256((root / MANIFEST).read_bytes()).hexdigest()
        result = build_context(projection, state, args.consumer,
                               expected_manifest_sha256=manifest_hash,
                               as_of=args.as_of, audit=args.audit)
        if args.format == "json":
            sys.stdout.buffer.write(canonical_bytes(result))
        else:
            print(f"{result['consumer']}: {len(result['canon'])} Canon records, "
                  f"{len(result['state'])} knowledge items, {result['withheld_count']} withheld")
            for record in result["canon"]:
                print(f"Canon: {record['title']} — {record['summary']}")
            for item in result["state"]:
                print(f"State: {item['summary']}")
            print("Context fingerprint: " + result["context_fingerprint"])
            if args.audit:
                print("AUDIT (developer only): " + json.dumps(result["audit"], sort_keys=True))
        return 0
    except (CanonError, OSError, ValueError, KeyError, TypeError) as exc:
        print("ERROR: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(run())
