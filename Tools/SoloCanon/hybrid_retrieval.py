"""Policy-filtered, offline semantic candidates beside C1 structured retrieval."""

from __future__ import annotations

import math
from pathlib import Path

from canon_store import CanonError, CanonStore, parse_as_of, query_fingerprint, tokens
from semantic_index import (LocalConceptProvider, SemanticProvider, index_path, load_index,
                            provider_identity)

DEFAULT_THRESHOLD = 0.18
DEFAULT_SEMANTIC_LIMIT = 8


def similarity(left: dict[str, int], right: dict[str, int]) -> float:
    numerator = sum(value * right.get(key, 0) for key, value in left.items())
    if not numerator:
        return 0.0
    denominator = math.sqrt(sum(value * value for value in left.values())) * math.sqrt(sum(value * value for value in right.values()))
    return round(numerator / denominator, 6) if denominator else 0.0


def hybrid_search(store: CanonStore, query: str, *, scopes: tuple[str, ...] = ("developer",),
                  as_of: str | None = None, include_historical: bool = False,
                  filters: dict | None = None, related_depth: int = 0, limit: int = 20,
                  semantic_limit: int = DEFAULT_SEMANTIC_LIMIT,
                  threshold: float = DEFAULT_THRESHOLD, provider: SemanticProvider | None = None,
                  path: Path | None = None, require_semantic: bool = False,
                  consumer: str | None = None,
                  fingerprint_context: dict | None = None) -> dict:
    if not query.strip() or not 1 <= limit <= 50 or not 1 <= semantic_limit <= 50 or not 0 <= threshold <= 1:
        raise CanonError("invalid hybrid query, limit, or semantic threshold")
    provider = provider or LocalConceptProvider()
    path = path or index_path(store.root)
    filters = filters or {}
    as_of = parse_as_of(as_of, store.default_as_of)
    # C1 owns visibility, date and metadata policy. Filter before similarity so
    # even candidate IDs and scores cannot disclose hidden records.
    allowed = set(store.eligible_ids(scopes=scopes, as_of=as_of,
                                     include_historical=include_historical, filters=filters))
    allowed = {identifier for identifier in allowed if not any(
        successor in allowed for successor in store.records[identifier]["superseded_by"])}
    structured = store.search(query, scopes=scopes, as_of=as_of,
                              include_historical=include_historical, filters=filters,
                              related_depth=related_depth)
    structured = [item for item in structured if item["record"]["id"] in allowed]
    structured_ids = [item["record"]["id"] for item in structured]
    status = "ready"
    warning = None
    index_sha = None
    candidates = []
    try:
        index, index_sha = load_index(path, store, provider)
    except CanonError as exc:
        if require_semantic:
            raise
        status = "unavailable"
        warning = str(exc)
    else:
        query_vector = provider.embed(query)
        for item in index["records"]:
            identifier = item["id"]
            if identifier not in allowed:
                continue
            score = similarity(query_vector, item["embedding"])
            if score >= threshold and score > 0:
                candidates.append({"id": identifier, "similarity": score})
        candidates.sort(key=lambda item: (int(store.records[item["id"]]["authority"]["level"][1:]),
                                          -item["similarity"], item["id"]))
        candidates = candidates[:semantic_limit]
    semantic_scores = {item["id"]: item["similarity"] for item in candidates}
    entries = {}
    for item in structured:
        identifier = item["record"]["id"]
        graph_reasons = [reason for reason in item["reasons"] if reason.startswith("related from ")]
        entries[identifier] = {"record": item["record"], "score": item["score"],
                               "lexical_score": item["score"], "graph_relations": graph_reasons,
                               "semantic_similarity": semantic_scores.get(identifier),
                               "semantic_candidate": identifier in semantic_scores,
                               "reasons": list(item["reasons"])}
    for candidate in candidates:
        identifier = candidate["id"]
        reason = "semantic candidate: similarity %.6f (candidate only)" % candidate["similarity"]
        if identifier in entries:
            entries[identifier]["reasons"] = sorted(set(entries[identifier]["reasons"] + [reason]))
        else:
            entries[identifier] = {"record": store.view(identifier, allowed), "score": 0,
                                   "lexical_score": 0, "graph_relations": [],
                                   "semantic_similarity": candidate["similarity"],
                                   "semantic_candidate": True, "reasons": [reason]}
    def rank(item: dict) -> tuple:
        record = item["record"]
        semantic = item["semantic_similarity"] or 0
        relevance_band = (0 if item["lexical_score"] >= 70 else
                          1 if semantic >= 0.5 else
                          2 if item["lexical_score"] > 0 else 3)
        return (int(record["authority"]["level"][1:]),
                0 if record["status"] == "canonical" else 1,
                0 if "exact ID match" in item["reasons"] else 1,
                relevance_band, -item["lexical_score"], -len(item["graph_relations"]),
                -semantic, record["id"])
    ranked = sorted(entries.values(), key=rank)[:limit]
    ambiguities = []
    for item in ranked:
        ambiguity = item["record"]["facts"].get("ambiguity")
        if isinstance(ambiguity, dict):
            ambiguities.append({"result": "ambiguity", "truth_key": ambiguity["key"],
                                "description": ambiguity["description"],
                                "records": [item["record"]["id"]]})
    resolved = store.resolve(query, scopes=scopes, as_of=as_of,
                             include_historical=include_historical, filters=filters)
    if resolved["result"] == "conflict":
        ambiguities.append({"result": "conflict", "truth_key": resolved["truth_key"],
                            "description": resolved["reason"],
                            "records": [item["id"] for item in resolved["records"]]})
    fingerprint = query_fingerprint(store.manifest_sha256, "hybrid", query, as_of=as_of,
                                    scopes=scopes,
                                    filters={**filters, "provider": provider_identity(provider),
                                             "semantic_threshold": threshold,
                                             "semantic_limit": semantic_limit,
                                             "semantic_index_sha256": index_sha,
                                             "semantic_status": status,
                                             "context": fingerprint_context or {}},
                                    include_historical=include_historical,
                                    related_depth=related_depth, limit=limit, consumer=consumer)
    return {"retrieval_mode": "hybrid", "semantic_status": status,
            "semantic_warning": warning, "semantic_provider": provider_identity(provider),
            "semantic_index_manifest": store.manifest_sha256 if index_sha else None,
            "semantic_index_sha256": index_sha,
            "semantic_threshold": threshold, "semantic_candidates": candidates,
            "structured_record_ids": structured_ids,
            "records": ranked, "conflicts": sorted(ambiguities, key=lambda item: (item["truth_key"], item["result"])),
            "query_fingerprint": fingerprint}


def hybrid_pack(store: CanonStore, *, consumer: str, task: str, max_records: int | None = None,
                related_depth: int | None = None, provider: SemanticProvider | None = None,
                path: Path | None = None, threshold: float = DEFAULT_THRESHOLD,
                semantic_limit: int = DEFAULT_SEMANTIC_LIMIT,
                require_semantic: bool = False) -> dict:
    from canon_store import PROFILES
    if consumer not in PROFILES:
        raise CanonError("unknown consumer profile")
    profile = PROFILES[consumer]
    limit = max_records if max_records is not None else profile["limit"]
    depth = related_depth if related_depth is not None else profile["depth"]
    result = hybrid_search(store, task, scopes=profile["scopes"], as_of=store.default_as_of,
                           related_depth=depth, limit=limit, semantic_limit=semantic_limit,
                           threshold=threshold, provider=provider, path=path,
                           require_semantic=require_semantic, consumer=consumer)
    # Keep C1's compact record projection, with explicit separate dimensions.
    entries = []
    for item in result["records"]:
        record = item["record"]
        entries.append({"id": record["id"], "type": record["type"], "title": record["title"],
                        "authority": record["authority"]["level"], "status": record["status"],
                        "summary": record["summary"], "facts": record["facts"],
                        "constraints": record["constraints"], "sources": record["sources"],
                        "external_evidence": record["external_evidence"],
                        "relationships": record["relationships"], "reasons": item["reasons"],
                        "lexical_score": item["lexical_score"],
                        "graph_relations": item["graph_relations"],
                        "semantic_similarity": item["semantic_similarity"]})
    return {"canon_version": "0.1", "consumer": consumer, "task": task,
            "as_of": store.default_as_of, "manifest_sha256": store.manifest_sha256,
            "query_fingerprint": result["query_fingerprint"],
            "query": {"terms": list(tokens(task)), "related_depth": depth, "max_records": limit},
            "records": entries, "conflicts": result["conflicts"],
            "retrieval_mode": "hybrid", "semantic_status": result["semantic_status"],
            "semantic_warning": result["semantic_warning"],
            "semantic_provider": result["semantic_provider"],
            "semantic_model": result["semantic_provider"]["model_id"],
            "semantic_index_manifest": result["semantic_index_manifest"],
            "semantic_index_sha256": result["semantic_index_sha256"],
            "semantic_candidates": result["semantic_candidates"],
            "semantic_threshold": threshold}
