import copy
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

from canon_store import CanonError, CanonStore, PROFILES, ROOT, canonical_bytes
from visual_preflight import build_visual_preflight, categories, topics, visual_conflicts, write_evidence, render_text

FOUNDER = "Improve Founder character animation fidelity"
ATLANTIS = "Improve Atlantis Founder District lighting"
MARA = "Redesign Mara from scratch"
REPOSITORY = {"worktree": str(ROOT), "branch": "codex/test", "head": "a" * 40,
              "dirty": False, "status_short": []}


class VisualPreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.store = CanonStore(ROOT)

    def preflight(self, task=FOUNDER, **kwargs):
        return build_visual_preflight(self.store, task, REPOSITORY,
                                      timestamp="2026-10-03T12:00:00+00:00", **kwargs)

    def test_valid_visual_preflight(self):
        artifact, pack = self.preflight()
        self.assertEqual(artifact["result"], "pass")
        self.assertEqual(pack["consumer"], "visual")

    def test_default_cli_is_read_only(self):
        evidence_root = ROOT / ".solo-loop/evidence/canon-preflight"
        before = set(evidence_root.iterdir()) if evidence_root.exists() else set()
        result = subprocess.run([sys.executable, str(TOOL_DIR / "visual_preflight.py"),
                                 "--task", FOUNDER, "--format", "json"], cwd=ROOT,
                                text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["result"], "pass")
        self.assertEqual(set(evidence_root.iterdir()) if evidence_root.exists() else set(), before)
        self.assertEqual(list(TOOL_DIR.rglob("*.pyc")), [])

    def test_evidence_write_mode(self):
        artifact, pack = self.preflight()
        with tempfile.TemporaryDirectory() as temp:
            directory = write_evidence(Path(temp), artifact, pack)
            self.assertEqual({path.name for path in directory.iterdir()},
                             {"visual-preflight.json", "visual-pack.json"})
            self.assertEqual((directory / "visual-pack.json").read_bytes(), canonical_bytes(pack))

    def test_category_detection(self):
        self.assertEqual(categories(FOUNDER), ["character", "animation"])
        self.assertEqual(categories(ATLANTIS), ["environment", "lighting"])
        self.assertEqual(categories("Garage camera materials"), ["environment", "camera", "materials", "interior"])

    def test_founder_district_is_place_not_character(self):
        self.assertEqual(topics(ATLANTIS), ["atlantis"])

    def test_founder_visual_canon(self):
        _, pack = self.preflight()
        self.assertIn("character.founder", pack["record_ids"])
        self.assertIn("asset.founder.production", pack["record_ids"])
        self.assertNotIn("location.atlantis", pack["record_ids"])

    def test_atlantis_visual_canon(self):
        _, pack = self.preflight(ATLANTIS)
        self.assertIn("location.atlantis", pack["record_ids"])
        self.assertNotIn("asset.founder.production", pack["record_ids"])

    def test_garage_visual_canon(self):
        _, pack = self.preflight("Improve Founder Garage lighting")
        self.assertIn("location.founder_garage", pack["record_ids"])
        self.assertNotIn("character.founder", pack["record_ids"])

    def test_visual_profile_does_not_leak_simulation_internal(self):
        self.assertNotIn("simulation_internal", PROFILES["visual"]["scopes"])
        _, pack = self.preflight()
        self.assertTrue(all(set(self.store.records[item["id"]]["visibility"]) &
                            set(PROFILES["visual"]["scopes"]) for item in pack["records"]))

    def test_production_outweighs_accepted_and_blocked(self):
        _, pack = self.preflight()
        self.assertLess(pack["record_ids"].index("asset.founder.production"),
                        pack["record_ids"].index("asset.founder.shoulder_r1"))
        self.assertLess(pack["record_ids"].index("asset.founder.shoulder_r1"),
                        pack["record_ids"].index("experiment.founder.shoulder_rejected"))

    def test_blocked_study_is_not_target(self):
        _, pack = self.preflight()
        self.assertNotIn("experiment.founder.shoulder_rejected", pack["target_record_ids"])
        self.assertEqual(pack["blocked_or_experimental"][0]["label"], "DO NOT USE AS TARGET")

    def test_owner_acceptance_distinct_from_test_pass(self):
        _, pack = self.preflight()
        self.assertEqual(pack["production_assets"][0]["owner_acceptance"],
                         "accepted_candidate_and_promoted_to_normal_route")
        self.assertIn("not owner visual acceptance", render_text(self.preflight()[0]))

    def test_missing_required_asset_blocks(self):
        with self.assertRaisesRegex(CanonError, "required visual Canon record unavailable"):
            self.preflight(required=("asset.founder.missing",))

    def test_invisible_required_record_blocks(self):
        with patch.dict(self.store.records["asset.founder.production"], {"visibility": ["simulation_internal"]}):
            with self.assertRaisesRegex(CanonError, "required visual Canon record unavailable"):
                self.preflight()

    def test_conflicting_p1_identities_detected(self):
        first = {"id": "character.founder", "type": "character", "authority": "P1",
                 "status": "canonical", "facts": {"identity_subject": "founder", "identity_asset_id": "asset.one"}}
        second = dict(first, id="character.founder_alt", facts={"identity_subject": "founder", "identity_asset_id": "asset.two"})
        self.assertIn("conflicting active production visual identities: founder", visual_conflicts([first, second]))

    def test_conflicting_p1_identities_block_adapter(self):
        alternate = copy.deepcopy(self.store.records["character.founder"])
        alternate["id"] = "character.founder_alternate"
        alternate["facts"]["identity_asset_id"] = "asset.founder.alternate"
        with patch.object(self.store, "ids", tuple(sorted((*self.store.ids, alternate["id"])))), \
             patch.dict(self.store.records, {alternate["id"]: alternate}), \
             patch.dict(self.store.edges, {alternate["id"]: ()}):
            artifact, _ = self.preflight()
        self.assertEqual(artifact["result"], "blocked")
        self.assertTrue(any("conflicting active production visual identities" in notice["message"]
                            for notice in artifact["notices"]))

    def test_contradictory_production_asset_detected(self):
        first = {"id": "asset.one", "type": "asset", "authority": "P1", "status": "canonical",
                 "facts": {"identity_subject": "founder", "asset_role": "production_runtime_character", "asset_path": "one.usdz"}}
        second = copy.deepcopy(first)
        second["id"] = "asset.two"
        second["facts"]["asset_path"] = "two.usdz"
        self.assertIn("contradictory production asset identity: founder/production_runtime_character",
                      visual_conflicts([first, second]))

    def test_source_paths_deduplicate_and_sort(self):
        _, pack = self.preflight()
        self.assertEqual(pack["source_inspection"], sorted(set(pack["source_inspection"])))

    def test_atlantis_sources_do_not_dump_founder_character(self):
        _, pack = self.preflight(ATLANTIS)
        self.assertIn("App/RealityKit/Atlantis/founder_district.usdz", pack["source_inspection"])
        self.assertNotIn("App/RealityKit/FounderCharacter/founder_candidate_a.usdz", pack["source_inspection"])

    def test_deterministic_record_order(self):
        _, first = self.preflight()
        _, second = self.preflight()
        self.assertEqual(first["record_ids"], second["record_ids"])

    def test_fingerprint_is_stable(self):
        first, _ = self.preflight()
        second, _ = self.preflight()
        self.assertEqual(first["visual_preflight_fingerprint"], second["visual_preflight_fingerprint"])

    def test_timestamp_does_not_change_fingerprint(self):
        first, _ = self.preflight()
        second, _ = build_visual_preflight(self.store, FOUNDER, REPOSITORY,
                                           timestamp="2026-10-04T12:00:00+00:00")
        self.assertEqual(first["visual_preflight_fingerprint"], second["visual_preflight_fingerprint"])

    def test_git_metadata_does_not_change_fingerprint(self):
        first, _ = self.preflight()
        second, _ = build_visual_preflight(self.store, FOUNDER, dict(REPOSITORY, branch="other", head="b" * 40))
        self.assertEqual(first["visual_preflight_fingerprint"], second["visual_preflight_fingerprint"])

    def test_motion_retrieves_reduce_motion(self):
        _, pack = self.preflight()
        self.assertIn("rule.reduce_motion_visual", pack["record_ids"])
        self.assertIn("rule.reduce_motion_visual", pack["required_record_ids"])

    def test_mara_replacement_blocks(self):
        artifact, pack = self.preflight(MARA)
        self.assertEqual(artifact["result"], "blocked")
        self.assertIn("character.mara", pack["record_ids"])
        self.assertTrue(any(item["code"] == "visual_identity_conflict" for item in artifact["notices"]))

    def test_mara_missing_reference_warns(self):
        artifact, _ = self.preflight(MARA)
        self.assertTrue(any(item["code"] == "reference_unavailable" for item in artifact["notices"]))

    def test_mara_acceptance_has_no_runtime_promotion(self):
        _, pack = self.preflight(MARA)
        mara = next(item for item in pack["accepted_references"] if item["record_id"] == "character.mara")
        self.assertEqual(mara["acceptance_scope"], "Gate 1 shape and wardrobe only")
        self.assertNotIn("character.mara", [item["record_id"] for item in pack["production_assets"]])

    def test_visual_records_do_not_require_generated_loop_files(self):
        visual_ids = ("asset.founder.production", "asset.founder.shoulder_r1",
                      "character.founder", "character.mara", "rule.visual_identity",
                      "rule.reduce_motion_visual", "experiment.founder.shoulder_rejected")
        self.assertFalse(any(source.get("path", "").startswith(".solo-loop/")
                             for identifier in visual_ids
                             for source in self.store.records[identifier]["sources"]))

    def test_malformed_canon_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            shutil.copytree(ROOT / "Canon", root / "Canon")
            (root / "Canon/records/characters/character.mara.json").write_text("{bad")
            with self.assertRaises(CanonError):
                CanonStore(root)

    def test_c2_codex_preflight_still_passes(self):
        result = subprocess.run([sys.executable, str(TOOL_DIR / "codex_preflight.py"),
                                 "--task", "Implement Signal TV media narrative integration", "--format", "json"],
                                cwd=ROOT, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["result"], "pass")

    def test_pack_bytes_are_stable(self):
        _, first = self.preflight()
        _, second = self.preflight()
        self.assertEqual(hashlib.sha256(canonical_bytes(first)).hexdigest(),
                         hashlib.sha256(canonical_bytes(second)).hexdigest())
