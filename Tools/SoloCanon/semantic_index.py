#!/usr/bin/env python3
"""Build or inspect the disposable offline SOLO Canon semantic candidate index."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Protocol

sys.dont_write_bytecode = True

from canon_store import CanonError, CanonStore, ROOT, canonical_bytes

INDEX_VERSION = "0.1"
DEFAULT_INDEX = Path(".solo-loop/cache/canon-semantic/index.json")

# Small, inspectable synonym families. This is a deterministic semantic
# approximation, not a learned embedding model or an authority source.
CONCEPTS = {
    "media": ("news", "television", "tv", "broadcast", "press", "headline", "media", "coverage", "reputation", "signal"),
    "privacy": ("hidden", "private", "secret", "unrevealed", "undisclosed", "concealed"),
    "knowledge": ("know", "knows", "knowledge", "aware", "truth", "facts", "fact", "reveal", "disclose"),
    "characters": ("character", "characters", "agent", "agents", "dialogue", "writer"),
    "production": ("production", "ship", "shipped", "actual", "real", "canonical", "accepted"),
    "model": ("model", "asset", "figure", "mesh", "character"),
    "experiment": ("test", "testing", "stress", "simulate", "simulation", "experiment", "chaos", "thousands"),
    "exploit": ("broken", "strategy", "strategies", "exploit", "loophole", "degenerate", "balance"),
    "narrative": ("narrative", "story", "writer", "copy", "dialogue", "director"),
    "decision": ("decide", "decision", "choose", "intent", "authority", "promote", "promotion", "canon"),
    "garage": ("garage", "workshop", "workspace", "founder", "desk"),
    "momentum": ("momentum", "growth", "velocity", "traction"),
}
CONCEPT_MAP = {term: concept for concept, terms in CONCEPTS.items() for term in terms}
STOP = {"a", "an", "and", "are", "be", "becomes", "can", "company", "companies", "do", "does", "for", "from",
        "in", "is", "it", "let", "of", "on", "our", "should", "the", "their", "to", "we", "what", "with", "you"}


class SemanticProvider(Protocol):
    provider_id: str
    provider_version: str
    model_id: str

    def embed(self, text: str) -> dict[str, int]: ...


class LocalConceptProvider:
    provider_id = "solo-local-concepts"
    provider_version = "1.0"
    model_id = "solo-concepts-v1"

    def embed(self, text: str) -> dict[str, int]:
        vector: dict[str, int] = {}
        for token in re.findall(r"[a-z0-9]+", text.lower()):
            if token in STOP:
                continue
            # A concept feature can bridge different words; the literal feature
            # preserves precise terms that should remain distinguishable.
            vector["word:" + token] = vector.get("word:" + token, 0) + 1
            concept = CONCEPT_MAP.get(token)
            if concept:
                vector["concept:" + concept] = vector.get("concept:" + concept, 0) + 2
        return dict(sorted(vector.items()))


def record_text(record: dict) -> str:
    return " ".join((record["id"], record["title"], record["summary"],
                     " ".join(record["tags"]),
                     json.dumps(record["facts"], sort_keys=True, ensure_ascii=False),
                     " ".join(record["constraints"]),
                     " ".join(relation["predicate"] for relation in record["relationships"])))


def provider_identity(provider: SemanticProvider) -> dict:
    return {"id": provider.provider_id, "version": provider.provider_version, "model_id": provider.model_id}


def build_index(store: CanonStore, provider: SemanticProvider) -> dict:
    records = []
    for identifier in store.ids:
        record = store.records[identifier]
        records.append({"id": identifier,
                        "content_sha256": hashlib.sha256(canonical_bytes(record)).hexdigest(),
                        "embedding": provider.embed(record_text(record))})
    return {"schema_version": INDEX_VERSION, "canon_manifest_sha256": store.manifest_sha256,
            "provider": provider_identity(provider), "records": records}


def validate_index(index: dict, store: CanonStore, provider: SemanticProvider) -> None:
    if not isinstance(index, dict) or set(index) != {"schema_version", "canon_manifest_sha256", "provider", "records"}:
        raise CanonError("malformed semantic index")
    if index["schema_version"] != INDEX_VERSION or index["provider"] != provider_identity(provider):
        raise CanonError("semantic index provider or format mismatch")
    if index["canon_manifest_sha256"] != store.manifest_sha256:
        raise CanonError("stale semantic index: Canon manifest mismatch")
    records = index["records"]
    if not isinstance(records, list) or [item.get("id") for item in records if isinstance(item, dict)] != list(store.ids) or len(records) != len(store.ids):
        raise CanonError("semantic index record IDs do not match Canon")
    for item in records:
        record = store.records[item["id"]]
        if set(item) != {"id", "content_sha256", "embedding"} or item["content_sha256"] != hashlib.sha256(canonical_bytes(record)).hexdigest():
            raise CanonError("semantic index record content mismatch")
        vector = item["embedding"]
        if not isinstance(vector, dict) or any(not isinstance(key, str) or not key or type(value) is not int or value <= 0
                                               for key, value in vector.items()):
            raise CanonError("malformed semantic index embedding")


def load_index(path: Path, store: CanonStore, provider: SemanticProvider) -> tuple[dict, str]:
    try:
        data = path.read_bytes()
        index = json.loads(data)
    except (OSError, ValueError) as exc:
        raise CanonError("semantic index unavailable or malformed: " + str(exc)) from exc
    validate_index(index, store, provider)
    return index, hashlib.sha256(canonical_bytes(index)).hexdigest()


def index_path(root: Path = ROOT) -> Path:
    return root / DEFAULT_INDEX


def run(argv=None, *, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "check"))
    args = parser.parse_args(argv)
    try:
        store = CanonStore(root)
        provider = LocalConceptProvider()
        path = index_path(root)
        if args.command == "build":
            index = build_index(store, provider)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(canonical_bytes(index))
        index, fingerprint = load_index(path, store, provider)
        print(json.dumps({"status": "ready", "path": str(path), "record_count": len(index["records"]),
                          "canon_manifest_sha256": store.manifest_sha256, "index_sha256": fingerprint,
                          "provider": provider_identity(provider)}, sort_keys=True))
        return 0
    except CanonError as exc:
        print("ERROR: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(run())
