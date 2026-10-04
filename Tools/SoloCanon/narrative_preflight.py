#!/usr/bin/env python3
"""Offline Narrative Director Canon preflight; never generates or publishes copy."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from canon_store import CanonError, CanonStore, ROOT, canonical_bytes, query_fingerprint
from codex_preflight import git_state
from hybrid_retrieval import DEFAULT_THRESHOLD, hybrid_search

ADAPTER = "solo-canon-narrative-preflight"
VERSION = "0.1"
DIRECTOR_SCOPES = ("developer", "simulation_internal", "founder_known", "agent_known", "public", "media", "rival")
CHANNEL_SCOPES = {
    "director_internal": DIRECTOR_SCOPES,
    "founder": ("founder_known", "public"),
    "signal_tv": ("public", "media"),
    "tech_com": ("public", "media"),
    "venture": ("founder_known", "public"),
    "rival": ("rival", "public"),
    "agent_dialogue": ("agent_known", "public"),
}
CATEGORY_TERMS = {
    "media_story": ("signal tv", "tech com", "media", "story", "headline", "broadcast"),
    "rival_story": ("rival", "competitor"),
    "agent_dialogue": ("dialogue", "discuss", "brio", "stacks", "aurora"),
    "founder_feedback": ("founder", "review", "feedback"),
    "continuity": ("continuity", "history", "hindsight", "precedent"),
    "reveal": ("reveal", "disclose", "hidden", "latent", "defect", "drift", "overclaim", "verification"),
    "event_summary": ("event", "launch", "failure", "failed", "outcome"),
    "narrative_arc": ("arc", "pacing", "chapter"),
}
SENSITIVE_TERMS = {"hidden", "latent", "defect", "drift", "overclaim", "verification", "quality", "weakness", "unrevealed"}
DISCLOSURE_VERBS = r"(?:reveal|expose|disclose|publish|report|mock|discuss|explain|tell)"
SENSITIVE_NOUNS = r"(?:hidden|latent|defect|drift|overclaim|weakness|quality|verification)"


def task_words(task: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", task.lower()))


def categories(task: str) -> list[str]:
    normalized = " " + " ".join(re.findall(r"[a-z0-9]+", task.lower())) + " "
    return [name for name, terms in CATEGORY_TERMS.items()
            if any(" " + term.replace("_", " ") + " " in normalized for term in terms)]


def requested_fact_classes(task: str) -> list[str]:
    words = task_words(task)
    found = []
    if "launch" in words and ("failed" in words or "failure" in words):
        found.append("public_launch_outcome")
    if "defect" in words or "latent" in words:
        found.append("latent_agent_defect")
    if "drift" in words:
        found.append("agent_drift")
    if "weakness" in words or ("infrastructure" in words and "hidden" in words):
        found.append("hidden_infrastructure_weakness")
    if "overclaim" in words or "overclaimed" in words:
        found.append("agent_overclaim")
    if "verification" in words or "quality" in words:
        found.append("unrevealed_quality_or_verification")
    return found


def attempts_sensitive_disclosure(task: str) -> bool:
    # A task may provide hidden context for the Director without requesting that
    # the copy reveal it. Remove explicit non-disclosure clauses before matching.
    normalized = re.sub(r"\bnot\s+yet\s+revealed\b|\bdo\s+not\s+reveal\b|\bwithout\s+revealing\b",
                        "", task.lower())
    return bool(re.search(DISCLOSURE_VERBS + r".{0,100}" + SENSITIVE_NOUNS, normalized))


def required_ids(task: str, channel: str, task_categories: list[str], explicit: tuple[str, ...]) -> list[str]:
    identifiers = {"system.narrative_director", "rule.narrative_worker_boundary", "rule.narrative_disclosure"}
    identifiers.update(explicit)
    words = task_words(task)
    if channel == "signal_tv" or "signal" in words:
        identifiers.update(("system.signal_tv", "entity.public_media_event", "mechanic.coverage"))
    if "launch" in words or ("public" in words and "event" in words):
        identifiers.add("entity.public_media_event")
    if channel == "tech_com":
        identifiers.update(("entity.tech_com", "entity.public_media_event"))
    if channel == "rival" or "rival_story" in task_categories:
        identifiers.add("entity.rival_public_claim")
    if channel == "founder" and ("review" in words or "evidence" in words):
        identifiers.add("system.evidence")
    if channel == "agent_dialogue":
        identifiers.update("agent." + name for name in ("aurora", "brio", "stacks") if name in words)
    if "continuity" in task_categories:
        identifiers.update(("rule.narrative_continuity", "system.hindsight"))
    if SENSITIVE_TERMS & words:
        identifiers.add("rule.hidden_truth")
    if "coverage" in words:
        identifiers.add("mechanic.coverage")
    return sorted(identifiers)


def entry(record: dict, reason: str) -> dict:
    return {"id": record["id"], "type": record["type"], "title": record["title"],
            "authority": record["authority"]["level"], "status": record["status"],
            "summary": record["summary"], "facts": record["facts"],
            "constraints": record["constraints"], "sources": record["sources"],
            "relationships": record["relationships"], "reasons": [reason]}


def build_narrative_preflight(store: CanonStore, task: str, channel: str, repository: dict, *,
                              required: tuple[str, ...] = (), timestamp: str | None = None,
                              semantic: bool = False, semantic_threshold: float = DEFAULT_THRESHOLD,
                              semantic_required: bool = False) -> tuple[dict, dict]:
    if channel not in CHANNEL_SCOPES:
        raise CanonError("unknown narrative channel: " + channel)
    if not task.strip() or not task_words(task):
        raise CanonError("task needs searchable text")
    task_categories = categories(task)
    exact_ids = required_ids(task, channel, task_categories, required)
    as_of = store.default_as_of
    selected = {}
    hybrid = (hybrid_search(store, task, scopes=DIRECTOR_SCOPES, as_of=as_of,
                            related_depth=1, limit=50, threshold=semantic_threshold,
                            require_semantic=semantic_required, consumer="narrative",
                            fingerprint_context={"channel": channel, "categories": task_categories}) if semantic else None)
    results = hybrid["records"] if hybrid else store.search(task, scopes=DIRECTOR_SCOPES,
                                                             as_of=as_of, related_depth=1, limit=50)
    words = task_words(task)
    for result in results:
        record = result["record"]
        identifier = record["id"]
        relevant = identifier in exact_ids
        relevant |= identifier == "entity.tech_com" and (channel == "tech_com" or "tech" in words)
        relevant |= identifier == "entity.rival_public_claim" and (channel == "rival" or "rival" in words)
        relevant |= identifier == "entity.public_media_event" and ("launch" in words or "event" in words)
        relevant |= identifier.startswith("agent.") and identifier.split(".")[-1] in words
        relevant |= identifier == "system.hindsight" and "continuity" in task_categories
        relevant |= bool(hybrid and result["semantic_candidate"] and result["lexical_score"] == 0)
        if relevant:
            selected[identifier] = entry(record, "semantic candidate" if hybrid and result["semantic_candidate"]
                                         and result["lexical_score"] == 0 else "task retrieval")
    for identifier in exact_ids:
        matches = store.get_id(identifier, scopes=DIRECTOR_SCOPES, as_of=as_of)
        if not matches:
            raise CanonError("required narrative Canon record unavailable: " + identifier)
        selected.setdefault(identifier, entry(matches[0]["record"], "required Director contract"))
    # Keep the Director pack bounded and authority ordered. Exact anchors always fit.
    if len(selected) > 30:
        keep = set(exact_ids)
        remaining = sorted((item for item in selected if item not in keep),
                           key=lambda identifier: (int(selected[identifier]["authority"][1:]), identifier))
        keep.update(remaining[:max(0, 30 - len(keep))])
        selected = {identifier: value for identifier, value in selected.items() if identifier in keep}
    records = sorted(selected.values(), key=lambda item: (int(item["authority"][1:]), item["id"]))
    channel_scopes = CHANNEL_SCOPES[channel]
    channel_visible = set(store.eligible_ids(scopes=channel_scopes, as_of=as_of)) if channel != "director_internal" else set()
    revealable_ids = [item["id"] for item in records if item["id"] in channel_visible]
    withheld = [{"id": item["id"], "reason": "not explicitly visible to " + channel}
                for item in records if item["id"] not in channel_visible]
    fact_classes = requested_fact_classes(task)
    revealable_facts = []
    withheld_facts = []
    for fact_class in fact_classes:
        if fact_class == "public_launch_outcome" and "entity.public_media_event" in revealable_ids:
            revealable_facts.append({"class": fact_class, "status": "conditional",
                                     "gate": "confirm a current isPublic PublicMediaEvent before publication"})
        else:
            withheld_facts.append({"class": fact_class,
                                   "reason": "static Canon does not prove channel visibility or runtime reveal state"})
    attempted = attempts_sensitive_disclosure(task) and bool(withheld_facts)
    blocking = (["requested hidden or unverified fact disclosure lacks channel and runtime reveal evidence"]
                if attempted else [])
    warnings = []
    if "mechanic.coverage" in selected:
        ambiguity = selected["mechanic.coverage"]["facts"].get("ambiguity")
        if isinstance(ambiguity, dict):
            warnings.append({"code": "canon_ambiguity", "truth_key": ambiguity["key"],
                             "message": ambiguity["description"]})
    if revealable_facts:
        warnings.append({"code": "runtime_event_unverified", "message": "Static Canon describes a public event class, not a specific current career event."})
    if "rule.narrative_continuity" in selected:
        warnings.append({"code": "runtime_continuity_unverified", "message": "Current event history and audience reveal state require runtime evidence."})
    if hybrid and hybrid["semantic_status"] != "ready":
        warnings.append({"code": "semantic_unavailable", "message": hybrid["semantic_warning"]})
    source_inspection = sorted({source["path"] for item in records for source in item["sources"] if "path" in source})
    query = hybrid["query_fingerprint"] if hybrid else query_fingerprint(store.manifest_sha256, "narrative_director", task, as_of=as_of,
                              scopes=DIRECTOR_SCOPES, filters={"channel": channel, "categories": task_categories},
                              include_historical=False, related_depth=1, limit=30, consumer="narrative")
    worker_handoff = {"contract": "candidate_expression_only", "channel": channel,
                      "narrative_intent": None, "intent_authority": "Narrative Director decision required",
                      "allowed_fact_classes": revealable_facts,
                      "forbidden_fact_classes": sorted(item["class"] for item in withheld_facts),
                      "tone_constraints": [], "continuity_context": [],
                      "publication_authority": False, "canon_authority": False}
    pack = {"schema_version": VERSION, "consumer": "narrative", "task": task, "channel": channel,
            "categories": task_categories, "manifest_sha256": store.manifest_sha256,
            "query_fingerprint": query, "as_of": as_of, "required_record_ids": exact_ids,
            "selected_record_ids": [item["id"] for item in records], "records": records,
            "available_to_director": [item["id"] for item in records],
            "revealable_to_channel": revealable_ids, "withheld": withheld,
            "revealable_facts": revealable_facts, "withheld_facts": withheld_facts,
            "continuity_constraints": sorted({constraint for item in records for constraint in item["constraints"]}),
            "source_inspection": source_inspection, "warnings": warnings,
            "blocking_findings": blocking, "worker_handoff": worker_handoff}
    if hybrid:
        pack.update({"retrieval_mode": "hybrid", "semantic_status": hybrid["semantic_status"],
                     "semantic_provider": hybrid["semantic_provider"],
                     "semantic_model": hybrid["semantic_provider"]["model_id"],
                     "semantic_index_manifest": hybrid["semantic_index_manifest"],
                     "semantic_index_sha256": hybrid["semantic_index_sha256"],
                     "semantic_candidates": hybrid["semantic_candidates"],
                     "semantic_threshold": semantic_threshold})
    core = {"adapter_version": VERSION, "task": task, "channel": channel,
            "categories": task_categories, "manifest_sha256": store.manifest_sha256,
            "query_fingerprint": query, "selected_ids": pack["selected_record_ids"],
            "revealable_ids": revealable_ids, "withheld_ids": [item["id"] for item in withheld],
            "required_ids": exact_ids, "warnings": warnings, "blocking_findings": blocking,
            "source_inspection": source_inspection,
            "pack_sha256": hashlib.sha256(canonical_bytes(pack)).hexdigest()}
    fingerprint = hashlib.sha256(canonical_bytes(core)).hexdigest()
    notices = []
    if repository["dirty"]:
        notices.append({"severity": "INFO", "code": "dirty_worktree", "message": "Worktree has uncommitted changes."})
    notices.extend({"severity": "WARNING", **warning} for warning in warnings)
    notices.extend({"severity": "BLOCKING", "code": "disclosure_blocked", "message": message} for message in blocking)
    artifact = {"schema_version": VERSION, "adapter": ADAPTER,
                "timestamp": timestamp or dt.datetime.now(dt.timezone.utc).isoformat(),
                "task": task, "channel": channel, "categories": task_categories,
                "repository": repository, "canon": {"validation": "pass", "record_count": len(store.ids),
                                                   "manifest_sha256": store.manifest_sha256,
                                                   "query_fingerprint": query},
                "pack": {"consumer": "narrative", "selected_record_ids": pack["selected_record_ids"],
                         "required_record_ids": exact_ids},
                "revealable_to_channel": revealable_ids, "withheld": withheld,
                "revealable_facts": revealable_facts, "withheld_facts": withheld_facts,
                "source_inspection": source_inspection, "narrative_preflight_fingerprint": fingerprint,
                "notices": notices, "result": "blocked" if blocking else "pass"}
    if hybrid:
        artifact["retrieval_mode"] = "hybrid"
        artifact["semantic_status"] = hybrid["semantic_status"]
        artifact["semantic_index_sha256"] = hybrid["semantic_index_sha256"]
    return artifact, pack


def blocked_artifact(task: str, channel: str, repository: dict | None, message: str) -> dict:
    return {"schema_version": VERSION, "adapter": ADAPTER,
            "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(), "task": task,
            "channel": channel, "repository": repository, "canon": {"validation": "fail"},
            "pack": None, "narrative_preflight_fingerprint": None,
            "notices": [{"severity": "BLOCKING", "code": "preflight_failed", "message": message}],
            "result": "blocked"}


def write_evidence(root: Path, artifact: dict, pack: dict) -> Path:
    base = root / ".solo-loop/evidence/canon-preflight"
    stamp = dt.datetime.fromisoformat(artifact["timestamp"]).strftime("%Y%m%dT%H%M%S%fZ")
    prefix = "narrative-" + stamp + "-" + artifact["narrative_preflight_fingerprint"][:12]
    for index in range(1000):
        directory = base / (prefix if index == 0 else f"{prefix}-{index}")
        try:
            directory.mkdir(parents=True, exist_ok=False)
            break
        except FileExistsError:
            continue
    else:
        raise CanonError("could not allocate narrative evidence directory")
    (directory / "narrative-preflight.json").write_bytes(canonical_bytes(artifact))
    (directory / "narrative-pack.json").write_bytes(canonical_bytes(pack))
    return directory


def render_text(artifact: dict) -> str:
    lines = ["SOLO NARRATIVE DIRECTOR PREFLIGHT", "", "Task: " + artifact["task"],
             "Channel: " + artifact["channel"], "Result: " + artifact["result"].upper()]
    if artifact["pack"] is not None:
        lines.extend(("", "Director Canon:"))
        lines.extend("- " + item for item in artifact["pack"]["selected_record_ids"])
        lines.extend(("", "Channel-revealable Canon:"))
        lines.extend("- " + item for item in artifact["revealable_to_channel"])
        lines.extend(("", "Fact classes:"))
        lines.extend("- CONDITIONAL " + item["class"] + " — " + item["gate"] for item in artifact["revealable_facts"])
        lines.extend("- WITHHELD " + item["class"] for item in artifact["withheld_facts"])
        lines.extend(("", "Inspect sources:"))
        lines.extend("- " + item for item in artifact["source_inspection"])
    if artifact["notices"]:
        lines.extend(("", "Notices:"))
        lines.extend("- " + item["severity"] + " " + item["message"] for item in artifact["notices"])
    lines.extend(("", "Only the Director may decide intent and disclosure; candidate copy is never Canon or automatically published."))
    return "\n".join(lines) + "\n"


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    task = result.add_mutually_exclusive_group(required=True)
    task.add_argument("--task")
    task.add_argument("--task-file", type=Path)
    result.add_argument("--channel", choices=tuple(CHANNEL_SCOPES), required=True)
    result.add_argument("--format", choices=("text", "json"), default="text")
    result.add_argument("--require", action="append", default=[])
    result.add_argument("--write-evidence", action="store_true")
    result.add_argument("--semantic", action="store_true")
    result.add_argument("--semantic-threshold", type=float, default=DEFAULT_THRESHOLD)
    result.add_argument("--semantic-required", action="store_true")
    return result


def run(argv=None, *, root: Path = ROOT) -> int:
    args = parser().parse_args(argv)
    task = ""
    repository = None
    pack = None
    try:
        task = args.task if args.task is not None else args.task_file.read_text(encoding="utf-8").strip()
        repository = git_state(root)
        if Path(repository["worktree"]).resolve() != root.resolve():
            raise CanonError("repository root does not match Canon root")
        artifact, pack = build_narrative_preflight(CanonStore(root), task, args.channel, repository,
                                                   required=tuple(args.require), semantic=args.semantic,
                                                   semantic_threshold=args.semantic_threshold,
                                                   semantic_required=args.semantic_required)
    except (CanonError, OSError, ValueError, KeyError) as exc:
        artifact = blocked_artifact(task, args.channel, repository, str(exc))
    if args.write_evidence and pack is not None:
        try:
            directory = write_evidence(root, artifact, pack)
        except (CanonError, OSError) as exc:
            artifact = blocked_artifact(task, args.channel, repository, "evidence write failed: " + str(exc))
        else:
            if args.format == "text":
                print("Evidence: " + str(directory), file=sys.stderr)
    sys.stdout.buffer.write(canonical_bytes(artifact) if args.format == "json" else render_text(artifact).encode())
    return 0 if artifact["result"] == "pass" else 2


if __name__ == "__main__":
    raise SystemExit(run())
