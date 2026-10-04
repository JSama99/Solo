"""C7 runtime-safe Canon projection and regression tests."""

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

from canon_store import CanonError, CanonStore, ROOT, canonical_bytes
from validate_canon import LEVELS, make_manifest
from runtime_projection import build_projection, validate_projection, FIELDS, FORBIDDEN_TEXT
from codex_preflight import build_preflight
from visual_preflight import build_visual_preflight
from narrative_preflight import build_narrative_preflight
from chaos_preflight import build_chaos_preflight
from hybrid_retrieval import hybrid_search
from canon_pack import build_pack

REPOSITORY = {"worktree": str(ROOT), "branch": "test", "head": "a" * 40,
              "dirty": False, "status_short": []}


def record(identifier, *, runtime=True, public=False, level="P1", status=None,
           end=None, facts=None, relations=None, block=None):
    status = status or {"P1": "canonical", "P5": "experimental", "P6": "historical", "P7": "deprecated"}[level]
    visibility = ["developer"] + (["runtime_safe"] if runtime else []) + (["public"] if public else [])
    item = {"schema_version": "0.1", "id": identifier, "type": "system", "title": identifier,
            "summary": "Developer details", "status": status,
            "authority": {"level": level, "kind": LEVELS[level]},
            "validity": {"valid_from": "2026-01-01" if end else "2026-10-03", "valid_until": end},
            "visibility": visibility, "facts": facts or {}, "relationships": relations or [],
            "constraints": ["internal constraint"],
            "sources": [{"kind": "source_file", "path": "source.swift"}] if level == "P1" else [],
            "evidence": [], "supersedes": [], "superseded_by": [], "tags": ["developer"]}
    if runtime:
        item["runtime_projection"] = block if block is not None else {
            "title": "Safe title", "summary": "Safe world identity.", "facts": {"kind": "world"},
            "relationships": [], "tags": ["world"]}
    return item


class RuntimeFixture(unittest.TestCase):
    def fixture_store(self, records):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / "Canon/records").mkdir(parents=True)
        (root / "Canon/manifests").mkdir(parents=True)
        (root / "source.swift").write_text("// fixture\n")
        entries = []
        for item in records:
            path = "Canon/records/" + item["id"] + ".json"
            (root / path).write_bytes(canonical_bytes(item))
            entries.append((path, item))
        (root / "Canon/manifests/canon-manifest.json").write_bytes(canonical_bytes(make_manifest(entries)))
        return CanonStore(root)


class RuntimeProjectionTests(RuntimeFixture):
    @classmethod
    def setUpClass(cls):
        cls.store = CanonStore(ROOT)
        cls.projection = build_projection(cls.store, as_of="2026-10-03")

    def ids(self):
        return self.projection["eligible_record_ids"]

    def projected(self, identifier):
        return next(item for item in self.projection["records"] if item["id"] == identifier)

    def test_valid_build(self):
        self.assertEqual(self.projection["record_count"], 7)

    def test_deterministic_hash(self):
        self.assertEqual(build_projection(self.store, as_of="2026-10-03")["projection_sha256"], self.projection["projection_sha256"])

    def test_byte_identical_output(self):
        self.assertEqual(canonical_bytes(build_projection(self.store, as_of="2026-10-03")),
                         canonical_bytes(build_projection(CanonStore(ROOT), as_of="2026-10-03")))

    def test_runtime_safe_included(self):
        self.assertIn("agent.aurora", self.ids())

    def test_developer_only_excluded(self):
        self.assertNotIn("system.chaos_crew", self.ids())

    def test_public_only_excluded(self):
        self.assertNotIn("entity.public_media_event", self.ids())

    def test_simulation_internal_excluded(self):
        self.assertNotIn("system.simulation", self.ids())

    def test_mixed_record_unsafe_facts_excluded(self):
        self.assertNotIn("current_implementation", self.projected("system.signal_tv")["facts"])

    def test_source_paths_stripped(self):
        output = canonical_bytes(self.projection).decode()
        for term in ("App/", "Tools/", "Documentation/", ".swift", ".blend", ".usdz"):
            with self.subTest(term=term):
                self.assertNotIn(term, output)

    def test_evidence_paths_stripped(self):
        output = canonical_bytes(self.projection).decode()
        self.assertNotIn(".solo-loop/", output)
        self.assertNotIn("external_evidence", output)

    def test_authority_internals_stripped(self):
        self.assertNotIn("authority", self.projected("agent.aurora"))
        self.assertNotIn("visibility", self.projected("agent.aurora"))
        self.assertNotIn("status", self.projected("agent.aurora"))

    def test_hidden_relationship_target_dropped(self):
        edge = {"predicate": "related_to", "target": "system.secret"}
        source = record("system.public", relations=[edge])
        source["runtime_projection"]["relationships"] = [{**edge, "required": False}]
        store = self.fixture_store([source, record("system.secret", runtime=False)])
        projection = build_projection(store)
        self.assertEqual(projection["records"][0]["relationships"], [])
        self.assertNotIn("system.secret", canonical_bytes(projection).decode())

    def test_unsafe_required_relationship_blocks(self):
        edge = {"predicate": "related_to", "target": "system.secret"}
        source = record("system.public", relations=[edge])
        source["runtime_projection"]["relationships"] = [{**edge, "required": True}]
        store = self.fixture_store([source, record("system.secret", runtime=False)])
        with self.assertRaisesRegex(CanonError, "required runtime relationship"):
            build_projection(store)

    def test_valid_safe_relationship_kept(self):
        edge = {"predicate": "related_to", "target": "system.other"}
        source = record("system.public", relations=[edge])
        source["runtime_projection"]["relationships"] = [{**edge, "required": True}]
        store = self.fixture_store([source, record("system.other")])
        projected = build_projection(store)
        self.assertEqual(projected["records"][1]["relationships"], [edge])

    def test_unsupported_relationship_blocks(self):
        source = record("system.public")
        source["runtime_projection"]["relationships"] = [{"predicate": "related_to", "target": "system.other", "required": False}]
        store = self.fixture_store([source, record("system.other")])
        with self.assertRaisesRegex(CanonError, "unsupported runtime projection relationship"):
            build_projection(store)

    def test_historical_excluded(self):
        store = self.fixture_store([record("system.old", level="P6", end="2026-10-02")])
        self.assertEqual(build_projection(store)["record_count"], 0)

    def test_deprecated_excluded(self):
        store = self.fixture_store([record("system.old", level="P7", end="2026-10-02")])
        self.assertEqual(build_projection(store)["record_count"], 0)

    def test_experimental_excluded(self):
        store = self.fixture_store([record("system.study", level="P5")])
        self.assertEqual(build_projection(store)["record_count"], 0)

    def test_blocked_excluded(self):
        store = self.fixture_store([record("system.study", level="P5", status="blocked")])
        self.assertEqual(build_projection(store)["record_count"], 0)

    def test_superseded_excluded(self):
        old = record("system.old")
        new = record("system.new")
        old["superseded_by"] = ["system.new"]
        new["supersedes"] = ["system.old"]
        store = self.fixture_store([old, new])
        self.assertEqual(build_projection(store)["eligible_record_ids"], ["system.new"])

    def test_aurora_identity(self):
        self.assertEqual(self.projected("agent.aurora")["facts"], {"role": "research"})

    def test_stacks_identity(self):
        self.assertEqual(self.projected("agent.stacks")["facts"], {"role": "engineering"})

    def test_brio_identity(self):
        self.assertEqual(self.projected("agent.brio")["facts"], {"role": "marketing"})

    def test_aurora_hidden_details_excluded(self):
        self.assertNotIn("reliability", canonical_bytes(self.projected("agent.aurora")).decode())
        self.assertNotIn("drift", canonical_bytes(self.projected("agent.aurora")).decode())

    def test_signal_tv_identity(self):
        self.assertEqual(self.projected("system.signal_tv")["title"], "Signal TV")

    def test_signal_tv_implementation_excluded(self):
        output = canonical_bytes(self.projected("system.signal_tv")).decode()
        self.assertNotIn("Coverage", output)
        self.assertNotIn("GameStore", output)
        self.assertNotIn("latent", output)

    def test_founder_asset_excluded(self):
        self.assertNotIn("asset.founder.production", self.ids())

    def test_chaos_excluded(self):
        self.assertNotIn("system.chaos_crew", self.ids())

    def test_narrative_director_excluded(self):
        self.assertNotIn("system.narrative_director", self.ids())

    def test_malformed_projection_block_fails_closed(self):
        store = CanonStore(ROOT)
        store.records["agent.aurora"]["runtime_projection"]["facts"] = {"secret": "drift"}
        with self.assertRaises(CanonError):
            build_projection(store, as_of="2026-10-03")

    def test_stale_manifest_blocks(self):
        item = record("system.one")
        store = self.fixture_store([item])
        path = store.root / "Canon/records/system.one.json"
        changed = json.loads(path.read_text())
        changed["summary"] = "Changed"
        path.write_bytes(canonical_bytes(changed))
        with self.assertRaises(CanonError):
            CanonStore(store.root)

    def test_schema_validation_accepts_output(self):
        validate_projection(self.projection)
        schema = json.loads((ROOT / "Canon/schema/runtime-projection.schema.json").read_text())
        self.assertTrue(set(schema["required"]).issubset(self.projection))

    def test_schema_validation_rejects_extra_field(self):
        changed = {**self.projection, "sources": []}
        with self.assertRaises(CanonError):
            validate_projection(changed)

    def test_schema_validation_rejects_bad_hash(self):
        changed = {**self.projection, "projection_sha256": "0" * 64}
        with self.assertRaises(CanonError):
            validate_projection(changed)

    def test_as_of_changes_hash(self):
        self.assertNotEqual(build_projection(self.store, as_of="2026-10-03")["projection_sha256"],
                            build_projection(self.store, as_of="2026-10-04")["projection_sha256"])

    def test_duplicate_projected_ids_block(self):
        store = CanonStore(ROOT)
        store.ids = tuple(list(store.ids) + ["agent.aurora"])
        with self.assertRaisesRegex(CanonError, "duplicate projected ID"):
            build_projection(store, as_of="2026-10-03")

    def test_unreadable_visibility_blocks(self):
        store = CanonStore(ROOT)
        store.records["agent.aurora"]["visibility"] = None
        with self.assertRaisesRegex(CanonError, "visibility cannot be evaluated"):
            build_projection(store, as_of="2026-10-03")

    def test_leakage_scan(self):
        output = canonical_bytes(self.projection).decode()
        self.assertIsNone(FORBIDDEN_TEXT.search(output))

    def test_policy_field_map(self):
        self.assertEqual(FIELDS["sources"], "remove")
        self.assertIn("projection", FIELDS["facts"])

    def test_runtime_pack_uses_projection_only(self):
        pack = build_pack(self.store, consumer="runtime", task="Aurora")
        self.assertEqual(pack["records"][0]["id"], "agent.aurora")
        self.assertEqual(pack["records"][0]["facts"], {"role": "research"})
        self.assertEqual(pack["records"][0]["sources"], [])
        self.assertNotIn("App/", canonical_bytes(pack).decode())

    def test_runtime_pack_does_not_admit_public_only(self):
        pack = build_pack(self.store, consumer="runtime", task="public media event")
        self.assertNotIn("entity.public_media_event", [item["id"] for item in pack["records"]])

    def test_runtime_pack_cannot_request_public_scope(self):
        with self.assertRaises(CanonError):
            build_pack(self.store, consumer="runtime", task="Aurora", visibility="public")

    def test_codex_adapter_unchanged(self):
        artifact, pack = build_preflight(self.store, "Signal TV", REPOSITORY)
        self.assertEqual(artifact["result"], "pass")

    def test_visual_adapter_unchanged(self):
        artifact, pack = build_visual_preflight(self.store, "Improve Atlantis lighting", REPOSITORY)
        self.assertEqual(artifact["result"], "pass")

    def test_narrative_adapter_unchanged(self):
        artifact, pack = build_narrative_preflight(self.store, "Report public Coverage", "signal_tv", REPOSITORY)
        self.assertEqual(artifact["result"], "pass")

    def test_chaos_adapter_unchanged(self):
        artifact, pack = build_chaos_preflight(self.store, "Stress test Momentum", REPOSITORY, seed="1")
        self.assertEqual(artifact["result"], "pass")

    def test_hybrid_retrieval_unchanged(self):
        result = hybrid_search(self.store, "news reacting to the player's company", limit=8)
        self.assertEqual(result["semantic_status"], "ready")
        self.assertIn("mechanic.coverage", [item["record"]["id"] for item in result["records"]])


if __name__ == "__main__":
    unittest.main()
