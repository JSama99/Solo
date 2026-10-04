import importlib.util
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "validate_canon.py"
spec = importlib.util.spec_from_file_location("validate_canon", MODULE)
canon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(canon)


def record(identifier="system.one", level="P3", status="implemented"):
    return {
        "schema_version": "0.1", "id": identifier, "type": "system", "title": "One",
        "status": status, "authority": {"level": level, "kind": canon.LEVELS[level]},
        "summary": "Fixture", "validity": {"valid_from": "2026-10-03", "valid_until": None},
        "visibility": ["developer"], "facts": {}, "relationships": [], "constraints": [],
        "sources": [], "evidence": [], "supersedes": [], "superseded_by": [], "tags": []
    }


class CanonValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "Canon/records").mkdir(parents=True)
        (self.root / "Canon/manifests").mkdir(parents=True)
        (self.root / "source.swift").write_text("// fixture\n")

    def tearDown(self):
        self.temp.cleanup()

    def put(self, value, name=None):
        path = self.root / "Canon/records" / (name or value["id"] + ".json")
        path.write_text(json.dumps(value))

    def errors(self):
        return "\n".join(canon.validate_tree(self.root, check_manifest=False)[0])

    def test_valid_minimal_record(self):
        self.put(record())
        self.assertEqual(self.errors(), "")

    def test_valid_production_with_provenance(self):
        item = record(level="P1", status="canonical")
        item["sources"] = [{"kind": "source_file", "path": "source.swift"}]
        self.put(item)
        self.assertEqual(self.errors(), "")

    def test_duplicate_id_rejected(self):
        self.put(record(), "first.json")
        self.put(record(), "second.json")
        self.assertIn("duplicate ID", self.errors())

    def test_invalid_authority_rejected(self):
        item = record()
        item["authority"]["kind"] = "owner_locked"
        self.put(item)
        self.assertIn("invalid authority", self.errors())

    def test_unknown_visibility_rejected(self):
        item = record()
        item["visibility"] = ["everyone"]
        self.put(item)
        self.assertIn("invalid visibility", self.errors())

    def test_missing_relationship_rejected(self):
        item = record()
        item["relationships"] = [{"predicate": "depends_on", "target": "system.missing"}]
        self.put(item)
        self.assertIn("unresolved relationship target", self.errors())

    def test_missing_evidence_rejected(self):
        item = record()
        item["evidence"] = ["evidence.missing"]
        self.put(item)
        self.assertIn("missing evidence target", self.errors())

    def test_self_supersession_rejected(self):
        item = record()
        item["supersedes"] = [item["id"]]
        self.put(item)
        self.assertIn("self-supersession", self.errors())

    def test_invalid_date_interval_rejected(self):
        item = record()
        item["validity"] = {"valid_from": "2026-10-03", "valid_until": "2026-10-02"}
        self.put(item)
        self.assertIn("invalid date interval", self.errors())

    def test_missing_p1_provenance_rejected(self):
        self.put(record(level="P1", status="canonical"))
        self.assertIn("missing P0/P1/P2 provenance", self.errors())

    def test_historical_superseded_by_current(self):
        old = record("system.old", level="P6", status="historical")
        old["validity"] = {"valid_from": "2025-01-01", "valid_until": "2026-10-02"}
        old["superseded_by"] = ["system.one"]
        new = record()
        new["supersedes"] = ["system.old"]
        self.put(old)
        self.put(new)
        self.assertEqual(self.errors(), "")

    def test_deterministic_manifest_ordering(self):
        one = record("system.one")
        two = record("system.two")
        two["visibility"] = ["public", "developer"]
        self.put(two)
        self.put(one)
        errors, manifest = canon.validate_tree(self.root, check_manifest=False)
        self.assertEqual(errors, [])
        self.assertEqual([e["id"] for e in manifest["records"]], ["system.one", "system.two"])
        self.assertEqual(manifest["records"][1]["visibility"], ["developer", "public"])
        self.assertEqual(canon.canonical_json(manifest), canon.canonical_json(canon.make_manifest(list(reversed([(e["path"], json.loads((self.root / e["path"]).read_text())) for e in manifest["records"]])))))

    def test_conflicting_active_truth_rejected(self):
        one = record("system.one", "P1", "canonical")
        two = record("system.two", "P1", "canonical")
        for item, value in ((one, "A"), (two, "B")):
            item["sources"] = [{"kind": "source_file", "path": "source.swift"}]
            item["facts"] = {"truth_key": "system.owner", "truth_value": value}
            self.put(item)
        self.assertIn("contradictory active P0/P1", self.errors())

    def test_loop_external_evidence_audits_present_ledger(self):
        item = record()
        relative = ".solo-loop/runs/run-one/evidence.jsonl"
        path = self.root / relative
        path.parent.mkdir(parents=True)
        path.write_text('{"event":"run_created","run_id":"run-one","graph_id":"graph-one"}\n'
                        '{"event":"run_completed","record_sha256":"' + "a" * 64 + '"}\n')
        item["external_evidence"] = [{"system": "solo_loop_v3", "path": relative,
                                      "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                      "run_id": "run-one", "graph_id": "graph-one", "ledger_head": "a" * 64}]
        self.put(item)
        self.assertEqual(self.errors(), "")
        path.write_text(path.read_text() + "\n")
        self.assertIn("external evidence SHA-256 mismatch", self.errors())

    def test_absent_generated_loop_evidence_keeps_auditable_locator(self):
        item = record()
        item["external_evidence"] = [{"system": "solo_loop_v3",
                                      "path": ".solo-loop/runs/run-one/evidence.jsonl",
                                      "sha256": "b" * 64, "run_id": "run-one",
                                      "graph_id": "graph-one", "ledger_head": "a" * 64}]
        self.put(item)
        self.assertEqual(self.errors(), "")


if __name__ == "__main__":
    unittest.main()
