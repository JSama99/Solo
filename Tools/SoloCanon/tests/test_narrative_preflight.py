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

from canon_store import CanonError, CanonStore, ROOT, canonical_bytes
from narrative_preflight import (CHANNEL_SCOPES, build_narrative_preflight, categories,
                                 requested_fact_classes, attempts_sensitive_disclosure,
                                 write_evidence, render_text)

SIGNAL = "Create a Signal TV story about a failed product launch where the underlying cause is a hidden agent defect not yet revealed to the Founder."
FOUNDER = "Explain a failed launch to the Founder after canonical review revealed the agent defect."
RIVAL = "Have a rival publicly mock the player's hidden infrastructure weakness."
AGENT = "Have Brio discuss Stacks' hidden drift before Founder review."
REPOSITORY = {"worktree": str(ROOT), "branch": "codex/test", "head": "a" * 40,
              "dirty": False, "status_short": []}


class NarrativePreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.store = CanonStore(ROOT)

    def preflight(self, task=SIGNAL, channel="signal_tv", **kwargs):
        return build_narrative_preflight(self.store, task, channel, REPOSITORY,
                                         timestamp="2026-10-03T12:00:00+00:00", **kwargs)

    def test_valid_preflight(self):
        artifact, pack = self.preflight()
        self.assertEqual(artifact["result"], "pass")
        self.assertEqual(pack["consumer"], "narrative")

    def test_default_cli_is_read_only(self):
        evidence_root = ROOT / ".solo-loop/evidence/canon-preflight"
        before = set(evidence_root.iterdir()) if evidence_root.exists() else set()
        result = subprocess.run([sys.executable, str(TOOL_DIR / "narrative_preflight.py"),
                                 "--task", SIGNAL, "--channel", "signal_tv", "--format", "json"],
                                cwd=ROOT, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["result"], "pass")
        self.assertEqual(set(evidence_root.iterdir()) if evidence_root.exists() else set(), before)
        self.assertEqual(list(TOOL_DIR.rglob("*.pyc")), [])

    def test_evidence_write_mode(self):
        artifact, pack = self.preflight()
        with tempfile.TemporaryDirectory() as temp:
            directory = write_evidence(Path(temp), artifact, pack)
            self.assertEqual({path.name for path in directory.iterdir()},
                             {"narrative-preflight.json", "narrative-pack.json"})
            self.assertEqual((directory / "narrative-pack.json").read_bytes(), canonical_bytes(pack))

    def test_channel_policy_is_explicit(self):
        self.assertEqual(set(CHANNEL_SCOPES), {"director_internal", "founder", "signal_tv", "tech_com",
                                               "venture", "rival", "agent_dialogue"})
        self.assertEqual(CHANNEL_SCOPES["signal_tv"], ("public", "media"))
        self.assertEqual(CHANNEL_SCOPES["rival"], ("rival", "public"))

    def test_categories_are_deterministic(self):
        self.assertEqual(categories(SIGNAL), categories(SIGNAL))
        self.assertIn("media_story", categories(SIGNAL))
        self.assertIn("agent_dialogue", categories(AGENT))

    def test_signal_tv_excludes_internal_truth(self):
        _, pack = self.preflight()
        self.assertIn("rule.hidden_truth", pack["available_to_director"])
        self.assertNotIn("rule.hidden_truth", pack["revealable_to_channel"])

    def test_public_scoped_classes_do_not_describe_hidden_mechanics(self):
        for identifier in ("entity.public_media_event", "entity.tech_com", "entity.rival_public_claim"):
            record = self.store.records[identifier]
            public_text = json.dumps([record["summary"], record["facts"], record["constraints"]]).lower()
            self.assertNotIn("latent defect", public_text)
            self.assertNotIn("hidden player", public_text)
            self.assertNotIn("simulation_internal", public_text)

    def test_founder_unverified_reveal_blocks(self):
        artifact, pack = self.preflight(FOUNDER, "founder")
        self.assertEqual(artifact["result"], "blocked")
        self.assertIn("latent_agent_defect", [item["class"] for item in pack["withheld_facts"]])

    def test_rival_hidden_weakness_blocks(self):
        artifact, pack = self.preflight(RIVAL, "rival")
        self.assertEqual(artifact["result"], "blocked")
        self.assertIn("hidden_infrastructure_weakness", [item["class"] for item in pack["withheld_facts"]])

    def test_agent_dialogue_hidden_drift_blocks(self):
        artifact, pack = self.preflight(AGENT, "agent_dialogue")
        self.assertEqual(artifact["result"], "blocked")
        self.assertIn("agent_drift", [item["class"] for item in pack["withheld_facts"]])

    def test_internal_knowledge_and_disclosure_are_distinct(self):
        _, pack = self.preflight()
        self.assertIn("system.signal_tv", pack["available_to_director"])
        self.assertNotIn("system.signal_tv", pack["revealable_to_channel"])
        self.assertIn("system.signal_tv", [item["id"] for item in pack["withheld"]])

    def test_explicit_hidden_disclosure_blocks(self):
        artifact, _ = self.preflight("Reveal the hidden agent defect on Signal TV", "signal_tv")
        self.assertEqual(artifact["result"], "blocked")
        self.assertTrue(any(item["severity"] == "BLOCKING" for item in artifact["notices"]))

    def test_hidden_context_without_disclosure_passes(self):
        self.assertFalse(attempts_sensitive_disclosure(SIGNAL))
        self.assertEqual(self.preflight()[0]["result"], "pass")

    def test_public_event_class_is_conditionally_revealable(self):
        _, pack = self.preflight()
        self.assertIn("entity.public_media_event", pack["revealable_to_channel"])
        self.assertEqual(pack["revealable_facts"][0]["status"], "conditional")
        self.assertIn("isPublic", pack["revealable_facts"][0]["gate"])

    def test_p1_production_precedes_p2_architecture(self):
        _, pack = self.preflight()
        self.assertLess(pack["selected_record_ids"].index("entity.public_media_event"),
                        pack["selected_record_ids"].index("system.narrative_director"))

    def test_director_architecture_is_not_runtime_p1(self):
        record = self.store.records["system.narrative_director"]
        self.assertEqual(record["authority"]["level"], "P2")
        self.assertEqual(record["facts"]["runtime_state"], "not_implemented")

    def test_worker_handoff_has_no_canon_or_publication_authority(self):
        _, pack = self.preflight()
        handoff = pack["worker_handoff"]
        self.assertFalse(handoff["publication_authority"])
        self.assertFalse(handoff["canon_authority"])
        self.assertIsNone(handoff["narrative_intent"])
        self.assertNotIn("latent_agent_defect", [item["class"] for item in handoff["allowed_fact_classes"]])

    def test_relationship_expansion_respects_channel_visibility(self):
        public = self.store.get_id("entity.public_media_event", scopes=("public",), related_depth=1)
        ids = [item["record"]["id"] for item in public]
        self.assertNotIn("rule.narrative_disclosure", ids)

    def test_historical_record_is_not_current(self):
        with patch.dict(self.store.records["entity.public_media_event"]["validity"], {"valid_until": "2026-10-02"}):
            with self.assertRaisesRegex(CanonError, "required narrative Canon record unavailable"):
                self.preflight()

    def test_coverage_ambiguity_is_warning(self):
        artifact, _ = self.preflight()
        self.assertEqual(artifact["result"], "pass")
        self.assertTrue(any(item.get("truth_key") == "mechanic.coverage.mutation_authority"
                            and item["severity"] == "WARNING" for item in artifact["notices"]))

    def test_malformed_canon_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            shutil.copytree(ROOT / "Canon", root / "Canon")
            (root / "Canon/records/entities/entity.public_media_event.json").write_text("{bad")
            with self.assertRaises(CanonError):
                CanonStore(root)

    def test_fingerprint_is_stable(self):
        first, _ = self.preflight()
        second, _ = self.preflight()
        self.assertEqual(first["narrative_preflight_fingerprint"], second["narrative_preflight_fingerprint"])

    def test_timestamp_does_not_change_fingerprint(self):
        first, _ = self.preflight()
        second, _ = build_narrative_preflight(self.store, SIGNAL, "signal_tv", REPOSITORY,
                                              timestamp="2026-10-04T12:00:00+00:00")
        self.assertEqual(first["narrative_preflight_fingerprint"], second["narrative_preflight_fingerprint"])

    def test_git_metadata_does_not_change_fingerprint(self):
        first, _ = self.preflight()
        second, _ = build_narrative_preflight(self.store, SIGNAL, "signal_tv",
                                              dict(REPOSITORY, branch="other", head="b" * 40))
        self.assertEqual(first["narrative_preflight_fingerprint"], second["narrative_preflight_fingerprint"])

    def test_c2_codex_preflight_still_passes(self):
        result = subprocess.run([sys.executable, str(TOOL_DIR / "codex_preflight.py"),
                                 "--task", "Implement Signal TV media narrative integration", "--format", "json"],
                                cwd=ROOT, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["result"], "pass")

    def test_c3_visual_preflight_still_passes(self):
        result = subprocess.run([sys.executable, str(TOOL_DIR / "visual_preflight.py"),
                                 "--task", "Improve Founder character animation fidelity", "--format", "json"],
                                cwd=ROOT, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["result"], "pass")

    def test_missing_required_record_blocks(self):
        with self.assertRaisesRegex(CanonError, "required narrative Canon record unavailable"):
            self.preflight(required=("entity.missing",))

    def test_pack_bytes_are_stable(self):
        _, first = self.preflight()
        _, second = self.preflight()
        self.assertEqual(hashlib.sha256(canonical_bytes(first)).hexdigest(),
                         hashlib.sha256(canonical_bytes(second)).hexdigest())

    def test_text_explains_director_boundary(self):
        self.assertIn("Only the Director", render_text(self.preflight()[0]))

    def test_sensitive_fact_classification(self):
        self.assertEqual(requested_fact_classes(AGENT), ["agent_drift"])

    def test_blocked_disclosure_evidence_is_reviewable(self):
        artifact, pack = self.preflight(RIVAL, "rival")
        with tempfile.TemporaryDirectory() as temp:
            directory = write_evidence(Path(temp), artifact, pack)
            self.assertEqual(json.loads((directory / "narrative-preflight.json").read_text())["result"], "blocked")
