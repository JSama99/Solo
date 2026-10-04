#!/usr/bin/env python3
"""Offline Chaos Crew Canon experiment contract; does not execute simulations."""

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

ADAPTER = "solo-canon-chaos-preflight"
VERSION = "0.1"
SCOPES = PROFILES["chaos"]["scopes"]
CATEGORY_TERMS = {
    "balance": ("balance", "best-performing", "optimal"),
    "exploit": ("exploit", "strategy", "loophole", "degenerate"),
    "economy": ("economy", "revenue", "runway", "finance", "zero revenue", "cost"),
    "agent_behavior": ("agent", "aurora", "stacks", "brio", "drift", "overclaim", "reliability"),
    "progression": ("progression", "venture", "achievement", "era"),
    "rival_behavior": ("rival", "competitor"),
    "resource_loop": ("momentum", "trust", "coverage", "energy", "attention", "resource", "loop"),
    "save_invariant": ("save", "migration", "persistence"),
    "determinism": ("deterministic", "determinism", "seed", "replay", "rng"),
}
MECHANIC_TERMS = {
    "mechanic.momentum": ("momentum",),
    "mechanic.trust": ("trust",),
    "mechanic.runway": ("runway", "survive", "survival"),
    "mechanic.revenue": ("revenue",),
    "mechanic.coverage": ("coverage",),
    "mechanic.founder_energy": ("energy",),
    "mechanic.founder_attention": ("attention",),
}
CATEGORY_IDS = {
    "economy": ("mechanic.revenue", "mechanic.runway"),
    "agent_behavior": ("system.work_sessions", "system.evidence"),
    "progression": ("system.persistence",),
    "rival_behavior": ("entity.rival_public_claim",),
    "save_invariant": ("system.persistence", "rule.save_compatibility"),
    "determinism": ("rule.determinism",),
}
SIMULATION_IDS = {"system.simulation", "system.persistence", "system.work_sessions", "system.evidence",
                  "system.hindsight", "system.signal_tv", "system.chaos_crew"}
RULE_IDS = {"rule.simulation_authority", "rule.determinism", "rule.save_compatibility",
            "rule.canon_promotion", "rule.chaos_observation_only", "rule.simulation_invariants"}
ENTITY_IDS = {"entity.rival_public_claim"}
SOURCE_GUIDANCE = {
    "economy": ("App/CompanyFinance.swift", "Tests/CompanyFinanceTests.swift"),
    "agent_behavior": ("App/WorkSessionEngine.swift", "Tests/WorkSessionEngineTests.swift"),
    "progression": ("App/GameStore.swift", "Tests/GameStoreTests.swift"),
    "rival_behavior": ("Tests/RivalEngineTests.swift",),
    "resource_loop": ("App/GameStore.swift", "Tests/GameStoreTests.swift"),
    "save_invariant": ("App/GameStore.swift", "Tests/GameStoreTests.swift"),
    "determinism": ("Tests/SimulationEngineTests.swift",),
}
FINDING_STATES = ("observed", "reproduced", "verified", "proposed", "rejected", "promoted")


def words(task: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", task.lower()))


def matches(task: str, terms: tuple[str, ...]) -> bool:
    normalized = " " + " ".join(re.findall(r"[a-z0-9]+", task.lower())) + " "
    return any(" " + term.replace("-", " ") + " " in normalized for term in terms)


def categories(task: str) -> list[str]:
    return [name for name, terms in CATEGORY_TERMS.items() if matches(task, terms)] or ["balance"]


def seed_contract(seed: str | None) -> dict:
    if seed is None:
        raise CanonError("explicit --seed is required for a Chaos experiment contract")
    if not re.fullmatch(r"(?:0|[1-9][0-9]*)", seed) or int(seed) > 2**64 - 1:
        raise CanonError("seed must be an unsigned decimal UInt64")
    return {"mode": "single_seed_reproduction", "seed": int(seed), "rng": "production_seeded_path",
            "implicit_random_seed": False}


def selected_ids(store: CanonStore, task: str, category_list: list[str], required: tuple[str, ...]) -> list[str]:
    identifiers = {"system.simulation", "system.chaos_crew", "rule.simulation_authority",
                   "rule.determinism", "rule.chaos_observation_only", "rule.canon_promotion",
                   "rule.simulation_invariants"}
    identifiers.update(required)
    identifiers.update(identifier for identifier, terms in MECHANIC_TERMS.items() if matches(task, terms))
    for category in category_list:
        identifiers.update(CATEGORY_IDS.get(category, ()))
    if "mechanic.momentum" in identifiers:
        identifiers.update(("mechanic.founder_attention", "mechanic.trust", "mechanic.revenue"))
    if "mechanic.coverage" in identifiers:
        identifiers.add("system.signal_tv")
    if "save_invariant" in category_list:
        identifiers.add("rule.save_compatibility")
    # The profile permits developer scope, but this adapter permits only simulation
    # systems/mechanics/rules and explicitly required relevant records.
    allowed = {identifier for identifier in store.eligible_ids(scopes=SCOPES) if
               identifier.startswith("mechanic.") or identifier in SIMULATION_IDS or identifier in RULE_IDS
               or identifier in ENTITY_IDS}
    unavailable = sorted(identifiers - allowed)
    if unavailable:
        raise CanonError("required simulation Canon unavailable: " + ", ".join(unavailable))
    return sorted(identifiers, key=lambda identifier: (int(store.records[identifier]["authority"]["level"][1:]), identifier))


def build_chaos_preflight(store: CanonStore, task: str, repository: dict, *, seed: str | None,
                          required: tuple[str, ...] = (), timestamp: str | None = None) -> tuple[dict, dict]:
    if not task.strip() or not words(task):
        raise CanonError("task needs searchable text")
    seeds = seed_contract(seed)
    category_list = categories(task)
    ids = selected_ids(store, task, category_list, required)
    if store.records["system.simulation"]["authority"]["level"] != "P1":
        raise CanonError("production simulation authority unresolved")
    base = build_pack(store, consumer="chaos", task=task)
    records = [store.view(identifier, set(ids)) for identifier in ids]
    sources = sorted({source["path"] for record in records for source in record["sources"] if "path" in source
                      and source["path"] != "App/SignalTVView.swift"}
                     | {path for category in category_list for path in SOURCE_GUIDANCE.get(category, ())
                        if (store.root / path).is_file()})
    invariants = []
    if "rule.determinism" in ids:
        invariants.append({"id": "seeded_replay", "assertion": "same seed and same inputs preserve RNG ordering and cached outcomes",
                           "sources": ["AGENTS.md", "App/SimulationEngine.swift", "App/GameStore.swift"]})
    if "mechanic.coverage" in ids:
        invariants.append({"id": "coverage_bounds", "assertion": "Coverage is clamped to -100 through 100 on production mutation paths",
                           "sources": ["App/SignalTVModels.swift", "App/GameStore.swift"]})
    if "save_invariant" in category_list:
        invariants.append({"id": "save_version", "assertion": "current save envelope version remains 20; migration compatibility must be checked",
                           "sources": ["App/GameStore.swift"]})
    invariants.sort(key=lambda item: item["id"])
    warnings = []
    blockers = []
    if "agent_behavior" in category_list or "rival_behavior" in category_list:
        warnings.append({"code": "path_determinism_unverified",
                         "message": "Preflight has not verified deterministic replay for every requested agent or rival path; inspect the selected tests before making a reproduction claim."})
    if "mechanic.coverage" in ids:
        ambiguity = store.records["mechanic.coverage"]["facts"].get("ambiguity")
        if ambiguity:
            finding = {"code": "coverage_mutation_authority", "truth_key": ambiguity["key"],
                       "message": ambiguity["description"]}
            if matches(task, ("every", "all", "exhaustive", "complete")):
                blockers.append(finding)
            else:
                warnings.append(finding)
    normalized = " ".join(task.lower().split())
    if re.search(r"\b(?:mutate|modify|rewrite|write|alter|update|edit)\b.{0,45}\b(?:live|player|career)\s+saves?\b", normalized):
        blockers.append({"code": "live_save_mutation", "message": "Chaos experiments may not mutate live player saves."})
    if (re.search(r"\b(?:automatically|auto)\b.{0,100}\b(?:update|rewrite|change|promote|replace)\b.{0,80}\b(?:formula|canon|mechanic)\b", normalized)
            or re.search(r"\b(?:update|rewrite|change|promote|replace)\b.{0,80}\b(?:formula|canon|mechanic)\b.{0,40}\b(?:automatically|auto)\b", normalized)
            or re.search(r"\b(?:update|rewrite|change|replace)\b.{0,60}\b(?:production|mechanic\.[a-z_]+)\b.{0,50}\bformula\b", normalized)):
        blockers.append({"code": "self_promotion", "message": "Chaos cannot automatically change production formulas or Canon."})
    scenario = {"inputs": "to_be_specified", "strategy": "to_be_specified", "termination": "to_be_specified",
                "comparison": "same code, Canon, seed, and scenario"}
    if "mechanic.revenue" in ids and "zero" in words(task):
        scenario["revenue_constraint"] = 0
        scenario["termination"] = "bounded_horizon_required; finite runs cannot establish indefinite survival"
    specification = {"category": category_list[0], "categories": category_list, "task": task,
                     "systems": [identifier for identifier in ids if identifier.startswith("mechanic.")],
                     "simulation_authority": ["system.simulation"], "seed_contract": seeds,
                     "scenario_parameters": scenario, "invariants": invariants,
                     "required_sources": sources, "visibility": list(SCOPES),
                     "execution": "not_run", "production_mutation": False}
    experiment_fingerprint = hashlib.sha256(canonical_bytes({
        "adapter_version": VERSION, "manifest_sha256": store.manifest_sha256,
        "query_fingerprint": base["query_fingerprint"], "selected_ids": ids,
        "specification": specification})).hexdigest()
    observation = {"kind": "chaos_finding", "initial_status": "not_run", "allowed_states": list(FINDING_STATES),
                   "chaos_max_state": "proposed", "authority": "non_canonical", "seed": seeds["seed"],
                   "finding": None, "reproduction_count": 0, "canon_promotion": "not_authorized",
                   "promotion_requires": "external Canon governance and independent verification"}
    pack = {"schema_version": VERSION, "consumer": "chaos", "task": task,
            "manifest_sha256": store.manifest_sha256, "query_fingerprint": base["query_fingerprint"],
            "experiment_fingerprint": experiment_fingerprint,
            "selected_record_ids": ids, "records": records, "experiment_specification": specification,
            "observation_template": observation, "warnings": warnings, "blocking_findings": blockers}
    pack_sha = hashlib.sha256(canonical_bytes(pack)).hexdigest()
    core = {"adapter_version": VERSION, "task": task, "category": category_list,
            "seed_specification": seeds, "manifest_sha256": store.manifest_sha256,
            "query_fingerprint": base["query_fingerprint"], "selected_ids": ids,
            "invariants": invariants, "source_list": sources, "scenario_parameters": scenario,
            "warnings": warnings, "blockers": blockers, "pack_sha256": pack_sha}
    fingerprint = hashlib.sha256(canonical_bytes(core)).hexdigest()
    notices = ([{"severity": "INFO", "code": "dirty_worktree", "message": "Worktree has uncommitted changes."}]
               if repository["dirty"] else [])
    notices.extend({"severity": "WARNING", **item} for item in warnings)
    notices.extend({"severity": "BLOCKING", **item} for item in blockers)
    artifact = {"schema_version": VERSION, "adapter": ADAPTER,
                "timestamp": timestamp or dt.datetime.now(dt.timezone.utc).isoformat(),
                "task": task, "categories": category_list, "repository": repository,
                "canon": {"validation": "pass", "record_count": len(store.ids),
                          "manifest_sha256": store.manifest_sha256,
                          "query_fingerprint": base["query_fingerprint"]},
                "pack": {"consumer": "chaos", "selected_record_ids": ids, "sha256": pack_sha},
                "experiment_specification": specification, "source_inspection": sources,
                "invariants": invariants, "notices": notices,
                "experiment_fingerprint": experiment_fingerprint,
                "chaos_preflight_fingerprint": fingerprint,
                "result": "blocked" if blockers else "pass"}
    return artifact, pack


def blocked_artifact(task: str, repository: dict | None, message: str) -> dict:
    return {"schema_version": VERSION, "adapter": ADAPTER,
            "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(), "task": task,
            "repository": repository, "canon": {"validation": "fail"}, "pack": None,
            "chaos_preflight_fingerprint": None,
            "notices": [{"severity": "BLOCKING", "code": "preflight_failed", "message": message}],
            "result": "blocked"}


def write_evidence(root: Path, artifact: dict, pack: dict) -> Path:
    base = root / ".solo-loop/evidence/canon-preflight"
    stamp = dt.datetime.fromisoformat(artifact["timestamp"]).strftime("%Y%m%dT%H%M%S%fZ")
    prefix = "chaos-" + stamp + "-" + artifact["chaos_preflight_fingerprint"][:12]
    for index in range(1000):
        directory = base / (prefix if index == 0 else f"{prefix}-{index}")
        try:
            directory.mkdir(parents=True, exist_ok=False)
            break
        except FileExistsError:
            continue
    else:
        raise CanonError("could not allocate Chaos evidence directory")
    (directory / "chaos-preflight.json").write_bytes(canonical_bytes(artifact))
    (directory / "chaos-pack.json").write_bytes(canonical_bytes(pack))
    return directory


def render_text(artifact: dict) -> str:
    lines = ["SOLO CHAOS PREFLIGHT", "", "Task: " + artifact["task"],
             "Result: " + artifact["result"].upper()]
    if artifact["pack"]:
        lines.extend(("Seed: " + str(artifact["experiment_specification"]["seed_contract"]["seed"]),
                      "Pack SHA-256: " + artifact["pack"]["sha256"],
                      "Experiment fingerprint: " + artifact["experiment_fingerprint"],
                      "Fingerprint: " + artifact["chaos_preflight_fingerprint"], "", "Selected Canon:"))
        lines.extend("- " + identifier for identifier in artifact["pack"]["selected_record_ids"])
        lines.extend(("", "Sources:"))
        lines.extend("- " + path for path in artifact["source_inspection"])
    if artifact["notices"]:
        lines.extend(("", "Notices:"))
        lines.extend("- " + item["severity"] + " " + item["message"] for item in artifact["notices"])
    lines.append("\nPreflight only; no simulation was run and no Canon finding was promoted.")
    return "\n".join(lines) + "\n"


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--task", required=True)
    result.add_argument("--seed")
    result.add_argument("--format", choices=("text", "json"), default="text")
    result.add_argument("--require", action="append", default=[])
    result.add_argument("--write-evidence", action="store_true")
    return result


def run(argv=None, *, root: Path = ROOT) -> int:
    args = parser().parse_args(argv)
    repository = None
    pack = None
    try:
        repository = git_state(root)
        if Path(repository["worktree"]).resolve() != root.resolve():
            raise CanonError("repository root does not match Canon root")
        artifact, pack = build_chaos_preflight(CanonStore(root), args.task, repository,
                                               seed=args.seed, required=tuple(args.require))
    except (CanonError, OSError, ValueError, KeyError) as exc:
        artifact = blocked_artifact(args.task, repository, str(exc))
    if args.write_evidence and pack is not None:
        try:
            directory = write_evidence(root, artifact, pack)
        except (CanonError, OSError) as exc:
            artifact = blocked_artifact(args.task, repository, "evidence write failed: " + str(exc))
        else:
            if args.format == "text":
                print("Evidence: " + str(directory), file=sys.stderr)
    sys.stdout.buffer.write(canonical_bytes(artifact) if args.format == "json" else render_text(artifact).encode())
    return 0 if artifact["result"] == "pass" else 2


if __name__ == "__main__":
    raise SystemExit(run())
