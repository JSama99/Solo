"""C5 Chaos preflight governance and deterministic handoff tests."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

from canon_store import CanonError, CanonStore, ROOT, canonical_bytes
from chaos_preflight import build_chaos_preflight, categories, seed_contract, write_evidence
from codex_preflight import build_preflight as build_codex
from visual_preflight import build_visual_preflight
from narrative_preflight import build_narrative_preflight

MOMENTUM = "Search for a deterministic strategy that increases Momentum without proportional cost."
RUNWAY = "Stress test whether companies can survive indefinitely with zero revenue."
COVERAGE = "Find every deterministic strategy that can increase or decrease Coverage."
REWRITE = "Run 10,000 companies and automatically update mechanic.trust to the best-performing formula."
REPOSITORY = {"worktree": str(ROOT), "branch": "test", "head": "a" * 40,
              "dirty": False, "status_short": []}


class ChaosPreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.store = CanonStore(ROOT)

    def build(self, task=MOMENTUM, seed="8349232", required=()):
        return build_chaos_preflight(self.store, task, REPOSITORY, seed=seed,
                                     required=required, timestamp="2026-10-03T00:00:00+00:00")

    def test_valid_preflight(self):
        self.assertEqual(self.build()[0]["result"], "pass")

    def test_read_only_default(self):
        self.assertFalse(self.build()[0]["experiment_specification"]["production_mutation"])

    def test_evidence_write_mode(self):
        with tempfile.TemporaryDirectory() as temp:
            artifact, pack = self.build()
            path = write_evidence(Path(temp), artifact, pack)
            self.assertEqual(json.loads((path / "chaos-pack.json").read_bytes()), pack)
            self.assertEqual(json.loads((path / "chaos-preflight.json").read_bytes()), artifact)

    def test_evidence_distinct_directories(self):
        with tempfile.TemporaryDirectory() as temp:
            artifact, pack = self.build()
            self.assertNotEqual(write_evidence(Path(temp), artifact, pack),
                                write_evidence(Path(temp), artifact, pack))

    def test_category_deterministic(self):
        self.assertEqual(categories(MOMENTUM), categories(MOMENTUM))

    def test_all_categories_classifiable(self):
        cases = {"balance":"balance", "exploit":"exploit", "finance":"economy",
                 "agent drift":"agent_behavior", "venture":"progression",
                 "rival":"rival_behavior", "momentum":"resource_loop",
                 "save":"save_invariant", "seed":"determinism"}
        for task, category in cases.items():
            with self.subTest(task=task):
                self.assertIn(category, categories(task))

    def test_internal_visibility(self):
        self.assertIn("simulation_internal", self.build()[0]["experiment_specification"]["visibility"])

    def test_unrelated_restricted_material_excluded(self):
        ids = self.build()[1]["selected_record_ids"]
        self.assertNotIn("asset.founder.production", ids)
        self.assertNotIn("system.narrative_director", ids)

    def test_explicit_seed_preserved(self):
        self.assertEqual(self.build()[0]["experiment_specification"]["seed_contract"]["seed"], 8349232)

    def test_missing_seed_blocks(self):
        with self.assertRaises(CanonError):
            self.build(seed=None)

    def test_malformed_seed_blocks(self):
        for seed in ("-1", "+1", "1.5", "0x12", "01", str(2**64)):
            with self.subTest(seed=seed), self.assertRaises(CanonError):
                seed_contract(seed)

    def test_uint64_max_accepted(self):
        self.assertEqual(seed_contract(str(2**64-1))["seed"], 2**64-1)

    def test_same_seed_fingerprint(self):
        self.assertEqual(self.build()[0]["chaos_preflight_fingerprint"],
                         self.build()[0]["chaos_preflight_fingerprint"])

    def test_different_seed_fingerprint(self):
        self.assertNotEqual(self.build(seed="1")[0]["chaos_preflight_fingerprint"],
                            self.build(seed="2")[0]["chaos_preflight_fingerprint"])

    def test_experiment_fingerprint_reproducible(self):
        self.assertEqual(self.build()[0]["experiment_fingerprint"], self.build()[1]["experiment_fingerprint"])

    def test_experiment_fingerprint_changes_with_seed(self):
        self.assertNotEqual(self.build(seed="1")[0]["experiment_fingerprint"],
                            self.build(seed="2")[0]["experiment_fingerprint"])

    def test_pack_bytes_deterministic(self):
        self.assertEqual(canonical_bytes(self.build()[1]), canonical_bytes(self.build()[1]))

    def test_p1_mechanic_precedes_p2_chaos(self):
        ids = self.build()[1]["selected_record_ids"]
        self.assertLess(ids.index("mechanic.momentum"), ids.index("system.chaos_crew"))

    def test_observation_cannot_self_promote(self):
        template = self.build()[1]["observation_template"]
        self.assertEqual(template["canon_promotion"], "not_authorized")
        self.assertEqual(template["chaos_max_state"], "proposed")

    def test_proposed_still_noncanonical(self):
        template = self.build()[1]["observation_template"]
        self.assertEqual(template["authority"], "non_canonical")
        self.assertIn("proposed", template["allowed_states"])

    def test_no_fake_observation(self):
        template = self.build()[1]["observation_template"]
        self.assertEqual(template["initial_status"], "not_run")
        self.assertIsNone(template["finding"])

    def test_missing_authority_blocks(self):
        store = CanonStore(ROOT)
        store.records["system.simulation"]["authority"]["level"] = "P2"
        with self.assertRaises(CanonError):
            build_chaos_preflight(store, MOMENTUM, REPOSITORY, seed="1")

    def test_required_unavailable_blocks(self):
        with self.assertRaises(CanonError):
            self.build(required=("asset.founder.production",))

    def test_invariant_list_deterministic(self):
        invariants = self.build(COVERAGE)[0]["invariants"]
        self.assertEqual([item["id"] for item in invariants], sorted(item["id"] for item in invariants))

    def test_source_paths_deterministic(self):
        paths = self.build()[0]["source_inspection"]
        self.assertEqual(paths, sorted(set(paths)))

    def test_coverage_ambiguity_warning(self):
        notices = self.build("Stress test Coverage changes.")[0]["notices"]
        self.assertTrue(any(item["severity"] == "WARNING" and item["code"] == "coverage_mutation_authority"
                            for item in notices))

    def test_coverage_exhaustive_blocks(self):
        artifact, _ = self.build(COVERAGE)
        self.assertEqual(artifact["result"], "blocked")
        self.assertTrue(any(item.get("truth_key") == "mechanic.coverage.mutation_authority"
                            for item in artifact["notices"]))

    def test_momentum_specification_only(self):
        artifact, pack = self.build()
        self.assertIn("mechanic.momentum", pack["selected_record_ids"])
        self.assertIn("system.simulation", pack["selected_record_ids"])
        self.assertEqual(artifact["experiment_specification"]["execution"], "not_run")

    def test_zero_revenue_specification_only(self):
        artifact, _ = self.build(RUNWAY)
        self.assertEqual(artifact["result"], "pass")
        self.assertEqual(artifact["experiment_specification"]["scenario_parameters"]["revenue_constraint"], 0)
        self.assertEqual(artifact["experiment_specification"]["execution"], "not_run")
        self.assertIn("bounded_horizon_required", artifact["experiment_specification"]["scenario_parameters"]["termination"])

    def test_rival_path_determinism_warning(self):
        artifact, _ = self.build("Stress test rival behavior")
        self.assertTrue(any(item.get("code") == "path_determinism_unverified" for item in artifact["notices"]))

    def test_auto_formula_rewrite_blocks(self):
        artifact, _ = self.build(REWRITE)
        self.assertEqual(artifact["result"], "blocked")
        self.assertTrue(any(item.get("code") == "self_promotion" for item in artifact["notices"]))

    def test_live_save_mutation_blocks(self):
        artifact, _ = self.build("Mutate live player saves while testing revenue")
        self.assertEqual(artifact["result"], "blocked")

    def test_malformed_canon_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "Canon/manifests").mkdir(parents=True)
            (root / "Canon/manifests/canon-manifest.json").write_text("{}")
            with self.assertRaises((CanonError, KeyError, ValueError)):
                CanonStore(root)

    def test_codex_adapter_regression(self):
        artifact, _ = build_codex(self.store, "Inspect Momentum", REPOSITORY)
        self.assertEqual(artifact["result"], "pass")

    def test_visual_adapter_regression(self):
        artifact, _ = build_visual_preflight(self.store, "Improve Atlantis lighting", REPOSITORY)
        self.assertEqual(artifact["result"], "pass")

    def test_narrative_adapter_regression(self):
        artifact, _ = build_narrative_preflight(self.store, "Report public Coverage", "signal_tv", REPOSITORY)
        self.assertEqual(artifact["result"], "pass")


if __name__ == "__main__":
    unittest.main()
