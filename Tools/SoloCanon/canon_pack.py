#!/usr/bin/env python3
"""Build a bounded deterministic SOLO Canon context pack for one consumer and task."""

import argparse
import sys

from canon_store import CanonError, CanonStore, PROFILES, canonical_bytes, parse_as_of, query_fingerprint, tokens


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--consumer", required=True, choices=tuple(PROFILES))
    result.add_argument("--task", required=True)
    result.add_argument("--format", choices=("markdown", "json"), default="markdown")
    result.add_argument("--as-of")
    result.add_argument("--include-historical", action="store_true")
    result.add_argument("--visibility", help="narrow to one scope already allowed by the consumer profile")
    result.add_argument("--max-records", type=int)
    result.add_argument("--related-depth", type=int, choices=(0, 1, 2))
    return result


def build_pack(store: CanonStore, *, consumer: str, task: str, as_of: str | None = None,
               include_historical: bool = False, visibility: str | None = None,
               max_records: int | None = None, related_depth: int | None = None) -> dict:
    if consumer not in PROFILES:
        raise CanonError("unknown consumer profile")
    if not task.strip() or not tokens(task):
        raise CanonError("task needs at least one searchable term")
    profile = PROFILES[consumer]
    if visibility is not None and visibility not in profile["scopes"]:
        raise CanonError("visibility scope is not allowed by consumer profile")
    scopes = (visibility,) if visibility else profile["scopes"]
    limit = max_records if max_records is not None else profile["limit"]
    if not 1 <= limit <= 50:
        raise CanonError("max-records must be 1 through 50")
    depth = related_depth if related_depth is not None else profile["depth"]
    if depth not in (0, 1, 2):
        raise CanonError("related-depth must be 0, 1, or 2")
    as_of = parse_as_of(as_of, store.default_as_of)
    if consumer == "runtime":
        if include_historical:
            raise CanonError("runtime Pack cannot include historical Canon")
        from runtime_projection import build_projection
        projection = build_projection(store, as_of=as_of)
        query_terms = set(tokens(task))
        scored = []
        for record in projection["records"]:
            searchable = " ".join((record["id"], record["title"], record["summary"],
                                   " ".join(record["tags"]),
                                   " ".join(str(value) for value in record["facts"].values())))
            overlap = sorted(query_terms.intersection(tokens(searchable)))
            if overlap:
                scored.append((len(overlap), record, overlap))
        scored.sort(key=lambda item: (-item[0], item[1]["id"]))
        entries = [{"id": record["id"], "type": record["type"], "title": record["title"],
                    "authority": "runtime_safe", "status": "current", "summary": record["summary"],
                    "facts": record["facts"], "constraints": [], "sources": [],
                    "external_evidence": [], "relationships": record["relationships"],
                    "reasons": ["runtime projection match: " + ", ".join(overlap)]}
                   for _, record, overlap in scored[:limit]]
        fingerprint = query_fingerprint(store.manifest_sha256, "runtime_projection_pack", task,
                                        as_of=as_of, scopes=("runtime_safe",),
                                        filters={"projection_sha256": projection["projection_sha256"]},
                                        include_historical=False, related_depth=0,
                                        limit=limit, consumer="runtime")
        return {"canon_version": "0.1", "consumer": "runtime", "task": task,
                "as_of": as_of, "manifest_sha256": store.manifest_sha256,
                "runtime_projection_sha256": projection["projection_sha256"],
                "query_fingerprint": fingerprint,
                "query": {"terms": list(tokens(task)), "related_depth": 0, "max_records": limit},
                "records": entries, "conflicts": []}
    # Retrieve before bounding so profile preferences can break close lexical ties.
    results = store.search(task, scopes=scopes, as_of=as_of,
                           include_historical=include_historical, related_depth=depth)
    preferred = set(profile["types"])
    results.sort(key=lambda item: (
        int(item["record"]["authority"]["level"][1:]),
        -item["score"] - (1 if item["record"]["type"] in preferred else 0),
        item["record"]["id"]))
    results = results[:limit]
    entries = []
    conflicts = []
    for item in results:
        record = item["record"]
        entries.append({"id": record["id"], "type": record["type"], "title": record["title"],
                        "authority": record["authority"]["level"], "status": record["status"],
                        "summary": record["summary"], "facts": record["facts"],
                        "constraints": record["constraints"], "sources": record["sources"],
                        "external_evidence": record["external_evidence"],
                        "relationships": record["relationships"], "reasons": item["reasons"]})
        ambiguity = record["facts"].get("ambiguity")
        if isinstance(ambiguity, dict):
            conflicts.append({"result": "ambiguity", "truth_key": ambiguity["key"],
                              "description": ambiguity["description"], "sources": ambiguity["sources"],
                              "records": [record["id"]]})
    resolved = store.resolve(task, scopes=scopes, as_of=as_of, include_historical=include_historical)
    if resolved["result"] == "conflict":
        conflicts.append({"result": "conflict", "truth_key": resolved["truth_key"],
                          "description": resolved["reason"],
                          "records": [record["id"] for record in resolved["records"]]})
    conflicts.sort(key=lambda item: (item["truth_key"], item["result"]))
    fingerprint = query_fingerprint(store.manifest_sha256, "pack", task, as_of=as_of,
                                    scopes=scopes, filters={}, include_historical=include_historical,
                                    related_depth=depth, limit=limit, consumer=consumer)
    return {"canon_version": "0.1", "consumer": consumer, "task": task,
            "as_of": as_of, "manifest_sha256": store.manifest_sha256,
            "query_fingerprint": fingerprint,
            "query": {"terms": list(tokens(task)), "related_depth": depth, "max_records": limit},
            "records": entries, "conflicts": conflicts}


def markdown(pack: dict) -> bytes:
    lines = ["# SOLO Canon Pack", "", f"Consumer: {pack['consumer']}",
             f"Task: {pack['task']}", f"As of: {pack['as_of']}",
             f"Manifest SHA-256: {pack['manifest_sha256']}",
             f"Query fingerprint: {pack['query_fingerprint']}", ""]
    if not pack["records"]:
        lines.extend(("No applicable records.", ""))
    for record in pack["records"]:
        lines.extend((f"## {record['id']} — {record['title']}", "",
                      f"{record['authority']} · {record['status']} · {record['type']}", "",
                      record["summary"], ""))
        if record["facts"]:
            lines.append("Facts:")
            for key in sorted(record["facts"]):
                value = record["facts"][key]
                if isinstance(value, (dict, list)):
                    import json
                    value = json.dumps(value, sort_keys=True, ensure_ascii=False)
                lines.append(f"- {key}: {value}")
            lines.append("")
        if record["sources"]:
            lines.append("Sources:")
            lines.extend("- " + source.get("path", source.get("sha", "")) for source in record["sources"])
            lines.append("")
        if record["external_evidence"]:
            lines.append("External evidence:")
            lines.extend(f"- {reference['path']} (SHA-256 {reference['sha256']})" for reference in record["external_evidence"])
            lines.append("")
        lines.append("Reasons:")
        lines.extend("- " + reason for reason in record["reasons"])
        lines.append("")
    if pack["conflicts"]:
        lines.extend(("## Ambiguities and conflicts", ""))
        for conflict in pack["conflicts"]:
            lines.append(f"- {conflict['result'].upper()} {conflict['truth_key']}: {conflict['description']}")
        lines.append("")
    return ("\n".join(lines).rstrip() + "\n").encode("utf-8")


def run(argv=None):
    args = parser().parse_args(argv)
    try:
        pack = build_pack(CanonStore(), consumer=args.consumer, task=args.task,
                          as_of=args.as_of, include_historical=args.include_historical,
                          visibility=args.visibility, max_records=args.max_records,
                          related_depth=args.related_depth)
        sys.stdout.buffer.write(canonical_bytes(pack) if args.format == "json" else markdown(pack))
        return 0 if pack["records"] else 1
    except CanonError as exc:
        print("ERROR: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(run())
