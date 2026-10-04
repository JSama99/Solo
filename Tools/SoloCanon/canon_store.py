"""Deterministic, offline SOLO Canon retrieval. No network or runtime game access."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
from pathlib import Path

from validate_canon import SCOPES, TYPES, STATUSES, LEVELS, validate_tree

TOOL_VERSION = "1.0"
ROOT = Path(__file__).resolve().parents[2]
# C0 seed was verified on this date; some build hosts report an earlier clock.
CANON_SNAPSHOT_FLOOR = "2026-10-03"
STOP_WORDS = {"a", "an", "and", "for", "implement", "implementation", "in", "integration", "of", "the", "to", "with"}
STATUS_ORDER = {name: i for i, name in enumerate(("canonical", "accepted", "implemented", "proposed", "experimental", "historical", "deprecated", "blocked"))}
PROFILES = {
    "codex": {"scopes": ("developer", "simulation_internal", "founder_known", "agent_known"), "types": ("system", "mechanic", "rule", "decision", "asset"), "depth": 1, "limit": 12},
    "visual": {"scopes": ("developer", "founder_known"), "types": ("asset", "character", "location", "rule", "decision"), "depth": 1, "limit": 12},
    "narrative": {"scopes": ("developer", "founder_known", "agent_known", "public", "media"), "types": ("character", "agent", "location", "rule", "decision", "system"), "depth": 1, "limit": 12},
    "chaos": {"scopes": ("developer", "simulation_internal"), "types": ("mechanic", "system", "rule", "experiment"), "depth": 1, "limit": 12},
    "runtime": {"scopes": ("runtime_safe",), "types": ("rule", "entity", "character", "location", "mechanic", "agent", "system"), "depth": 1, "limit": 12},
}


class CanonError(Exception):
    pass


def tokens(value: str) -> tuple[str, ...]:
    return tuple(part for part in re.findall(r"[a-z0-9]+", value.lower()) if part not in STOP_WORDS)


def canonical_bytes(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def parse_as_of(value: str | None, default: str) -> str:
    if value is None:
        return default
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise CanonError("as-of must be YYYY-MM-DD")
    try:
        dt.date.fromisoformat(value)
    except ValueError as exc:
        raise CanonError("as-of must be a real ISO date") from exc
    return value


def query_fingerprint(manifest_hash: str, mode: str, query: str, *, as_of: str,
                      scopes: tuple[str, ...], filters: dict, include_historical: bool,
                      related_depth: int = 0, limit: int | None = None, consumer: str | None = None) -> str:
    normalized = {"tool_version": TOOL_VERSION, "manifest_sha256": manifest_hash,
                  "mode": mode, "query_text": " ".join(query.lower().split()),
                  "query_terms": list(tokens(query)), "as_of": as_of,
                  "scopes": sorted(scopes), "filters": filters,
                  "include_historical": include_historical,
                  "related_depth": related_depth, "limit": limit, "consumer": consumer}
    return hashlib.sha256(canonical_bytes(normalized)).hexdigest()


class CanonStore:
    def __init__(self, root: Path = ROOT):
        self.root = Path(root)
        errors, _ = validate_tree(self.root)
        # Contradictory truth is a queryable conflict; every other validation error closes retrieval.
        fatal = [error for error in errors if "contradictory active P0/P1 truth_key:" not in error]
        if fatal:
            raise CanonError("Canon validation failed: " + "; ".join(fatal))
        manifest_path = self.root / "Canon/manifests/canon-manifest.json"
        manifest_bytes = manifest_path.read_bytes()
        self.manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
        self.manifest = json.loads(manifest_bytes)
        self.records = {}
        for entry in self.manifest["records"]:
            record = json.loads((self.root / entry["path"]).read_text(encoding="utf-8"))
            self.records[entry["id"]] = record
        self.ids = tuple(sorted(self.records))
        self.by_type = self._index("type")
        self.by_status = self._index("status")
        self.by_authority = self._index("authority", nested="level")
        self.by_visibility = self._multi_index("visibility")
        self.by_tag = self._multi_index("tags")
        self.edges = {identifier: tuple(sorted(
            ((relation["predicate"], relation["target"]) for relation in self.records[identifier]["relationships"]),
            key=lambda edge: (edge[0], edge[1]))) for identifier in self.ids}
        self.default_as_of = max(dt.date.today().isoformat(), CANON_SNAPSHOT_FLOOR)

    def _index(self, key: str, nested: str | None = None) -> dict[str, tuple[str, ...]]:
        values = {}
        for identifier in self.ids:
            value = self.records[identifier][key]
            if nested:
                value = value[nested]
            values.setdefault(value, []).append(identifier)
        return {key: tuple(value) for key, value in sorted(values.items())}

    def _multi_index(self, key: str) -> dict[str, tuple[str, ...]]:
        values = {}
        for identifier in self.ids:
            for value in self.records[identifier][key]:
                values.setdefault(value, []).append(identifier)
        return {key: tuple(value) for key, value in sorted(values.items())}

    def _eligible(self, record: dict, scopes: tuple[str, ...], as_of: str,
                  include_historical: bool, filters: dict) -> bool:
        if not set(record["visibility"]).intersection(scopes):
            return False
        validity = record["validity"]
        if validity["valid_from"] > as_of:
            return False
        if not include_historical and validity["valid_until"] is not None and validity["valid_until"] < as_of:
            return False
        if record["status"] == "blocked" and filters.get("status") != "blocked":
            return False
        if filters.get("type") and record["type"] != filters["type"]:
            return False
        if filters.get("status") and record["status"] != filters["status"]:
            return False
        if filters.get("authority") and record["authority"]["level"] != filters["authority"]:
            return False
        if filters.get("tag") and filters["tag"] not in record["tags"]:
            return False
        return True

    def eligible_ids(self, *, scopes: tuple[str, ...] = ("developer",), as_of: str | None = None,
                     include_historical: bool = False, filters: dict | None = None) -> tuple[str, ...]:
        as_of = parse_as_of(as_of, self.default_as_of)
        filters = filters or {}
        if not scopes or any(scope not in SCOPES for scope in scopes):
            raise CanonError("unknown or empty visibility scope")
        if filters.get("type") and filters["type"] not in TYPES:
            raise CanonError("unknown type filter")
        if filters.get("status") and filters["status"] not in STATUSES:
            raise CanonError("unknown status filter")
        if filters.get("authority") and filters["authority"] not in LEVELS:
            raise CanonError("unknown authority filter")
        return tuple(identifier for identifier in self.ids if self._eligible(self.records[identifier], scopes, as_of, include_historical, filters))

    def view(self, identifier: str, allowed: set[str]) -> dict:
        record = self.records[identifier]
        return {"id": identifier, "type": record["type"], "title": record["title"],
                "summary": record["summary"], "status": record["status"],
                "authority": record["authority"], "visibility": sorted(record["visibility"]),
                "validity": record["validity"], "facts": record["facts"],
                "constraints": record["constraints"], "tags": sorted(record["tags"]),
                "sources": record["sources"],
                "external_evidence": record.get("external_evidence", []),
                "relationships": [dict(predicate=p, target=t) for p, t in self.edges[identifier] if t in allowed],
                "evidence": sorted(e for e in record["evidence"] if e in allowed),
                "supersedes": sorted(e for e in record["supersedes"] if e in allowed),
                "superseded_by": sorted(e for e in record["superseded_by"] if e in allowed)}

    @staticmethod
    def _text_score(record: dict, query: str, allowed: set[str]) -> tuple[int, list[str]]:
        terms = tokens(query)
        if not terms:
            return 0, []
        sources = " ".join(source.get("path", source.get("sha", "")) for source in record["sources"])
        sources += " " + " ".join(reference["path"] for reference in record.get("external_evidence", []))
        relation_text = " ".join(f"{r['predicate']} {r['target']}" for r in record["relationships"] if r["target"] in allowed)
        fields = (("id token", record["id"], 70), ("title token", record["title"], 35),
                  ("tag token", " ".join(record["tags"]), 25), ("summary token", record["summary"], 12),
                  ("fact token", json.dumps(record["facts"], sort_keys=True), 8),
                  ("constraint token", " ".join(record["constraints"]), 8),
                  ("source path token", sources, 3), ("relationship token", relation_text, 2))
        score = 0
        reasons = []
        if query.lower().strip() == record["id"]:
            score += 1000
            reasons.append("exact ID match")
        if query.lower().strip() == record["title"].lower():
            score += 90
            reasons.append("exact title match")
        for label, value, weight in fields:
            matches = set(terms).intersection(tokens(value))
            if matches:
                score += weight * len(matches)
                reasons.append(f"{label}: {', '.join(sorted(matches))}")
        return score, reasons

    def _rank(self, identifier: str, score: int) -> tuple:
        record = self.records[identifier]
        return (int(record["authority"]["level"][1:]), STATUS_ORDER[record["status"]], -score, identifier)

    def _expand(self, seeds: dict[str, tuple[int, list[str]]], allowed: set[str], depth: int) -> dict[str, tuple[int, list[str]]]:
        if depth not in (0, 1, 2):
            raise CanonError("related depth must be 0, 1, or 2")
        results = {identifier: (score, list(reasons)) for identifier, (score, reasons) in seeds.items()}
        frontier = tuple(sorted(seeds))
        for _ in range(depth):
            next_frontier = set()
            for identifier in frontier:
                for predicate, target in self.edges[identifier]:
                    if target not in allowed:
                        continue
                    reason = f"related from {identifier} via {predicate}"
                    if target not in results:
                        results[target] = (0, [reason])
                        next_frontier.add(target)
                    elif reason not in results[target][1]:
                        results[target][1].append(reason)
            frontier = tuple(sorted(next_frontier))
        return results

    def search(self, query: str, *, scopes: tuple[str, ...] = ("developer",), as_of: str | None = None,
               include_historical: bool = False, filters: dict | None = None,
               related_depth: int = 0, limit: int | None = None) -> list[dict]:
        allowed = set(self.eligible_ids(scopes=scopes, as_of=as_of, include_historical=include_historical, filters=filters))
        scored = {}
        for identifier in sorted(allowed):
            score, reasons = self._text_score(self.records[identifier], query, allowed)
            if score:
                scored[identifier] = (score, reasons)
        results = self._expand(scored, allowed, related_depth)
        ordered = sorted(results, key=lambda identifier: self._rank(identifier, results[identifier][0]))
        if limit is not None:
            if limit < 1:
                raise CanonError("limit must be positive")
            ordered = ordered[:limit]
        return [{"record": self.view(identifier, allowed), "score": results[identifier][0],
                 "reasons": sorted(results[identifier][1])} for identifier in ordered]

    def get_id(self, identifier: str, *, scopes: tuple[str, ...] = ("developer",), as_of: str | None = None,
               include_historical: bool = False, filters: dict | None = None,
               related_depth: int = 0) -> list[dict]:
        allowed = set(self.eligible_ids(scopes=scopes, as_of=as_of, include_historical=include_historical, filters=filters))
        if identifier not in allowed:
            return []
        results = self._expand({identifier: (1000, ["exact ID match"])}, allowed, related_depth)
        ordered = [identifier] + sorted((item for item in results if item != identifier), key=lambda item: self._rank(item, results[item][0]))
        return [{"record": self.view(item, allowed), "score": results[item][0],
                 "reasons": sorted(results[item][1])} for item in ordered]

    def resolve(self, query: str, *, scopes: tuple[str, ...] = ("developer",), as_of: str | None = None,
                include_historical: bool = False, filters: dict | None = None) -> dict:
        allowed = set(self.eligible_ids(scopes=scopes, as_of=as_of, include_historical=include_historical, filters=filters))
        terms = set(tokens(query))
        groups = {}
        for identifier in sorted(allowed):
            record = self.records[identifier]
            key = record["facts"].get("truth_key")
            if (record["authority"]["level"] in {"P0", "P1"} and key and terms.intersection(tokens(key))):
                groups.setdefault(key, []).append(identifier)
        for key in sorted(groups):
            applicable = [identifier for identifier in groups[key] if not any(
                successor in allowed for successor in self.records[identifier]["superseded_by"])]
            values = {json.dumps(self.records[identifier]["facts"].get("truth_value"), sort_keys=True) for identifier in applicable}
            if len(values) > 1:
                return {"result": "conflict", "truth_key": key,
                        "records": [self.view(identifier, allowed) for identifier in applicable],
                        "reason": "incompatible active P0/P1 truth without applicable supersession"}
        matches = self.search(query, scopes=scopes, as_of=as_of, include_historical=include_historical, filters=filters)
        matches = [item for item in matches if not any(successor in allowed for successor in self.records[item["record"]["id"]]["superseded_by"])]
        if not matches:
            return {"result": "not_found", "records": []}
        top = matches[0]
        ambiguity = top["record"]["facts"].get("ambiguity")
        if isinstance(ambiguity, dict) and all(key in ambiguity for key in ("key", "description", "sources")):
            return {"result": "ambiguity", "truth_key": ambiguity["key"],
                    "description": ambiguity["description"], "sources": ambiguity["sources"],
                    "records": [top["record"]]}
        return {"result": "resolved", "records": [top["record"]], "reasons": top["reasons"]}
