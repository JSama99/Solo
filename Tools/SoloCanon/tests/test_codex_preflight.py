import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

TOOL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_DIR))

from canon_pack import build_pack
from canon_store import CanonError, CanonStore, ROOT, canonical_bytes
from codex_preflight import (build_preflight, classify_task, git_state, render_text,
                             source_paths, write_evidence)

TASK = "Implement Signal TV media narrative integration"
REPOSITORY = {"worktree": str(ROOT), "branch": "codex/test", "head": "a" * 40,
              "dirty": False, "status_short": []}


class PreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.store = CanonStore(ROOT)

    def preflight(self, **kwargs):
        return build_preflight(self.store, TASK, REPOSITORY, timestamp="2026-10-03T12:00:00+00:00", **kwargs)

    def test_valid_preflight_succeeds(self):
        artifact, pack = self.preflight()
        self.assertEqual(artifact["result"], "pass")
        self.assertEqual(pack["consumer"], "codex")

    def test_invalid_canon_blocks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            shutil.copytree(ROOT / "Canon", root / "Canon")
            path = next((root / "Canon/records").rglob("*.json"))
            path.write_text("{bad json")
            with self.assertRaises(CanonError):
                CanonStore(root)

    def test_stale_manifest_blocks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            shutil.copytree(ROOT / "Canon", root / "Canon")
            path = next((root / "Canon/records").rglob("*.json"))
            item = json.loads(path.read_text())
            item["summary"] += " changed"
            path.write_text(json.dumps(item))
            with self.assertRaisesRegex(CanonError, "manifest"):
                CanonStore(root)

    def test_dirty_worktree_is_info(self):
        repository = dict(REPOSITORY, dirty=True, status_short=[" M AGENTS.md"])
        artifact, _ = build_preflight(self.store, TASK, repository)
        self.assertEqual(artifact["result"], "pass")
        self.assertEqual(artifact["notices"][0]["severity"], "INFO")

    def test_branch_and_head_captured(self):
        artifact, _ = self.preflight()
        self.assertEqual(artifact["repository"]["branch"], "codex/test")
        self.assertEqual(artifact["repository"]["head"], "a" * 40)

    def test_selected_ids_are_deterministic(self):
        first, _ = self.preflight()
        second, _ = self.preflight()
        self.assertEqual(first["pack"]["record_ids"], second["pack"]["record_ids"])
        self.assertIn("system.signal_tv", first["pack"]["record_ids"])

    def test_source_paths_are_sorted(self):
        artifact, _ = self.preflight()
        self.assertEqual(artifact["sources_to_inspect"], sorted(artifact["sources_to_inspect"]))
        self.assertIn("App/SignalTVModels.swift", artifact["sources_to_inspect"])

    def test_duplicate_source_paths_are_removed(self):
        _, pack = self.preflight()
        paths = source_paths(pack)
        self.assertEqual(len(paths), len(set(paths)))

    def test_signal_tv_ambiguity_is_visible(self):
        artifact, _ = self.preflight()
        self.assertEqual(artifact["ambiguities"][0]["truth_key"], "mechanic.coverage.mutation_authority")

    def test_ambiguity_warns_without_blocking(self):
        artifact, _ = self.preflight()
        self.assertEqual(artifact["result"], "pass")
        self.assertIn("WARNING", [notice["severity"] for notice in artifact["notices"]])

    def test_required_valid_record_succeeds(self):
        artifact, _ = self.preflight(required=("system.signal_tv",))
        self.assertEqual(artifact["pack"]["required_record_ids"], ["system.signal_tv"])

    def test_missing_required_record_blocks(self):
        with self.assertRaisesRegex(CanonError, "required Canon record unavailable"):
            self.preflight(required=("system.missing",))

    def test_visibility_unavailable_required_record_blocks(self):
        with patch.dict(self.store.records["system.signal_tv"], {"visibility": ["public"]}):
            with self.assertRaisesRegex(CanonError, "required Canon record unavailable"):
                self.preflight(required=("system.signal_tv",))

    def test_temporally_inactive_required_record_blocks(self):
        with patch.dict(self.store.records["system.signal_tv"]["validity"], {"valid_from": "2099-01-01"}):
            with self.assertRaisesRegex(CanonError, "required Canon record unavailable"):
                self.preflight(required=("system.signal_tv",))

    def test_identical_core_hashes_identically(self):
        first, _ = self.preflight()
        second, _ = self.preflight()
        self.assertEqual(first["preflight_fingerprint"], second["preflight_fingerprint"])

    def test_timestamp_is_excluded_from_fingerprint(self):
        first, _ = self.preflight()
        second, _ = build_preflight(self.store, TASK, REPOSITORY, timestamp="2026-10-04T12:00:00+00:00")
        self.assertEqual(first["preflight_fingerprint"], second["preflight_fingerprint"])

    def test_git_state_is_excluded_from_fingerprint(self):
        first, _ = self.preflight()
        second, _ = build_preflight(self.store, TASK, dict(REPOSITORY, branch="other", head="b" * 40))
        self.assertEqual(first["preflight_fingerprint"], second["preflight_fingerprint"])

    def test_pack_matches_direct_c1(self):
        _, pack = self.preflight()
        self.assertEqual(canonical_bytes(pack), canonical_bytes(build_pack(self.store, consumer="codex", task=TASK)))

    def test_json_schema_result_is_stable(self):
        artifact, _ = self.preflight()
        decoded = json.loads(canonical_bytes(artifact))
        self.assertEqual((decoded["schema_version"], decoded["adapter"], decoded["result"]),
                         ("0.1", "solo-canon-codex-preflight", "pass"))

    def test_write_mode_creates_three_artifacts(self):
        artifact, pack = self.preflight()
        with tempfile.TemporaryDirectory() as temp:
            directory = write_evidence(Path(temp), artifact, pack)
            self.assertEqual({path.name for path in directory.iterdir()},
                             {"codex-preflight.json", "canon-pack.json", "canon-pack.md"})
            self.assertEqual((directory / "canon-pack.json").read_bytes(), canonical_bytes(pack))

    def test_default_build_creates_no_repository_files(self):
        evidence_root = ROOT / ".solo-loop/evidence/canon-preflight"
        before = set(evidence_root.iterdir()) if evidence_root.exists() else set()
        result = subprocess.run([sys.executable, str(TOOL_DIR / "codex_preflight.py"),
                                 "--task", TASK, "--format", "json"], cwd=ROOT,
                                text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["result"], "pass")
        self.assertEqual(set(evidence_root.iterdir()) if evidence_root.exists() else set(), before)
        self.assertEqual(list(TOOL_DIR.rglob("*.pyc")), [])

    def test_cli_required_missing_returns_blocking_json(self):
        result = subprocess.run([sys.executable, str(TOOL_DIR / "codex_preflight.py"),
                                 "--task", TASK, "--require", "system.missing", "--format", "json"],
                                cwd=ROOT, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 2)
        artifact = json.loads(result.stdout)
        self.assertEqual(artifact["result"], "blocked")
        self.assertIsNone(artifact["pack"])

    def test_task_file_cli(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "task.txt"
            path.write_text(TASK, encoding="utf-8")
            result = subprocess.run([sys.executable, str(TOOL_DIR / "codex_preflight.py"),
                                     "--task-file", str(path), "--format", "json"],
                                    cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["task"], TASK)

    def test_blocked_write_does_not_create_evidence(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaises(CanonError):
                write_evidence(root, {"result": "blocked"}, {})
            self.assertFalse((root / ".solo-loop").exists())

    def test_malformed_git_state_fails_safely(self):
        result = subprocess.CompletedProcess([], 1, "", "not a repository")
        with patch("codex_preflight.subprocess.run", return_value=result):
            with self.assertRaisesRegex(CanonError, "repository state unavailable"):
                git_state(ROOT)

    def test_classifier_is_deterministic_and_cli_explicit(self):
        self.assertEqual(classify_task(TASK), ["narrative", "media"])
        self.assertEqual(classify_task("Fix formatting"), [])

    def test_text_has_inspection_and_warning(self):
        artifact, _ = self.preflight()
        output = render_text(artifact)
        self.assertIn("Required source inspection:", output)
        self.assertIn("WARNING mechanic.coverage.mutation_authority", output)

    def test_pack_and_fingerprint_are_hex_sha256(self):
        artifact, pack = self.preflight()
        self.assertEqual(len(artifact["preflight_fingerprint"]), 64)
        self.assertEqual(len(hashlib.sha256(canonical_bytes(pack)).hexdigest()), 64)
