#!/usr/bin/env python3
"""Exact lookup, lexical search, and authority-aware resolution for SOLO Canon."""

import argparse
import sys

from canon_store import CanonError, CanonStore, canonical_bytes, parse_as_of, query_fingerprint
from hybrid_retrieval import DEFAULT_SEMANTIC_LIMIT, DEFAULT_THRESHOLD, hybrid_search


def parser():
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    for name in ("id", "search", "resolve"):
        command = commands.add_parser(name)
        command.add_argument("query", help="exact ID or lexical concept")
        command.add_argument("--format", choices=("text", "json"), default="text")
        command.add_argument("--visibility", default="developer")
        command.add_argument("--as-of")
        command.add_argument("--include-historical", action="store_true")
        command.add_argument("--type")
        command.add_argument("--status")
        command.add_argument("--authority")
        command.add_argument("--tag")
        command.add_argument("--related-depth", type=int, choices=(0, 1, 2), default=0)
        command.add_argument("--limit", type=int, default=20)
        if name == "search":
            command.add_argument("--semantic", action="store_true", help="opt in to offline hybrid candidates")
            command.add_argument("--semantic-limit", type=int, default=DEFAULT_SEMANTIC_LIMIT)
            command.add_argument("--semantic-threshold", type=float, default=DEFAULT_THRESHOLD)
            command.add_argument("--semantic-required", action="store_true", help="block if the cached semantic index is unavailable")
    return root


def human_record(item):
    record = item["record"]
    lines = [record["id"], f"Type: {record['type']}", f"Status: {record['status']}",
             f"Authority: {record['authority']['level']} {record['authority']['kind']}",
             "Visibility: " + ", ".join(record["visibility"]), "", "Summary:", record["summary"]]
    if record["sources"]:
        lines.extend(("", "Sources:"))
        lines.extend("- " + source.get("path", source.get("sha", "")) for source in record["sources"])
    if item.get("reasons"):
        lines.extend(("", "Reasons:"))
        lines.extend("- " + reason for reason in item["reasons"])
    return "\n".join(lines)


def run(argv=None):
    args = parser().parse_args(argv)
    try:
        store = CanonStore()
        as_of = parse_as_of(args.as_of, store.default_as_of)
        scopes = (args.visibility,)
        filters = {name: getattr(args, name) for name in ("type", "status", "authority", "tag") if getattr(args, name)}
        if args.limit < 1:
            raise CanonError("limit must be positive")
        if args.command == "resolve" and args.related_depth:
            raise CanonError("related-depth applies to id and search, not resolve")
        options = dict(scopes=scopes, as_of=as_of, include_historical=args.include_historical, filters=filters)
        if args.command == "id":
            records = store.get_id(args.query, related_depth=args.related_depth, **options)
            result = "found" if records else "not_found"
            payload = {"result": result, "records": records[:args.limit]}
        elif args.command == "search" and args.semantic:
            hybrid = hybrid_search(store, args.query, scopes=scopes, as_of=as_of,
                                   include_historical=args.include_historical, filters=filters,
                                   related_depth=args.related_depth, limit=args.limit,
                                   semantic_limit=args.semantic_limit,
                                   threshold=args.semantic_threshold,
                                   require_semantic=args.semantic_required)
            records = hybrid["records"]
            payload = {"result": "found" if records else "not_found", "records": records,
                       "retrieval_mode": "hybrid", "semantic_status": hybrid["semantic_status"],
                       "semantic_warning": hybrid["semantic_warning"],
                       "semantic_provider": hybrid["semantic_provider"],
                       "semantic_model": hybrid["semantic_provider"]["model_id"],
                       "semantic_index_manifest": hybrid["semantic_index_manifest"],
                       "semantic_index_sha256": hybrid["semantic_index_sha256"],
                       "semantic_candidates": hybrid["semantic_candidates"],
                       "semantic_threshold": args.semantic_threshold,
                       "conflicts": hybrid["conflicts"]}
        elif args.command == "search":
            records = store.search(args.query, related_depth=args.related_depth, limit=args.limit, **options)
            payload = {"result": "found" if records else "not_found", "records": records}
        else:
            payload = store.resolve(args.query, **options)
        fingerprint = hybrid["query_fingerprint"] if args.command == "search" and args.semantic else query_fingerprint(store.manifest_sha256, args.command, args.query,
                                        as_of=as_of, scopes=scopes, filters=filters,
                                        include_historical=args.include_historical,
                                        related_depth=args.related_depth, limit=args.limit)
        output = {"canon_version": "0.1", "manifest_sha256": store.manifest_sha256,
                  "query_fingerprint": fingerprint, "query": args.query, "as_of": as_of,
                  "visibility": args.visibility, "filters": filters, **payload}
        if args.format == "json":
            sys.stdout.buffer.write(canonical_bytes(output))
        elif payload["result"] in {"conflict", "ambiguity"}:
            print(payload["result"].upper())
            print("Truth key: " + payload["truth_key"])
            print(payload.get("description", payload.get("reason", "No authoritative resolution exists.")))
            for record in payload["records"]:
                print("- " + record["id"])
            for source in payload.get("sources", []):
                print("Source: " + source)
            print("Manifest: " + store.manifest_sha256)
            print("Query fingerprint: " + fingerprint)
        elif payload["result"] == "not_found":
            print("No applicable Canon record found.")
        else:
            items = payload["records"]
            if args.command == "resolve":
                items = [{"record": payload["records"][0], "reasons": payload.get("reasons", [])}]
            print("\n\n".join(human_record(item) for item in items))
            print("\nManifest: " + store.manifest_sha256)
            print("Query fingerprint: " + fingerprint)
        return 3 if payload["result"] in {"conflict", "ambiguity"} else 1 if payload["result"] == "not_found" else 0
    except CanonError as exc:
        print("ERROR: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(run())
