import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_DIR))

from canon_store import CanonError, CanonStore, canonical_bytes, query_fingerprint
from canon_pack import build_pack, markdown
from validate_canon import LEVELS, make_manifest


def record(identifier, *, level="P1", title=None, summary=None, visibility=None,
           start="2026-10-03", end=None, facts=None, relationships=None, sources=None,
           tags=None, kind="system"):
    status = {"P0": "canonical", "P1": "canonical", "P2": "accepted", "P3": "implemented",
              "P4": "proposed", "P5": "experimental", "P6": "historical", "P7": "deprecated"}[level]
    return {"schema_version": "0.1", "id": identifier, "type": kind,
            "title": title or identifier, "summary": summary or identifier,
            "status": status, "authority": {"level": level, "kind": LEVELS[level]},
            "validity": {"valid_from": start, "valid_until": end},
            "visibility": visibility or ["developer"], "facts": facts or {},
            "relationships": relationships or [], "constraints": [],
            "sources": sources if sources is not None else ([{"kind": "source_file", "path": "source.swift"}] if level in {"P0", "P1", "P2"} else []),
            "evidence": [], "supersedes": [], "superseded_by": [], "tags": tags or []}


class RetrievalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "Canon/records").mkdir(parents=True)
        (self.root / "Canon/manifests").mkdir(parents=True)
        (self.root / "source.swift").write_text("// fixture\n")
        self.items = {}

    def tearDown(self):
        self.temp.cleanup()

    def add(self, item):
        self.items[item["id"]] = item
        return item

    def store(self):
        entries = []
        for identifier, item in sorted(self.items.items()):
            path = "Canon/records/" + identifier + ".json"
            (self.root / path).write_text(json.dumps(item, sort_keys=True))
            entries.append((path, item))
        (self.root / "Canon/manifests/canon-manifest.json").write_bytes(canonical_bytes(make_manifest(entries)))
        return CanonStore(self.root)

    def test_exact_id_lookup(self):
        self.add(record("system.signal_tv", title="Signal TV"))
        self.assertEqual(self.store().get_id("system.signal_tv")[0]["record"]["id"], "system.signal_tv")

    def test_unknown_id_returns_no_result(self):
        self.add(record("system.one"))
        self.assertEqual(self.store().get_id("system.missing"), [])

    def test_lexical_search_order_is_stable(self):
        self.add(record("system.beta", title="Coverage"))
        self.add(record("system.alpha", title="Coverage"))
        store = self.store()
        first = [item["record"]["id"] for item in store.search("coverage")]
        self.assertEqual(first, ["system.alpha", "system.beta"])
        self.assertEqual(first, [item["record"]["id"] for item in CanonStore(self.root).search("coverage")])

    def test_authority_precedes_lexical_score(self):
        self.add(record("system.production", summary="Coverage is governed here"))
        self.add(record("system.experiment", level="P5", title="Coverage", summary="Coverage Coverage"))
        self.assertEqual(self.store().search("coverage")[0]["record"]["id"], "system.production")

    def test_visibility_excludes_hidden_record(self):
        self.add(record("system.hidden", title="Secret", visibility=["simulation_internal"]))
        self.assertEqual(self.store().search("secret", scopes=("public",)), [])

    def test_historical_excluded_by_default(self):
        self.add(record("system.old", level="P6", title="Old Camera", start="2025-01-01", end="2026-09-30"))
        self.assertEqual(self.store().search("camera"), [])

    def test_as_of_retrieves_historical_valid_record(self):
        self.add(record("system.old", level="P6", title="Old Camera", start="2025-01-01", end="2026-09-30"))
        self.assertEqual(self.store().search("camera", as_of="2026-09-20")[0]["record"]["id"], "system.old")

    def test_superseded_record_does_not_resolve_current(self):
        old = self.add(record("system.old", level="P6", title="Camera", start="2025-01-01", end="2026-10-02"))
        new = self.add(record("system.new", title="Camera"))
        old["superseded_by"] = ["system.new"]
        new["supersedes"] = ["system.old"]
        self.assertEqual(self.store().resolve("camera")["records"][0]["id"], "system.new")

    def test_unresolved_high_authority_conflict_surfaces(self):
        self.add(record("rule.one", facts={"truth_key": "coverage.owner", "truth_value": "A"}, summary="Coverage owner A", kind="rule"))
        self.add(record("rule.two", facts={"truth_key": "coverage.owner", "truth_value": "B"}, summary="Coverage owner B", kind="rule"))
        result = self.store().resolve("coverage")
        self.assertEqual(result["result"], "conflict")
        self.assertEqual([item["id"] for item in result["records"]], ["rule.one", "rule.two"])

    def test_hidden_conflict_side_is_not_disclosed(self):
        self.add(record("rule.public", title="Coverage", visibility=["public"],
                        facts={"truth_key": "coverage.owner", "truth_value": "A"}, kind="rule"))
        self.add(record("rule.secret", title="Coverage", visibility=["simulation_internal"],
                        facts={"truth_key": "coverage.owner", "truth_value": "B"}, kind="rule"))
        result = self.store().resolve("coverage", scopes=("public",))
        self.assertEqual(result["result"], "resolved")
        self.assertNotIn("rule.secret", canonical_bytes(result).decode())

    def test_relationship_expansion(self):
        self.add(record("system.signal", title="Signal", relationships=[{"predicate": "reads", "target": "mechanic.coverage"}]))
        self.add(record("mechanic.coverage", title="Coverage", kind="mechanic"))
        result = self.store().get_id("system.signal", related_depth=1)
        self.assertEqual([item["record"]["id"] for item in result], ["system.signal", "mechanic.coverage"])
        self.assertIn("related from system.signal via reads", result[1]["reasons"])

    def test_hidden_relationship_target_does_not_leak(self):
        self.add(record("system.public", title="Public", visibility=["public"], relationships=[{"predicate": "reads", "target": "system.secret"}]))
        self.add(record("system.secret", title="Secret", visibility=["simulation_internal"]))
        result = self.store().get_id("system.public", scopes=("public",), related_depth=1)
        self.assertEqual(len(result), 1)
        self.assertNotIn("system.secret", canonical_bytes(result).decode())
        self.assertEqual(self.store().search("secret", scopes=("public",)), [])

    def test_include_historical_does_not_admit_future_record(self):
        self.add(record("system.future", title="Future Camera", start="2027-01-01"))
        self.assertEqual(self.store().search("camera", as_of="2026-10-03", include_historical=True), [])

    def test_metadata_filters_compose(self):
        self.add(record("mechanic.coverage", title="Coverage", kind="mechanic", tags=["finance"]))
        self.add(record("system.coverage", title="Coverage", tags=["finance"]))
        self.add(record("mechanic.other", title="Coverage", kind="mechanic"))
        result = self.store().search("coverage", filters={"type": "mechanic", "authority": "P1", "tag": "finance"})
        self.assertEqual([item["record"]["id"] for item in result], ["mechanic.coverage"])

    def test_identical_json_pack_bytes(self):
        self.add(record("system.signal_tv", title="Signal TV"))
        store = self.store()
        one = canonical_bytes(build_pack(store, consumer="codex", task="Signal TV"))
        two = canonical_bytes(build_pack(CanonStore(self.root), consumer="codex", task="Signal TV"))
        self.assertEqual(one, two)

    def test_identical_markdown_pack_bytes(self):
        self.add(record("system.signal_tv", title="Signal TV"))
        store = self.store()
        self.assertEqual(markdown(build_pack(store, consumer="codex", task="Signal TV")),
                         markdown(build_pack(CanonStore(self.root), consumer="codex", task="Signal TV")))

    def test_manifest_change_changes_query_fingerprint(self):
        options = dict(as_of="2026-10-03", scopes=("developer",), filters={}, include_historical=False)
        self.assertNotEqual(query_fingerprint("a" * 64, "search", "coverage", **options),
                            query_fingerprint("b" * 64, "search", "coverage", **options))

    def test_record_edit_stales_manifest_and_changes_fingerprint(self):
        self.add(record("system.one", summary="Original fact"))
        before = self.store().manifest_sha256
        self.items["system.one"]["summary"] = "Changed fact"
        (self.root / "Canon/records/system.one.json").write_text(json.dumps(self.items["system.one"], sort_keys=True))
        with self.assertRaises(CanonError):
            CanonStore(self.root)
        after = self.store().manifest_sha256
        self.assertNotEqual(before, after)

    def test_runtime_profile_cannot_read_developer_record(self):
        self.add(record("system.secret", title="Secret", visibility=["developer"]))
        self.assertEqual(build_pack(self.store(), consumer="runtime", task="secret")["records"], [])

    def test_codex_profile_finds_signal_tv(self):
        self.add(record("system.signal_tv", title="Signal TV public media"))
        pack = build_pack(self.store(), consumer="codex", task="Implement Signal TV media narrative integration")
        self.assertIn("system.signal_tv", [item["id"] for item in pack["records"]])

    def test_pack_record_limit(self):
        self.add(record("system.one", title="Signal"))
        self.add(record("system.two", title="Signal"))
        self.assertEqual(len(build_pack(self.store(), consumer="codex", task="signal", max_records=1)["records"]), 1)

    def test_malformed_canon_fails_closed(self):
        item = self.add(record("system.bad"))
        item["sources"] = [{"kind": "source_file", "path": "missing.swift"}]
        with self.assertRaises(CanonError):
            self.store()


if __name__ == "__main__":
    unittest.main()
