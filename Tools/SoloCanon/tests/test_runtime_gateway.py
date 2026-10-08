"""C8 gateway authorization, integrity, and deterministic output proofs."""

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

from canon_store import CanonError, ROOT, canonical_bytes
from runtime_gateway import CANON_IDS, CONSUMERS, VISIBILITY, build_context, validate_state
from runtime_projection import validate_projection

FIXTURE = Path(__file__).parent / "fixtures/runtime-state-before-review.json"
PROJECTION = ROOT / ".solo-loop/cache/runtime-canon/projection.json"
MANIFEST = ROOT / "Canon/manifests/canon-manifest.json"


class RuntimeGatewayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.projection = json.loads(PROJECTION.read_text())
        cls.state = json.loads(FIXTURE.read_text())
        cls.manifest_hash = hashlib.sha256(MANIFEST.read_bytes()).hexdigest()

    def context(self, consumer="founder", state=None, projection=None, **kwargs):
        return build_context(projection or self.projection, state or self.state, consumer,
                             expected_manifest_sha256=self.manifest_hash, **kwargs)

    def item_ids(self, consumer, state=None):
        return {item["id"] for item in self.context(consumer, state)["state"]}

    def test_valid_projection(self):
        self.assertIsNone(validate_projection(self.projection))

    def test_invalid_projection_blocks(self):
        projection = copy.deepcopy(self.projection)
        projection["records"][0]["summary"] = "tampered"
        with self.assertRaises(CanonError):
            self.context(projection=projection)

    def test_stale_manifest_blocks(self):
        with self.assertRaises(CanonError):
            build_context(self.projection, self.state, "founder", expected_manifest_sha256="0" * 64)

    def test_valid_state(self):
        self.assertEqual(len(validate_state(self.state)["knowledge"]), 12)

    def test_invalid_state_envelope_blocks(self):
        state = copy.deepcopy(self.state)
        state["raw_game_store"] = {}
        with self.assertRaises(CanonError):
            self.context(state=state)

    def test_unknown_consumer_blocks(self):
        with self.assertRaises(CanonError):
            self.context("unknown")

    def test_aurora_self_assignment(self):
        self.assertIn("runtime.assignment.aurora_research", self.item_ids("aurora"))

    def test_aurora_no_stacks_drift(self):
        self.assertNotIn("runtime.fact.stacks_drift", self.item_ids("aurora"))

    def test_stacks_no_aurora_assignment(self):
        self.assertNotIn("runtime.assignment.aurora_research", self.item_ids("stacks"))

    def test_brio_public_coverage(self):
        self.assertIn("runtime.metric.coverage", self.item_ids("brio"))

    def test_brio_campaign(self):
        self.assertIn("runtime.event.campaign_result", self.item_ids("brio"))

    def test_brio_no_stacks_defect(self):
        self.assertNotIn("runtime.fact.stacks_defect", self.item_ids("brio"))

    def test_founder_before_review(self):
        self.assertNotIn("runtime.fact.stacks_defect", self.item_ids("founder"))

    def test_founder_after_review(self):
        state = copy.deepcopy(self.state)
        next(item for item in state["knowledge"] if item["id"] == "runtime.fact.stacks_defect")["visibility"].append("founder")
        self.assertIn("runtime.fact.stacks_defect", self.item_ids("founder", state))
        self.assertEqual(self.projection["projection_sha256"], self.context("founder", state)["projection_sha256"])

    def test_signal_public_launch(self):
        self.assertIn("runtime.event.launch_failure", self.item_ids("signal_tv"))

    def test_signal_no_founder_cause(self):
        self.assertNotIn("runtime.fact.founder_cause", self.item_ids("signal_tv"))

    def test_rival_public_launch(self):
        self.assertIn("runtime.event.launch_failure", self.item_ids("rival"))

    def test_rival_no_private_runway(self):
        self.assertNotIn("runtime.metric.private_runway", self.item_ids("rival"))

    def test_media_not_founder(self):
        self.assertNotIn("runtime.event.media_tip", self.item_ids("founder"))

    def test_founder_not_media(self):
        self.assertNotIn("runtime.fact.founder_cause", self.item_ids("tech_com"))

    def test_self_not_shared(self):
        self.assertNotIn("runtime.assignment.aurora_research", self.item_ids("brio"))

    def test_internal_never_delivered(self):
        for consumer in CONSUMERS:
            with self.subTest(consumer=consumer):
                self.assertNotIn("runtime.fact.internal_seed", self.item_ids(consumer))

    def test_normal_output_omits_withheld_ids(self):
        result = self.context("signal_tv")
        output = canonical_bytes(result).decode()
        self.assertNotIn("runtime.fact.stacks_defect", output)
        self.assertNotIn("runtime.fact.internal_seed", output)
        self.assertNotIn('"audit"', output)

    def test_audit_exposes_exclusions(self):
        result = self.context("signal_tv", audit=True)
        self.assertIn("runtime.fact.stacks_defect", {item["id"] for item in result["audit"]["excluded_state"]})

    def test_duplicate_ids_block(self):
        state = copy.deepcopy(self.state)
        state["knowledge"].append(copy.deepcopy(state["knowledge"][0]))
        with self.assertRaises(CanonError):
            self.context(state=state)

    def test_unknown_visibility_blocks(self):
        state = copy.deepcopy(self.state)
        state["knowledge"][0]["visibility"] = ["developer"]
        with self.assertRaises(CanonError):
            self.context(state=state)

    def test_internal_mixed_label_blocks(self):
        state = copy.deepcopy(self.state)
        state["knowledge"][-1]["visibility"] = ["simulation_internal", "public"]
        with self.assertRaises(CanonError):
            self.context(state=state)

    def test_projection_hash(self):
        self.assertEqual(self.context()["projection_sha256"], self.projection["projection_sha256"])

    def test_state_hash(self):
        self.assertEqual(self.context()["state_sha256"], hashlib.sha256(canonical_bytes(validate_state(self.state))).hexdigest())

    def test_same_fingerprint(self):
        self.assertEqual(self.context()["context_fingerprint"], self.context()["context_fingerprint"])

    def test_reordered_state_same_fingerprint(self):
        state = copy.deepcopy(self.state)
        state["knowledge"].reverse()
        self.assertEqual(self.context()["context_fingerprint"], self.context(state=state)["context_fingerprint"])

    def test_changed_state_changes_fingerprint(self):
        state = copy.deepcopy(self.state)
        state["knowledge"][0]["summary"] += " Today."
        self.assertNotEqual(self.context()["context_fingerprint"], self.context(state=state)["context_fingerprint"])

    def test_changed_consumer_changes_fingerprint(self):
        self.assertNotEqual(self.context("founder")["context_fingerprint"], self.context("brio")["context_fingerprint"])

    def test_as_of_mismatch_blocks(self):
        with self.assertRaises(CanonError):
            self.context(as_of="2026-10-04")

    def test_relationship_policy_blocks(self):
        projection = copy.deepcopy(self.projection)
        record = next(item for item in projection["records"] if item["id"] == "agent.aurora")
        record["relationships"] = [{"predicate": "related_to", "target": "agent.stacks"}]
        core = {key: value for key, value in projection.items() if key != "projection_sha256"}
        projection["projection_sha256"] = hashlib.sha256(canonical_bytes(core)).hexdigest()
        # A signed projection whose included record references excluded static truth must fail.
        with self.assertRaises(CanonError):
            self.context("aurora", projection=projection)

    def test_no_full_canon_or_semantic_index_needed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "projection.json").write_bytes(canonical_bytes(self.projection))
            (root / "state.json").write_bytes(canonical_bytes(self.state))
            completed = subprocess.run([sys.executable, "-B", str(TOOLS / "runtime_gateway.py"),
                                        "--consumer", "brio", "--state-fixture", str(root / "state.json"),
                                        "--projection", str(root / "projection.json"),
                                        "--expected-manifest-sha256", self.manifest_hash,
                                        "--format", "json"], cwd=root, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(json.loads(completed.stdout)["consumer"], "brio")

    def test_projection_record_count_unchanged(self):
        self.assertEqual(self.projection["record_count"], 7)

    def test_projection_golden_hash_matches_corrected_director_manifest(self):
        # The developer-only Director correction changes the manifest binding,
        # while the runtime-safe record set and disclosure policy stay fixed.
        self.assertEqual(self.projection["projection_sha256"], "dae7056b0c3cc5b2c4e02854478f81216169b785477f5096a45eb6b3f19fabc2")


# Each generated method is a separate test case in unittest discovery, making the
# authorization matrix visible in test counts and failure names.
for label, permitted in VISIBILITY.items():
    for consumer in CONSUMERS:
        def check(self, label=label, consumer=consumer, permitted=permitted):
            state = {"schema_version": "0.1", "state_version": 1,
                     "knowledge": [{"id": "runtime.fact.matrix", "kind": "fact", "summary": "Matrix fact.",
                                    "visibility": [label]}]}
            present = "runtime.fact.matrix" in self.item_ids(consumer, state)
            self.assertEqual(present, consumer in permitted)
        setattr(RuntimeGatewayTests, f"test_matrix_{label}_{consumer}", check)


if __name__ == "__main__":
    unittest.main()
