#!/usr/bin/env python3
"""Read-only by default: validate SOLO Canon and prepare a Codex task handoff."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import re
import subprocess
import sys
from pathlib import Path

# The documented plain `python3` invocation must remain read-only as well.
sys.dont_write_bytecode = True

from canon_pack import build_pack, markdown
from canon_store import CanonError, CanonStore, PROFILES, ROOT, canonical_bytes
from hybrid_retrieval import DEFAULT_THRESHOLD, hybrid_pack


ADAPTER = "solo-canon-codex-preflight"
VERSION = "0.1"
CATEGORIES = {
    "architecture": ("architecture", "architectural"),
    "gameplay": ("gameplay", "game mechanics"),
    "simulation": ("simulation", "simulator", "rng", "determinism"),
    "visual": ("visual", "camera", "animation", "lighting"),
    "narrative": ("narrative", "story", "dialogue"),
    "agents": ("agent", "aurora", "stacks", "brio"),
    "world": ("world", "atlantis", "garage"),
    "assets": ("asset", "model", "texture"),
    "persistence": ("save", "persistence", "migration"),
    "economy": ("economy", "runway", "revenue", "finance"),
    "media": ("media", "signal tv", "coverage"),
    "rivals": ("rival",),
    "chaos": ("chaos crew",),
}


def classify_task(task: str) -> list[str]:
    words = " " + " ".join(re.findall(r"[a-z0-9]+", task.lower())) + " "
    return [name for name, terms in CATEGORIES.items() if any(" " + term + " " in words or
            (term in {"agent", "asset", "rival", "save"} and " " + term + "s " in words)
            for term in terms)]


def git_state(root: Path) -> dict:
    def command(*args: str) -> str:
        try:
            result = subprocess.run(("git", *args), cwd=root, text=True, capture_output=True,
                                    check=False, timeout=10)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise CanonError("repository state unavailable: " + str(exc)) from exc
        if result.returncode or not result.stdout.strip():
            raise CanonError("repository state unavailable: git " + " ".join(args))
        return result.stdout.rstrip("\n")

    worktree = command("rev-parse", "--show-toplevel")
    head = command("rev-parse", "HEAD")
    branch = command("branch", "--show-current")
    if not Path(worktree).is_absolute() or len(head) != 40 or any(c not in "0123456789abcdef" for c in head):
        raise CanonError("repository state unavailable: malformed worktree or HEAD")
    # An empty status is valid; unlike the other commands, it is not an error.
    try:
        result = subprocess.run(("git", "status", "--short"), cwd=root, text=True,
                                capture_output=True, check=False, timeout=10)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise CanonError("repository state unavailable: " + str(exc)) from exc
    if result.returncode:
        raise CanonError("repository state unavailable: git status --short")
    return {"worktree": worktree, "branch": branch, "head": head,
            "dirty": bool(result.stdout), "status_short": result.stdout.splitlines()}


def source_paths(pack: dict, required_records: list[dict] = ()) -> list[str]:
    paths = {source["path"] for record in [*pack["records"], *required_records]
             for source in record["sources"] if "path" in source}
    paths.update(path for item in pack["conflicts"] for path in item.get("sources", []))
    return sorted(paths)


def build_preflight(store: CanonStore, task: str, repository: dict, *, required: tuple[str, ...] = (),
                    timestamp: str | None = None, semantic: bool = False,
                    semantic_threshold: float = DEFAULT_THRESHOLD,
                    semantic_required: bool = False) -> tuple[dict, dict]:
    pack = (hybrid_pack(store, consumer="codex", task=task, threshold=semantic_threshold,
                        require_semantic=semantic_required) if semantic else
            build_pack(store, consumer="codex", task=task))
    required_ids = sorted(set(required))
    required_records = []
    for identifier in required_ids:
        matches = store.get_id(identifier, scopes=PROFILES["codex"]["scopes"], as_of=pack["as_of"])
        if not matches:
            raise CanonError("required Canon record unavailable: " + identifier)
        required_records.append(matches[0]["record"])
    conflicts = [item for item in pack["conflicts"] if item["result"] == "conflict"]
    ambiguities = [item for item in pack["conflicts"] if item["result"] == "ambiguity"]
    sources = source_paths(pack, required_records)
    record_ids = [record["id"] for record in pack["records"]]
    core = {"adapter_version": VERSION, "task": task, "manifest_sha256": store.manifest_sha256,
            "query_fingerprint": pack["query_fingerprint"], "record_ids": record_ids,
            "required_record_ids": required_ids, "sources_to_inspect": sources,
            "conflicts": conflicts, "ambiguities": ambiguities}
    # Historical precedents are developer context, never authoritative Canon pack records.
    precedents = None
    if (store.root / "Tools/FailureLedger/ledger.py").is_file() or (store.root / "FailureLedger").exists():
        tools_path = str(Path(__file__).resolve().parents[1])
        if tools_path not in sys.path:
            sys.path.insert(0, tools_path)
        try:
            from FailureLedger.ledger import Ledger
            precedents = Ledger(store.root).retrieve(task)
        except (ImportError, OSError, ValueError, KeyError, TypeError) as exc:
            raise CanonError("Failure Ledger unavailable or invalid: " + str(exc)) from exc
        core["failure_precedents"] = precedents
    fingerprint = hashlib.sha256(canonical_bytes(core)).hexdigest()
    notices = []
    if repository["dirty"]:
        notices.append({"severity": "INFO", "code": "dirty_worktree", "message": "Worktree has uncommitted changes."})
    for item in pack["conflicts"]:
        notices.append({"severity": "WARNING", "code": item["result"],
                        "message": item["truth_key"] + ": " + item["description"]})
    if semantic and pack["semantic_status"] != "ready":
        notices.append({"severity": "WARNING", "code": "semantic_unavailable",
                        "message": pack["semantic_warning"]})
    artifact = {"schema_version": VERSION, "adapter": ADAPTER,
                "timestamp": timestamp or dt.datetime.now(dt.timezone.utc).isoformat(),
                "task": task, "task_categories": classify_task(task), "repository": repository,
                "canon": {"record_count": len(store.ids), "manifest_sha256": store.manifest_sha256,
                          "query_fingerprint": pack["query_fingerprint"], "validation": "pass"},
                "pack": {"consumer": "codex", "record_ids": record_ids,
                         "required_record_ids": required_ids},
                "conflicts": conflicts, "ambiguities": ambiguities,
                "sources_to_inspect": sources, "preflight_fingerprint": fingerprint,
                "notices": notices, "result": "pass"}
    if precedents is not None:
        artifact["failure_precedents"] = precedents
        for record in precedents["unresolved_warnings"]:
            notices.append({"severity": "WARNING", "code": "failure_precedent_unresolved",
                            "message": record["id"] + ": " + record["title"] + " (" + record["status"] + ")"})
    if semantic:
        artifact["retrieval_mode"] = "hybrid"
        artifact["semantic_status"] = pack["semantic_status"]
        artifact["semantic_provider"] = pack["semantic_provider"]
        artifact["semantic_index_sha256"] = pack["semantic_index_sha256"]
    return artifact, pack


def blocked_artifact(task: str, repository: dict | None, error: str, *, timestamp: str | None = None) -> dict:
    return {"schema_version": VERSION, "adapter": ADAPTER,
            "timestamp": timestamp or dt.datetime.now(dt.timezone.utc).isoformat(),
            "task": task, "repository": repository,
            "canon": {"validation": "fail"}, "pack": None, "conflicts": [], "ambiguities": [],
            "sources_to_inspect": [], "preflight_fingerprint": None,
            "notices": [{"severity": "BLOCKING", "code": "preflight_failed", "message": error}],
            "result": "blocked"}


def write_evidence(root: Path, artifact: dict, pack: dict) -> Path:
    if artifact["result"] != "pass":
        raise CanonError("blocked preflight cannot write trusted evidence")
    base = root / ".solo-loop/evidence/canon-preflight"
    stamp = dt.datetime.fromisoformat(artifact["timestamp"]).strftime("%Y%m%dT%H%M%S%fZ")
    prefix = stamp + "-" + artifact["preflight_fingerprint"][:12]
    for index in range(1000):
        directory = base / (prefix if index == 0 else f"{prefix}-{index}")
        try:
            directory.mkdir(parents=True, exist_ok=False)
            break
        except FileExistsError:
            continue
    else:
        raise CanonError("could not allocate a unique evidence directory")
    (directory / "codex-preflight.json").write_bytes(canonical_bytes(artifact))
    (directory / "canon-pack.json").write_bytes(canonical_bytes(pack))
    (directory / "canon-pack.md").write_bytes(markdown(pack))
    return directory


def render_text(artifact: dict) -> str:
    lines = ["CODEX CANON PREFLIGHT", "", "Task:", artifact["task"], "",
             "Canon:", "PASS" if artifact["result"] == "pass" else "BLOCKING", ""]
    if artifact["result"] == "pass":
        lines.extend(("Applicable Canon:", *("- " + item for item in artifact["pack"]["record_ids"]), "",
                      "Required source inspection:", *("- " + item for item in artifact["sources_to_inspect"]), ""))
    if "failure_precedents" in artifact:
        precedents = artifact["failure_precedents"]
        lines.extend(("Historical failure precedents (developer-only; not Canon authority):",
                      *("- " + r["id"] + " — " + r["title"] + " [" + r["status"] + "]" for r in precedents["incidents"]), "",
                      "Accepted development prevention rules:",
                      *("- " + r["id"] + ": " + r["shortProhibition"] for r in precedents["accepted_rules"]), "",
                      "Required precedent gates:", *("- " + gate for gate in precedents["required_gates"]), "",
                      "Previously failed fixes:",
                      *("- " + f["failureId"] + ": " + f["approach"] + "; " + f["observedOutcome"] + "; evidence " + ", ".join(f["evidenceReferences"]) for f in precedents["failed_fixes"]), "",
                      "Candidate lessons (not accepted rules):",
                      *("- " + r["id"] + " — " + r["title"] for r in precedents["candidate_lessons"]), ""))
    if artifact["notices"]:
        lines.extend(("Notices:", *(f"- {item['severity']} {item['message']}" for item in artifact["notices"]), ""))
    if artifact["result"] == "pass":
        lines.extend(("Before editing:", "1. Inspect the listed production sources.",
                      "2. Preserve hidden-truth boundaries and simulation ownership.",
                      "3. Inspect any ambiguity before changing its authority.", ""))
    return "\n".join(lines).rstrip() + "\n"


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    task = result.add_mutually_exclusive_group(required=True)
    task.add_argument("--task")
    task.add_argument("--task-file", type=Path)
    result.add_argument("--format", choices=("text", "json"), default="text")
    result.add_argument("--require", action="append", default=[])
    result.add_argument("--write-evidence", action="store_true")
    result.add_argument("--semantic", action="store_true")
    result.add_argument("--semantic-threshold", type=float, default=DEFAULT_THRESHOLD)
    result.add_argument("--semantic-required", action="store_true")
    return result


def run(argv=None, *, root: Path = ROOT) -> int:
    args = parser().parse_args(argv)
    try:
        task = args.task if args.task is not None else args.task_file.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError) as exc:
        task = ""
        error = "task file unavailable: " + str(exc)
    else:
        error = None
    repository = None
    pack = None
    try:
        if error:
            raise CanonError(error)
        repository = git_state(root)
        if Path(repository["worktree"]).resolve() != root.resolve():
            raise CanonError("repository root does not match Canon root")
        artifact, pack = build_preflight(CanonStore(root), task, repository, required=tuple(args.require),
                                        semantic=args.semantic, semantic_threshold=args.semantic_threshold,
                                        semantic_required=args.semantic_required)
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
