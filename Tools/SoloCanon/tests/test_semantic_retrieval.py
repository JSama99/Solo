"""C6 offline candidate retrieval, policy, adapters, and evaluation."""

import json
import socket
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

from canon_store import CanonError, CanonStore, ROOT, canonical_bytes
from validate_canon import LEVELS, make_manifest
from semantic_index import (DEFAULT_INDEX, LocalConceptProvider, build_index, index_path,
                            load_index, provider_identity, validate_index)
from hybrid_retrieval import hybrid_search, hybrid_pack
from codex_preflight import build_preflight
from narrative_preflight import build_narrative_preflight
from visual_preflight import build_visual_preflight
from chaos_preflight import build_chaos_preflight
from evaluate_hybrid import FIXTURE, authority_violations, evaluate, visibility_violations

REPOSITORY = {"worktree": str(ROOT), "branch": "test", "head": "a" * 40,
              "dirty": False, "status_short": []}


def fixture_record(identifier, *, title, summary, level="P1", visibility=None, facts=None):
    return {"schema_version": "0.1", "id": identifier, "type": "system", "title": title,
            "summary": summary, "status": {"P1": "canonical", "P5": "experimental"}[level],
            "authority": {"level": level, "kind": LEVELS[level]},
            "validity": {"valid_from": "2026-10-03", "valid_until": None},
            "visibility": visibility or ["developer"], "facts": facts or {},
            "relationships": [], "constraints": [],
            "sources": [{"kind": "source_file", "path": "source.swift"}] if level == "P1" else [],
            "evidence": [], "supersedes": [], "superseded_by": [], "tags": []}


class SemanticFixture(unittest.TestCase):
    def make_store(self, records):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        (root / "Canon/records").mkdir(parents=True)
        (root / "Canon/manifests").mkdir(parents=True)
        (root / "source.swift").write_text("// fixture\n")
        entries = []
        for record in records:
            path = "Canon/records/" + record["id"] + ".json"
            (root / path).write_bytes(canonical_bytes(record))
            entries.append((path, record))
        (root / "Canon/manifests/canon-manifest.json").write_bytes(canonical_bytes(make_manifest(entries)))
        store = CanonStore(root)
        path = root / DEFAULT_INDEX
        path.parent.mkdir(parents=True)
        path.write_bytes(canonical_bytes(build_index(store, LocalConceptProvider())))
        return store, path


class SemanticRetrievalTests(SemanticFixture):
    @classmethod
    def setUpClass(cls):
        cls.store = CanonStore(ROOT)
        cls.provider = LocalConceptProvider()

    def test_provider_interface(self):
        self.assertEqual(self.provider.provider_id, "solo-local-concepts")
        self.assertIsInstance(self.provider.embed("news broadcast"), dict)

    def test_provider_offline_deterministic(self):
        self.assertEqual(self.provider.embed("news broadcast"), self.provider.embed("news broadcast"))

    def test_index_build(self):
        index = build_index(self.store, self.provider)
        self.assertEqual(len(index["records"]), 45)

    def test_index_manifest_fingerprint(self):
        self.assertEqual(build_index(self.store, self.provider)["canon_manifest_sha256"], self.store.manifest_sha256)

    def test_record_hashes_present(self):
        self.assertTrue(all(len(item["content_sha256"]) == 64 for item in build_index(self.store, self.provider)["records"]))

    def test_stale_index_detected(self):
        index = build_index(self.store, self.provider)
        index["canon_manifest_sha256"] = "0" * 64
        with self.assertRaisesRegex(CanonError, "stale semantic index"):
            validate_index(index, self.store, self.provider)

    def test_stale_index_warns_and_falls_back(self):
        with tempfile.TemporaryDirectory() as temp:
            index = build_index(self.store, self.provider)
            index["canon_manifest_sha256"] = "0" * 64
            path = Path(temp) / "index.json"
            path.write_bytes(canonical_bytes(index))
            result = hybrid_search(self.store, "Signal TV", path=path)
            self.assertEqual(result["semantic_status"], "unavailable")
            self.assertIn("stale semantic index", result["semantic_warning"])
            self.assertEqual(result["records"][0]["record"]["id"], "system.signal_tv")

    def test_structured_fallback_without_index(self):
        result = hybrid_search(self.store, "Signal TV", path=Path("/private/tmp/nonexistent-c6-index.json"))
        self.assertEqual(result["semantic_status"], "unavailable")
        self.assertEqual(result["records"][0]["record"]["id"], "system.signal_tv")

    def test_required_semantic_blocks_without_index(self):
        with self.assertRaises(CanonError):
            hybrid_search(self.store, "Signal TV", path=Path("/private/tmp/nonexistent-c6-index.json"), require_semantic=True)

    def test_semantic_adds_lexical_miss(self):
        query = "test thousands of companies for broken strategies"
        self.assertEqual(self.store.search(query), [])
        self.assertIn("system.chaos_crew", [item["record"]["id"] for item in hybrid_search(self.store, query)["records"]])

    def test_visibility_hidden_match_excluded(self):
        store, path = self.make_store([fixture_record("system.secret", title="Secret news broadcast", summary="Private media", visibility=["simulation_internal"]),
                                       fixture_record("system.public", title="Public", summary="Public information", visibility=["public"])])
        result = hybrid_search(store, "secret news broadcast", scopes=("public",), path=path)
        self.assertNotIn("system.secret", canonical_bytes(result).decode())

    def test_p1_outranks_more_similar_p5(self):
        store, path = self.make_store([fixture_record("system.production", title="Media", summary="Company coverage"),
                                       fixture_record("system.experiment", title="Secret news broadcast", summary="Secret news broadcast", level="P5")])
        ids = [item["record"]["id"] for item in hybrid_search(store, "secret news broadcast", path=path)["records"]]
        self.assertEqual(ids[0], "system.production")

    def test_coverage_ambiguity_unresolved(self):
        result = hybrid_search(self.store, "Coverage")
        self.assertTrue(any(item["truth_key"] == "mechanic.coverage.mutation_authority" for item in result["conflicts"]))

    def test_threshold_filters_weak_match(self):
        low = hybrid_search(self.store, "news", threshold=0.18)
        high = hybrid_search(self.store, "news", threshold=0.95)
        self.assertGreaterEqual(len(low["semantic_candidates"]), len(high["semantic_candidates"]))
        self.assertEqual(high["semantic_candidates"], [])

    def test_reasons_stable(self):
        a = hybrid_search(self.store, "news reacting to the player's company")
        b = hybrid_search(self.store, "news reacting to the player's company")
        self.assertEqual(canonical_bytes(a), canonical_bytes(b))
        self.assertIn("candidate only", canonical_bytes(a).decode())

    def test_provider_in_fingerprint(self):
        a = hybrid_search(self.store, "Signal TV")
        self.assertIn(self.provider.provider_id, canonical_bytes(a).decode())

    def test_provider_change_changes_fingerprint(self):
        class OtherProvider(LocalConceptProvider):
            provider_id = "other-provider"
        a = hybrid_search(self.store, "Signal TV")
        b = hybrid_search(self.store, "Signal TV", provider=OtherProvider())
        self.assertNotEqual(a["query_fingerprint"], b["query_fingerprint"])

    def test_model_change_changes_fingerprint(self):
        class OtherModel(LocalConceptProvider):
            model_id = "other-model"
        a = hybrid_search(self.store, "Signal TV")
        b = hybrid_search(self.store, "Signal TV", provider=OtherModel())
        self.assertNotEqual(a["query_fingerprint"], b["query_fingerprint"])

    def test_threshold_change_changes_fingerprint(self):
        self.assertNotEqual(hybrid_search(self.store, "Signal TV", threshold=0.2)["query_fingerprint"],
                            hybrid_search(self.store, "Signal TV", threshold=0.3)["query_fingerprint"])

    def test_cached_index_stable_ranking(self):
        a = hybrid_search(self.store, "news reacting to the player's company")
        b = hybrid_search(CanonStore(ROOT), "news reacting to the player's company")
        self.assertEqual(canonical_bytes(a), canonical_bytes(b))

    def test_malformed_index_falls_back(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "index.json"
            path.write_text("{broken")
            result = hybrid_search(self.store, "Signal TV", path=path)
            self.assertEqual(result["semantic_status"], "unavailable")

    def test_codex_structured_unchanged(self):
        artifact, pack = build_preflight(self.store, "Signal TV", REPOSITORY)
        self.assertNotIn("retrieval_mode", pack)
        self.assertNotIn("retrieval_mode", artifact)

    def test_codex_hybrid(self):
        artifact, pack = build_preflight(self.store, "news reacting to the player's company", REPOSITORY, semantic=True)
        self.assertEqual(pack["retrieval_mode"], "hybrid")
        self.assertEqual(artifact["semantic_status"], "ready")
        self.assertIn("semantic_candidates", pack)

    def test_narrative_structured_unchanged(self):
        artifact, pack = build_narrative_preflight(self.store, "Report public Coverage", "signal_tv", REPOSITORY)
        self.assertNotIn("retrieval_mode", pack)
        self.assertNotIn("retrieval_mode", artifact)

    def test_narrative_hybrid(self):
        artifact, pack = build_narrative_preflight(self.store, "news reacting to the player's company", "signal_tv", REPOSITORY, semantic=True)
        self.assertEqual(pack["retrieval_mode"], "hybrid")
        self.assertIn("semantic_candidates", pack)
        self.assertEqual(artifact["semantic_status"], "ready")

    def test_visual_adapter_unchanged(self):
        artifact, pack = build_visual_preflight(self.store, "Improve Atlantis lighting", REPOSITORY)
        self.assertNotIn("retrieval_mode", pack)

    def test_chaos_adapter_unchanged(self):
        artifact, pack = build_chaos_preflight(self.store, "Stress test Momentum", REPOSITORY, seed="1")
        self.assertNotIn("retrieval_mode", pack)

    def test_no_network_calls(self):
        with patch.object(socket, "socket", side_effect=AssertionError("network call")):
            self.assertEqual(hybrid_search(self.store, "Signal TV")["semantic_status"], "ready")

    def test_evaluation_fixture_runs(self):
        fixture = json.loads(FIXTURE.read_text())
        report = evaluate(self.store, fixture)
        self.assertEqual(len(report["queries"]), 11)
        self.assertGreater(report["hybrid_recall_at_k"], report["structured_recall_at_k"])

    def test_visibility_evaluation_detects_bypass(self):
        self.assertEqual(visibility_violations(["system.secret"], {"system.public"}), ["system.secret"])

    def test_authority_evaluation_detects_inversion(self):
        store, _ = self.make_store([fixture_record("system.production", title="Media", summary="News"),
                                    fixture_record("system.experiment", title="Media", summary="News", level="P5")])
        self.assertEqual(authority_violations(["system.experiment", "system.production"], store), ["system.production"])

    def test_index_not_canon_evidence(self):
        index = build_index(self.store, self.provider)
        self.assertNotIn("evidence", index)
        self.assertIn(".solo-loop/cache", str(index_path(ROOT)))


if __name__ == "__main__":
    unittest.main()
