#!/usr/bin/env python3
"""Validated, bounded SOLO visual Canon preflight; read-only unless asked to write evidence."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from canon_pack import build_pack
from canon_store import CanonError, CanonStore, PROFILES, ROOT, canonical_bytes
from codex_preflight import git_state

ADAPTER = "solo-canon-visual-preflight"
VERSION = "0.1"
VISUAL_TYPES = {"asset", "character", "location", "rule", "experiment", "decision"}
VISUAL_TERMS = {
    "character": ("character", "founder", "mara", "rig", "face", "wardrobe"),
    "environment": ("environment", "atlantis", "garage", "district", "world"),
    "lighting": ("light", "lighting", "daylight", "atmosphere", "shadow"),
    "camera": ("camera", "framing", "shot", "fov"),
    "animation": ("animation", "motion", "locomotion", "gait", "movement"),
    "materials": ("material", "texture", "shader"),
    "interior": ("interior", "room", "desk", "garage"),
    "asset": ("asset", "usdz", "mesh", "blender", "model"),
    "presentation": ("presentation", "ui", "viewport", "hud"),
}
TOPIC_ANCHORS = {
    "founder": ("character.founder", "asset.founder.production", "rule.visual_identity"),
    "mara": ("character.mara", "rule.visual_identity"),
    "garage": ("location.founder_garage", "rule.visual_identity"),
    "atlantis": ("location.atlantis", "rule.visual_identity"),
}
STATUS_LABELS = {"P0": "OWNER LOCKED", "P1": "PRODUCTION", "P2": "OWNER ACCEPTED",
                 "P3": "IMPLEMENTED", "P4": "PROPOSED", "P5": "STUDY",
                 "P6": "HISTORICAL", "P7": "HISTORICAL"}


def words(task: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", task.lower()))


def categories(task: str) -> list[str]:
    found = words(task)
    result = [name for name, terms in VISUAL_TERMS.items() if any(term in found or term + "s" in found for term in terms)]
    if (re.search(r"\bfounder\s+(district|garage|street)\b", task.lower())
            and not found.intersection({"character", "avatar", "rig", "face", "wardrobe", "gait"})
            and "character" in result):
        result.remove("character")
    return result


def topics(task: str) -> list[str]:
    found = words(task)
    result = [topic for topic in TOPIC_ANCHORS if topic in found]
    place_phrase = bool(re.search(r"\bfounder\s+(district|garage|street)\b", task.lower()))
    character_cue = bool(found.intersection({"character", "avatar", "rig", "face", "wardrobe", "gait"}))
    if place_phrase and not character_cue and "founder" in result:
        result.remove("founder")
    if "district" in found and "atlantis" not in result:
        result.append("atlantis")
    return result


def visual_conflicts(records: list[dict]) -> list[str]:
    issues = []
    identities = {}
    assets = {}
    for record in records:
        if record["authority"] not in {"P0", "P1"} or record["status"] == "blocked":
            continue
        facts = record["facts"]
        subject = facts.get("identity_subject")
        if subject and record["type"] == "character":
            identities.setdefault(subject, set()).add(facts.get("identity_asset_id", record["id"]))
        role = facts.get("asset_role")
        path = facts.get("asset_path") or facts.get("production_asset_path") or facts.get("production_founder_district_asset")
        if subject and role and path:
            assets.setdefault((subject, role), set()).add(path)
    for subject, values in sorted(identities.items()):
        if len(values) > 1:
            issues.append("conflicting active production visual identities: " + subject)
    for (subject, role), values in sorted(assets.items()):
        if len(values) > 1:
            issues.append("contradictory production asset identity: " + subject + "/" + role)
    return issues


def entry_from_record(record: dict, reason: str) -> dict:
    return {"id": record["id"], "type": record["type"], "title": record["title"],
            "authority": record["authority"]["level"], "status": record["status"],
            "summary": record["summary"], "facts": record["facts"],
            "constraints": record["constraints"], "sources": record["sources"],
            "external_evidence": record["external_evidence"],
            "relationships": record["relationships"], "reasons": [reason]}


def build_visual_preflight(store: CanonStore, task: str, repository: dict, *, required: tuple[str, ...] = (),
                           timestamp: str | None = None) -> tuple[dict, dict]:
    # C1 handles validation, visibility, time, and relationship rules. C3 narrows its
    # broad lexical result to visual topics, then injects exact visible anchors.
    base = build_pack(store, consumer="visual", task=task, max_records=50, related_depth=0)
    task_categories = categories(task)
    task_topics = topics(task)
    scopes = PROFILES["visual"]["scopes"]
    required_ids = set(required)
    for topic in task_topics:
        required_ids.update(TOPIC_ANCHORS[topic])
    if "animation" in task_categories or "camera" in task_categories:
        required_ids.add("rule.reduce_motion_visual")
    selected = {}
    for entry in base["records"]:
        if entry["type"] not in VISUAL_TYPES:
            continue
        identifier = entry["id"]
        is_visual = "visual" in store.records[identifier]["tags"] or entry["type"] in {"asset", "character", "location"}
        if not is_visual:
            continue
        if task_topics:
            relevant = any(identifier.startswith(("character." + topic, "asset." + topic))
                           for topic in task_topics if topic in {"founder", "mara"})
            relevant |= "garage" in task_topics and identifier == "location.founder_garage"
            relevant |= "atlantis" in task_topics and identifier == "location.atlantis"
            relevant |= identifier in {"rule.visual_identity", "rule.reduce_motion_visual"}
            if not relevant:
                continue
        if identifier == "asset.founder.shoulder_r1" and not ("animation" in task_categories or "shoulder" in words(task)):
            continue
        if identifier == "rule.reduce_motion_visual" and not ({"animation", "camera"} & set(task_categories)):
            continue
        selected[identifier] = entry
    for identifier in sorted(required_ids):
        match = store.get_id(identifier, scopes=scopes, as_of=base["as_of"])
        if not match:
            raise CanonError("required visual Canon record unavailable: " + identifier)
        selected.setdefault(identifier, entry_from_record(match[0]["record"], "required visual anchor"))
    # A Founder motion task needs the accepted calibration and rejected history,
    # but an unrelated Founder task does not inherit the full motion audit.
    if "founder" in task_topics and "animation" in task_categories:
        for identifier in ("asset.founder.shoulder_r1", "experiment.founder.shoulder_rejected"):
            filters = {"status": "blocked"} if identifier == "experiment.founder.shoulder_rejected" else None
            match = store.get_id(identifier, scopes=scopes, as_of=base["as_of"], filters=filters)
            if match:
                selected.setdefault(identifier, entry_from_record(match[0]["record"], "relevant motion history"))
    ordered = sorted(selected.values(), key=lambda item: (int(item["authority"][1:]), item["id"]))
    for item in ordered:
        item["visual_state"] = ("BLOCKED" if item["status"] == "blocked" else
                                "EXPERIMENTAL" if item["status"] == "experimental" else
                                "HISTORICAL" if item["status"] in {"historical", "deprecated"} else
                                STATUS_LABELS[item["authority"]])
    # Blocked studies stay visible as negative history, never in the target set.
    target_records = [item for item in ordered if item["status"] not in {"blocked", "historical", "deprecated", "experimental", "proposed"}
                      and item["authority"] not in {"P4", "P5", "P6", "P7"}]
    studies = [item for item in ordered if item not in target_records]
    def inspection_sources(item: dict) -> list[str]:
        paths = [source["path"] for source in item["sources"] if "path" in source]
        if item["id"] == "rule.visual_identity" and task_topics:
            shared = {"AGENTS.md"}
            if "founder" in task_topics:
                shared.add("Documentation/FounderCharacter/FOUNDER_CHARACTER_PRODUCTION_PROMOTION_REPORT.md")
            if "mara" in task_topics:
                shared.add("Assets/Atlantis/Characters/MaraChen/ASSET_CONTRACT.md")
            if {"atlantis", "garage"} & set(task_topics):
                shared.add("Documentation/Shipathon/SHIPATHON_VISUAL_LOCK.md")
            return [path for path in paths if path in shared]
        if item["id"] == "rule.reduce_motion_visual" and task_topics == ["mara"]:
            return [path for path in paths if path in {"AGENTS.md", "App/GameplayMotion.swift",
                                                       "Assets/Atlantis/Characters/MaraChen/ASSET_CONTRACT.md"}]
        if item["id"] == "rule.reduce_motion_visual" and "mara" not in task_topics:
            return [path for path in paths if path != "Assets/Atlantis/Characters/MaraChen/ASSET_CONTRACT.md"]
        return paths

    source_paths = sorted({path for item in ordered for path in inspection_sources(item)})
    reference_paths = sorted({value for item in ordered for key, value in item["facts"].items()
                              if key.endswith("_path") and isinstance(value, str)})
    sources = sorted(set(source_paths).union(reference_paths))
    production_assets = [{"record_id": item["id"], "path": item["facts"].get("asset_path") or
                          item["facts"].get("production_asset_path") or item["facts"].get("production_founder_district_asset"),
                          "role": item["facts"].get("asset_role", "production_environment"),
                          "authority": item["authority"],
                          "sha256_from_record": item["facts"].get("sha256_from_promotion_report") or
                          item["facts"].get("production_asset_sha256_from_visual_lock"),
                          "owner_acceptance": item["facts"].get("owner_acceptance")}
                         for item in target_records if item["authority"] in {"P0", "P1"} and
                         (item["facts"].get("asset_path") or item["facts"].get("production_asset_path") or
                          item["facts"].get("production_founder_district_asset"))]
    accepted_references = [{"record_id": item["id"], "acceptance_scope": item["facts"].get("owner_acceptance"),
                            "reference_path": item["facts"].get("reference_path") or item["facts"].get("accepted_source_path"),
                            "production_promotion": item["facts"].get("production_promotion")}
                           for item in target_records if item["authority"] == "P2" and
                           item["type"] in {"asset", "character", "location", "decision"}]
    study_refs = [{"record_id": item["id"], "authority": item["authority"], "status": item["status"],
                   "label": "DO NOT USE AS TARGET"} for item in studies]
    constraints = sorted({constraint for item in target_records for constraint in item["constraints"]})
    allowed_ids = set(store.eligible_ids(scopes=scopes, as_of=base["as_of"]))
    identity_candidates = [entry_from_record(store.view(identifier, allowed_ids), "identity conflict audit")
                           for identifier in sorted(allowed_ids)
                           if store.records[identifier]["facts"].get("identity_subject") in task_topics]
    conflicts = visual_conflicts(identity_candidates)
    notices = []
    if repository["dirty"]:
        notices.append({"severity": "INFO", "code": "dirty_worktree", "message": "Worktree has uncommitted changes."})
    for path in reference_paths:
        if not (store.root / path).is_file():
            notices.append({"severity": "WARNING", "code": "reference_unavailable", "message": path + " is absent in this checkout."})
    for study in studies:
        notices.append({"severity": "WARNING", "code": "non_target_study", "message": study["id"] + " is " + study["status"] + "; DO NOT USE AS TARGET."})
    if "mara" in task_topics:
        notices.append({"severity": "WARNING", "code": "partial_owner_acceptance",
                        "message": "Mara Gate 1 shape and wardrobe are accepted; runtime appearance remains unapproved."})
    replacement = bool(re.search(r"\b(redesign|replace|recreate|start over|from scratch)\b", task.lower()))
    if replacement and ("mara" in task_topics or "founder" in task_topics):
        conflicts.append("Replacement of an accepted character identity requires a new owner decision.")
    for message in conflicts:
        notices.append({"severity": "BLOCKING", "code": "visual_identity_conflict", "message": message})
    for conflict in base["conflicts"]:
        if conflict["result"] == "conflict":
            message = conflict["truth_key"] + ": " + conflict["description"]
            conflicts.append(message)
            notices.append({"severity": "BLOCKING", "code": "visual_canon_conflict", "message": message})
        else:
            notices.append({"severity": "WARNING", "code": conflict["result"],
                            "message": conflict["truth_key"] + ": " + conflict["description"]})
    query = {"adapter_version": VERSION, "base_query_fingerprint": base["query_fingerprint"],
             "categories": task_categories, "topics": task_topics, "selected_ids": [item["id"] for item in ordered],
             "required_ids": sorted(required_ids)}
    query_fingerprint = hashlib.sha256(canonical_bytes(query)).hexdigest()
    pack = {"schema_version": VERSION, "consumer": "visual", "task": task,
            "categories": task_categories, "topics": task_topics, "manifest_sha256": store.manifest_sha256,
            "query_fingerprint": query_fingerprint, "base_query_fingerprint": base["query_fingerprint"],
            "as_of": base["as_of"], "record_ids": [item["id"] for item in ordered],
            "required_record_ids": sorted(required_ids), "records": ordered,
            "target_record_ids": [item["id"] for item in target_records],
            "production_assets": production_assets, "accepted_references": accepted_references,
            "blocked_or_experimental": study_refs, "constraints": constraints,
            "source_inspection": sources, "conflicts": conflicts,
            "warnings": [item for item in notices if item["severity"] == "WARNING"
                         and item["code"] != "reference_unavailable"]}
    core = {"adapter_version": VERSION, "task": task, "categories": task_categories,
            "topics": task_topics, "manifest_sha256": store.manifest_sha256,
            "query_fingerprint": query_fingerprint, "record_ids": pack["record_ids"],
            "required_record_ids": pack["required_record_ids"], "source_inspection": sources,
            "warnings": pack["warnings"], "conflicts": conflicts}
    fingerprint = hashlib.sha256(canonical_bytes(core)).hexdigest()
    artifact = {"schema_version": VERSION, "adapter": ADAPTER,
                "timestamp": timestamp or dt.datetime.now(dt.timezone.utc).isoformat(),
                "task": task, "categories": task_categories, "repository": repository,
                "canon": {"record_count": len(store.ids), "manifest_sha256": store.manifest_sha256,
                          "query_fingerprint": query_fingerprint, "validation": "pass"},
                "pack": {"consumer": "visual", "record_ids": pack["record_ids"],
                         "required_record_ids": pack["required_record_ids"]},
                "production_assets": production_assets, "accepted_references": accepted_references,
                "blocked_or_experimental": study_refs, "source_inspection": sources,
                "visual_preflight_fingerprint": fingerprint, "notices": notices,
                "result": "blocked" if conflicts else "pass"}
    return artifact, pack


def blocked_artifact(task: str, repository: dict | None, message: str) -> dict:
    return {"schema_version": VERSION, "adapter": ADAPTER,
            "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(), "task": task,
            "repository": repository, "canon": {"validation": "fail"}, "pack": None,
            "visual_preflight_fingerprint": None, "source_inspection": [],
            "notices": [{"severity": "BLOCKING", "code": "preflight_failed", "message": message}],
            "result": "blocked"}


def write_evidence(root: Path, artifact: dict, pack: dict) -> Path:
    base = root / ".solo-loop/evidence/canon-preflight"
    stamp = dt.datetime.fromisoformat(artifact["timestamp"]).strftime("%Y%m%dT%H%M%S%fZ")
    prefix = "visual-" + stamp + "-" + artifact["visual_preflight_fingerprint"][:12]
    for index in range(1000):
        directory = base / (prefix if index == 0 else f"{prefix}-{index}")
        try:
            directory.mkdir(parents=True, exist_ok=False)
            break
        except FileExistsError:
            continue
    else:
        raise CanonError("could not allocate visual evidence directory")
    (directory / "visual-preflight.json").write_bytes(canonical_bytes(artifact))
    (directory / "visual-pack.json").write_bytes(canonical_bytes(pack))
    return directory


def render_text(artifact: dict) -> str:
    lines = ["SOLO VISUAL CANON PREFLIGHT", "", "Task: " + artifact["task"],
             "Result: " + artifact["result"].upper()]
    if artifact["pack"] is not None:
        lines.extend(("Categories: " + ", ".join(artifact["categories"]), "", "Applicable visual Canon:"))
        lines.extend("- " + identifier for identifier in artifact["pack"]["record_ids"])
        lines.extend(("", "Inspect sources/references:"))
        lines.extend("- " + path for path in artifact["source_inspection"])
    if artifact["notices"]:
        lines.extend(("", "Notices:"))
        lines.extend("- " + item["severity"] + " " + item["message"] for item in artifact["notices"])
    lines.extend(("", "Automated verification is not owner visual acceptance."))
    return "\n".join(lines) + "\n"


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    task = result.add_mutually_exclusive_group(required=True)
    task.add_argument("--task")
    task.add_argument("--task-file", type=Path)
    result.add_argument("--format", choices=("text", "json"), default="text")
    result.add_argument("--require", action="append", default=[])
    result.add_argument("--write-evidence", action="store_true")
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
        artifact, pack = build_visual_preflight(CanonStore(root), task, repository,
                                                required=tuple(args.require))
    except (CanonError, OSError, ValueError, KeyError) as exc:
        artifact = blocked_artifact(task, repository, str(exc))
    if args.write_evidence and pack is not None:
        try:
            directory = write_evidence(root, artifact, pack)
        except (CanonError, OSError) as exc:
            artifact = blocked_artifact(task, repository, "evidence write failed: " + str(exc))
        else:
            if args.format == "text":
                print("Evidence: " + str(directory), file=sys.stderr)
    sys.stdout.buffer.write(canonical_bytes(artifact) if args.format == "json" else render_text(artifact).encode())
    return 0 if artifact["result"] == "pass" else 2


if __name__ == "__main__":
    raise SystemExit(run())
